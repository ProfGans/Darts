import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../../domain/x01/x01_models.dart';
import '../debug/app_debug.dart';
import '../repositories/computer_repository.dart';
import '../repositories/settings_repository.dart';
import 'background_task_runner.dart';

abstract class SimulationTaskExecutor {
  Future<Map<String, Object?>?> readPersistedSimulationTables();

  Future<T> runJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  });

  Future<T> runPersistentJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  });

  Future<void> prewarmSimulationWorker({
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  });

  Future<void> disposeSimulationWorker();
}

class DefaultSimulationTaskExecutor implements SimulationTaskExecutor {
  const DefaultSimulationTaskExecutor();

  @override
  Future<Map<String, Object?>?> readPersistedSimulationTables() {
    return BackgroundTaskRunner.instance.readPersistedSimulationTables();
  }

  @override
  Future<T> runJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    return BackgroundTaskRunner.instance.runJob<T>(
      taskType: taskType,
      initialLabel: initialLabel,
      payload: payload,
      onUpdate: onUpdate,
    );
  }

  @override
  Future<T> runPersistentJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    return BackgroundTaskRunner.instance.runSimulationWorkerJob<T>(
      taskType: taskType,
      initialLabel: initialLabel,
      payload: payload,
      onUpdate: onUpdate,
    );
  }

  @override
  Future<void> prewarmSimulationWorker({
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    return BackgroundTaskRunner.instance.prewarmSimulationWorker(
      payload: payload,
      onUpdate: onUpdate,
    );
  }

  @override
  Future<void> disposeSimulationWorker() {
    return BackgroundTaskRunner.instance.disposeSimulationWorker();
  }
}

class SimulationJobHandle<T> extends ChangeNotifier {
  SimulationJobHandle._({
    required this.id,
    required this.taskType,
    required this.initialLabel,
  });

  final String id;
  final String taskType;
  final String initialLabel;
  final Completer<T> _completer = Completer<T>();

  String _label = '';
  double? _progress;
  bool _inProgress = true;
  Object? _error;
  StackTrace? _stackTrace;

  Future<T> get result => _completer.future;
  String get label => _label.isEmpty ? initialLabel : _label;
  double? get progress => _progress;
  bool get inProgress => _inProgress;
  bool get isCompleted => _completer.isCompleted;
  Object? get error => _error;
  StackTrace? get stackTrace => _stackTrace;

  void update(BackgroundTaskSnapshot snapshot) {
    _label = snapshot.label;
    _progress = snapshot.progress;
    _inProgress = snapshot.inProgress;
    notifyListeners();
  }

  void complete(T value) {
    _inProgress = false;
    _progress ??= 1;
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
    notifyListeners();
  }

  void fail(Object error, [StackTrace? stackTrace]) {
    _inProgress = false;
    _error = error;
    _stackTrace = stackTrace;
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
    notifyListeners();
  }
}

class SimulationService extends ChangeNotifier {
  SimulationService({
    SimulationTaskExecutor? executor,
  }) : _executor = executor ?? const DefaultSimulationTaskExecutor();

  static final SimulationService instance = SimulationService();

  static const int _maxProfiles = 12;
  static const Duration _workerRestartBackoff = Duration(milliseconds: 150);

  final SimulationTaskExecutor _executor;
  final Map<String, SimulationJobHandle<dynamic>> _jobsById =
      <String, SimulationJobHandle<dynamic>>{};

  Map<String, Object?>? _tables;
  Future<void>? _startupWarmupFuture;
  SimulationJobHandle<void>? _warmupJob;
  int _jobSequence = 0;

  bool get hasWarmupData => _tables != null;
  bool get isWarmupRunning =>
      _startupWarmupFuture != null || (_warmupJob?.inProgress ?? false);
  SimulationJobHandle<void>? get warmupJob => _warmupJob;
  List<SimulationJobHandle<dynamic>> get activeJobs =>
      _jobsById.values.where((job) => job.inProgress).toList(growable: false);

  Future<void> initialize() async {
    final storedTables = await _executor.readPersistedSimulationTables();
    if (isValidSimulationWarmupSnapshot(storedTables)) {
      _tables = storedTables;
      AppDebug.instance.info('Warmup', 'Persistente Warm-up-Daten gefunden');
    } else {
      _tables = null;
      AppDebug.instance.info('Warmup', 'Keine gueltigen Warm-up-Daten gefunden');
    }
    notifyListeners();
  }

  void applyToBotEngine(BotEngine botEngine) {
    final botTables = _botTables;
    if (botTables == null) {
      return;
    }
    botEngine.importDeterministicTables(botTables);
  }

  void applyToX01MatchSimulator(X01MatchSimulator simulator) {
    applyToBotEngine(simulator.botEngine);
    final x01Tables = _x01Tables;
    if (x01Tables == null) {
      return;
    }
    simulator.importDeterministicTables(x01Tables);
  }

  Future<void> startWarmupIfNeeded() {
    if (hasWarmupData) {
      return Future<void>.value();
    }
    final existing = _startupWarmupFuture;
    if (existing != null) {
      return existing;
    }
    final future = _runStartupWarmup();
    _startupWarmupFuture = future;
    return future;
  }

  Future<void> prewarmProfiles(
    Map<String, Object?> profilesById, {
    String initialLabel = 'Simulationsdaten werden vorbereitet',
    void Function(SimulationJobHandle<void> handle)? onHandle,
  }) async {
    if (profilesById.isEmpty) {
      return;
    }
    final handle = _startTrackedJob<void>(
      taskType: 'prepare_simulation',
      initialLabel: initialLabel,
      runner: (onUpdate) => _runPersistentWarmupWithRecovery(
        payload: <String, Object?>{
          'profilesById': profilesById,
        },
        onUpdate: onUpdate,
      ),
    );
    onHandle?.call(handle);
    await handle.result;

    final storedTables = await _executor.readPersistedSimulationTables();
    if (isValidSimulationWarmupSnapshot(storedTables)) {
      _tables = storedTables;
      notifyListeners();
    }
  }

  SimulationJobHandle<T> startJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
  }) {
    return _startTrackedJob<T>(
      taskType: taskType,
      initialLabel: initialLabel,
      runner: (onUpdate) => _executor.runJob<T>(
        taskType: taskType,
        initialLabel: initialLabel,
        payload: payload,
        onUpdate: onUpdate,
      ),
    );
  }

  SimulationJobHandle<T> startPersistentJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
  }) {
    return _startTrackedJob<T>(
      taskType: taskType,
      initialLabel: initialLabel,
      runner: (onUpdate) => _runPersistentJobWithRecovery<T>(
        taskType: taskType,
        initialLabel: initialLabel,
        payload: payload,
        onUpdate: onUpdate,
      ),
    );
  }

  SimulationJobHandle<T> _startTrackedJob<T>({
    required String taskType,
    required String initialLabel,
    required Future<T> Function(
      void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
    ) runner,
  }) {
    final handle = SimulationJobHandle<T>._(
      id: 'simulation-job-${_jobSequence++}',
      taskType: taskType,
      initialLabel: initialLabel,
    );
    _jobsById[handle.id] = handle;
    notifyListeners();

    unawaited(() async {
      try {
        final value = await runner(handle.update);
        handle.complete(value);
      } catch (error, stackTrace) {
        handle.fail(error, stackTrace);
      } finally {
        _jobsById.remove(handle.id);
        notifyListeners();
      }
    }());
    return handle;
  }

  Future<T> _runPersistentJobWithRecovery<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    try {
      return await _executor.runPersistentJob<T>(
        taskType: taskType,
        initialLabel: initialLabel,
        payload: payload,
        onUpdate: onUpdate,
      );
    } catch (error) {
      AppDebug.instance.warning(
        'SimulationWorker',
        'Worker-Job "$taskType" wird nach Fehler neu versucht: $error',
      );
      await _executor.disposeSimulationWorker();
      await Future<void>.delayed(_workerRestartBackoff);
      return _executor.runPersistentJob<T>(
        taskType: taskType,
        initialLabel: initialLabel,
        payload: payload,
        onUpdate: onUpdate,
      );
    }
  }

  Future<void> _runStartupWarmup() async {
    final profilesById = _buildWarmupProfilesPayload();
    if (profilesById.isEmpty) {
      _startupWarmupFuture = null;
      return;
    }
    try {
      AppDebug.instance.info(
        'Warmup',
        'Starte Simulation-Warm-up im Hintergrund | Profile=${profilesById.length}',
      );
      final handle = _startTrackedJob<void>(
        taskType: 'prepare_simulation',
        initialLabel: 'Simulationsdaten werden vorbereitet',
        runner: (onUpdate) => _runPersistentWarmupWithRecovery(
          payload: <String, Object?>{
            'profilesById': profilesById,
          },
          onUpdate: onUpdate,
        ),
      );
      _warmupJob = handle;
      notifyListeners();
      await handle.result;

      final storedTables = await _executor.readPersistedSimulationTables();
      if (isValidSimulationWarmupSnapshot(storedTables)) {
        _tables = storedTables;
        AppDebug.instance.info('Warmup', 'Simulation-Warm-up abgeschlossen');
      } else {
        AppDebug.instance.warning(
          'Warmup',
          'Warm-up lief, aber es wurden keine gueltigen Tabellen gespeichert.',
        );
      }
    } catch (error) {
      AppDebug.instance.error('Warmup', error.toString());
    } finally {
      _warmupJob = null;
      _startupWarmupFuture = null;
      notifyListeners();
    }
  }

  Future<void> _runPersistentWarmupWithRecovery({
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    try {
      await _executor.prewarmSimulationWorker(
        payload: payload,
        onUpdate: onUpdate,
      );
    } catch (error) {
      AppDebug.instance.warning(
        'SimulationWorker',
        'Warm-up wird nach Worker-Fehler neu versucht: $error',
      );
      await _executor.disposeSimulationWorker();
      await Future<void>.delayed(_workerRestartBackoff);
      await _executor.prewarmSimulationWorker(
        payload: payload,
        onUpdate: onUpdate,
      );
    }
  }

  Map<String, Object?> _buildWarmupProfilesPayload() {
    final profilesByKey = <String, BotProfile>{};

    void addProfile(BotProfile profile) {
      if (profilesByKey.length >= _maxProfiles) {
        return;
      }
      final key = _profileKey(profile);
      profilesByKey.putIfAbsent(key, () => profile);
    }

    addProfile(
      SettingsRepository.instance.createBotProfile(
        skill: 420,
        finishingSkill: 360,
      ),
    );
    addProfile(
      SettingsRepository.instance.createBotProfile(
        skill: 700,
        finishingSkill: 520,
      ),
    );
    addProfile(
      SettingsRepository.instance.createBotProfile(
        skill: 920,
        finishingSkill: 860,
      ),
    );

    for (final player in ComputerRepository.instance.players) {
      addProfile(
        SettingsRepository.instance.createBotProfile(
          skill: player.skill,
          finishingSkill: player.finishingSkill,
        ),
      );
      if (profilesByKey.length >= _maxProfiles) {
        break;
      }
    }

    return <String, Object?>{
      for (final entry in profilesByKey.entries)
        entry.key: <String, Object?>{
          'skill': entry.value.skill,
          'finishingSkill': entry.value.finishingSkill,
          'radiusCalibrationPercent': entry.value.radiusCalibrationPercent,
          'simulationSpreadPercent': entry.value.simulationSpreadPercent,
        },
    };
  }

  String _profileKey(BotProfile profile) {
    return [
      profile.skill,
      profile.finishingSkill,
      profile.radiusCalibrationPercent,
      profile.simulationSpreadPercent,
    ].join(':');
  }

  Map<String, Object?>? get _botTables {
    final source = _tables;
    if (source == null) {
      return null;
    }
    final bot = source['bot'];
    if (bot is! Map) {
      return null;
    }
    return bot.cast<String, Object?>();
  }

  Map<String, Object?>? get _x01Tables {
    final source = _tables;
    if (source == null) {
      return null;
    }
    final x01 = source['x01'];
    if (x01 is! Map) {
      return null;
    }
    return x01.cast<String, Object?>();
  }
}

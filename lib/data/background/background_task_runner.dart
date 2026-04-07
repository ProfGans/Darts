import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/app_storage.dart';
import '../debug/app_debug.dart';
import 'simulation_snapshot.dart';
import '../../domain/bot/bot_engine.dart';
import '../../domain/tournament/tournament_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/checkout_planner.dart';
import '../../domain/x01/x01_match_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';

class BackgroundTaskSnapshot {
  const BackgroundTaskSnapshot({
    required this.taskType,
    required this.label,
    required this.inProgress,
    this.progress,
  });

  final String taskType;
  final String label;
  final bool inProgress;
  final double? progress;
}

bool isValidSimulationWarmupSnapshot(Map<String, Object?>? snapshot) {
  if (snapshot == null || snapshot.isEmpty) {
    return false;
  }
  final version = (snapshot['version'] as num?)?.toInt();
  final schema = snapshot['schema'] as String?;
  final bot = snapshot['bot'];
  final x01 = snapshot['x01'];
  if (version != simulationWarmupSnapshotVersion) {
    return false;
  }
  if (schema != simulationWarmupSnapshotSchema) {
    return false;
  }
  if (bot is! Map || x01 is! Map) {
    return false;
  }
  return bot.isNotEmpty && x01.isNotEmpty;
}

class BackgroundTaskRunner extends ChangeNotifier {
  BackgroundTaskRunner._();

  static final BackgroundTaskRunner instance = BackgroundTaskRunner._();
  static const String _simulationTablesStorageKey = 'simulation_warmup_tables';

  String? _activeTaskType;
  String _label = '';
  bool _inProgress = false;
  double? _progress;
  Isolate? _simulationWorkerIsolate;
  SendPort? _simulationWorkerSendPort;
  Future<void>? _simulationWorkerStartup;
  StreamSubscription<dynamic>? _simulationWorkerErrorSub;
  StreamSubscription<dynamic>? _simulationWorkerExitSub;
  ReceivePort? _simulationWorkerErrorPort;
  ReceivePort? _simulationWorkerExitPort;
  bool _persistentSimulationTablesLoaded = false;
  Future<void>? _persistentSimulationTablesLoadFuture;
  final Set<String> _warmedSimulationProfileKeys = <String>{};
  bool _simulationMatchPathWarmed = false;

  String? get activeTaskType => _activeTaskType;
  String get label => _label;
  bool get inProgress => _inProgress;
  double? get progress => _progress;

  Future<Map<String, Object?>?> readPersistedSimulationTables() async {
    final json = await AppStorage.instance.readJsonMap(_simulationTablesStorageKey);
    return json?.cast<String, Object?>();
  }

  void _publish({
    required String taskType,
    required String label,
    required bool inProgress,
    double? progress,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
    _activeTaskType = inProgress ? taskType : null;
    _label = label;
    _inProgress = inProgress;
    _progress = normalizedProgress;
    final snapshot = BackgroundTaskSnapshot(
      taskType: taskType,
      label: label,
      inProgress: inProgress,
      progress: normalizedProgress,
    );
    onUpdate?.call(snapshot);
    notifyListeners();
  }

  Future<T> runJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<T>();
    Isolate? isolate;

    _publish(
      taskType: taskType,
      label: initialLabel,
      inProgress: true,
      progress: 0,
      onUpdate: onUpdate,
    );

    late final StreamSubscription<dynamic> receiveSub;
    late final StreamSubscription<dynamic> errorSub;
    late final StreamSubscription<dynamic> exitSub;

    Future<void> cleanup() async {
      await receiveSub.cancel();
      await errorSub.cancel();
      await exitSub.cancel();
      receivePort.close();
      errorPort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    receiveSub = receivePort.listen((dynamic message) async {
      if (message is! Map) {
        return;
      }
      final type = message['type'];
      if (type == 'progress') {
        _publish(
          taskType: taskType,
          label: (message['label'] as String?) ?? initialLabel,
          inProgress: true,
          progress: (message['progress'] as num?)?.toDouble(),
          onUpdate: onUpdate,
        );
        return;
      }
      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(message['value'] as T);
        }
        return;
      }
      if (type == 'error' && !completer.isCompleted) {
        completer.completeError(
          StateError((message['message'] as String?) ?? 'Background task failed.'),
        );
      }
    });

    errorSub = errorPort.listen((dynamic error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    exitSub = exitPort.listen((dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Background task "$taskType" ended unexpectedly.'),
        );
      }
    });

    isolate = await Isolate.spawn<_BackgroundTaskRequest>(
      _backgroundTaskEntry,
      _BackgroundTaskRequest(
        taskType: taskType,
        payload: payload,
        sendPort: receivePort.sendPort,
      ),
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    try {
      final result = await completer.future;
      _publish(
        taskType: taskType,
        label: initialLabel,
        inProgress: false,
        progress: 1,
        onUpdate: onUpdate,
      );
      return result;
    } finally {
      await cleanup();
      _publish(
        taskType: taskType,
        label: '',
        inProgress: false,
        progress: null,
        onUpdate: onUpdate,
      );
    }
  }

  Future<T> runSimulationWorkerJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    await _ensureSimulationWorker();
    await _ensurePersistentSimulationTablesLoaded();
    final workerPort = _simulationWorkerSendPort;
    if (workerPort == null) {
      throw StateError('Simulation worker konnte nicht gestartet werden.');
    }

    final receivePort = ReceivePort();
    final completer = Completer<T>();

    _publish(
      taskType: taskType,
      label: initialLabel,
      inProgress: true,
      progress: 0,
      onUpdate: onUpdate,
    );

    late final StreamSubscription<dynamic> receiveSub;
    receiveSub = receivePort.listen((dynamic message) async {
      if (message is! Map) {
        return;
      }
      final type = message['type'];
      if (type == 'progress') {
        _publish(
          taskType: taskType,
          label: (message['label'] as String?) ?? initialLabel,
          inProgress: true,
          progress: (message['progress'] as num?)?.toDouble(),
          onUpdate: onUpdate,
        );
        return;
      }
      if (type == 'result' && !completer.isCompleted) {
        await _persistSimulationTablesFromWorkerResult(message['value']);
        completer.complete(message['value'] as T);
        return;
      }
      if (type == 'error' && !completer.isCompleted) {
        completer.completeError(
          StateError((message['message'] as String?) ?? 'Worker-Fehler'),
        );
      }
    });

    workerPort.send(<String, Object?>{
      'taskType': taskType,
      'payload': payload,
      'replyTo': receivePort.sendPort,
    });

    try {
      final result = await completer.future;
      _publish(
        taskType: taskType,
        label: initialLabel,
        inProgress: false,
        progress: 1,
        onUpdate: onUpdate,
      );
      return result;
    } finally {
      await receiveSub.cancel();
      receivePort.close();
      _publish(
        taskType: taskType,
        label: '',
        inProgress: false,
        progress: null,
        onUpdate: onUpdate,
      );
    }
  }

  Future<void> _ensureSimulationWorker() async {
    if (_simulationWorkerSendPort != null) {
      AppDebug.instance.info('Trace', 'Simulation-Worker reuse');
      return;
    }
    if (_simulationWorkerStartup != null) {
      AppDebug.instance.info('Trace', 'Simulation-Worker wartet auf laufenden Start');
      await _simulationWorkerStartup;
      return;
    }
    final workerStartStopwatch = Stopwatch()..start();
    AppDebug.instance.info('Trace', 'Simulation-Worker Start');
    final startupCompleter = Completer<void>();
    _simulationWorkerStartup = startupCompleter.future;
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    _simulationWorkerErrorPort = errorPort;
    _simulationWorkerExitPort = exitPort;

    late final StreamSubscription<dynamic> receiveSub;

    receiveSub = receivePort.listen((dynamic message) {
      if (message is Map && message['type'] == 'ready') {
        final port = message['sendPort'];
        if (port is SendPort) {
          _simulationWorkerSendPort = port;
          if (!startupCompleter.isCompleted) {
            startupCompleter.complete();
          }
        }
      }
    });
    _simulationWorkerErrorSub = errorPort.listen((dynamic error) {
      _simulationWorkerSendPort = null;
      _simulationWorkerIsolate = null;
      if (!startupCompleter.isCompleted) {
        startupCompleter.completeError(error);
      }
    });
    _simulationWorkerExitSub = exitPort.listen((dynamic _) {
      _simulationWorkerSendPort = null;
      _simulationWorkerIsolate = null;
      if (!startupCompleter.isCompleted) {
        startupCompleter.completeError(
          StateError('Simulation worker wurde unerwartet beendet.'),
        );
      }
    });

    try {
      _simulationWorkerIsolate = await Isolate.spawn<_PersistentWorkerInit>(
        _simulationWorkerEntry,
        _PersistentWorkerInit(sendPort: receivePort.sendPort),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
      await startupCompleter.future;
      workerStartStopwatch.stop();
      AppDebug.instance.info(
        'Trace',
        'Simulation-Worker bereit | Dauer=${workerStartStopwatch.elapsedMilliseconds} ms',
      );
    } finally {
      await receiveSub.cancel();
      receivePort.close();
      _simulationWorkerStartup = null;
      if (_simulationWorkerSendPort == null) {
        await _simulationWorkerErrorSub?.cancel();
        await _simulationWorkerExitSub?.cancel();
        _simulationWorkerErrorSub = null;
        _simulationWorkerExitSub = null;
        errorPort.close();
        exitPort.close();
        _simulationWorkerErrorPort = null;
        _simulationWorkerExitPort = null;
      }
    }
  }

  Future<void> disposeSimulationWorker() async {
    final workerPort = _simulationWorkerSendPort;
    final isolate = _simulationWorkerIsolate;
    _simulationWorkerSendPort = null;
    _simulationWorkerIsolate = null;
    if (workerPort != null) {
      workerPort.send(const <String, Object?>{'type': 'dispose'});
    }
    isolate?.kill(priority: Isolate.immediate);
    await _simulationWorkerErrorSub?.cancel();
    await _simulationWorkerExitSub?.cancel();
    _simulationWorkerErrorSub = null;
    _simulationWorkerExitSub = null;
    _simulationWorkerErrorPort?.close();
    _simulationWorkerExitPort?.close();
    _simulationWorkerErrorPort = null;
    _simulationWorkerExitPort = null;
    _persistentSimulationTablesLoaded = false;
    _persistentSimulationTablesLoadFuture = null;
    _warmedSimulationProfileKeys.clear();
    _simulationMatchPathWarmed = false;
  }

  Future<void> prewarmSimulationWorker({
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    await _ensureSimulationWorker();
    await _ensurePersistentSimulationTablesLoaded();
    final requestedProfiles =
        ((payload['profilesById'] as Map?) ?? const <Object?, Object?>{})
            .cast<Object?, Object?>()
            .keys
            .map((entry) => entry.toString())
            .toSet();
    final missingProfiles = requestedProfiles
        .where((entry) => !_warmedSimulationProfileKeys.contains(entry))
        .toList(growable: false);
    if (_simulationMatchPathWarmed && missingProfiles.isEmpty) {
      AppDebug.instance.info(
        'Trace',
        'Simulation-Prewarm Skip | Grund=bereits warm | Profile=${requestedProfiles.length}',
      );
      return;
    }
    final workerPort = _simulationWorkerSendPort;
    if (workerPort == null) {
      throw StateError('Simulation worker konnte nicht gestartet werden.');
    }
    final receivePort = ReceivePort();
    final completer = Completer<void>();
    _publish(
      taskType: 'prepare_simulation',
      label: 'Simulationsdaten werden vorbereitet',
      inProgress: true,
      progress: 0,
      onUpdate: onUpdate,
    );
    late final StreamSubscription<dynamic> receiveSub;
    receiveSub = receivePort.listen((dynamic message) async {
      if (message is! Map) {
        return;
      }
      final type = message['type'];
      if (type == 'progress') {
        _publish(
          taskType: 'prepare_simulation',
          label:
              (message['label'] as String?) ?? 'Simulationsdaten werden vorbereitet',
          inProgress: true,
          progress: (message['progress'] as num?)?.toDouble(),
          onUpdate: onUpdate,
        );
        return;
      }
      if (type == 'result' && !completer.isCompleted) {
        await _persistSimulationTablesFromWorkerResult(message['value']);
        completer.complete();
        return;
      }
      if (type == 'error' && !completer.isCompleted) {
        completer.completeError(
          StateError((message['message'] as String?) ?? 'Worker-Fehler'),
        );
      }
    });

    workerPort.send(<String, Object?>{
      'taskType': 'prepare_simulation',
      'payload': payload,
      'replyTo': receivePort.sendPort,
    });

    try {
      await completer.future;
      _publish(
        taskType: 'prepare_simulation',
        label: 'Simulationsdaten sind bereit',
        inProgress: false,
        progress: 1,
        onUpdate: onUpdate,
      );
    } finally {
      await receiveSub.cancel();
      receivePort.close();
      _publish(
        taskType: 'prepare_simulation',
        label: '',
        inProgress: false,
        progress: null,
        onUpdate: onUpdate,
      );
    }
  }

  Future<void> _ensurePersistentSimulationTablesLoaded() async {
    if (_persistentSimulationTablesLoaded) {
      return;
    }
    if (_persistentSimulationTablesLoadFuture != null) {
      await _persistentSimulationTablesLoadFuture;
      return;
    }
    _persistentSimulationTablesLoadFuture = _loadPersistentSimulationTables();
    try {
      await _persistentSimulationTablesLoadFuture;
    } finally {
      _persistentSimulationTablesLoadFuture = null;
    }
  }

  Future<void> _loadPersistentSimulationTables() async {
    final workerPort = _simulationWorkerSendPort;
    if (workerPort == null) {
      return;
    }
    final json = await AppStorage.instance.readJsonMap(_simulationTablesStorageKey);
    final normalizedJson = json?.cast<String, Object?>();
    if (!isValidSimulationWarmupSnapshot(normalizedJson)) {
      if (normalizedJson != null) {
        AppDebug.instance.warning(
          'Warmup',
          'Ungueltiger persistierter Snapshot wird verworfen.',
        );
        await AppStorage.instance.delete(_simulationTablesStorageKey);
      }
      _persistentSimulationTablesLoaded = true;
      return;
    }
    final receivePort = ReceivePort();
    final completer = Completer<void>();
    late final StreamSubscription<dynamic> receiveSub;
    receiveSub = receivePort.listen((dynamic message) {
      if (message is! Map) {
        return;
      }
      final type = message['type'];
      if (type == 'result' && !completer.isCompleted) {
        completer.complete();
        return;
      }
      if (type == 'error' && !completer.isCompleted) {
        completer.completeError(
          StateError((message['message'] as String?) ?? 'Worker-Fehler'),
        );
      }
    });
    workerPort.send(<String, Object?>{
      'taskType': 'load_simulation_tables',
      'payload': <String, Object?>{
        'tables': normalizedJson,
      },
      'replyTo': receivePort.sendPort,
    });
    try {
      await completer.future;
      _persistentSimulationTablesLoaded = true;
      AppDebug.instance.info('Trace', 'Persistente Simulationstabellen geladen');
    } finally {
      await receiveSub.cancel();
      receivePort.close();
    }
  }

  Future<void> _persistSimulationTablesFromWorkerResult(Object? result) async {
    if (result is! Map) {
      return;
    }
    final warmed = result['warmedProfiles'];
    if (warmed is List) {
      for (final entry in warmed) {
        _warmedSimulationProfileKeys.add(entry.toString());
      }
    }
    final matchPathWarmed = result['matchPathWarmed'];
    if (matchPathWarmed is bool && matchPathWarmed) {
      _simulationMatchPathWarmed = true;
    }
    final snapshot = result['deterministicTables'];
    if (snapshot is! Map) {
      return;
    }
    final json = snapshot.cast<String, Object?>();
    if (!isValidSimulationWarmupSnapshot(json)) {
      AppDebug.instance.warning(
        'Warmup',
        'Persistierter Snapshot wurde verworfen, weil die Struktur ungueltig ist.',
      );
      return;
    }
    await AppStorage.instance.writeJson(_simulationTablesStorageKey, json);
  }
}

class _BackgroundTaskRequest {
  const _BackgroundTaskRequest({
    required this.taskType,
    required this.payload,
    required this.sendPort,
  });

  final String taskType;
  final Map<String, Object?> payload;
  final SendPort sendPort;
}

class _PersistentWorkerInit {
  const _PersistentWorkerInit({
    required this.sendPort,
  });

  final SendPort sendPort;
}

void _backgroundTaskEntry(_BackgroundTaskRequest request) {
  switch (request.taskType) {
    case 'estimate_theo_average':
      final value = _runTheoAverageEstimate(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'simulate_bot_match':
      final value = _runBotMatchSimulation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'checkout_calculator':
      final value = _runCheckoutCalculation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'simulate_tournament':
      final future = _runTournamentSimulation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      future.then((value) {
        request.sendPort.send(<String, Object?>{
          'type': 'result',
          'value': value,
        });
      }).catchError((Object error, StackTrace stackTrace) {
        request.sendPort.send(<String, Object?>{
          'type': 'error',
          'message': '$error\n$stackTrace',
        });
      });
      return;
    case 'simulate_tournament_match_batch':
      final value = _runTournamentMatchBatchSimulation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'resolve_training_pool':
      final future = _runTrainingPoolResolution(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      future.then((value) {
        request.sendPort.send(<String, Object?>{
          'type': 'result',
          'value': value,
        });
      }).catchError((Object error, StackTrace stackTrace) {
        request.sendPort.send(<String, Object?>{
          'type': 'error',
          'message': '$error\n$stackTrace',
        });
      });
      return;
  }

  throw UnsupportedError(
    'Unknown background task type: ${request.taskType}',
  );
}

class _SimulationWorkerState {
  _SimulationWorkerState()
      : engine = TournamentEngine(),
        theoSimulator = X01MatchSimulator(
          matchEngine: X01MatchEngine(),
          botEngine: BotEngine(recordPerformanceLogs: false),
          recordPerformanceLogs: false,
        );

  final TournamentEngine engine;
  final X01MatchSimulator theoSimulator;
}

void _simulationWorkerEntry(_PersistentWorkerInit init) {
  final commandPort = ReceivePort();
  final state = _SimulationWorkerState();
  init.sendPort.send(<String, Object?>{
    'type': 'ready',
    'sendPort': commandPort.sendPort,
  });

  commandPort.listen((dynamic message) async {
    if (message is! Map) {
      return;
    }
    final replyTo = message['replyTo'];
    if (message['type'] == 'dispose') {
      commandPort.close();
      Isolate.exit();
    }
    if (replyTo is! SendPort) {
      return;
    }
    try {
      final taskType = message['taskType'] as String? ?? '';
      final payload =
          ((message['payload'] as Map?) ?? const <Object?, Object?>{})
              .cast<String, Object?>();
      final value = await _runPersistentWorkerTask(
        taskType: taskType,
        payload: payload,
        sendPort: replyTo,
        state: state,
      );
      replyTo.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
    } catch (error, stackTrace) {
      replyTo.send(<String, Object?>{
        'type': 'error',
        'message': '$error\n$stackTrace',
      });
    }
  });
}

Future<Object?> _runPersistentWorkerTask({
  required String taskType,
  required Map<String, Object?> payload,
  required SendPort sendPort,
  required _SimulationWorkerState state,
}) async {
  switch (taskType) {
    case 'load_simulation_tables':
      final tables =
          ((payload['tables'] as Map?) ?? const <Object?, Object?>{})
              .cast<String, Object?>();
      state.engine.importDeterministicWarmupTables(tables);
      return const <String, Object?>{'loaded': true};
    case 'prepare_simulation':
      return _prepareSimulationCachesInWorker(
        payload: payload,
        sendPort: sendPort,
        state: state,
      );
    case 'estimate_theo_average':
      return _runTheoAverageEstimateInWorker(
        payload: payload,
        sendPort: sendPort,
        state: state,
      );
    case 'resolve_training_pool':
      return _runTrainingPoolResolutionWithSimulator(
        payload: payload,
        sendPort: sendPort,
        simulator: state.theoSimulator,
      );
    case 'simulate_tournament':
      return _runTournamentSimulationWithEngine(
        payload: payload,
        sendPort: sendPort,
        engine: state.engine,
      );
  }
  throw UnsupportedError('Unknown persistent worker task type: $taskType');
}

Future<Map<String, Object?>> _prepareSimulationCachesInWorker({
  required Map<String, Object?> payload,
  required SendPort sendPort,
  required _SimulationWorkerState state,
}) async {
  final profileEntries =
      ((payload['profilesById'] as Map?) ?? const <Object?, Object?>{})
          .cast<Object?, Object?>();
  final profiles = <BotProfile>[];
  final warmedProfiles = <String>[];
  for (final entry in profileEntries.entries) {
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    warmedProfiles.add(entry.key.toString());
    profiles.add(_deserializeBotProfile(value.cast<String, dynamic>()));
  }
  await state.engine.prepareCommonSimulationCaches(
    profiles: profiles,
    onProgress: (label, progress) {
      sendPort.send(<String, Object?>{
        'type': 'progress',
        'label': label,
        'progress': progress,
      });
    },
  );
  return <String, Object?>{
    'prepared': true,
    'warmedProfiles': warmedProfiles,
    'matchPathWarmed': true,
    'deterministicTables': state.engine.exportDeterministicWarmupTables(),
  };
}

double _runTheoAverageEstimateInWorker({
  required Map<String, Object?> payload,
  required SendPort sendPort,
  required _SimulationWorkerState state,
}) {
  final stopwatch = Stopwatch()..start();
  final skill = (payload['skill'] as num?)?.toInt() ?? 1;
  final finishingSkill = (payload['finishingSkill'] as num?)?.toInt() ?? skill;
  final radiusCalibrationPercent =
      (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92;
  final simulationSpreadPercent =
      (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115;
  final matchCount = (payload['matchCount'] as num?)?.toInt() ?? 100;
  final playerName = (payload['playerName'] as String?) ?? 'Spieler';
  if (kDebugMode) {
    debugPrint(
      '[TheoWorker] START player="$playerName" skill=$skill finish=$finishingSkill '
      'matchCount=$matchCount radius=$radiusCalibrationPercent spread=$simulationSpreadPercent',
    );
  }

  final profile = BotProfile(
    skill: skill,
    finishingSkill: finishingSkill,
    radiusCalibrationPercent: radiusCalibrationPercent,
    simulationSpreadPercent: simulationSpreadPercent,
  );
  final player = SimulatedPlayer(
    name: 'Theo',
    profile: profile,
  );
  const config = MatchConfig(
    startScore: 501,
    mode: MatchMode.legs,
    checkoutRequirement: CheckoutRequirement.doubleOut,
    legsToWin: 8,
  );

  var totalAverage = 0.0;
  for (var index = 0; index < matchCount; index += 1) {
    final matchNumber = index + 1;
    final matchStopwatch = Stopwatch()..start();
    if (index == 0 ||
        matchNumber == matchCount ||
        matchNumber % 4 == 0) {
      sendPort.send(<String, Object?>{
        'type': 'progress',
        'label':
            'Theo wird berechnet: $playerName ($matchNumber/$matchCount) - Referenz-Match $matchNumber/$matchCount',
        'progress': matchNumber / matchCount,
      });
    }
    final result = state.theoSimulator.simulateAutoMatch(
      playerA: player,
      playerB: player,
      config: config,
      detailed: false,
      random: Random(7919 * matchNumber),
    );
    totalAverage += ((result.averageA + result.averageB) / 2)
        .clamp(0, 180)
        .toDouble();
    if (kDebugMode &&
        (matchNumber == 1 ||
            matchNumber == matchCount ||
            matchNumber % 10 == 0)) {
      debugPrint(
        '[TheoWorker] MATCH_DONE player="$playerName" match=$matchNumber/$matchCount '
        'durationMs=${matchStopwatch.elapsedMilliseconds} avg=${((result.averageA + result.averageB) / 2).toStringAsFixed(2)}',
      );
    }
  }
  final average = (totalAverage / matchCount).clamp(0, 180).toDouble();
  if (kDebugMode) {
    debugPrint(
      '[TheoWorker] END player="$playerName" average=${average.toStringAsFixed(2)} '
      'durationMs=${stopwatch.elapsedMilliseconds}',
    );
  }
  return average;
}

Map<String, Object?> _runTournamentMatchBatchSimulation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final matchPayloads =
      ((payload['matches'] as List?) ?? const <Object?>[]).whereType<Map>().toList();
  final totalMatches = matchPayloads.length;
  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(),
  );
  final results = <Object?>[];

  for (var index = 0; index < totalMatches; index += 1) {
    final entry = matchPayloads[index].cast<String, dynamic>();
    final playerA = SimulatedPlayer(
      name: (entry['playerAName'] as String?) ?? 'A',
      profile: _deserializeBotProfile(
        ((entry['playerAProfile'] as Map?) ?? const <Object?, Object?>{})
            .cast<String, dynamic>(),
      ),
    );
    final playerB = SimulatedPlayer(
      name: (entry['playerBName'] as String?) ?? 'B',
      profile: _deserializeBotProfile(
        ((entry['playerBProfile'] as Map?) ?? const <Object?, Object?>{})
            .cast<String, dynamic>(),
      ),
    );
    final config = MatchConfig(
      startScore: (entry['startScore'] as num?)?.toInt() ?? 501,
      mode: MatchMode.values.byName(
        entry['matchMode'] as String? ?? MatchMode.legs.name,
      ),
      startRequirement: StartRequirement.values.byName(
        entry['startRequirement'] as String? ??
            StartRequirement.straightIn.name,
      ),
      checkoutRequirement: CheckoutRequirement.values.byName(
        entry['checkoutRequirement'] as String? ??
            CheckoutRequirement.doubleOut.name,
      ),
      legsToWin: (entry['legsToWin'] as num?)?.toInt() ?? 6,
      setsToWin: (entry['setsToWin'] as num?)?.toInt() ?? 1,
      legsPerSet: (entry['legsPerSet'] as num?)?.toInt() ?? 1,
    );
    final simulation = simulator.simulateAutoMatch(
      playerA: playerA,
      playerB: playerB,
      config: config,
      detailed: false,
    );
    final winnerId =
        simulation.winner.name == playerA.name
            ? (entry['playerAId'] as String?) ?? ''
            : (entry['playerBId'] as String?) ?? '';
    final winnerName =
        simulation.winner.name == playerA.name ? playerA.name : playerB.name;
    results.add(<String, Object?>{
      'matchId': entry['matchId'] as String? ?? '',
      'result': _serializeTournamentMatchResult(
        simulation: simulation,
        playerAId: (entry['playerAId'] as String?) ?? '',
        playerAName: playerA.name,
        playerBId: (entry['playerBId'] as String?) ?? '',
        playerBName: playerB.name,
        winnerId: winnerId,
        winnerName: winnerName,
      ),
    });
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Turnier wird simuliert (${index + 1}/$totalMatches Matchbloecke)',
      'progress': totalMatches == 0 ? null : (index + 1) / totalMatches,
    });
  }

  return <String, Object?>{
    'results': results,
  };
}

class _TrainingResolutionCandidate {
  const _TrainingResolutionCandidate({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
    required this.error,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
  final double error;

  int get gap => (skill - finishingSkill).abs();
}

Future<List<Object?>> _runTrainingPoolResolution({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) async {
  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(recordPerformanceLogs: false),
    recordPerformanceLogs: false,
  );
  return _runTrainingPoolResolutionWithSimulator(
    payload: payload,
    sendPort: sendPort,
    simulator: simulator,
  );
}

Future<List<Object?>> _runTrainingPoolResolutionWithSimulator({
  required Map<String, Object?> payload,
  required SendPort sendPort,
  required X01MatchSimulator simulator,
}) async {
  final entries =
      ((payload['players'] as List?) ?? const <Object?>[]).whereType<Map>().toList();
  final radiusCalibrationPercent =
      (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92;
  final simulationSpreadPercent =
      (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115;
  final matchCount = (payload['matchCount'] as num?)?.toInt() ?? 8;

  final estimatedAverageCache = <String, double>{};
  final results = <Object?>[];

  for (var index = 0; index < entries.length; index += 1) {
    final entry = entries[index].cast<String, dynamic>();
    final playerId = (entry['id'] as String?) ?? 'unknown';
    final targetAverage =
        ((entry['targetAverage'] as num?)?.toDouble() ?? 0).clamp(0, 180);
    final resolution = await _resolveTrainingTargetAverageInWorker(
      simulator: simulator,
      estimatedAverageCache: estimatedAverageCache,
      targetAverage: targetAverage.toDouble(),
      radiusCalibrationPercent: radiusCalibrationPercent,
      simulationSpreadPercent: simulationSpreadPercent,
      matchCount: matchCount,
    );
    results.add(<String, Object?>{
      'id': playerId,
      'skill': resolution.skill,
      'finishingSkill': resolution.finishingSkill,
      'theoreticalAverage': resolution.theoreticalAverage,
    });
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Trainingsmodus wird angewendet... (${index + 1}/${entries.length} Spieler)',
      'progress': entries.isEmpty ? 1.0 : (index + 1) / entries.length,
    });
  }

  return results;
}

Future<_TrainingResolutionCandidate> _resolveTrainingTargetAverageInWorker({
  required X01MatchSimulator simulator,
  required Map<String, double> estimatedAverageCache,
  required double targetAverage,
  required int radiusCalibrationPercent,
  required int simulationSpreadPercent,
  required int matchCount,
}) async {
  Future<double> estimateAverage({
    required int skill,
    required int finishingSkill,
  }) async {
    final cacheKey =
        '$skill:$finishingSkill:$radiusCalibrationPercent:$simulationSpreadPercent:$matchCount';
    final cached = estimatedAverageCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    final profile = BotProfile(
      skill: skill,
      finishingSkill: finishingSkill,
      radiusCalibrationPercent: radiusCalibrationPercent,
      simulationSpreadPercent: simulationSpreadPercent,
    );
    final player = SimulatedPlayer(name: 'Training', profile: profile);
    const config = MatchConfig(
      startScore: 501,
      mode: MatchMode.legs,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      legsToWin: 8,
    );

    var totalAverage = 0.0;
    for (var matchIndex = 0; matchIndex < matchCount; matchIndex += 1) {
      final result = simulator.simulateAutoMatch(
        playerA: player,
        playerB: player,
        config: config,
        detailed: false,
        random: Random(
          (7919 * (matchIndex + 1)) + (skill * 31) + (finishingSkill * 17),
        ),
      );
      totalAverage += ((result.averageA + result.averageB) / 2)
          .clamp(0, 180)
          .toDouble();
    }
    final average = (totalAverage / matchCount).clamp(0, 180).toDouble();
    estimatedAverageCache[cacheKey] = average;
    return average;
  }

  Future<_TrainingResolutionCandidate> buildCandidate({
    required int skill,
    required int finishingSkill,
  }) async {
    final average = await estimateAverage(
      skill: skill,
      finishingSkill: finishingSkill,
    );
    return _TrainingResolutionCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: average,
      error: (average - targetAverage).abs(),
    );
  }

  _TrainingResolutionCandidate pickBetter({
    required _TrainingResolutionCandidate? current,
    required _TrainingResolutionCandidate next,
  }) {
    if (current == null) {
      return next;
    }
    const errorEpsilon = 0.0001;
    if (next.error + errorEpsilon < current.error) {
      return next;
    }
    if (current.error + errorEpsilon < next.error) {
      return current;
    }
    if (next.gap != current.gap) {
      return next.gap < current.gap ? next : current;
    }
    final nextMaxSkill = max(next.skill, next.finishingSkill);
    final currentMaxSkill = max(current.skill, current.finishingSkill);
    if (nextMaxSkill != currentMaxSkill) {
      return nextMaxSkill < currentMaxSkill ? next : current;
    }
    final nextMinSkill = min(next.skill, next.finishingSkill);
    final currentMinSkill = min(current.skill, current.finishingSkill);
    if (nextMinSkill != currentMinSkill) {
      return nextMinSkill < currentMinSkill ? next : current;
    }
    if (next.skill != current.skill) {
      return next.skill < current.skill ? next : current;
    }
    if (next.finishingSkill != current.finishingSkill) {
      return next.finishingSkill < current.finishingSkill ? next : current;
    }
    return current;
  }

  Future<_TrainingResolutionCandidate> searchCandidate({
    required int minimumValue,
    required int maximumValue,
    required Future<_TrainingResolutionCandidate> Function(int value)
        buildValueCandidate,
  }) async {
    var low = minimumValue;
    var high = maximumValue;
    _TrainingResolutionCandidate? best;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final middleCandidate = await buildValueCandidate(middle);
      best = pickBetter(current: best, next: middleCandidate);
      if (middleCandidate.theoreticalAverage < targetAverage) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    for (final value in <int>{low, high, low - 1, high + 1}) {
      if (value < minimumValue || value > maximumValue) {
        continue;
      }
      best = pickBetter(
        current: best,
        next: await buildValueCandidate(value),
      );
    }

    return best!;
  }

  final bestEqual = await searchCandidate(
    minimumValue: 1,
    maximumValue: 1000,
    buildValueCandidate: (value) async => buildCandidate(
      skill: value,
      finishingSkill: value,
    ),
  );

  final moveUp = targetAverage >= bestEqual.theoreticalAverage;
  final minimumValue = moveUp ? bestEqual.skill : 1;
  final maximumValue = moveUp ? 1000 : bestEqual.skill;

  final skillDriven = await searchCandidate(
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    buildValueCandidate: (value) async => buildCandidate(
      skill: value,
      finishingSkill: bestEqual.finishingSkill,
    ),
  );
  final finishingDriven = await searchCandidate(
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    buildValueCandidate: (value) async => buildCandidate(
      skill: bestEqual.skill,
      finishingSkill: value,
    ),
  );

  const improvementEpsilon = 0.01;
  final bestSplit = pickBetter(current: skillDriven, next: finishingDriven);
  if (bestSplit.error + improvementEpsilon < bestEqual.error) {
    return bestSplit;
  }
  return bestEqual;
}

Future<Map<String, Object?>> _runTournamentSimulation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) async {
  final engine = TournamentEngine();
  return _runTournamentSimulationWithEngine(
    payload: payload,
    sendPort: sendPort,
    engine: engine,
  );
}

Future<Map<String, Object?>> _runTournamentSimulationWithEngine({
  required Map<String, Object?> payload,
  required SendPort sendPort,
  required TournamentEngine engine,
}) async {
  final bracketPayload = payload['bracket'];
  if (bracketPayload is! Map) {
    throw StateError('simulate_tournament requires a bracket payload.');
  }
  final profileEntries = ((payload['profilesById'] as Map?) ?? const <Object?, Object?>{})
      .cast<Object?, Object?>();
  final includeHumanMatches = payload['includeHumanMatches'] as bool? ?? false;
  final bracket = TournamentBracket.fromJson(
    bracketPayload.cast<String, dynamic>(),
  );
  final profilesById = <String, BotProfile>{};
  for (final entry in profileEntries.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! Map) {
      continue;
    }
    profilesById[key] = _deserializeBotProfile(value.cast<String, dynamic>());
  }

  engine.resetPerformanceTotals();
  if (!engine.commonSimulationCachesPrepared) {
    await engine.prepareCommonSimulationCaches(
      profiles: profilesById.values,
      onProgress: (label, progress) {
        sendPort.send(<String, Object?>{
          'type': 'progress',
          'label': label,
          'progress': progress,
        });
      },
    );
  }

  final totalMatches = _countTotalMatches(bracket);
  var workingBracket = bracket;
  var simulatedMatches = 0;
  var batchSize = 8;
  var stoppedForHumanMatch = false;

  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Turnier wird simuliert: ${bracket.definition.name} (0/$totalMatches Matches)',
    'progress': totalMatches == 0 ? null : 0.0,
  });

  while (!workingBracket.isCompleted) {
    if (!includeHumanMatches && _shouldStopBeforeNextRoundBg(workingBracket)) {
      stoppedForHumanMatch = true;
      break;
    }
    final batch = engine.simulateMatchesBatch(
      bracket: workingBracket,
      profileProvider: (String participantId) =>
          profilesById[participantId] ??
          const BotProfile(
            skill: 700,
            finishingSkill: 700,
          ),
      includeHumanMatches: includeHumanMatches,
      maxMatches: batchSize,
    );
    if (!batch.madeProgress) {
      break;
    }
    workingBracket = batch.bracket;
    simulatedMatches += batch.simulatedMatches;
    final completedMatches = _countCompletedMatches(workingBracket);
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Turnier wird simuliert: ${workingBracket.definition.name} ($completedMatches/$totalMatches Matches)',
      'progress': totalMatches == 0
          ? null
          : (completedMatches / totalMatches).clamp(0.0, 1.0).toDouble(),
    });
  }

  return <String, Object?>{
    'bracket': workingBracket.toJson(),
    'simulatedMatches': simulatedMatches,
    'completed': workingBracket.isCompleted,
    'stoppedForHumanMatch': stoppedForHumanMatch,
  };
}

double _runTheoAverageEstimate({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final skill = (payload['skill'] as num?)?.toInt() ?? 1;
  final finishingSkill = (payload['finishingSkill'] as num?)?.toInt() ?? skill;
  final radiusCalibrationPercent =
      (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92;
  final simulationSpreadPercent =
      (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115;
  final matchCount = (payload['matchCount'] as num?)?.toInt() ?? 100;
  final playerName = (payload['playerName'] as String?) ?? 'Spieler';

  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(),
  );
  final profile = BotProfile(
    skill: skill,
    finishingSkill: finishingSkill,
    radiusCalibrationPercent: radiusCalibrationPercent,
    simulationSpreadPercent: simulationSpreadPercent,
  );
  const config = MatchConfig(
    startScore: 501,
    mode: MatchMode.legs,
    checkoutRequirement: CheckoutRequirement.doubleOut,
    legsToWin: 8,
  );

  var totalAverage = 0.0;
  for (var index = 0; index < matchCount; index += 1) {
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Theo wird berechnet: $playerName (${index + 1}/$matchCount) - Referenz-Match ${index + 1}/$matchCount',
      'progress': (index + 1) / matchCount,
    });
    final player = SimulatedPlayer(
      name: 'Theo',
      profile: profile,
    );
    final result = simulator.simulateAutoMatch(
      playerA: player,
      playerB: player,
      config: config,
      detailed: false,
      random: Random(7919 * (index + 1)),
    );
    totalAverage += ((result.averageA + result.averageB) / 2)
        .clamp(0, 180)
        .toDouble();
  }

  return (totalAverage / matchCount).clamp(0, 180).toDouble();
}

Map<String, Object?> _runBotMatchSimulation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird vorbereitet',
    'progress': 0.05,
  });
  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(),
  );
  final playerA = SimulatedPlayer(
    name: (payload['playerAName'] as String?) ?? 'Bot A',
    profile: BotProfile(
      skill: (payload['playerASkill'] as num?)?.toInt() ?? 750,
      finishingSkill: (payload['playerAFinishingSkill'] as num?)?.toInt() ?? 750,
      radiusCalibrationPercent:
          (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
      simulationSpreadPercent:
          (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
    ),
  );
  final playerB = SimulatedPlayer(
    name: (payload['playerBName'] as String?) ?? 'Bot B',
    profile: BotProfile(
      skill: (payload['playerBSkill'] as num?)?.toInt() ?? 650,
      finishingSkill: (payload['playerBFinishingSkill'] as num?)?.toInt() ?? 650,
      radiusCalibrationPercent:
          (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
      simulationSpreadPercent:
          (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
    ),
  );
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird simuliert',
    'progress': 0.1,
  });
  final result = simulator.simulateAutoMatch(
    playerA: playerA,
    playerB: playerB,
    config: const MatchConfig(
      startScore: 501,
      mode: MatchMode.legs,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      legsToWin: 6,
    ),
  );
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird aufbereitet',
    'progress': 0.95,
  });
  return _serializeSimulatedMatchResult(result);
}

Map<String, Object?> _runCheckoutCalculation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final mode = (payload['mode'] as String?) ?? 'checkout';
  final dartsLeft = (payload['dartsLeft'] as num?)?.toInt() ?? 3;
  final checkoutRequirement = _checkoutRequirementFromName(
    payload['checkoutRequirement'] as String?,
  );
  final playStyle = _checkoutPlayStyleFromName(payload['playStyle'] as String?);
  final preferredDoubles = ((payload['preferredDoubles'] as List?) ?? const [])
      .whereType<num>()
      .map((entry) => entry.toInt())
      .toSet();
  final dislikedDoubles = ((payload['dislikedDoubles'] as List?) ?? const [])
      .whereType<num>()
      .map((entry) => entry.toInt())
      .toSet();
  const standardOuterBullPreference = 50;
  const standardBullPreference = 50;
  const standardSetupPreference = 85;
  const maxVisibleOptions = 8;

  final planner = CheckoutPlanner();
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': mode == 'setup'
        ? 'Stellwege werden berechnet'
        : 'Checkout-Wege werden berechnet',
    'progress': 0.1,
  });

  if (mode == 'setup') {
    final startScore = (payload['startScore'] as num?)?.toInt() ?? 0;
    if (!planner.isValidSetupStartScore(startScore) || dartsLeft <= 0) {
      return <String, Object?>{
        'mode': 'setup',
        'bands': <String, Object?>{},
      };
    }
    final bandOptions = planner.bestSetupBandOptions(
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: standardSetupPreference,
      outerBullPreference: standardOuterBullPreference,
      bullPreference: standardBullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
    final serializedBands = <String, Object?>{};
    for (final entry in bandOptions.entries) {
      final adjustment = planner.doublePreferenceAdjustment(
        entry.value.finishRoute.isEmpty ? null : entry.value.finishRoute.last,
        preferredDoubles: preferredDoubles,
        dislikedDoubles: dislikedDoubles,
      );
      serializedBands[entry.key.name] = <String, Object?>{
        'option': _serializeSetupLeaveOption(entry.value),
        'effectiveScore': entry.value.score + adjustment,
        'effectiveBreakdown': _serializeSetupScoreBreakdown(
          _applyDoubleAdjustmentToSetupBreakdownBg(
            entry.value.breakdown,
            entry.value.finishRoute.isEmpty ? null : entry.value.finishRoute.last,
            adjustment,
          ),
        ),
        'startScore': startScore,
        'dartsLeft': dartsLeft,
        'checkoutRequirement': checkoutRequirement.name,
        'playStyle': playStyle.name,
        'preferredDoubles': preferredDoubles.toList()..sort(),
        'dislikedDoubles': dislikedDoubles.toList()..sort(),
        'targetBand': entry.key.name,
      };
    }
    return <String, Object?>{
      'mode': 'setup',
      'bands': serializedBands,
    };
  }

  final score = (payload['score'] as num?)?.toInt() ?? 0;
  if (score <= 1 || dartsLeft <= 0) {
    return <String, Object?>{
      'mode': 'checkout',
      'options': const <Object?>[],
    };
  }
  final finishes = planner.allCheckoutRoutes(
    score: score,
    dartsLeft: dartsLeft,
    checkoutRequirement: checkoutRequirement,
    playStyle: playStyle,
  );
  if (finishes.isEmpty) {
    return <String, Object?>{
      'mode': 'checkout',
      'options': const <Object?>[],
    };
  }

  final rankedRoutes = finishes
      .map((route) {
        final adjustment = planner.doublePreferenceAdjustment(
          route.isEmpty ? null : route.last,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        final baseScore = planner.scoreRoute(
          route: route,
          startScore: score,
          totalDarts: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: standardOuterBullPreference,
          bullPreference: standardBullPreference,
        );
        return <String, Object?>{
          'route': route,
          'score': baseScore + adjustment,
          'adjustment': adjustment,
        };
      })
      .toList()
    ..sort(
      (left, right) =>
          ((right['score'] as int?) ?? 0).compareTo((left['score'] as int?) ?? 0),
    );

  final options = <Object?>[];
  for (final rankedRoute in rankedRoutes.take(maxVisibleOptions)) {
    final route = (rankedRoute['route'] as List).cast<DartThrowResult>();
    final adjustment = (rankedRoute['adjustment'] as int?) ?? 0;
    final breakdown = _applyDoubleAdjustmentToBreakdownBg(
      planner.routeScoreBreakdown(
        route: route,
        startScore: score,
        totalDarts: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: standardOuterBullPreference,
        bullPreference: standardBullPreference,
      ),
      route.isEmpty ? null : route.last,
      adjustment,
    );
    final missScenarios = _buildMissScenariosBg(
      planner: planner,
      route: route,
      startScore: score,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: standardOuterBullPreference,
      bullPreference: standardBullPreference,
    );
    final fallbackHints = _buildFallbackHintsBg(
      planner: planner,
      route: route,
      startScore: score,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    options.add(<String, Object?>{
      'throws': route.map(_serializeThrow).toList(growable: false),
      'score': rankedRoute['score'],
      'breakdown': _serializeRouteScoreBreakdown(breakdown),
      'missScenarios': missScenarios,
      'fallbackHints': fallbackHints,
      'rationaleHint': _buildRationaleHintBg(
        planner: planner,
        route: route,
        startScore: score,
        totalDarts: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      ),
      'badges': _buildBadgesBg(
        planner: planner,
        route: route,
        missScenarios: missScenarios,
        fallbackHints: fallbackHints,
      ),
    });
  }
  return <String, Object?>{
    'mode': 'checkout',
    'options': options,
  };
}

Map<String, Object?> _serializeSimulatedMatchResult(SimulatedMatchResult result) {
  return <String, Object?>{
    'winnerName': result.winner.name,
    'winnerProfile': _serializeBotProfile(result.winner.profile),
    'scoreText': result.scoreText,
    'averageA': result.averageA,
    'averageB': result.averageB,
    'first9AverageA': result.first9AverageA,
    'first9AverageB': result.first9AverageB,
    'checkoutRateA': result.checkoutRateA,
    'checkoutRateB': result.checkoutRateB,
    'doubleAttemptsA': result.doubleAttemptsA,
    'doubleAttemptsB': result.doubleAttemptsB,
    'successfulChecksA': result.successfulChecksA,
    'successfulChecksB': result.successfulChecksB,
    'scores100PlusA': result.scores100PlusA,
    'scores100PlusB': result.scores100PlusB,
    'scores140PlusA': result.scores140PlusA,
    'scores140PlusB': result.scores140PlusB,
    'scores180A': result.scores180A,
    'scores180B': result.scores180B,
    'legDartsDistributionA': result.legDartsDistributionA.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'legDartsDistributionB': result.legDartsDistributionB.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'legSummaries': result.legSummaries.map(_serializeLegSummary).toList(),
    'playerStatsA': _serializePlayerStats(result.playerStatsA),
    'playerStatsB': _serializePlayerStats(result.playerStatsB),
    'legsA': result.legsA,
    'legsB': result.legsB,
    'setsA': result.setsA,
    'setsB': result.setsB,
  };
}

Map<String, Object?> _serializeTournamentMatchResult({
  required SimulatedMatchResult simulation,
  required String playerAId,
  required String playerAName,
  required String playerBId,
  required String playerBName,
  required String winnerId,
  required String winnerName,
}) {
  return TournamentMatchResult(
    winnerId: winnerId,
    winnerName: winnerName,
    scoreText: simulation.scoreText,
    participantStats: <TournamentPlayerMatchStats>[
      _playerMatchStatsFromSimulatedBg(
        participantId: playerAId,
        participantName: playerAName,
        stats: simulation.playerStatsA,
      ),
      _playerMatchStatsFromSimulatedBg(
        participantId: playerBId,
        participantName: playerBName,
        stats: simulation.playerStatsB,
      ),
    ],
  ).toJson();
}

TournamentPlayerMatchStats _playerMatchStatsFromSimulatedBg({
  required String participantId,
  required String participantName,
  required SimulatedPlayerStats stats,
}) {
  return TournamentPlayerMatchStats(
    participantId: participantId,
    participantName: participantName,
    pointsScored: stats.pointsScored,
    dartsThrown: stats.dartsThrown,
    visits: stats.visits,
    legsWon: stats.legsWon,
    legsPlayed: stats.legsPlayed,
    legsStarted: stats.legsStarted,
    legsWonAsStarter: stats.legsWonAsStarter,
    legsWonWithoutStarter: stats.legsWonWithoutStarter,
    scores0To40: stats.scores0To40,
    scores41To59: stats.scores41To59,
    scores60Plus: stats.scores60Plus,
    scores100Plus: stats.scores100Plus,
    scores140Plus: stats.scores140Plus,
    scores171Plus: stats.scores171Plus,
    scores180: stats.scores180,
    checkoutAttempts: stats.checkoutAttempts,
    successfulCheckouts: stats.successfulCheckouts,
    checkoutAttempts1Dart: stats.checkoutAttempts1Dart,
    checkoutAttempts2Dart: stats.checkoutAttempts2Dart,
    checkoutAttempts3Dart: stats.checkoutAttempts3Dart,
    successfulCheckouts1Dart: stats.successfulCheckouts1Dart,
    successfulCheckouts2Dart: stats.successfulCheckouts2Dart,
    successfulCheckouts3Dart: stats.successfulCheckouts3Dart,
    thirdDartCheckoutAttempts: stats.thirdDartCheckoutAttempts,
    thirdDartCheckouts: stats.thirdDartCheckouts,
    bullCheckoutAttempts: stats.bullCheckoutAttempts,
    bullCheckouts: stats.bullCheckouts,
    functionalDoubleAttempts: stats.functionalDoubleAttempts,
    functionalDoubleSuccesses: stats.functionalDoubleSuccesses,
    firstNinePoints: stats.firstNinePoints,
    firstNineDarts: stats.firstNineDarts,
    highestFinish: stats.highestFinish,
    bestLegDarts: stats.bestLegDarts,
    totalFinishValue: stats.totalFinishValue,
    withThrowPoints: stats.withThrowPoints,
    withThrowDarts: stats.withThrowDarts,
    againstThrowPoints: stats.againstThrowPoints,
    againstThrowDarts: stats.againstThrowDarts,
    decidingLegPoints: stats.decidingLegPoints,
    decidingLegDarts: stats.decidingLegDarts,
    decidingLegsPlayed: stats.decidingLegsPlayed,
    decidingLegsWon: stats.decidingLegsWon,
    won9Darters: stats.won9Darters,
    won12Darters: stats.won12Darters,
    won15Darters: stats.won15Darters,
    won18Darters: stats.won18Darters,
  );
}

Map<String, Object?> _serializeBotProfile(BotProfile profile) {
  return <String, Object?>{
    'skill': profile.skill,
    'finishingSkill': profile.finishingSkill,
    'radiusCalibrationPercent': profile.radiusCalibrationPercent,
    'simulationSpreadPercent': profile.simulationSpreadPercent,
  };
}

BotProfile _deserializeBotProfile(Map<String, dynamic> json) {
  return BotProfile(
    skill: (json['skill'] as num?)?.toInt() ?? 700,
    finishingSkill: (json['finishingSkill'] as num?)?.toInt() ?? 700,
    radiusCalibrationPercent:
        (json['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
    simulationSpreadPercent:
        (json['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
  );
}

Map<String, Object?> _serializeLegSummary(SimulatedLegSummary summary) {
  return <String, Object?>{
    'legNumber': summary.legNumber,
    'starterKey': summary.starterKey,
    'winnerKey': summary.winnerKey,
    'decidingLeg': summary.decidingLeg,
    'scoreBeforeStartA': summary.scoreBeforeStartA,
    'scoreBeforeStartB': summary.scoreBeforeStartB,
    'legDartsA': summary.legDartsA,
    'legDartsB': summary.legDartsB,
    'legAverageA': summary.legAverageA,
    'legAverageB': summary.legAverageB,
    'remainingScoreA': summary.remainingScoreA,
    'remainingScoreB': summary.remainingScoreB,
    'visitDebugs': summary.visitDebugs.map(_serializeVisitDebug).toList(),
  };
}

Map<String, Object?> _serializeVisitDebug(SimulatedVisitDebug debug) {
  return <String, Object?>{
    'playerName': debug.playerName,
    'startScore': debug.startScore,
    'endScore': debug.endScore,
    'scoredPoints': debug.scoredPoints,
    'checkedOut': debug.checkedOut,
    'busted': debug.busted,
    'targets': debug.targets.map(_serializeThrow).toList(),
    'throws': debug.throws.map(_serializeThrow).toList(),
    'targetReasons': debug.targetReasons,
    'plannedRoutes': debug.plannedRoutes
        .map((route) => route.map(_serializeThrow).toList())
        .toList(),
  };
}

Map<String, Object?> _serializePlayerStats(SimulatedPlayerStats stats) {
  return <String, Object?>{
    'pointsScored': stats.pointsScored,
    'dartsThrown': stats.dartsThrown,
    'visits': stats.visits,
    'legsWon': stats.legsWon,
    'legsPlayed': stats.legsPlayed,
    'legsStarted': stats.legsStarted,
    'legsWonAsStarter': stats.legsWonAsStarter,
    'legsWonWithoutStarter': stats.legsWonWithoutStarter,
    'scores0To40': stats.scores0To40,
    'scores41To59': stats.scores41To59,
    'scores60Plus': stats.scores60Plus,
    'scores100Plus': stats.scores100Plus,
    'scores140Plus': stats.scores140Plus,
    'scores171Plus': stats.scores171Plus,
    'scores180': stats.scores180,
    'checkoutAttempts': stats.checkoutAttempts,
    'successfulCheckouts': stats.successfulCheckouts,
    'checkoutAttempts1Dart': stats.checkoutAttempts1Dart,
    'checkoutAttempts2Dart': stats.checkoutAttempts2Dart,
    'checkoutAttempts3Dart': stats.checkoutAttempts3Dart,
    'successfulCheckouts1Dart': stats.successfulCheckouts1Dart,
    'successfulCheckouts2Dart': stats.successfulCheckouts2Dart,
    'successfulCheckouts3Dart': stats.successfulCheckouts3Dart,
    'thirdDartCheckoutAttempts': stats.thirdDartCheckoutAttempts,
    'thirdDartCheckouts': stats.thirdDartCheckouts,
    'bullCheckoutAttempts': stats.bullCheckoutAttempts,
    'bullCheckouts': stats.bullCheckouts,
    'functionalDoubleAttempts': stats.functionalDoubleAttempts,
    'functionalDoubleSuccesses': stats.functionalDoubleSuccesses,
    'firstNinePoints': stats.firstNinePoints,
    'firstNineDarts': stats.firstNineDarts,
    'highestFinish': stats.highestFinish,
    'bestLegDarts': stats.bestLegDarts,
    'totalFinishValue': stats.totalFinishValue,
    'withThrowPoints': stats.withThrowPoints,
    'withThrowDarts': stats.withThrowDarts,
    'againstThrowPoints': stats.againstThrowPoints,
    'againstThrowDarts': stats.againstThrowDarts,
    'decidingLegPoints': stats.decidingLegPoints,
    'decidingLegDarts': stats.decidingLegDarts,
    'decidingLegsPlayed': stats.decidingLegsPlayed,
    'decidingLegsWon': stats.decidingLegsWon,
    'won9Darters': stats.won9Darters,
    'won12Darters': stats.won12Darters,
    'won15Darters': stats.won15Darters,
    'won18Darters': stats.won18Darters,
  };
}

Map<String, Object?> _serializeThrow(DartThrowResult entry) {
  return <String, Object?>{
    'label': entry.label,
    'baseValue': entry.baseValue,
    'scoredPoints': entry.scoredPoints,
    'isDouble': entry.isDouble,
    'isTriple': entry.isTriple,
    'isBull': entry.isBull,
    'isMiss': entry.isMiss,
  };
}

Map<String, Object?> _serializeRouteScoreBreakdown(
  CheckoutRouteScoreBreakdown breakdown,
) {
  return <String, Object?>{
    'dartPathScore': breakdown.dartPathScore,
    'comfort': breakdown.comfort,
    'robustness': breakdown.robustness,
    'doubleQuality': breakdown.doubleQuality,
    'narrowFieldPenalty': breakdown.narrowFieldPenalty,
    'bullPenalty': breakdown.bullPenalty,
    'segmentFlow': breakdown.segmentFlow,
    'dartPathDetails': breakdown.dartPathDetails,
    'comfortDetails': breakdown.comfortDetails,
    'robustnessDetails': breakdown.robustnessDetails,
    'doubleQualityDetails': breakdown.doubleQualityDetails,
    'narrowFieldDetails': breakdown.narrowFieldDetails,
    'bullPenaltyDetails': breakdown.bullPenaltyDetails,
    'segmentFlowDetails': breakdown.segmentFlowDetails,
  };
}

Map<String, Object?> _serializeSetupScoreBreakdown(
  CheckoutSetupScoreBreakdown breakdown,
) {
  return <String, Object?>{
    'setupPathScore': breakdown.setupPathScore,
    'routeGuidance': breakdown.routeGuidance,
    'leaveQuality': breakdown.leaveQuality,
    'missPenalty': breakdown.missPenalty,
    'totalScore': breakdown.totalScore,
    'setupPathDetails': breakdown.setupPathDetails,
    'routeGuidanceDetails': breakdown.routeGuidanceDetails,
    'leaveQualityDetails': breakdown.leaveQualityDetails,
    'missPenaltyDetails': breakdown.missPenaltyDetails,
  };
}

Map<String, Object?> _serializeSetupLeaveOption(CheckoutSetupLeaveOption option) {
  return <String, Object?>{
    'setupRoute': option.setupRoute.map(_serializeThrow).toList(),
    'remainingScore': option.remainingScore,
    'finishRoute': option.finishRoute.map(_serializeThrow).toList(),
    'score': option.score,
    'breakdown': _serializeSetupScoreBreakdown(option.breakdown),
  };
}

CheckoutRequirement _checkoutRequirementFromName(String? value) {
  return CheckoutRequirement.values.firstWhere(
    (entry) => entry.name == value,
    orElse: () => CheckoutRequirement.doubleOut,
  );
}

CheckoutPlayStyle _checkoutPlayStyleFromName(String? value) {
  return CheckoutPlayStyle.values.firstWhere(
    (entry) => entry.name == value,
    orElse: () => CheckoutPlayStyle.balanced,
  );
}

CheckoutRouteScoreBreakdown _applyDoubleAdjustmentToBreakdownBg(
  CheckoutRouteScoreBreakdown breakdown,
  DartThrowResult? finalThrow,
  int adjustment,
) {
  if (adjustment == 0 || finalThrow == null) {
    return breakdown;
  }

  return CheckoutRouteScoreBreakdown(
    dartPathScore: breakdown.dartPathScore,
    comfort: breakdown.comfort,
    robustness: breakdown.robustness,
    doubleQuality: breakdown.doubleQuality + adjustment,
    narrowFieldPenalty: breakdown.narrowFieldPenalty,
    bullPenalty: breakdown.bullPenalty,
    segmentFlow: breakdown.segmentFlow,
    dartPathDetails: breakdown.dartPathDetails,
    comfortDetails: breakdown.comfortDetails,
    robustnessDetails: breakdown.robustnessDetails,
    doubleQualityDetails: <String>[
      ...breakdown.doubleQualityDetails,
      if (adjustment > 0)
        'Persoenliche Doppel-Praeferenz fuer ${finalThrow.label}: +$adjustment',
      if (adjustment < 0)
        'Persoenlicher Malus fuer ${finalThrow.label}: $adjustment',
    ],
    narrowFieldDetails: breakdown.narrowFieldDetails,
    bullPenaltyDetails: breakdown.bullPenaltyDetails,
    segmentFlowDetails: breakdown.segmentFlowDetails,
  );
}

CheckoutSetupScoreBreakdown _applyDoubleAdjustmentToSetupBreakdownBg(
  CheckoutSetupScoreBreakdown breakdown,
  DartThrowResult? finalThrow,
  int adjustment,
) {
  if (adjustment == 0 || finalThrow == null) {
    return breakdown;
  }

  return CheckoutSetupScoreBreakdown(
    setupPathScore: breakdown.setupPathScore,
    routeGuidance: breakdown.routeGuidance,
    leaveQuality: breakdown.leaveQuality + adjustment,
    missPenalty: breakdown.missPenalty,
    totalScore: breakdown.totalScore + adjustment,
    setupPathDetails: breakdown.setupPathDetails,
    routeGuidanceDetails: breakdown.routeGuidanceDetails,
    leaveQualityDetails: <String>[
      ...breakdown.leaveQualityDetails,
      if (adjustment > 0)
        'Persoenliche Doppel-Praeferenz fuer ${finalThrow.label}: +$adjustment',
      if (adjustment < 0)
        'Persoenlicher Malus fuer ${finalThrow.label}: $adjustment',
    ],
    missPenaltyDetails: breakdown.missPenaltyDetails,
  );
}

List<Map<String, Object?>> _buildMissScenariosBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
  int outerBullPreference = 50,
  int bullPreference = 50,
}) {
  const rules = X01Rules();
  final scenarios = <Map<String, Object?>>[];
  var remaining = startScore;

  for (var index = 0; index < route.length; index += 1) {
    final dartThrow = route[index];
    final dartsAfterThis = totalDarts - index - 1;

    if (dartThrow.isTriple) {
      final singleRemaining = remaining - dartThrow.baseValue;
      final singleText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: singleRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (singleText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': 'Single statt ${dartThrow.label}',
          'outcome': singleText['text'],
          'state': singleText['state'],
        });
      }

      for (final neighbor in rules.adjacentSegments(dartThrow.baseValue)) {
        final neighborRemaining = remaining - neighbor;
        final neighborText = _describeMissContinuationBg(
          planner: planner,
          remainingScore: neighborRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (neighborText != null) {
          scenarios.add(<String, Object?>{
            'dartIndex': index + 1,
            'targetLabel': dartThrow.label,
            'label': 'Nachbar $neighbor statt ${dartThrow.label}',
            'outcome': neighborText['text'],
            'state': neighborText['state'],
          });
        }
      }
    } else if (dartThrow.isDouble && !dartThrow.isBull) {
      final singleRemaining = remaining - dartThrow.baseValue;
      final singleText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: singleRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (singleText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': 'Single statt ${dartThrow.label}',
          'outcome': singleText['text'],
          'state': singleText['state'],
        });
      }
    } else if (dartThrow.isBull) {
      final outerBullRemaining = remaining - 25;
      final outerBullText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: outerBullRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (outerBullText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': '25 statt BULL',
          'outcome': outerBullText['text'],
          'state': outerBullText['state'],
        });
      }
    }

    remaining -= dartThrow.scoredPoints;
  }

  return scenarios.take(4).toList(growable: false);
}

Map<String, Object?>? _describeMissContinuationBg({
  required CheckoutPlanner planner,
  required int remainingScore,
  required int dartsLeft,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
  int outerBullPreference = 50,
  int bullPreference = 50,
}) {
  if (remainingScore <= 1 || dartsLeft <= 0) {
    return null;
  }

  final continuation = planner.bestContinuationPlan(
    score: remainingScore,
    dartsLeft: dartsLeft,
    checkoutRequirement: checkoutRequirement,
    playStyle: playStyle,
    outerBullPreference: outerBullPreference,
    bullPreference: bullPreference,
  );
  if (continuation == null || continuation.throws.isEmpty) {
    return <String, Object?>{
      'text': '$remainingScore Rest, kein guter Anschluss',
      'state': 'bad',
    };
  }

  final labels = continuation.throws.take(dartsLeft).map((e) => e.label).join(' | ');
  if (continuation.immediateFinish) {
    return <String, Object?>{
      'text': '$remainingScore Rest, Finish ueber $labels',
      'state': 'finish',
    };
  }
  return <String, Object?>{
    'text': '$remainingScore Rest, weiter mit $labels',
    'state': 'setup',
  };
}

List<String> _buildFallbackHintsBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
}) {
  final hints = <String>[];
  var remaining = startScore;
  for (var index = 0; index < route.length; index += 1) {
    final dartThrow = route[index];
    final dartsAfterThis = totalDarts - index - 1;
    final isSingleMissScenario =
        dartThrow.isTriple || (dartThrow.isDouble && !dartThrow.isBull);
    if (isSingleMissScenario) {
      final singleFallbackRemaining = remaining - dartThrow.baseValue;
      if (singleFallbackRemaining > 1 && dartsAfterThis > 0) {
        final fallbackPlan = planner.bestContinuationPlan(
          score: singleFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
        if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
          final labels = fallbackPlan.throws.take(dartsAfterThis).map((e) => e.label).join(' | ');
          final prefix = 'Bei Single statt ${dartThrow.label}: ';
          final suffix = fallbackPlan.immediateFinish
              ? labels
              : '$labels fuer den naechsten Besuch';
          hints.add('$prefix$suffix');
        }
      }
    }
    remaining -= dartThrow.scoredPoints;
  }
  return hints.take(2).toList(growable: false);
}

String? _buildRationaleHintBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
}) {
  if (route.length < 2 || totalDarts < 2) {
    return null;
  }

  final first = route.first;
  final firstRemaining = startScore - first.scoredPoints;
  if (firstRemaining <= 1) {
    return null;
  }

  final second = route[1];
  final afterSecond = firstRemaining - second.scoredPoints;
  final singleOnSecondRemaining = firstRemaining - second.baseValue;
  final targetFinish = afterSecond == 0 ? second.label : _formatRemainingBg(afterSecond);

  String? fallbackText;
  if (second.isTriple && totalDarts >= 3 && singleOnSecondRemaining > 1) {
    final fallbackPlan = planner.bestContinuationPlan(
      score: singleOnSecondRemaining,
      dartsLeft: totalDarts - 2,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
      final labels = fallbackPlan.throws.take(totalDarts - 2).map((e) => e.label).join(' | ');
      fallbackText = fallbackPlan.immediateFinish
          ? labels
          : '$labels fuer den naechsten Besuch';
    }
  }

  if (first.isTriple && totalDarts >= 3) {
    final singleOnFirstRemaining = startScore - first.baseValue;
    if (singleOnFirstRemaining > 1) {
      final firstFallbackPlan = planner.bestContinuationPlan(
        score: singleOnFirstRemaining,
        dartsLeft: totalDarts - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      );
      if (firstFallbackPlan != null && firstFallbackPlan.throws.isNotEmpty) {
        final firstFallbackLabels = firstFallbackPlan.throws
            .take(totalDarts - 1)
            .map((e) => e.label)
            .join(' | ');
        final firstFallbackText = firstFallbackPlan.immediateFinish
            ? firstFallbackLabels
            : '$firstFallbackLabels fuer den naechsten Besuch';
        final firstFallbackLead = firstFallbackPlan.immediateFinish
            ? 'trotzdem ein guter Weg'
            : 'ein brauchbarer Weg fuer den naechsten Besuch';
        if (fallbackText != null) {
          return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
              'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
              '$firstFallbackLead. '
              'Darum geht der 2. Dart auf ${second.label}, weil auch ein Single statt ${second.label} '
              'noch $fallbackText offenlaesst.';
        }
        return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
            'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
            '$firstFallbackLead.';
      }
    }
  }

  if (fallbackText != null) {
    return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
        'Darum geht der 2. Dart auf ${second.label}, weil dann $targetFinish bleibt '
        'und bei Single statt ${second.label} trotzdem $fallbackText offen ist.';
  }

  return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
      'Der 2. Dart geht auf ${second.label}, damit anschliessend $targetFinish bleibt.';
}

String _formatRemainingBg(int remaining) {
  if (remaining == 50) {
    return 'Bull';
  }
  if (remaining > 1 && remaining <= 40 && remaining.isEven) {
    return 'D${remaining ~/ 2}';
  }
  return '$remaining Rest';
}

List<String> _buildBadgesBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required List<Map<String, Object?>> missScenarios,
  required List<String> fallbackHints,
}) {
  final badges = <String>[];
  final narrowFields = route.where(planner.isNarrowField).length;

  if (route.length == 2) {
    badges.add('2-Dart-Weg');
  }
  if (route.isNotEmpty && !route.last.isBull) {
    badges.add(route.last.isFinishDouble ? 'starkes Schlussdoppel' : 'klares Schlussfeld');
  }
  if (narrowFields <= 1) {
    badges.add('wenig schmale Felder');
  }
  if (route.every((entry) => !entry.isBull && entry.label != '25')) {
    badges.add('Bull vermieden');
  }
  if (_hasSameSegmentFlowBg(route)) {
    badges.add('ruhiger Segmentfluss');
  }
  if (fallbackHints.isNotEmpty) {
    badges.add('Miss-Fallback');
  }
  if (missScenarios.any((scenario) => scenario['state'] == 'finish')) {
    badges.add('robuster Miss-Fallback');
  }
  return badges.take(4).toList(growable: false);
}

bool _hasSameSegmentFlowBg(List<DartThrowResult> route) {
  for (var index = 1; index < route.length; index += 1) {
    if (route[index - 1].baseValue == route[index].baseValue) {
      return true;
    }
  }
  return false;
}

int _countTotalMatches(TournamentBracket bracket) {
  var count = 0;
  for (final round in bracket.rounds) {
    count += round.matches.length;
  }
  return count;
}

int _countCompletedMatches(TournamentBracket bracket) {
  var count = 0;
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.completed) {
        count += 1;
      }
    }
  }
  return count;
}

bool _shouldStopBeforeNextRoundBg(TournamentBracket bracket) {
  final roundNumber = _nextPendingRoundNumberBg(bracket);
  if (roundNumber == null) {
    return false;
  }
  return _hasPendingHumanMatchInRoundBg(bracket, roundNumber);
}

int? _nextPendingRoundNumberBg(TournamentBracket bracket) {
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.pending && match.isReady) {
        return round.roundNumber;
      }
    }
  }
  return null;
}

bool _hasPendingHumanMatchInRoundBg(TournamentBracket bracket, int roundNumber) {
  for (final round in bracket.rounds) {
    if (round.roundNumber != roundNumber) {
      continue;
    }
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.pending &&
          match.isReady &&
          match.isHumanMatch) {
        return true;
      }
    }
    return false;
  }
  return false;
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:dart_flutter_app/data/background/background_task_runner.dart';
import 'package:dart_flutter_app/data/background/simulation_snapshot.dart';
import 'package:dart_flutter_app/data/background/simulation_service.dart';

void main() {
  test('parallel jobs keep independent status handles', () async {
    final executor = _FakeSimulationTaskExecutor();
    final service = SimulationService(executor: executor);

    final first = service.startJob<String>(
      taskType: 'job_a',
      initialLabel: 'Start A',
      payload: const <String, Object?>{},
    );
    final second = service.startJob<String>(
      taskType: 'job_b',
      initialLabel: 'Start B',
      payload: const <String, Object?>{},
    );

    executor.emitJobProgress('job_a', 'A laeuft', 0.25);
    executor.emitJobProgress('job_b', 'B laeuft', 0.75);
    executor.completeJob('job_a', 'done-a');
    executor.completeJob('job_b', 'done-b');

    expect(await first.result, 'done-a');
    expect(await second.result, 'done-b');
    expect(first.label, 'A laeuft');
    expect(second.label, 'B laeuft');
    expect(first.progress, 0.25);
    expect(second.progress, 0.75);
  });

  test('invalid snapshot is ignored during initialize', () async {
    final executor = _FakeSimulationTaskExecutor()
      ..persistedTables = <String, Object?>{
        'version': 1,
        'schema': 'simulation_warmup_tables',
        'bot': <String, Object?>{},
        'x01': <String, Object?>{},
      };
    final service = SimulationService(executor: executor);

    await service.initialize();

    expect(service.hasWarmupData, isFalse);
  });

  test('persistent job retries after worker failure', () async {
    final executor = _FakeSimulationTaskExecutor()
      ..failNextPersistentJob = true;
    final service = SimulationService(executor: executor);

    final handle = service.startPersistentJob<String>(
      taskType: 'simulate_tournament',
      initialLabel: 'Simuliere',
      payload: const <String, Object?>{},
    );

    executor.emitPersistentProgress('simulate_tournament', 'Neustart', 0.5);
    executor.completePersistentJob('simulate_tournament', 'ok');

    expect(await handle.result, 'ok');
    expect(executor.disposeCalls, 1);
    expect(executor.persistentRuns, 2);
    expect(handle.label, 'Neustart');
  });
}

class _FakeSimulationTaskExecutor implements SimulationTaskExecutor {
  final Map<String, void Function(BackgroundTaskSnapshot snapshot)> _jobUpdates =
      <String, void Function(BackgroundTaskSnapshot snapshot)>{};
  final Map<String, Completer<Object?>> _jobCompleters =
      <String, Completer<Object?>>{};
  final Map<String, void Function(BackgroundTaskSnapshot snapshot)>
      _persistentUpdates =
      <String, void Function(BackgroundTaskSnapshot snapshot)>{};
  final Map<String, Completer<Object?>> _persistentCompleters =
      <String, Completer<Object?>>{};

  Map<String, Object?>? persistedTables;
  bool failNextPersistentJob = false;
  int disposeCalls = 0;
  int persistentRuns = 0;

  @override
  Future<void> disposeSimulationWorker() async {
    disposeCalls += 1;
  }

  void emitJobProgress(String taskType, String label, double progress) {
    _jobUpdates[taskType]?.call(
      BackgroundTaskSnapshot(
        taskType: taskType,
        label: label,
        inProgress: true,
        progress: progress,
      ),
    );
  }

  void emitPersistentProgress(String taskType, String label, double progress) {
    _persistentUpdates[taskType]?.call(
      BackgroundTaskSnapshot(
        taskType: taskType,
        label: label,
        inProgress: true,
        progress: progress,
      ),
    );
  }

  void completeJob(String taskType, Object? value) {
    _jobCompleters[taskType]?.complete(value);
  }

  void completePersistentJob(String taskType, Object? value) {
    _persistentCompleters[taskType]?.complete(value);
  }

  @override
  Future<void> prewarmSimulationWorker({
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    persistedTables = <String, Object?>{
      'version': simulationWarmupSnapshotVersion,
      'schema': simulationWarmupSnapshotSchema,
      'appVersion': 'test',
      'bot': <String, Object?>{'a': 1},
      'x01': <String, Object?>{'b': 2},
    };
    onUpdate?.call(
      const BackgroundTaskSnapshot(
        taskType: 'prepare_simulation',
        label: 'warm',
        inProgress: true,
        progress: 0.5,
      ),
    );
  }

  @override
  Future<Map<String, Object?>?> readPersistedSimulationTables() async {
    return persistedTables;
  }

  @override
  Future<T> runJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    final completer = Completer<Object?>();
    _jobCompleters[taskType] = completer;
    if (onUpdate != null) {
      _jobUpdates[taskType] = onUpdate;
    }
    return completer.future.then((value) => value as T);
  }

  @override
  Future<T> runPersistentJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) {
    persistentRuns += 1;
    if (failNextPersistentJob) {
      failNextPersistentJob = false;
      return Future<T>.error(StateError('worker crashed'));
    }
    final completer = Completer<Object?>();
    _persistentCompleters[taskType] = completer;
    if (onUpdate != null) {
      _persistentUpdates[taskType] = onUpdate;
    }
    return completer.future.then((value) => value as T);
  }
}

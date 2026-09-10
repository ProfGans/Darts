import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:DartCore/data/background/simulation_warmup_bundle_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate bundled simulation warmup snapshot', () async {
    final stopwatch = Stopwatch()..start();
    final startRadius = _readIntEnv(
      'SIM_WARMUP_START_RADIUS',
      kSimulationWarmupDisplayRadiusMin,
    );
    final endRadius = _readIntEnv(
      'SIM_WARMUP_END_RADIUS',
      kSimulationWarmupDisplayRadiusMax,
    );
    final outputPath = Platform.environment['SIM_WARMUP_OUTPUT_PATH'] ??
        'assets/data/bundled_simulation_warmup_snapshot.json';
    final snapshot = await buildSimulationWarmupSnapshot(
      startDisplayRadius: startRadius,
      endDisplayRadius: endRadius,
      onProgress: (label, progress) {
        final progressText = progress == null
            ? label
            : '$label ${(progress * 100).toStringAsFixed(0)}%';
        // ignore: avoid_print
        print(progressText);
      },
    );

    final outputFile = File(outputPath);
    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsStringSync(jsonEncode(snapshot));

    // ignore: avoid_print
    print(
      'generated_snapshot=${outputFile.path} bytes=${outputFile.lengthSync()} elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}

int _readIntEnv(String key, int fallback) {
  final raw = Platform.environment[key];
  return int.tryParse(raw ?? '') ?? fallback;
}

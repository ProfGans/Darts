import 'dart:convert';
import 'dart:io';

import 'package:DartCore/data/background/simulation_warmup_bundle_builder.dart';
const String _defaultOutputPath =
    'assets/data/bundled_simulation_warmup_snapshot.json';

Future<void> main(List<String> arguments) async {
  final options = _parseOptions(arguments);
  final stopwatch = Stopwatch()..start();
  stdout.writeln(
    'Generating canonical warmup snapshot for '
    '${options.endRadius - options.startRadius + 1} radius buckets...',
  );
  await stdout.flush();

  final snapshot = await buildSimulationWarmupSnapshot(
    startDisplayRadius: options.startRadius,
    endDisplayRadius: options.endRadius,
    displaySpreadPercent: kSimulationWarmupDisplaySpreadPercent,
    onProgress: (label, progress) {
      final progressText = progress == null
          ? label
          : '$label ${(progress * 100).toStringAsFixed(0)}%';
      stdout.writeln(progressText);
    },
  );
  snapshot['generator'] = 'tool/generate_simulation_warmup_snapshot.dart';

  _writeSnapshot(
    snapshot,
    outputPath: options.outputPath,
    pretty: options.pretty,
  );
  stdout.writeln(
    'Wrote ${options.outputPath} in ${stopwatch.elapsed.inSeconds}s',
  );
}

void _writeSnapshot(
  Map<String, Object?> snapshot, {
  required String outputPath,
  required bool pretty,
}) {
  final targetFile = File(outputPath);
  targetFile.parent.createSync(recursive: true);
  final encoder = pretty ? const JsonEncoder.withIndent('  ') : const JsonEncoder();
  targetFile.writeAsStringSync(encoder.convert(snapshot));
}

_GeneratorOptions _parseOptions(List<String> arguments) {
  var startRadius = kSimulationWarmupDisplayRadiusMin;
  var endRadius = kSimulationWarmupDisplayRadiusMax;
  var outputPath = _defaultOutputPath;
  var pretty = false;

  for (final argument in arguments) {
    if (argument == '--pretty') {
      pretty = true;
      continue;
    }
    if (argument.startsWith('--start=')) {
      startRadius = int.tryParse(argument.substring('--start='.length)) ??
          startRadius;
      continue;
    }
    if (argument.startsWith('--end=')) {
      endRadius =
          int.tryParse(argument.substring('--end='.length)) ?? endRadius;
      continue;
    }
    if (argument.startsWith('--output=')) {
      outputPath = argument.substring('--output='.length);
    }
  }

  if (startRadius > endRadius) {
    final temp = startRadius;
    startRadius = endRadius;
    endRadius = temp;
  }

  return _GeneratorOptions(
    startRadius: startRadius.clamp(
      kSimulationWarmupDisplayRadiusMin,
      kSimulationWarmupDisplayRadiusMax,
    ),
    endRadius: endRadius.clamp(
      kSimulationWarmupDisplayRadiusMin,
      kSimulationWarmupDisplayRadiusMax,
    ),
    outputPath: outputPath,
    pretty: pretty,
  );
}

class _GeneratorOptions {
  const _GeneratorOptions({
    required this.startRadius,
    required this.endRadius,
    required this.outputPath,
    required this.pretty,
  });

  final int startRadius;
  final int endRadius;
  final String outputPath;
  final bool pretty;
}

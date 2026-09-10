import '../../domain/tournament/tournament_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../repositories/settings_repository.dart';
import 'simulation_snapshot.dart';

const int kSimulationWarmupDisplayRadiusMin = 90;
const int kSimulationWarmupDisplayRadiusMax = 110;
const int kSimulationWarmupDisplaySpreadPercent = 100;

Future<Map<String, Object?>> buildSimulationWarmupSnapshot({
  int startDisplayRadius = kSimulationWarmupDisplayRadiusMin,
  int endDisplayRadius = kSimulationWarmupDisplayRadiusMax,
  int displaySpreadPercent = kSimulationWarmupDisplaySpreadPercent,
  void Function(String label, double? progress)? onProgress,
}) async {
  var normalizedStart = startDisplayRadius.clamp(
    kSimulationWarmupDisplayRadiusMin,
    kSimulationWarmupDisplayRadiusMax,
  );
  var normalizedEnd = endDisplayRadius.clamp(
    kSimulationWarmupDisplayRadiusMin,
    kSimulationWarmupDisplayRadiusMax,
  );
  if (normalizedStart > normalizedEnd) {
    final temp = normalizedStart;
    normalizedStart = normalizedEnd;
    normalizedEnd = temp;
  }

  final effectiveSpread = SettingsRepository.effectiveSpreadPercentForDisplay(
    displaySpreadPercent,
  );
  final radii = <(int, int)>[
    for (var displayRadius = normalizedStart;
        displayRadius <= normalizedEnd;
        displayRadius += 1)
      (
        displayRadius,
        SettingsRepository.effectiveRadiusPercentForDisplay(displayRadius),
      ),
  ];

  final engine = TournamentEngine();
  await engine.prepareCommonSimulationCaches(
    profiles: <BotProfile>[
      for (final (_, effectiveRadius) in radii)
        ..._buildProfiles(
          effectiveRadius: effectiveRadius,
          effectiveSpread: effectiveSpread,
        ),
    ],
    maxRepresentativeProfiles: radii.length * 3 + 2,
    onProgress: onProgress,
  );

  final snapshot = <String, Object?>{
    'version': simulationWarmupSnapshotVersion,
    'schema': simulationWarmupSnapshotSchema,
    'appVersion': simulationWarmupSnapshotAppVersion,
    'generator': 'simulation_warmup_bundle_builder',
    'displayRadiusMin': normalizedStart,
    'displayRadiusMax': normalizedEnd,
    'displaySpreadPercent': displaySpreadPercent,
    'bot': <String, Object?>{},
    'x01': <String, Object?>{},
  };
  final exported = engine.exportDeterministicWarmupTables();
  _deepMergeMaps(
    (snapshot['bot'] as Map<String, Object?>),
    ((exported['bot'] as Map?) ?? const <Object?, Object?>{})
        .cast<String, Object?>(),
  );
  _deepMergeMaps(
    (snapshot['x01'] as Map<String, Object?>),
    ((exported['x01'] as Map?) ?? const <Object?, Object?>{})
        .cast<String, Object?>(),
  );
  return snapshot;
}

Iterable<BotProfile> _buildProfiles({
  required int effectiveRadius,
  required int effectiveSpread,
}) sync* {
  for (final (skill, finishingSkill) in const <(int, int)>[
    (320, 260),
    (420, 360),
    (560, 440),
    (700, 520),
    (820, 700),
    (920, 860),
    (1020, 940),
  ]) {
    yield BotProfile(
      skill: skill,
      finishingSkill: finishingSkill,
      radiusCalibrationPercent: effectiveRadius,
      simulationSpreadPercent: effectiveSpread,
    );
  }
}

void _deepMergeMaps(
  Map<String, Object?> target,
  Map<String, Object?> source,
) {
  for (final entry in source.entries) {
    final existing = target[entry.key];
    final next = entry.value;
    if (existing is Map && next is Map) {
      final mergedChild = existing.cast<String, Object?>();
      _deepMergeMaps(mergedChild, next.cast<String, Object?>());
      target[entry.key] = mergedChild;
      continue;
    }
    target[entry.key] = next;
  }
}

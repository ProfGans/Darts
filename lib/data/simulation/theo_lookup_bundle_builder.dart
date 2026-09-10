import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../repositories/settings_repository.dart';

const int kTheoLookupDisplayRadiusMin = 90;
const int kTheoLookupDisplayRadiusMax = 110;
const int kTheoLookupTargetAverageMinTenths = 350;
const int kTheoLookupTargetAverageMaxTenths = 1200;
const int kTheoLookupEffectiveSpreadPercent = 115;
const int _minSkill = 1;
const int _maxSkill = 1000;

class _TheoCandidate {
  const _TheoCandidate({
    required this.skill,
    required this.finishingSkill,
    required this.average,
    required this.error,
  });

  final int skill;
  final int finishingSkill;
  final double average;
  final double error;

  int get gap => (skill - finishingSkill).abs();

  _TheoCandidate copyWithError(double target) {
    return _TheoCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      average: average,
      error: (average - target).abs(),
    );
  }
}

String buildGeneratedTheoLookupTableSource({
  int startDisplayRadius = kTheoLookupDisplayRadiusMin,
  int endDisplayRadius = kTheoLookupDisplayRadiusMax,
  void Function(String label, double? progress)? onProgress,
}) {
  var normalizedStart = startDisplayRadius.clamp(
    kTheoLookupDisplayRadiusMin,
    kTheoLookupDisplayRadiusMax,
  );
  var normalizedEnd = endDisplayRadius.clamp(
    kTheoLookupDisplayRadiusMin,
    kTheoLookupDisplayRadiusMax,
  );
  if (normalizedStart > normalizedEnd) {
    final temp = normalizedStart;
    normalizedStart = normalizedEnd;
    normalizedEnd = temp;
  }

  final engine = BotEngine(recordPerformanceLogs: false);
  final effectiveRadii = <int>{
    for (var displayRadius = normalizedStart;
        displayRadius <= normalizedEnd;
        displayRadius += 1)
      SettingsRepository.effectiveRadiusPercentForDisplay(displayRadius),
  }.toList()
    ..sort();
  final totalBuckets = effectiveRadii.length.clamp(1, 1 << 30);

  final buffer = StringBuffer()
    ..writeln(
      'const int kTheoLookupAverageMinTenths = $kTheoLookupTargetAverageMinTenths;',
    )
    ..writeln(
      'const int kTheoLookupAverageMaxTenths = $kTheoLookupTargetAverageMaxTenths;',
    )
    ..writeln(
      'const int kTheoLookupSupportedEffectiveSpreadPercent = $kTheoLookupEffectiveSpreadPercent;',
    )
    ..writeln()
    ..writeln(
      'const Map<int, List<int>> kTheoLookupSkillPairsByEffectiveRadius = <int, List<int>>{',
    );

  onProgress?.call('Theo-Lookup wird vorbereitet', 0);
  for (var bucketIndex = 0; bucketIndex < effectiveRadii.length; bucketIndex += 1) {
    final effectiveRadius = effectiveRadii[bucketIndex];
    onProgress?.call(
      'Theo-Lookup Radius $effectiveRadius wird berechnet',
      bucketIndex / totalBuckets,
    );
    final values = _buildRadiusBucket(
      engine: engine,
      effectiveRadius: effectiveRadius,
    );
    buffer
      ..writeln('  $effectiveRadius: <int>[')
      ..writeln(_wrapInts(values))
      ..writeln('  ],');
  }

  buffer.writeln('};');
  onProgress?.call('Theo-Lookup ist bereit', 1);
  return buffer.toString();
}

List<int> _buildRadiusBucket({
  required BotEngine engine,
  required int effectiveRadius,
}) {
  final averageCache = <String, double>{};
  final equalCandidates = <_TheoCandidate>[];

  double averageFor(int skill, int finishingSkill) {
    final cacheKey = '$skill:$finishingSkill';
    final cached = averageCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final average = engine
        .estimateFallbackThreeDartAverage(
          BotProfile(
            skill: skill,
            finishingSkill: finishingSkill,
            radiusCalibrationPercent: effectiveRadius,
            simulationSpreadPercent: kTheoLookupEffectiveSpreadPercent,
          ),
        )
        .clamp(0, 180)
        .toDouble();
    averageCache[cacheKey] = average;
    return average;
  }

  _TheoCandidate buildCandidate(int skill, int finishingSkill, double target) {
    final average = averageFor(skill, finishingSkill);
    return _TheoCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      average: average,
      error: (average - target).abs(),
    );
  }

  for (var skill = _minSkill; skill <= _maxSkill; skill += 1) {
    equalCandidates.add(
      _TheoCandidate(
        skill: skill,
        finishingSkill: skill,
        average: averageFor(skill, skill),
        error: 0,
      ),
    );
  }

  final values = <int>[];
  var equalIndex = 0;
  _TheoCandidate? previousBest;

  for (var targetTenths = kTheoLookupTargetAverageMinTenths;
      targetTenths <= kTheoLookupTargetAverageMaxTenths;
      targetTenths += 1) {
    final target = targetTenths / 10.0;

    while (equalIndex + 1 < equalCandidates.length &&
        equalCandidates[equalIndex + 1].average <= target) {
      equalIndex += 1;
    }

    var bestEqual = equalCandidates[equalIndex].copyWithError(target);
    if (equalIndex + 1 < equalCandidates.length) {
      bestEqual = _pickBetter(
        bestEqual,
        equalCandidates[equalIndex + 1].copyWithError(target),
      );
    }

    var best = previousBest == null
        ? bestEqual
        : _pickBetter(previousBest.copyWithError(target), bestEqual);

    var improved = true;
    while (improved) {
      improved = false;
      for (final (skillDelta, finishDelta) in const <(int, int)>[
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
        (1, 1),
        (-1, -1),
        (1, -1),
        (-1, 1),
      ]) {
        final nextSkill = best.skill + skillDelta;
        final nextFinish = best.finishingSkill + finishDelta;
        if (nextSkill < _minSkill ||
            nextSkill > _maxSkill ||
            nextFinish < _minSkill ||
            nextFinish > _maxSkill) {
          continue;
        }
        final next = buildCandidate(nextSkill, nextFinish, target);
        final chosen = _pickBetter(best, next);
        if (chosen.skill != best.skill ||
            chosen.finishingSkill != best.finishingSkill) {
          best = chosen;
          improved = true;
        }
      }
    }

    previousBest = best;
    values
      ..add(best.skill)
      ..add(best.finishingSkill);
  }

  return values;
}

_TheoCandidate _pickBetter(_TheoCandidate current, _TheoCandidate next) {
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
  final nextMaxSkill =
      next.skill > next.finishingSkill ? next.skill : next.finishingSkill;
  final currentMaxSkill = current.skill > current.finishingSkill
      ? current.skill
      : current.finishingSkill;
  if (nextMaxSkill != currentMaxSkill) {
    return nextMaxSkill < currentMaxSkill ? next : current;
  }
  final nextMinSkill =
      next.skill < next.finishingSkill ? next.skill : next.finishingSkill;
  final currentMinSkill = current.skill < current.finishingSkill
      ? current.skill
      : current.finishingSkill;
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

String _wrapInts(List<int> values) {
  final buffer = StringBuffer();
  for (var index = 0; index < values.length; index += 1) {
    if (index % 24 == 0) {
      buffer.write('    ');
    }
    buffer.write(values[index]);
    if (index != values.length - 1) {
      buffer.write(', ');
    }
    if (index % 24 == 23 || index == values.length - 1) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}

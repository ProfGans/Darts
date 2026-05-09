import 'dart:io';

import '../lib/data/repositories/settings_repository.dart';
import '../lib/domain/bot/bot_engine.dart';
import '../lib/domain/x01/x01_models.dart';

const int _displayRadiusMin = 90;
const int _displayRadiusMax = 110;
const int _targetAverageMinTenths = 350;
const int _targetAverageMaxTenths = 1200;
const int _effectiveSpread = 115;
const int _minSkill = 1;
const int _maxSkill = 1000;

class _Candidate {
  const _Candidate({
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
}

void main() {
  final engine = BotEngine(recordPerformanceLogs: false);
  final effectiveRadii = <int>{
    for (var displayRadius = _displayRadiusMin;
        displayRadius <= _displayRadiusMax;
        displayRadius += 1)
      SettingsRepository.effectiveRadiusPercentForDisplay(displayRadius),
  }.toList()
    ..sort();

  final buffer = StringBuffer()
    ..writeln('const int kTheoLookupAverageMinTenths = $_targetAverageMinTenths;')
    ..writeln('const int kTheoLookupAverageMaxTenths = $_targetAverageMaxTenths;')
    ..writeln(
      'const int kTheoLookupSupportedEffectiveSpreadPercent = $_effectiveSpread;',
    )
    ..writeln()
    ..writeln(
      'const Map<int, List<int>> kTheoLookupSkillPairsByEffectiveRadius = <int, List<int>>{',
    );

  for (final effectiveRadius in effectiveRadii) {
    stdout.writeln('Generating radius bucket $effectiveRadius...');
    final averageCache = <String, double>{};
    final equalCandidates = <_Candidate>[];

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
              simulationSpreadPercent: _effectiveSpread,
            ),
          )
          .clamp(0, 180)
          .toDouble();
      averageCache[cacheKey] = average;
      return average;
    }

    _Candidate buildCandidate(int skill, int finishingSkill, double target) {
      final average = averageFor(skill, finishingSkill);
      return _Candidate(
        skill: skill,
        finishingSkill: finishingSkill,
        average: average,
        error: (average - target).abs(),
      );
    }

    _Candidate pickBetter(_Candidate current, _Candidate next) {
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

    for (var skill = _minSkill; skill <= _maxSkill; skill += 1) {
      final average = averageFor(skill, skill);
      equalCandidates.add(
        _Candidate(
          skill: skill,
          finishingSkill: skill,
          average: average,
          error: 0,
        ),
      );
    }

    final values = <int>[];
    var equalIndex = 0;
    _Candidate? previousBest;

    for (var targetTenths = _targetAverageMinTenths;
        targetTenths <= _targetAverageMaxTenths;
        targetTenths += 1) {
      final target = targetTenths / 10.0;

      while (equalIndex + 1 < equalCandidates.length &&
          equalCandidates[equalIndex + 1].average <= target) {
        equalIndex += 1;
      }

      var bestEqual = equalCandidates[equalIndex];
      if (equalIndex + 1 < equalCandidates.length) {
        bestEqual = pickBetter(
          bestEqual.copyWithError(target),
          equalCandidates[equalIndex + 1].copyWithError(target),
        );
      } else {
        bestEqual = bestEqual.copyWithError(target);
      }

      var best = previousBest == null
          ? bestEqual
          : pickBetter(previousBest.copyWithError(target), bestEqual);

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
          final chosen = pickBetter(best, next);
          if (!identical(chosen, best) &&
              (chosen.skill != best.skill ||
                  chosen.finishingSkill != best.finishingSkill)) {
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

    buffer
      ..writeln('  $effectiveRadius: <int>[')
      ..writeln(_wrapInts(values))
      ..writeln('  ],');
  }

  buffer.writeln('};');

  final targetFile = File(
    'lib/data/simulation/generated_theo_lookup_table.dart',
  );
  targetFile.writeAsStringSync(buffer.toString());
  stdout.writeln(
    'Wrote ${targetFile.path} for ${effectiveRadii.length} radius buckets.',
  );
}

extension on _Candidate {
  _Candidate copyWithError(double target) {
    return _Candidate(
      skill: skill,
      finishingSkill: finishingSkill,
      average: average,
      error: (average - target).abs(),
    );
  }
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

import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../repositories/settings_repository.dart';
import '../storage/app_storage.dart';
import 'generated_theo_lookup_table.dart';

class TheoLookupResolution {
  const TheoLookupResolution({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
}

class _TheoLookupCandidate {
  const _TheoLookupCandidate({
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

  TheoLookupResolution toResolution() {
    return TheoLookupResolution(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: theoreticalAverage,
    );
  }
}

class TheoResolutionLookup {
  static const double minSupportedAverage = 35.0;
  static const double maxSupportedAverage = 120.0;
  static const double supportedAverageStep = 0.1;

  static const int _minimumSkill = 1;
  static const int _maximumSkill = 1000;
  static const int _persistentCacheVersion = 1;
  static const String _storageKey = 'theo_lookup_buckets_v1';
  static const List<(int, int)> _neighborOffsets = <(int, int)>[
    (1, 0),
    (-1, 0),
    (0, 1),
    (0, -1),
    (1, 1),
    (-1, -1),
    (1, -1),
    (-1, 1),
  ];

  static final Map<int, List<int>> _runtimePackedBuckets = <int, List<int>>{};
  static final Map<int, Future<void>> _pendingBucketBuilds = <int, Future<void>>{};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final payload = await AppStorage.instance.readJsonMap(_storageKey);
    if (payload == null) {
      return;
    }
    final version = (payload['version'] as num?)?.toInt() ?? 0;
    if (version != _persistentCacheVersion) {
      return;
    }
    final spread = (payload['effectiveSpreadPercent'] as num?)?.toInt();
    if (spread != kTheoLookupSupportedEffectiveSpreadPercent) {
      return;
    }
    final buckets = payload['radiusBuckets'];
    if (buckets is! Map) {
      return;
    }
    for (final entry in buckets.entries) {
      final radius = int.tryParse(entry.key.toString());
      final packed = _coerceIntList(entry.value);
      if (radius == null || packed == null || packed.isEmpty) {
        continue;
      }
      _runtimePackedBuckets[radius] = packed;
    }
  }

  static Future<void> prewarmCurrentSettingsBucket() {
    final settings = SettingsRepository.instance.settings;
    return prewarmBucket(
      effectiveRadiusCalibrationPercent:
          SettingsRepository.effectiveRadiusPercentForDisplay(
        settings.radiusCalibrationPercent,
      ),
      effectiveSimulationSpreadPercent:
          SettingsRepository.effectiveSpreadPercentForDisplay(
        settings.simulationSpreadPercent,
      ),
    );
  }

  static Future<void> prewarmBucket({
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
  }) {
    final minSupportedEffectiveRadius =
        SettingsRepository.effectiveRadiusPercentForDisplay(90);
    final maxSupportedEffectiveRadius =
        SettingsRepository.effectiveRadiusPercentForDisplay(110);
    final supportedEffectiveSpread =
        SettingsRepository.effectiveSpreadPercentForDisplay(100);
    if (!usesSupportedGrid(
      targetAverage: minSupportedAverage,
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent:
          minSupportedEffectiveRadius,
      maxSupportedEffectiveRadiusCalibrationPercent:
          maxSupportedEffectiveRadius,
      fixedSupportedEffectiveSimulationSpreadPercent: supportedEffectiveSpread,
    )) {
      return Future<void>.value();
    }
    if (_packedBucketForRadius(
          effectiveRadiusCalibrationPercent,
          effectiveSimulationSpreadPercent,
        ) !=
        null) {
      return Future<void>.value();
    }
    final existing = _pendingBucketBuilds[effectiveRadiusCalibrationPercent];
    if (existing != null) {
      return existing;
    }
    final future = _buildAndPersistBucket(
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
    );
    _pendingBucketBuilds[effectiveRadiusCalibrationPercent] = future;
    future.whenComplete(() {
      _pendingBucketBuilds.remove(effectiveRadiusCalibrationPercent);
    });
    return future;
  }

  static bool usesSupportedGrid({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
  }) {
    return targetAverage >= minSupportedAverage &&
        targetAverage <= maxSupportedAverage &&
        effectiveRadiusCalibrationPercent >=
            minSupportedEffectiveRadiusCalibrationPercent &&
        effectiveRadiusCalibrationPercent <=
            maxSupportedEffectiveRadiusCalibrationPercent &&
        effectiveSimulationSpreadPercent ==
            fixedSupportedEffectiveSimulationSpreadPercent;
  }

  static TheoLookupResolution resolve({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
    required double Function(int skill, int finishingSkill) estimateAverage,
    Map<String, TheoLookupResolution>? cache,
    bool scheduleSupportedGridPrewarm = true,
  }) {
    final useSupportedGrid = usesSupportedGrid(
      targetAverage: targetAverage,
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent:
          minSupportedEffectiveRadiusCalibrationPercent,
      maxSupportedEffectiveRadiusCalibrationPercent:
          maxSupportedEffectiveRadiusCalibrationPercent,
      fixedSupportedEffectiveSimulationSpreadPercent:
          fixedSupportedEffectiveSimulationSpreadPercent,
    );
    final normalizedTarget = useSupportedGrid
        ? normalizeSupportedAverage(targetAverage)
        : targetAverage.clamp(0, 180).toDouble();
    final cacheKey = <String>[
      'lookup',
      effectiveRadiusCalibrationPercent.toString(),
      effectiveSimulationSpreadPercent.toString(),
      useSupportedGrid
          ? normalizedTarget.toStringAsFixed(1)
          : normalizedTarget.toStringAsFixed(4),
    ].join('|');
    final cached = cache?[cacheKey];
    if (cached != null) {
      return cached;
    }

    final precomputed = useSupportedGrid
        ? resolvePrecomputed(
            targetAverage: normalizedTarget,
            effectiveRadiusCalibrationPercent:
                effectiveRadiusCalibrationPercent,
            effectiveSimulationSpreadPercent:
                effectiveSimulationSpreadPercent,
            minSupportedEffectiveRadiusCalibrationPercent:
                minSupportedEffectiveRadiusCalibrationPercent,
            maxSupportedEffectiveRadiusCalibrationPercent:
                maxSupportedEffectiveRadiusCalibrationPercent,
            fixedSupportedEffectiveSimulationSpreadPercent:
                fixedSupportedEffectiveSimulationSpreadPercent,
          )
        : null;
    if (precomputed != null) {
      cache?[cacheKey] = precomputed;
      return precomputed;
    }

    if (useSupportedGrid && scheduleSupportedGridPrewarm) {
      unawaited(
        prewarmBucket(
          effectiveRadiusCalibrationPercent:
              effectiveRadiusCalibrationPercent,
          effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
        ),
      );
    }

    _TheoLookupCandidate buildCandidate({
      required int skill,
      required int finishingSkill,
    }) {
      final average = estimateAverage(skill, finishingSkill);
      return _TheoLookupCandidate(
        skill: skill,
        finishingSkill: finishingSkill,
        theoreticalAverage: average,
        error: (average - normalizedTarget).abs(),
      );
    }

    final bestEqual = _searchCandidate(
      target: normalizedTarget,
      minimumValue: _minimumSkill,
      maximumValue: _maximumSkill,
      buildValueCandidate: (value) => buildCandidate(
        skill: value,
        finishingSkill: value,
      ),
    );
    final moveUp = normalizedTarget >= bestEqual.theoreticalAverage;
    final minimumValue = moveUp ? bestEqual.skill : _minimumSkill;
    final maximumValue = moveUp ? _maximumSkill : bestEqual.skill;
    final skillDriven = _searchCandidate(
      target: normalizedTarget,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildValueCandidate: (value) => buildCandidate(
        skill: value,
        finishingSkill: bestEqual.finishingSkill,
      ),
    );
    final finishingDriven = _searchCandidate(
      target: normalizedTarget,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildValueCandidate: (value) => buildCandidate(
        skill: bestEqual.skill,
        finishingSkill: value,
      ),
    );

    const improvementEpsilon = 0.01;
    final bestSplit = _pickBetterCandidate(
      current: skillDriven,
      next: finishingDriven,
    );
    final resolution =
        bestSplit != null && bestSplit.error + improvementEpsilon < bestEqual.error
            ? bestSplit.toResolution()
            : bestEqual.toResolution();
    cache?[cacheKey] = resolution;
    return resolution;
  }

  static TheoLookupResolution? resolvePrecomputed({
    required double targetAverage,
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
    required int minSupportedEffectiveRadiusCalibrationPercent,
    required int maxSupportedEffectiveRadiusCalibrationPercent,
    required int fixedSupportedEffectiveSimulationSpreadPercent,
  }) {
    if (!usesSupportedGrid(
      targetAverage: targetAverage,
      effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent: effectiveSimulationSpreadPercent,
      minSupportedEffectiveRadiusCalibrationPercent:
          minSupportedEffectiveRadiusCalibrationPercent,
      maxSupportedEffectiveRadiusCalibrationPercent:
          maxSupportedEffectiveRadiusCalibrationPercent,
      fixedSupportedEffectiveSimulationSpreadPercent:
          fixedSupportedEffectiveSimulationSpreadPercent,
    )) {
      return null;
    }
    final packed = _packedBucketForRadius(
      effectiveRadiusCalibrationPercent,
      effectiveSimulationSpreadPercent,
    );
    if (packed == null || packed.isEmpty) {
      return null;
    }
    return _resolvePacked(
      packed: packed,
      normalizedTarget: normalizeSupportedAverage(targetAverage),
    );
  }

  static double normalizeSupportedAverage(double value) {
    final clamped = value.clamp(minSupportedAverage, maxSupportedAverage);
    return ((clamped * 10).round() / 10).toDouble();
  }

  static TheoLookupResolution? _resolvePacked({
    required List<int> packed,
    required double normalizedTarget,
  }) {
    final targetTenths = (normalizedTarget * 10).round();
    if (targetTenths < kTheoLookupAverageMinTenths ||
        targetTenths > kTheoLookupAverageMaxTenths) {
      return null;
    }
    final index = targetTenths - kTheoLookupAverageMinTenths;
    final dataIndex = index * 2;
    if (dataIndex < 0 || dataIndex + 1 >= packed.length) {
      return null;
    }
    return TheoLookupResolution(
      skill: packed[dataIndex],
      finishingSkill: packed[dataIndex + 1],
      theoreticalAverage: normalizedTarget,
    );
  }

  static List<int>? _packedBucketForRadius(
    int effectiveRadiusCalibrationPercent,
    int effectiveSimulationSpreadPercent,
  ) {
    if (effectiveSimulationSpreadPercent !=
        kTheoLookupSupportedEffectiveSpreadPercent) {
      return null;
    }
    final bundled =
        kTheoLookupSkillPairsByEffectiveRadius[effectiveRadiusCalibrationPercent];
    if (bundled != null && bundled.isNotEmpty) {
      return bundled;
    }
    return _runtimePackedBuckets[effectiveRadiusCalibrationPercent];
  }

  static Future<void> _buildAndPersistBucket({
    required int effectiveRadiusCalibrationPercent,
    required int effectiveSimulationSpreadPercent,
  }) async {
    if (effectiveSimulationSpreadPercent !=
        kTheoLookupSupportedEffectiveSpreadPercent) {
      return;
    }
    final built = kIsWeb
        ? _buildPersistentBucket(
            effectiveRadiusCalibrationPercent: effectiveRadiusCalibrationPercent,
            effectiveSimulationSpreadPercent:
                effectiveSimulationSpreadPercent,
          )
        : await Isolate.run<List<int>>(
            () => _buildPersistentBucket(
              effectiveRadiusCalibrationPercent:
                  effectiveRadiusCalibrationPercent,
              effectiveSimulationSpreadPercent:
                  effectiveSimulationSpreadPercent,
            ),
          );
    _runtimePackedBuckets[effectiveRadiusCalibrationPercent] = built;
    await _persistBuckets();
  }

  static Future<void> _persistBuckets() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, Object?>{
        'version': _persistentCacheVersion,
        'effectiveSpreadPercent': kTheoLookupSupportedEffectiveSpreadPercent,
        'radiusBuckets': <String, Object?>{
          for (final entry in _runtimePackedBuckets.entries)
            entry.key.toString(): entry.value,
        },
      },
    );
  }

  static _TheoLookupCandidate _searchCandidate({
    required double target,
    required int minimumValue,
    required int maximumValue,
    required _TheoLookupCandidate Function(int value) buildValueCandidate,
  }) {
    var low = minimumValue;
    var high = maximumValue;
    _TheoLookupCandidate? best;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final middleCandidate = buildValueCandidate(middle);
      best = _pickBetterCandidate(current: best, next: middleCandidate);
      if (middleCandidate.theoreticalAverage < target) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    for (final value in <int>{low, high, low - 1, high + 1}) {
      if (value < minimumValue || value > maximumValue) {
        continue;
      }
      best = _pickBetterCandidate(
        current: best,
        next: buildValueCandidate(value),
      );
    }

    return best!;
  }

  static _TheoLookupCandidate? _pickBetterCandidate({
    required _TheoLookupCandidate? current,
    required _TheoLookupCandidate next,
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
}

List<int> _buildPersistentBucket({
  required int effectiveRadiusCalibrationPercent,
  required int effectiveSimulationSpreadPercent,
}) {
  final engine = BotEngine(recordPerformanceLogs: false);
  final averageCache = <String, double>{};
  final equalCandidates = <_TheoLookupCandidate>[];

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
            radiusCalibrationPercent: effectiveRadiusCalibrationPercent,
            simulationSpreadPercent: effectiveSimulationSpreadPercent,
          ),
        )
        .clamp(0, 180)
        .toDouble();
    averageCache[cacheKey] = average;
    return average;
  }

  _TheoLookupCandidate buildCandidate({
    required int skill,
    required int finishingSkill,
    required double target,
  }) {
    final average = averageFor(skill, finishingSkill);
    return _TheoLookupCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: average,
      error: (average - target).abs(),
    );
  }

  for (var skill = TheoResolutionLookup._minimumSkill;
      skill <= TheoResolutionLookup._maximumSkill;
      skill += 1) {
    equalCandidates.add(
      _TheoLookupCandidate(
        skill: skill,
        finishingSkill: skill,
        theoreticalAverage: averageFor(skill, skill),
        error: 0,
      ),
    );
  }

  final packed = <int>[];
  var equalIndex = 0;
  _TheoLookupCandidate? previousBest;

  for (var targetTenths = kTheoLookupAverageMinTenths;
      targetTenths <= kTheoLookupAverageMaxTenths;
      targetTenths += 1) {
    final target = targetTenths / 10.0;

    while (equalIndex + 1 < equalCandidates.length &&
        equalCandidates[equalIndex + 1].theoreticalAverage <= target) {
      equalIndex += 1;
    }

    var bestEqual = _candidateWithTargetError(equalCandidates[equalIndex], target);
    if (equalIndex + 1 < equalCandidates.length) {
      bestEqual = TheoResolutionLookup._pickBetterCandidate(
            current: bestEqual,
            next: _candidateWithTargetError(
              equalCandidates[equalIndex + 1],
              target,
            ),
          ) ??
          bestEqual;
    }

    var best = previousBest == null
        ? bestEqual
        : (TheoResolutionLookup._pickBetterCandidate(
              current: _candidateWithTargetError(previousBest, target),
              next: bestEqual,
            ) ??
            bestEqual);

    var improved = true;
    while (improved) {
      improved = false;
      for (final (skillDelta, finishDelta) in TheoResolutionLookup._neighborOffsets) {
        final nextSkill = best.skill + skillDelta;
        final nextFinishingSkill = best.finishingSkill + finishDelta;
        if (nextSkill < TheoResolutionLookup._minimumSkill ||
            nextSkill > TheoResolutionLookup._maximumSkill ||
            nextFinishingSkill < TheoResolutionLookup._minimumSkill ||
            nextFinishingSkill > TheoResolutionLookup._maximumSkill) {
          continue;
        }
        final next = buildCandidate(
          skill: nextSkill,
          finishingSkill: nextFinishingSkill,
          target: target,
        );
        final chosen =
            TheoResolutionLookup._pickBetterCandidate(current: best, next: next) ??
                best;
        if (chosen.skill != best.skill ||
            chosen.finishingSkill != best.finishingSkill) {
          best = chosen;
          improved = true;
        }
      }
    }

    previousBest = best;
    packed
      ..add(best.skill)
      ..add(best.finishingSkill);
  }

  return packed;
}

_TheoLookupCandidate _candidateWithTargetError(
  _TheoLookupCandidate candidate,
  double target,
) {
  return _TheoLookupCandidate(
    skill: candidate.skill,
    finishingSkill: candidate.finishingSkill,
    theoreticalAverage: candidate.theoreticalAverage,
    error: (candidate.theoreticalAverage - target).abs(),
  );
}

List<int>? _coerceIntList(Object? value) {
  if (value is! List) {
    return null;
  }
  final converted = <int>[];
  for (final entry in value) {
    final number = (entry as num?)?.toInt();
    if (number == null) {
      return null;
    }
    converted.add(number);
  }
  return converted;
}

import 'dart:math';

import '../board/board_geometry.dart';
import '../x01/checkout_planner.dart';
import '../x01/x01_models.dart';
import '../x01/x01_rules.dart';

class BotAimDecision {
  const BotAimDecision({
    required this.target,
    required this.reason,
    this.route = const <DartThrowResult>[],
  });

  final DartThrowResult target;
  final String reason;
  final List<DartThrowResult> route;
}

class BotThrowSimulation {
  const BotThrowSimulation({
    required this.target,
    required this.hit,
    required this.targetPoint,
    required this.hitPoint,
    required this.scatterRadius,
    required this.reason,
    this.plannedRoute = const <DartThrowResult>[],
  });

  final DartThrowResult target;
  final DartThrowResult hit;
  final BoardPoint targetPoint;
  final BoardPoint hitPoint;
  final double scatterRadius;
  final String reason;
  final List<DartThrowResult> plannedRoute;
}

class _LeaveCandidate {
  const _LeaveCandidate({
    required this.target,
    required this.rest,
    required this.leavePreference,
  });

  final DartThrowResult target;
  final int rest;
  final int leavePreference;
}

class _SetupCandidate {
  const _SetupCandidate({
    required this.target,
    required this.route,
    required this.rest,
  });

  final DartThrowResult target;
  final List<DartThrowResult> route;
  final int rest;
}

class _ThrowModel {
  const _ThrowModel({
    required this.radialScale,
    required this.tangentialScale,
    required this.radialBias,
    required this.consistencySigma,
    required this.pressureMultiplier,
  });

  final double radialScale;
  final double tangentialScale;
  final double radialBias;
  final double consistencySigma;
  final double pressureMultiplier;
}

class BotEngine {
  static const int _legacyRadiusBaselinePercent = 92;
  static const int _legacySimulationSpreadBaselinePercent = 115;

  BotEngine({
    X01Rules? rules,
    BoardGeometry? boardGeometry,
    CheckoutPlanner? checkoutPlanner,
  })  : rules = rules ?? const X01Rules(),
        boardGeometry = boardGeometry ?? const BoardGeometry(),
        checkoutPlanner =
            checkoutPlanner ?? CheckoutPlanner(rules: rules ?? const X01Rules());

  final X01Rules rules;
  final BoardGeometry boardGeometry;
  final CheckoutPlanner checkoutPlanner;

  final Map<String, List<DartThrowResult>?> _preferredCheckoutCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, DartThrowResult?> _preferredSetupTargetCache =
      <String, DartThrowResult?>{};
  final Map<String, DartThrowResult?> _inVisitSetupTargetCache =
      <String, DartThrowResult?>{};
  final Map<int, DartThrowResult?> _preferredLeaveTargetCache =
      <int, DartThrowResult?>{};
  final Map<int, int> _leavePreferenceCache = <int, int>{};
  final Map<int, int> _leaveBullPenaltyCache = <int, int>{};
  final Map<String, List<List<DartThrowResult>>> _checkoutRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, double> _theoreticalAverageCache = <String, double>{};
  final List<DartThrowResult> _allThrows = const X01Rules().buildAllThrows();

  BotAimDecision decideAim({
    required BotProfile profile,
    required int score,
    required int dartsRemaining,
  }) {
    final preferredCheckout = findPreferredCheckout(
      score: score,
      dartsLeft: dartsRemaining,
    );
    if (preferredCheckout != null && preferredCheckout.isNotEmpty) {
      return BotAimDecision(
        target: preferredCheckout.first,
        reason: 'Preferred checkout',
        route: preferredCheckout,
      );
    }

    final setupTarget = findPreferredSetupTarget(
      score: score,
      dartsLeft: dartsRemaining,
    );
    if (setupTarget != null) {
      return BotAimDecision(
        target: setupTarget,
        reason: 'Preferred setup',
      );
    }

    if (score > 170) {
      return BotAimDecision(
        target: rules.createTriple(20),
        reason: 'Maximum scoring',
      );
    }

    if (score == 50) {
      final target = profile.finishingSkill >= 350
          ? rules.createBull()
          : rules.createOuterBull();
      return BotAimDecision(
        target: target,
        reason: 'Bull finish decision',
      );
    }

    if (score <= 40 && score.isEven) {
      return BotAimDecision(
        target: rules.createDouble(score ~/ 2),
        reason: 'Direct double finish',
      );
    }

    if (score <= 20) {
      return BotAimDecision(
        target: rules.createSingle((score - 1).clamp(0, 20)),
        reason: 'Avoid bogey finish',
      );
    }

    return BotAimDecision(
      target: rules.createSingle((score - 2).clamp(0, 20)),
      reason: 'Default leave choice',
    );
  }

  double getCheckoutCommitChance(BotProfile profile) {
    final normalized = profile.finishingSkill.clamp(1, 1000) / 1000;
    final value = 0.2 + normalized * 0.78;
    return value > 0.995 ? 0.995 : value;
  }

  double getRadiusCalibrationFactor(BotProfile profile) {
    final rawPercent = profile.radiusCalibrationPercent.toDouble();
    final clamped = rawPercent.clamp(60, 140);
    return clamped / _legacyRadiusBaselinePercent;
  }

  double getSimulationSpreadFactor(BotProfile profile) {
    final rawPercent = profile.simulationSpreadPercent.toDouble();
    final clamped = rawPercent.clamp(70, 160);
    return clamped / _legacySimulationSpreadBaselinePercent;
  }

  double getScoringBaseRadius({
    required int skill,
    required BotProfile profile,
  }) {
    final clamped = skill.clamp(1, 1000);
    final normalized = clamped / 1000;
    final calibrationFactor = 1.1 * getRadiusCalibrationFactor(profile);
    final baseSpreadFactor = normalized >= 0.5
        ? 1 - (normalized - 0.5) * 0.08
        : 1 + (0.5 - normalized) * 0.18;
    final spreadScale = getSimulationSpreadFactor(profile);
    final spreadFactor = 1 + ((baseSpreadFactor - 1) * spreadScale);

    if (normalized >= 0.999) {
      return 9 * calibrationFactor * spreadFactor;
    }

    return (9 + 124 * pow(1 - normalized, 1.62)) *
        calibrationFactor *
        spreadFactor;
  }

  double getScoringScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final radiusFactor = boardGeometry.radialFactorForPoint(
      boardGeometry.aimPointForThrow(target),
    );
    final pressure = score <= 80
        ? 1.08
        : score <= 170
            ? 1.03
            : 1;
    final baseRadius = getScoringBaseRadius(
      skill: profile.skill,
      profile: profile,
    );
    final tripleCenterFactor =
        (boardGeometry.radii.singleInner + boardGeometry.radii.tripleOuter) /
            2 /
            boardGeometry.radii.doubleOuter;

    if (baseRadius <= 0.001) {
      return 0;
    }

    final shapeFactor = 1 + (radiusFactor - tripleCenterFactor) * 0.18;
    return max(1.25, baseRadius * shapeFactor) * pressure;
  }

  double getCheckoutScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final radiusFactor = boardGeometry.radialFactorForPoint(
      boardGeometry.aimPointForThrow(target),
    );
    final pressure = score <= 80 ? 1.1 : 1.02;
    final baseRadius = getScoringBaseRadius(
      skill: profile.finishingSkill,
      profile: profile,
    );
    final doubleCenterFactor =
        (boardGeometry.radii.singleOuter + boardGeometry.radii.doubleOuter) /
            2 /
            boardGeometry.radii.doubleOuter;

    if (baseRadius <= 0.001) {
      return 0;
    }

    final shapeFactor = 1 + (radiusFactor - doubleCenterFactor) * 0.18;
    return max(1.25, baseRadius * shapeFactor) * pressure;
  }

  double getScatterRadius({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    return isCheckoutField(target)
        ? getCheckoutScatterRadius(
            profile: profile,
            score: score,
            target: target,
          )
        : getScoringScatterRadius(
            profile: profile,
            score: score,
            target: target,
          );
  }

  bool isCheckoutField(DartThrowResult dartThrow) {
    return dartThrow.isDouble || dartThrow.isBull || dartThrow.label == '25';
  }

  BotThrowSimulation simulateThrow({
    required int score,
    required int dartsLeft,
    required BotProfile profile,
    Random? random,
  }) {
    final decision = decideAim(
      profile: profile,
      score: score,
      dartsRemaining: dartsLeft,
    );
    return simulateTargetThrow(
      target: decision.target,
      score: score,
      profile: profile,
      random: random,
      reason: decision.reason,
      plannedRoute: decision.route,
    );
  }

  BotThrowSimulation simulateTargetThrow({
    required DartThrowResult target,
    required int score,
    required BotProfile profile,
    Random? random,
    String reason = '',
    List<DartThrowResult> plannedRoute = const <DartThrowResult>[],
  }) {
    final activeRandom = random ?? Random();
    final targetPoint = boardGeometry.aimPointForThrow(target);
    final baseScatterRadius = getScatterRadius(
      profile: profile,
      score: score,
      target: target,
    );
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    final jitter = (1 + (_nextGaussian(activeRandom) * model.consistencySigma))
        .clamp(0.72, 1.38);
    final scatterRadius = baseScatterRadius * model.pressureMultiplier * jitter;
    final sample = _randomUnitSample(activeRandom);
    final hitPoint = _projectScatterPoint(
      targetPoint: targetPoint,
      scatterRadius: scatterRadius,
      sample: sample,
      model: model,
    );
    final hit = boardGeometry.classifyBoardPoint(
      hitPoint.x,
      hitPoint.y,
      rules: rules,
    );
    return BotThrowSimulation(
      target: target,
      hit: hit,
      targetPoint: targetPoint,
      hitPoint: hitPoint,
      scatterRadius: scatterRadius,
      reason: reason,
      plannedRoute: plannedRoute,
    );
  }

  double estimateScoringAverage(BotProfile profile) {
    final target = rules.createTriple(20);
    final scatterRadius = getScoringScatterRadius(
      profile: profile,
      score: 501,
      target: target,
    );

    if (scatterRadius <= 0.001) {
      return 180;
    }

    final expectedPerDart = _estimateExpectedPointsForRadius(
      profile: profile,
      target: target,
      scatterRadius: scatterRadius,
      score: 501,
    );
    final normalizedSkill = profile.skill.clamp(1, 1000) / 1000;
    final compensationFactor = 1.035 + normalizedSkill * 0.02;
    return (expectedPerDart * 3 * compensationFactor).clamp(0, 180);
  }

  double estimateFinishingStrength(BotProfile profile) {
    final doubleTarget = rules.createDouble(16);
    final doubleRadius = getCheckoutScatterRadius(
      profile: profile,
      score: 32,
      target: doubleTarget,
    );
    final doubleHitRate = _estimateHitRateForThrow(
      profile: profile,
      target: doubleTarget,
      scatterRadius: doubleRadius,
      score: 32,
    );

    final bullTarget = rules.createBull();
    final bullRadius = getCheckoutScatterRadius(
      profile: profile,
      score: 50,
      target: bullTarget,
    );
    final bullHitRate = _estimateHitRateForThrow(
      profile: profile,
      target: bullTarget,
      scatterRadius: bullRadius,
      score: 50,
    );

    return (doubleHitRate * 0.85 + bullHitRate * 0.15).clamp(0, 1);
  }

  double _estimateRawThreeDartAverage(BotProfile profile) {
    final scoringAverage = estimateScoringAverage(profile);
    final finishingStrength = estimateFinishingStrength(profile);
    final finishFactor = 0.79 + finishingStrength * 0.2;
    return (scoringAverage * finishFactor).clamp(0, 180);
  }

  double estimateFallbackThreeDartAverage(BotProfile profile) {
    return _estimateRawThreeDartAverage(profile).toDouble();
  }

  double estimateThreeDartAverage(
    BotProfile profile, {
    bool forceRecalibrate = false,
  }) {
    final cacheKey = getTheoreticalAverageCacheKey(profile);
    if (!forceRecalibrate && _theoreticalAverageCache.containsKey(cacheKey)) {
      return _theoreticalAverageCache[cacheKey]!;
    }

    final value = _calculateCalibratedThreeDartAverage(
      profile: profile,
      cacheKey: cacheKey,
    );
    _theoreticalAverageCache[cacheKey] = value;
    return value;
  }

  double _calculateCalibratedThreeDartAverage({
    required BotProfile profile,
    required String cacheKey,
  }) {
    final structuralAverage = estimateFallbackThreeDartAverage(profile);
    final simulatedAverage = _calculateLongRunSimulationAverage(
      profile: profile,
      cacheKey: cacheKey,
    );
    final profileAnchorAverage = _estimateProfileAnchorAverage(profile);
    final orderingBias = _buildOrderingBias(profile);
    return ((structuralAverage * 0.74) +
            (simulatedAverage * 0.04) +
            (profileAnchorAverage * 0.22) +
            orderingBias)
        .clamp(0, 180)
        .toDouble();
  }

  double _calculateLongRunSimulationAverage({
    required BotProfile profile,
    required String cacheKey,
  }) {
    var grandTotalScored = 0;
    var grandTotalDarts = 0;
    const passes = 4;
    const legsToSimulate = 24;

    for (var pass = 0; pass < passes; pass += 1) {
      final seededRandom = _SeededRandom('$cacheKey|$pass');

      for (var leg = 0; leg < legsToSimulate; leg += 1) {
        var score = 501;
        var safety = 0;

        while (score > 0 && safety < 120) {
          final startScore = score;
          var visitScored = 0;
          var busted = false;

          for (var dart = 1; dart <= 3; dart += 1) {
            final simulation = simulateThrow(
              score: score,
              dartsLeft: 4 - dart,
              profile: profile,
              random: seededRandom,
            );
            final chosenThrow = simulation.hit;
            final newScore = score - chosenThrow.scoredPoints;
            grandTotalDarts += 1;

            if (newScore < 0 || newScore == 1) {
              score = startScore;
              busted = true;
              break;
            }

            if (newScore == 0) {
              if (chosenThrow.isFinishDouble) {
                visitScored += chosenThrow.scoredPoints;
                grandTotalScored += visitScored;
                score = 0;
              } else {
                score = startScore;
              }
              busted = true;
              break;
            }

            visitScored += chosenThrow.scoredPoints;
            score = newScore;
          }

          if (!busted) {
            grandTotalScored += visitScored;
          }

          safety += 1;
        }
      }
    }

    if (grandTotalDarts <= 0) {
      return 0;
    }

    return
        ((grandTotalScored / grandTotalDarts) * 3).clamp(0, 180).toDouble();
  }

  double _estimateProfileAnchorAverage(BotProfile profile) {
    final scoringSkill = profile.skill.clamp(1, 1000) / 1000;
    final finishingSkill = profile.finishingSkill.clamp(1, 1000) / 1000;
    return (14 + (scoringSkill * 54) + (finishingSkill * 56))
        .clamp(0, 180)
        .toDouble();
  }

  double _buildOrderingBias(BotProfile profile) {
    final blendedSkill =
        ((profile.skill.clamp(1, 1000) * 0.65) +
                (profile.finishingSkill.clamp(1, 1000) * 0.35)) /
            1000;
    return blendedSkill * 0.08;
  }

  double recalibrateThreeDartAverage(BotProfile profile) {
    final cacheKey = getTheoreticalAverageCacheKey(profile);
    _theoreticalAverageCache.remove(cacheKey);
    return estimateThreeDartAverage(
      profile,
      forceRecalibrate: true,
    );
  }

  String getTheoreticalAverageCacheKey(BotProfile profile) {
    return <String>[
      'v3',
      'board-geometry-2',
      profile.skill.round().toString(),
      profile.finishingSkill.round().toString(),
      profile.radiusCalibrationPercent.round().toString(),
      profile.simulationSpreadPercent.round().toString(),
    ].join('|');
  }

  List<DartThrowResult>? findPreferredCheckout({
    required int score,
    required int dartsLeft,
  }) {
    final cacheKey = '$score|$dartsLeft';
    if (_preferredCheckoutCache.containsKey(cacheKey)) {
      return _preferredCheckoutCache[cacheKey];
    }

    final best = checkoutPlanner.bestFinishRoute(score: score, dartsLeft: dartsLeft);
    if (best == null || best.isEmpty) {
      _preferredCheckoutCache[cacheKey] = null;
      return null;
    }
    _preferredCheckoutCache[cacheKey] = best;
    return best;
  }

  DartThrowResult? findPreferredSetupTarget({
    required int score,
    required int dartsLeft,
  }) {
    final cacheKey = '$score|$dartsLeft';
    if (_preferredSetupTargetCache.containsKey(cacheKey)) {
      return _preferredSetupTargetCache[cacheKey];
    }

    if (dartsLeft <= 0 || score <= 1) {
      _preferredSetupTargetCache[cacheKey] = null;
      return null;
    }

    final inVisit = findInVisitSetupTarget(score: score, dartsLeft: dartsLeft);
    if (inVisit != null) {
      _preferredSetupTargetCache[cacheKey] = inVisit;
      return inVisit;
    }

    if (score > 170 && dartsLeft > 1) {
      final continuation = checkoutPlanner.bestContinuationPlan(
        score: score,
        dartsLeft: dartsLeft,
      );
      if (continuation != null && continuation.throws.isNotEmpty) {
        final continuationTarget = continuation.throws.first;
        _preferredSetupTargetCache[cacheKey] = continuationTarget;
        return continuationTarget;
      }
    }

    if (dartsLeft == 1 || score > 170) {
      final leaveTarget = findPreferredLeaveTarget(score);
      _preferredSetupTargetCache[cacheKey] = leaveTarget;
      return leaveTarget;
    }

    if (score >= 62) {
      final setupThrow = rules.findSetupThrow(score);
      _preferredSetupTargetCache[cacheKey] = setupThrow;
      return setupThrow;
    }

    _preferredSetupTargetCache[cacheKey] = null;
    return null;
  }

  DartThrowResult? findInVisitSetupTarget({
    required int score,
    required int dartsLeft,
  }) {
    final cacheKey = '$score|$dartsLeft';
    if (_inVisitSetupTargetCache.containsKey(cacheKey)) {
      return _inVisitSetupTargetCache[cacheKey];
    }

    if (dartsLeft <= 1) {
      _inVisitSetupTargetCache[cacheKey] = null;
      return null;
    }

    final candidates = <_SetupCandidate>[];
    for (final dartThrow in _allThrows) {
      if (dartThrow.scoredPoints <= 0 || dartThrow.isBull) {
        continue;
      }

      final rest = score - dartThrow.scoredPoints;
      if (rest < 2) {
        continue;
      }

      final tail = findPreferredCheckout(score: rest, dartsLeft: dartsLeft - 1);
      if (tail == null || tail.isEmpty) {
        continue;
      }

      candidates.add(
        _SetupCandidate(
          target: dartThrow,
          route: <DartThrowResult>[dartThrow, ...tail],
          rest: rest,
        ),
      );
    }

    if (candidates.isEmpty) {
      _inVisitSetupTargetCache[cacheKey] = null;
      return null;
    }

    candidates.sort(_compareSetupCandidates);
    final best = candidates.first.target;
    _inVisitSetupTargetCache[cacheKey] = best;
    return best;
  }

  DartThrowResult? findPreferredLeaveTarget(int score) {
    if (_preferredLeaveTargetCache.containsKey(score)) {
      return _preferredLeaveTargetCache[score];
    }

    _LeaveCandidate? bestCandidate;
    for (final dartThrow in _allThrows) {
      if (dartThrow.scoredPoints <= 0 || dartThrow.isBull) {
        continue;
      }

      final rest = score - dartThrow.scoredPoints;
      if (rest < 2) {
        continue;
      }

      final candidate = _LeaveCandidate(
        target: dartThrow,
        rest: rest,
        leavePreference: getLeavePreference(rest),
      );

      if (bestCandidate == null ||
          _compareLeaveCandidates(candidate, bestCandidate) < 0) {
        bestCandidate = candidate;
      }
    }

    final bestTarget = bestCandidate?.target;
    _preferredLeaveTargetCache[score] = bestTarget;
    return bestTarget;
  }

  List<List<DartThrowResult>> collectCheckoutRoutes({
    required int score,
    required int dartsLeft,
    List<DartThrowResult> prefix = const <DartThrowResult>[],
  }) {
    if (prefix.isEmpty) {
      final cacheKey = '$score|$dartsLeft';
      if (_checkoutRoutesCache.containsKey(cacheKey)) {
        return _checkoutRoutesCache[cacheKey]!;
      }
    }

    if (dartsLeft <= 0) {
      return score == 0
          ? <List<DartThrowResult>>[prefix]
          : <List<DartThrowResult>>[];
    }

    final routes = <List<DartThrowResult>>[];
    for (final dartThrow in _allThrows) {
      final rest = score - dartThrow.scoredPoints;
      if (rest < 0 || rest == 1) {
        continue;
      }

      if (rest == 0) {
        if (dartThrow.isDouble) {
          routes.add(<DartThrowResult>[...prefix, dartThrow]);
        }
        continue;
      }

      routes.addAll(
        collectCheckoutRoutes(
          score: rest,
          dartsLeft: dartsLeft - 1,
          prefix: <DartThrowResult>[...prefix, dartThrow],
        ),
      );
    }

    if (prefix.isEmpty) {
      _checkoutRoutesCache['$score|$dartsLeft'] = routes;
    }
    return routes;
  }

  int getLeavePreference(int rest) {
    if (_leavePreferenceCache.containsKey(rest)) {
      return _leavePreferenceCache[rest]!;
    }

    late final int value;
    if (rest == 50) {
      value = 50;
    } else if (rest > 1 && rest <= 40 && rest.isEven) {
      value = 10000 + getFinishPreference(rules.createDouble(rest ~/ 2));
    } else {
      final checkoutRoute = findPreferredCheckout(score: rest, dartsLeft: 3);
      if (checkoutRoute != null && checkoutRoute.isNotEmpty) {
        final finalThrow = checkoutRoute.last;
        value = 8000 -
            countNarrowFields(checkoutRoute) * 200 -
            checkoutRoute.length * 30 -
            getBullPenalty(checkoutRoute) +
            getFinishPreference(finalThrow);
      } else if (isBogeyNumber(rest)) {
        value = -500 - rest;
      } else if (rest > 170) {
        value = 500 - (rest - 170).abs();
      } else {
        value = 100 - rest;
      }
    }

    _leavePreferenceCache[rest] = value;
    return value;
  }

  int getLeaveBullPenalty(int rest) {
    if (_leaveBullPenaltyCache.containsKey(rest)) {
      return _leaveBullPenaltyCache[rest]!;
    }

    if (rest == 50) {
      _leaveBullPenaltyCache[rest] = 200;
      return 200;
    }

    final route = findPreferredCheckout(score: rest, dartsLeft: 3);
    final penalty = route == null ? 0 : getBullPenalty(route);
    _leaveBullPenaltyCache[rest] = penalty;
    return penalty;
  }

  bool isBogeyNumber(int score) {
    return score == 169 ||
        score == 168 ||
        score == 166 ||
        score == 165 ||
        score == 163 ||
        score == 162 ||
        score == 159;
  }

  int countNarrowFields(List<DartThrowResult> route) {
    return route.fold<int>(
      0,
      (sum, dartThrow) => sum + (isNarrowField(dartThrow) ? 1 : 0),
    );
  }

  bool isNarrowField(DartThrowResult dartThrow) {
    if (dartThrow.isDouble || dartThrow.isTriple || dartThrow.isBull) {
      return true;
    }
    return dartThrow.label == '25';
  }

  int getBullPenalty(List<DartThrowResult> route) {
    var sum = 0;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      if (dartThrow.isBull) {
        sum += index == route.length - 1 ? 1000 : 250;
      } else if (dartThrow.label == '25') {
        sum += 120;
      }
    }
    return sum;
  }

  int getFinishPreference(DartThrowResult finalDart) {
    if (finalDart.isBull) {
      return -1;
    }

    var value = finalDart.baseValue;
    var twos = 0;
    while (value > 0 && value.isEven) {
      twos += 1;
      value ~/= 2;
    }
    return twos * 100 + finalDart.baseValue;
  }

  int getSetupPreference(List<DartThrowResult> route) {
    var sum = 0;
    for (var index = 0; index < route.length; index += 1) {
      final weight = route.length - index;
      sum += route[index].scoredPoints * weight;
    }
    return sum;
  }

  int getThrowTargetPenalty(DartThrowResult? dartThrow) {
    if (dartThrow == null) {
      return 0;
    }
    if (dartThrow.isBull) {
      return 1000;
    }
    if (dartThrow.label == '25') {
      return 220;
    }
    if (dartThrow.isDouble) {
      return 120;
    }
    if (dartThrow.isTriple) {
      return 40;
    }
    return 0;
  }

  double _estimateExpectedPointsForRadius({
    required BotProfile profile,
    required DartThrowResult target,
    required double scatterRadius,
    required int score,
  }) {
    final targetPoint = boardGeometry.aimPointForThrow(target);
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    var totalPoints = 0.0;
    for (final sample in _circleSamplePattern) {
      final hitPoint = _projectScatterPoint(
        targetPoint: targetPoint,
        scatterRadius: scatterRadius * model.pressureMultiplier,
        sample: sample,
        model: model,
      );
      final hit = boardGeometry.classifyBoardPoint(
        hitPoint.x,
        hitPoint.y,
        rules: rules,
      );
      totalPoints += hit.scoredPoints;
    }
    return totalPoints / _circleSamplePattern.length;
  }

  double _estimateHitRateForThrow({
    required BotProfile profile,
    required DartThrowResult target,
    required double scatterRadius,
    required int score,
  }) {
    if (scatterRadius <= 0.001) {
      return 1;
    }

    final targetPoint = boardGeometry.aimPointForThrow(target);
    final model = _buildThrowModel(
      profile: profile,
      score: score,
      target: target,
    );
    var hits = 0;
    for (final sample in _circleSamplePattern) {
      final hitPoint = _projectScatterPoint(
        targetPoint: targetPoint,
        scatterRadius: scatterRadius * model.pressureMultiplier,
        sample: sample,
        model: model,
      );
      final hit = boardGeometry.classifyBoardPoint(
        hitPoint.x,
        hitPoint.y,
        rules: rules,
      );
      if (hit.label == target.label) {
        hits += 1;
      }
    }
    return hits / _circleSamplePattern.length;
  }

  int _compareCheckoutRoutes(
    List<DartThrowResult> a,
    List<DartThrowResult> b,
  ) {
    final aNarrow = countNarrowFields(a);
    final bNarrow = countNarrowFields(b);
    if (aNarrow != bNarrow) {
      return aNarrow - bNarrow;
    }

    if (a.length != b.length) {
      return a.length - b.length;
    }

    final aBullPenalty = getBullPenalty(a);
    final bBullPenalty = getBullPenalty(b);
    if (aBullPenalty != bBullPenalty) {
      return aBullPenalty - bBullPenalty;
    }

    final aFinish = getFinishPreference(a.last);
    final bFinish = getFinishPreference(b.last);
    if (aFinish != bFinish) {
      return bFinish - aFinish;
    }

    final aSetup = getSetupPreference(a);
    final bSetup = getSetupPreference(b);
    if (aSetup != bSetup) {
      return bSetup - aSetup;
    }

    return b.first.scoredPoints - a.first.scoredPoints;
  }

  int _compareSetupCandidates(_SetupCandidate a, _SetupCandidate b) {
    final routeComparison = _compareCheckoutRoutes(a.route, b.route);
    if (routeComparison != 0) {
      return routeComparison;
    }

    final leaveComparison = _compareLeaveCandidates(
      _LeaveCandidate(
        target: a.target,
        rest: a.rest,
        leavePreference: getLeavePreference(a.rest),
      ),
      _LeaveCandidate(
        target: b.target,
        rest: b.rest,
        leavePreference: getLeavePreference(b.rest),
      ),
    );
    if (leaveComparison != 0) {
      return leaveComparison;
    }

    return b.target.scoredPoints - a.target.scoredPoints;
  }

  int _compareLeaveCandidates(_LeaveCandidate a, _LeaveCandidate b) {
    if (a.leavePreference != b.leavePreference) {
      return b.leavePreference - a.leavePreference;
    }

    final aBullPenalty = getLeaveBullPenalty(a.rest);
    final bBullPenalty = getLeaveBullPenalty(b.rest);
    if (aBullPenalty != bBullPenalty) {
      return aBullPenalty - bBullPenalty;
    }

    final aTargetPenalty = getThrowTargetPenalty(a.target);
    final bTargetPenalty = getThrowTargetPenalty(b.target);
    if (aTargetPenalty != bTargetPenalty) {
      return aTargetPenalty - bTargetPenalty;
    }

    return b.target.scoredPoints - a.target.scoredPoints;
  }

  _ThrowModel _buildThrowModel({
    required BotProfile profile,
    required int score,
    required DartThrowResult target,
  }) {
    final skillNorm = profile.skill.clamp(1, 1000) / 1000;
    final finishNorm = profile.finishingSkill.clamp(1, 1000) / 1000;
    final accuracyNorm = isCheckoutField(target) ? finishNorm : skillNorm;
    final consistencyNorm = ((skillNorm * 0.7) + (finishNorm * 0.3)).clamp(0, 1);
    final checkoutFocus = (0.58 + finishNorm * 0.32).clamp(0, 1);

    final narrowTarget = target.isTriple || target.isDouble || target.isBull;
    final tangentialBase = target.isTriple
        ? 1.26
        : target.isDouble
            ? 1.18
            : target.isBull
                ? 1.08
                : 0.98;
    final radialBase = target.isTriple
        ? 0.94
        : target.isDouble
            ? 0.9
            : target.isBull
                ? 0.88
                : 1.0;

    final radialScale =
        (radialBase - accuracyNorm * (narrowTarget ? 0.18 : 0.1)).clamp(0.62, 1.05);
    final tangentialScale =
        (tangentialBase - accuracyNorm * (narrowTarget ? 0.2 : 0.08)).clamp(0.72, 1.3);

    final radialBias = (target.isDouble
        ? (-0.16 + accuracyNorm * 0.08)
        : target.isTriple
            ? (-0.06 + accuracyNorm * 0.04)
            : target.isBull
                ? 0
                : (-0.01 + accuracyNorm * 0.02))
        .toDouble();

    final pressureMultiplier = (score <= 80
        ? (1.08 - checkoutFocus * 0.1).clamp(0.93, 1.08)
        : score <= 170
            ? (1.04 - checkoutFocus * 0.05).clamp(0.96, 1.04)
            : 1.0)
        .toDouble();

    final consistencySigma =
        (0.24 - consistencyNorm * 0.14).clamp(0.06, 0.2).toDouble();

    return _ThrowModel(
      radialScale: radialScale,
      tangentialScale: tangentialScale,
      radialBias: radialBias,
      consistencySigma: consistencySigma,
      pressureMultiplier: pressureMultiplier,
    );
  }

  BoardPoint _projectScatterPoint({
    required BoardPoint targetPoint,
    required double scatterRadius,
    required BoardPoint sample,
    required _ThrowModel model,
  }) {
    final dx = targetPoint.x - boardGeometry.center.x;
    final dy = targetPoint.y - boardGeometry.center.y;
    final distance = sqrt(dx * dx + dy * dy);
    final radialX = distance <= 0.0001 ? 0.0 : dx / distance;
    final radialY = distance <= 0.0001 ? -1.0 : dy / distance;
    final tangentX = -radialY;
    final tangentY = radialX;

    final radialDistance =
        (sample.x * model.radialScale + model.radialBias) * scatterRadius;
    final tangentialDistance =
        sample.y * model.tangentialScale * scatterRadius;

    return BoardPoint(
      targetPoint.x + radialX * radialDistance + tangentX * tangentialDistance,
      targetPoint.y + radialY * radialDistance + tangentY * tangentialDistance,
    );
  }

  BoardPoint _randomUnitSample(Random random) {
    final angle = random.nextDouble() * pi * 2;
    final radius = sqrt(random.nextDouble());
    return BoardPoint(
      cos(angle) * radius,
      sin(angle) * radius,
    );
  }

  double _nextGaussian(Random random) {
    final u1 = max(random.nextDouble(), 1e-9);
    final u2 = random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }
}

final List<BoardPoint> _circleSamplePattern = _buildCircleSamplePattern();

List<BoardPoint> _buildCircleSamplePattern() {
  const sampleCount = 257;
  final samples = <BoardPoint>[];
  final goldenAngle = pi * (3 - sqrt(5));

  for (var index = 0; index < sampleCount; index += 1) {
    final radius = sqrt((index + 0.5) / sampleCount);
    final angle = index * goldenAngle;
    samples.add(
      BoardPoint(
        cos(angle) * radius,
        sin(angle) * radius,
      ),
    );
  }

  return samples;
}

class _SeededRandom implements Random {
  _SeededRandom(String seedText) : _seed = _initialSeed(seedText);

  int _seed;

  static int _initialSeed(String seedText) {
    var seed = 2166136261;
    final text = seedText.isEmpty ? 'dart-bot' : seedText;
    for (var index = 0; index < text.length; index += 1) {
      seed ^= text.codeUnitAt(index);
      seed = (seed * 16777619) & 0xFFFFFFFF;
    }
    return seed & 0xFFFFFFFF;
  }

  int _nextRaw() {
    _seed = (_seed + 0x6D2B79F5) & 0xFFFFFFFF;
    var value = _seed;
    value = ((value ^ (value >> 15)) * (value | 1)) & 0xFFFFFFFF;
    value ^= value + ((((value ^ (value >> 7)) * (value | 61)) & 0xFFFFFFFF));
    return (value ^ (value >> 14)) & 0xFFFFFFFF;
  }

  @override
  bool nextBool() => nextDouble() >= 0.5;

  @override
  double nextDouble() => _nextRaw() / 4294967296;

  @override
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'Must be positive');
    }
    return _nextRaw() % max;
  }
}

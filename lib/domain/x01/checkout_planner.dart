import 'x01_models.dart';
import 'x01_rules.dart';

class CheckoutContinuationPlan {
  const CheckoutContinuationPlan({
    required this.throws,
    required this.immediateFinish,
    required this.score,
  });

  final List<DartThrowResult> throws;
  final bool immediateFinish;
  final int score;
}

class CheckoutSetupLeaveOption {
  const CheckoutSetupLeaveOption({
    required this.setupRoute,
    required this.remainingScore,
    required this.finishRoute,
    required this.score,
  });

  final List<DartThrowResult> setupRoute;
  final int remainingScore;
  final List<DartThrowResult> finishRoute;
  final int score;
}

class CheckoutRouteScoreBreakdown {
  const CheckoutRouteScoreBreakdown({
    required this.comfort,
    required this.robustness,
    required this.doubleQuality,
    required this.bullPenalty,
    required this.segmentFlow,
  });

  final int comfort;
  final int robustness;
  final int doubleQuality;
  final int bullPenalty;
  final int segmentFlow;
}

class CheckoutPlanner {
  CheckoutPlanner({
    X01Rules? rules,
  })  : rules = rules ?? const X01Rules(),
        _allThrows = (rules ?? const X01Rules()).buildAllThrows();

  final X01Rules rules;
  final List<DartThrowResult> _allThrows;

  final Map<String, List<List<DartThrowResult>>> _checkoutRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, List<List<DartThrowResult>>> _targetRoutesCache =
      <String, List<List<DartThrowResult>>>{};
  final Map<String, List<DartThrowResult>?> _finishRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, List<DartThrowResult>?> _targetRouteCache =
      <String, List<DartThrowResult>?>{};
  final Map<String, CheckoutContinuationPlan?> _continuationPlanCache =
      <String, CheckoutContinuationPlan?>{};

  void clearCaches() {
    _checkoutRoutesCache.clear();
    _targetRoutesCache.clear();
    _finishRouteCache.clear();
    _targetRouteCache.clear();
    _continuationPlanCache.clear();
  }

  List<List<DartThrowResult>> allRoutesToTargetRemaining({
    required int startScore,
    required int targetScore,
    required int dartsLeft,
  }) {
    final cacheKey = '$startScore|$targetScore|$dartsLeft';
    if (_targetRoutesCache.containsKey(cacheKey)) {
      return _targetRoutesCache[cacheKey]!;
    }

    if (startScore <= targetScore || targetScore < 0 || dartsLeft <= 0) {
      _targetRoutesCache[cacheKey] = const <List<DartThrowResult>>[];
      return _targetRoutesCache[cacheKey]!;
    }

    final routes = <List<DartThrowResult>>[];
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
    ) {
      if (dartsRemaining <= 0) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next < targetScore) {
          continue;
        }

        final nextRoute = <DartThrowResult>[...route, dartThrow];
        if (next == targetScore) {
          final key = nextRoute.map((entry) => entry.label).join('-');
          if (seen.add(key)) {
            routes.add(nextRoute);
          }
          continue;
        }

        search(next, dartsRemaining - 1, nextRoute);
      }
    }

    search(startScore, dartsLeft, <DartThrowResult>[]);
    _targetRoutesCache[cacheKey] = routes;
    return routes;
  }

  List<DartThrowResult>? bestRouteToTargetRemaining({
    required int startScore,
    required int targetScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    bool twoDartOnly = false,
    bool avoidBull = false,
  }) {
    final cacheKey = <Object>[
      startScore,
      targetScore,
      dartsLeft,
      checkoutRequirement,
      playStyle,
      twoDartOnly,
      avoidBull,
    ].join('|');
    if (_targetRouteCache.containsKey(cacheKey)) {
      return _targetRouteCache[cacheKey];
    }

    final routes = allRoutesToTargetRemaining(
      startScore: startScore,
      targetScore: targetScore,
      dartsLeft: dartsLeft,
    ).where((route) {
      if (twoDartOnly && route.length != 2) {
        return false;
      }
      if (avoidBull &&
          route.any((entry) => entry.isBull || entry.label == '25')) {
        return false;
      }
      return true;
    }).toList();

    if (routes.isEmpty) {
      _targetRouteCache[cacheKey] = null;
      return null;
    }

    routes.sort(
      (a, b) => scoreRouteToTargetRemaining(
        route: b,
        startScore: startScore,
        targetScore: targetScore,
        dartsLeft: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      ).compareTo(
        scoreRouteToTargetRemaining(
          route: a,
          startScore: startScore,
          targetScore: targetScore,
          dartsLeft: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        ),
      ),
    );

    final best = routes.first;
    _targetRouteCache[cacheKey] = best;
    return best;
  }

  List<List<DartThrowResult>> allCheckoutRoutes({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final cacheKey = '$score|$dartsLeft|$checkoutRequirement|$playStyle';
    if (_checkoutRoutesCache.containsKey(cacheKey)) {
      return _checkoutRoutesCache[cacheKey]!;
    }

    final finishes = <List<DartThrowResult>>[];
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
    ) {
      if (dartsRemaining <= 0) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next < 0 || next == 1) {
          continue;
        }

        final nextRoute = <DartThrowResult>[...route, dartThrow];
        if (next == 0) {
          if (!dartThrow.matchesCheckoutRequirement(checkoutRequirement)) {
            continue;
          }
          final key = nextRoute.map((entry) => entry.label).join('-');
          if (seen.add(key)) {
            finishes.add(nextRoute);
          }
          continue;
        }

        search(next, dartsRemaining - 1, nextRoute);
      }
    }

    search(score, dartsLeft, <DartThrowResult>[]);
    _checkoutRoutesCache[cacheKey] = finishes;
    return finishes;
  }

  List<DartThrowResult>? bestFinishRoute({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey =
        '$score|$dartsLeft|$checkoutRequirement|$playStyle|$outerBullPreference|$bullPreference';
    if (_finishRouteCache.containsKey(cacheKey)) {
      return _finishRouteCache[cacheKey];
    }

    final routes = allCheckoutRoutes(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (routes.isEmpty) {
      _finishRouteCache[cacheKey] = null;
      return null;
    }

    routes.sort((a, b) => scoreRoute(
          route: b,
          startScore: score,
          totalDarts: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        ).compareTo(
          scoreRoute(
            route: a,
            startScore: score,
            totalDarts: dartsLeft,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          ),
        ));
    final best = routes.first;
    _finishRouteCache[cacheKey] = best;
    return best;
  }

  List<DartThrowResult>? bestFinishRouteForNarrowFieldCount({
    required int score,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final routes = allCheckoutRoutes(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    ).where((route) => route.where(isNarrowField).length == narrowFieldCount).toList();

    if (routes.isEmpty) {
      return null;
    }

    routes.sort(
      (a, b) => scoreRoute(
        route: b,
        startScore: score,
        totalDarts: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      ).compareTo(
        scoreRoute(
          route: a,
          startScore: score,
          totalDarts: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        ),
      ),
    );

    return routes.first;
  }

  List<CheckoutSetupLeaveOption> topSetupLeavesForNarrowFieldCount({
    required int startScore,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
    int maxResults = 3,
  }) {
    if (startScore <= 1 || dartsLeft <= 0) {
      return const <CheckoutSetupLeaveOption>[];
    }

    final candidates = <CheckoutSetupLeaveOption>[];
    final seen = <String>{};

    void search(
      int remaining,
      int dartsRemaining,
      List<DartThrowResult> route,
      int narrowFieldsUsed,
    ) {
      if (dartsRemaining <= 0 || narrowFieldsUsed > narrowFieldCount) {
        return;
      }

      for (final dartThrow in _allThrows) {
        if (dartThrow.scoredPoints <= 0) {
          continue;
        }

        final next = remaining - dartThrow.scoredPoints;
        if (next <= 1) {
          continue;
        }

        final nextNarrowFields =
            narrowFieldsUsed + (isNarrowField(dartThrow) ? 1 : 0);
        if (nextNarrowFields > narrowFieldCount) {
          continue;
        }

        final nextRoute = <DartThrowResult>[...route, dartThrow];
        final finishRoute = bestFinishRoute(
          score: next,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );

        if (finishRoute != null && nextNarrowFields == narrowFieldCount) {
          final routeKey = nextRoute.map((entry) => entry.label).join('-');
          final key = '$next|$routeKey';
          if (seen.add(key)) {
            final candidate = CheckoutSetupLeaveOption(
              setupRoute: nextRoute,
              remainingScore: next,
              finishRoute: finishRoute,
              score: scoreSetupLeave(
                setupRoute: nextRoute,
                startScore: startScore,
                remainingScore: next,
                finishRoute: finishRoute,
                dartsLeft: dartsLeft,
                checkoutRequirement: checkoutRequirement,
                playStyle: playStyle,
                leavePreference: leavePreference,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              ),
            );
            candidates.add(candidate);
          }
        }

        search(
          next,
          dartsRemaining - 1,
          nextRoute,
          nextNarrowFields,
        );
      }
    }

    search(startScore, dartsLeft, const <DartThrowResult>[], 0);
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(maxResults).toList();
  }

  CheckoutSetupLeaveOption? bestSetupLeaveForNarrowFieldCount({
    required int startScore,
    required int dartsLeft,
    required int narrowFieldCount,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final results = topSetupLeavesForNarrowFieldCount(
      startScore: startScore,
      dartsLeft: dartsLeft,
      narrowFieldCount: narrowFieldCount,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: leavePreference,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
      maxResults: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  CheckoutContinuationPlan? bestContinuationPlan({
    required int score,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final cacheKey =
        '$score|$dartsLeft|$checkoutRequirement|$playStyle|$outerBullPreference|$bullPreference';
    if (_continuationPlanCache.containsKey(cacheKey)) {
      return _continuationPlanCache[cacheKey];
    }

    final exactRoute = bestFinishRoute(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (exactRoute != null && exactRoute.isNotEmpty) {
      final exactPlan = CheckoutContinuationPlan(
        throws: exactRoute,
        immediateFinish: true,
        score: 3000 +
            simpleRouteScore(
              exactRoute,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            ),
      );
      _continuationPlanCache[cacheKey] = exactPlan;
      return exactPlan;
    }

    if (dartsLeft <= 0) {
      _continuationPlanCache[cacheKey] = null;
      return null;
    }

    CheckoutContinuationPlan? best;
    for (final dartThrow in _allThrows) {
      if (dartThrow.scoredPoints <= 0) {
        continue;
      }

      final next = score - dartThrow.scoredPoints;
      if (next < 2 || next == 1) {
        continue;
      }

      if (dartsLeft == 1) {
        final nextVisitRoute = bestFinishRoute(
          score: next,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (nextVisitRoute == null || nextVisitRoute.isEmpty) {
          continue;
        }

        final candidate = CheckoutContinuationPlan(
          throws: <DartThrowResult>[dartThrow, ...nextVisitRoute],
          immediateFinish: false,
          score: 1400 +
              simpleRouteScore(
                nextVisitRoute,
                playStyle: playStyle,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              ) +
              setupThrowBias(dartThrow),
        );
        if (best == null || candidate.score > best.score) {
          best = candidate;
        }
        continue;
      }

      final tail = bestContinuationPlan(
        score: next,
        dartsLeft: dartsLeft - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (tail == null || tail.throws.isEmpty) {
        continue;
      }

      final candidate = CheckoutContinuationPlan(
        throws: <DartThrowResult>[dartThrow, ...tail.throws],
        immediateFinish: false,
        score: tail.score + setupThrowBias(dartThrow),
      );
      if (best == null || candidate.score > best.score) {
        best = candidate;
      }
    }

    _continuationPlanCache[cacheKey] = best;
    return best;
  }

  int scoreRoute({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final dartsUsedScore = 2200 - (route.length * 520);
    final twoDartCheckoutBonus = route.length == 2 ? 130 : 0;
    final narrowFieldPenalty = route.where(isNarrowField).length * 150;
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
            _outerBullPenaltyValue(72, outerBullPreference);
    final bullPenalty = route.where((entry) => entry.isBull).length *
        _bullPenaltyValue(72, bullPreference);
    final finalBullPenalty =
        route.isNotEmpty && route.last.isBull
            ? _bullPenaltyValue(140, bullPreference, scale: 2)
            : 0;
    final earlyBullPenalty = route
            .take(route.length > 1 ? route.length - 1 : 0)
            .where((entry) => entry.isBull)
            .length *
        _bullPenaltyValue(64, bullPreference);
    final earlyDoublePenalty = route
            .take(route.length > 1 ? route.length - 1 : 0)
            .where((entry) => entry.isDouble && !entry.isBull)
            .length *
        115;
    final goodDoubleBonus = doublePreference(route.last);
    final continuityBonus = continuityScore(route);
    final comfortBonus = comfortScore(route);
    final robustnessBonus = robustnessScore(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final styleBonus = playStyleRouteAdjustment(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      comfortBonus: comfortBonus,
      robustnessBonus: robustnessBonus,
      narrowFieldPenalty: narrowFieldPenalty,
    );

    return dartsUsedScore +
        twoDartCheckoutBonus +
        goodDoubleBonus +
        comfortBonus +
        continuityBonus +
        styleBonus +
        robustnessBonus -
        narrowFieldPenalty -
        outerBullPenalty -
        earlyDoublePenalty -
        earlyBullPenalty -
        finalBullPenalty -
        bullPenalty;
  }

  CheckoutRouteScoreBreakdown routeScoreBreakdown({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final earlyBullPenalty = route
            .take(route.length > 1 ? route.length - 1 : 0)
            .where((entry) => entry.isBull)
            .length *
        _bullPenaltyValue(64, bullPreference);
    final finalBullPenalty =
        route.isNotEmpty && route.last.isBull
            ? _bullPenaltyValue(96, bullPreference, scale: 1)
            : 0;
    final bullPenalty = route.where((entry) => entry.isBull).length *
        _bullPenaltyValue(52, bullPreference, scale: 1);
    final outerBullPenalty = route.where((entry) => entry.label == '25').length *
        _outerBullPenaltyValue(72, outerBullPreference);

    return CheckoutRouteScoreBreakdown(
      comfort: comfortScore(route),
      robustness: robustnessScore(
        route: route,
        startScore: startScore,
        totalDarts: totalDarts,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      ),
      doubleQuality: route.isEmpty ? 0 : doublePreference(route.last),
      bullPenalty: earlyBullPenalty +
          finalBullPenalty +
          bullPenalty +
          outerBullPenalty,
      segmentFlow: continuityScore(route),
    );
  }

  int simpleRouteScore(
    List<DartThrowResult> route, {
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final dartsUsedScore = 2000 - (route.length * 500);
    final twoDartCheckoutBonus = route.length == 2 ? 90 : 0;
    final narrowFieldPenalty = route.where(isNarrowField).length * 120;
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
            _outerBullPenaltyValue(58, outerBullPreference);
    final bullPenalty = route.where((entry) => entry.isBull).length *
        _bullPenaltyValue(60, bullPreference, scale: 1);
    final finalBullPenalty =
        route.isNotEmpty && route.last.isBull
            ? _bullPenaltyValue(104, bullPreference, scale: 1)
            : 0;
    final earlyBullPenalty = route
            .take(route.length > 1 ? route.length - 1 : 0)
            .where((entry) => entry.isBull)
            .length *
        _bullPenaltyValue(72, bullPreference);
    final earlyDoublePenalty = route
            .take(route.length > 1 ? route.length - 1 : 0)
            .where((entry) => entry.isDouble && !entry.isBull)
            .length *
        280;

    final baseScore = dartsUsedScore +
        twoDartCheckoutBonus +
        doublePreference(route.last) +
        comfortScore(route) +
        continuityScore(route) -
        narrowFieldPenalty -
        outerBullPenalty -
        earlyDoublePenalty -
        earlyBullPenalty -
        finalBullPenalty -
        bullPenalty;

    switch (playStyle) {
      case CheckoutPlayStyle.safe:
        return baseScore +
            (comfortScore(route) ~/ 3) -
            (route.length == 2 ? 20 : 0);
      case CheckoutPlayStyle.aggressive:
        return baseScore + (route.length == 2 ? 60 : 0);
      case CheckoutPlayStyle.balanced:
        return baseScore;
    }
  }

  int scoreRouteToTargetRemaining({
    required List<DartThrowResult> route,
    required int startScore,
    required int targetScore,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    if (route.isEmpty) {
      return -999999;
    }

    final dartsUsedScore = 1000 - (route.length * 120);
    final unusedDartPenalty = (dartsLeft - route.length) * 140;
    final comfortBonus = setupComfortScore(route);
    final continuityBonus = continuityScore(route);
    final narrowFieldPenalty = route.where(isNarrowField).length * 150;
    final outerBullPenalty =
        route.where((entry) => entry.label == '25').length *
            _outerBullPenaltyValue(68, outerBullPreference);
    final bullPenalty = route.where((entry) => entry.isBull).length *
        _bullPenaltyValue(48, bullPreference, scale: 1);
    final targetCheckout = bestFinishRoute(
      score: targetScore,
      dartsLeft: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final targetLeaveBonus = targetCheckout == null
        ? _targetPreference(targetScore)
        : 220 +
            (simpleRouteScore(
                  targetCheckout,
                  playStyle: playStyle,
                  outerBullPreference: outerBullPreference,
                  bullPreference: bullPreference,
                ) ~/
                3);

    return dartsUsedScore +
        comfortBonus +
        continuityBonus +
        targetLeaveBonus -
        unusedDartPenalty -
        narrowFieldPenalty -
        outerBullPenalty -
        bullPenalty;
  }

  int scoreSetupLeave({
    required List<DartThrowResult> setupRoute,
    required int startScore,
    required int remainingScore,
    required List<DartThrowResult> finishRoute,
    required int dartsLeft,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int leavePreference = 50,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final leaveScore = scoreRouteToTargetRemaining(
      route: setupRoute,
      startScore: startScore,
      targetScore: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final finishScore = scoreRoute(
      route: finishRoute,
      startScore: remainingScore,
      totalDarts: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final missPenalty = setupMissPenalty(
      route: setupRoute,
      startScore: startScore,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    final outerBullSetupPenalty =
        setupRoute.where((entry) => entry.label == '25').length * 42;
    final leadingOuterBullPenalty =
        setupRoute.isNotEmpty && setupRoute.first.label == '25' ? 34 : 0;
    final simpleWeight = (130 - leavePreference).clamp(30, 130);
    final finishWeight = (30 + leavePreference).clamp(30, 130);

    return (((leaveScore * simpleWeight) +
                ((finishScore ~/ 2) * finishWeight)) ~/
            100) -
        missPenalty -
        outerBullSetupPenalty -
        leadingOuterBullPenalty;
  }

  int setupMissPenalty({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    var remaining = startScore;
    var penalty = 0;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;

      if (dartThrow.isTriple && dartsAfterThis > 0) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - dartThrow.baseValue,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );

        for (final neighbor in rules.adjacentSegments(dartThrow.baseValue)) {
          penalty += _penaltyForSetupMiss(
            remainingScore: remaining - neighbor,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
            isPrimaryMiss: index == 0,
            isNeighborMiss: true,
          );
        }
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - dartThrow.baseValue,
          dartsLeft: dartsAfterThis > 0 ? dartsAfterThis + 1 : 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );
      } else if (dartThrow.isBull && dartsAfterThis > 0) {
        penalty += _penaltyForSetupMiss(
          remainingScore: remaining - 25,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
          isPrimaryMiss: index == 0,
        );
      }

      remaining -= dartThrow.scoredPoints;
    }

    return penalty;
  }

  int _penaltyForSetupMiss({
    required int remainingScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int outerBullPreference,
    required int bullPreference,
    bool isPrimaryMiss = false,
    bool isNeighborMiss = false,
  }) {
    if (remainingScore <= 1 || dartsLeft <= 0) {
      return isPrimaryMiss ? 90 : 70;
    }

    final continuation = bestContinuationPlan(
      score: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );

    if (continuation == null || continuation.throws.isEmpty) {
      return isPrimaryMiss
          ? (isNeighborMiss ? 62 : 74)
          : (isNeighborMiss ? 54 : 62);
    }

    if (continuation.immediateFinish) {
      return isNeighborMiss ? -10 : -18;
    }

    return isNeighborMiss ? 18 : 26;
  }

  int robustnessScore({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    var remaining = startScore;
    var score = 0;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;

      if (dartThrow.isTriple && dartsAfterThis > 0) {
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        if (singleFallbackRemaining > 1) {
          final urgencyBonus = index == 0 ? 42 : 0;
          final urgencyPenalty = index == 0 ? 36 : 0;
          final exactFallback = bestFinishRoute(
            score: singleFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );

          if (exactFallback != null && exactFallback.isNotEmpty) {
            final fallbackScore =
                simpleRouteScore(
                  exactFallback,
                  playStyle: playStyle,
                  outerBullPreference: outerBullPreference,
                  bullPreference: bullPreference,
                );
            final fallbackFinishBonus =
                doublePreference(exactFallback.last).clamp(0, 140) ~/ 6;
            final oneDartFinishBonus = exactFallback.length == 1 ? 34 : 0;
            final noTripleFallbackBonus =
                exactFallback.any((entry) => entry.isTriple) ? 0 : 20;
            final bullRescueBonus =
                exactFallback.length == 1 && exactFallback.last.isBull ? 60 : 0;
            final narrowFallbackPenalty =
                exactFallback.where(isNarrowField).length * 22;
            final sameSegmentFallbackBonus = exactFallback.isNotEmpty &&
                    exactFallback.first.baseValue == dartThrow.baseValue
                ? 72
                : 0;
            score += 28 +
                urgencyBonus +
                (fallbackScore ~/ 11) +
                fallbackFinishBonus +
                oneDartFinishBonus +
                noTripleFallbackBonus +
                bullRescueBonus -
                narrowFallbackPenalty +
                sameSegmentFallbackBonus;
          } else {
            final fallbackPlan = bestContinuationPlan(
              score: singleFallbackRemaining,
              dartsLeft: dartsAfterThis,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
              final fallbackScore = simpleRouteScore(
                fallbackPlan.throws.take(dartsAfterThis).toList(),
                playStyle: playStyle,
                outerBullPreference: outerBullPreference,
                bullPreference: bullPreference,
              );
              score += fallbackPlan.immediateFinish
                  ? 10 + urgencyBonus + (fallbackScore ~/ 36)
                  : -6 - urgencyPenalty + (fallbackScore ~/ 90);
            } else {
              score -= 44 + urgencyPenalty;
            }
          }
        }
      }

      if (dartThrow.isBull && dartsAfterThis > 0) {
        final outerBullFallbackRemaining = remaining - 25;
        if (outerBullFallbackRemaining > 1) {
          final exactFallback = bestFinishRoute(
            score: outerBullFallbackRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );

          if (exactFallback != null && exactFallback.isNotEmpty) {
            final fallbackScore = simpleRouteScore(
              exactFallback,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            final finishBonus =
                doublePreference(exactFallback.last).clamp(0, 140) ~/ 8;
            final oneDartFinishBonus = exactFallback.length == 1 ? 40 : 0;
            final repeatedBullBonus =
                exactFallback.isNotEmpty && exactFallback.first.isBull ? 54 : 0;
            score += 22 +
                (index == 0 ? 28 : 10) +
                (fallbackScore ~/ 12) +
                finishBonus +
                oneDartFinishBonus +
                repeatedBullBonus;
          } else {
            final fallbackPlan = bestContinuationPlan(
              score: outerBullFallbackRemaining,
              dartsLeft: dartsAfterThis,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: outerBullPreference,
              bullPreference: bullPreference,
            );
            if (fallbackPlan != null &&
                fallbackPlan.throws.isNotEmpty &&
                fallbackPlan.immediateFinish) {
              score += 18 + (index == 0 ? 18 : 0);
            }
          }
        }
      }

      remaining -= dartThrow.scoredPoints;
    }

    return score;
  }

  int comfortScore(List<DartThrowResult> route) {
    if (route.isEmpty) {
      return 0;
    }

    var score = 0;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final isLast = index == route.length - 1;

      if (!isLast) {
        if (dartThrow.isTriple) {
          score -= 112;
          if (dartThrow.baseValue >= 19) {
            score += 18;
          } else if (dartThrow.baseValue >= 17) {
            score += 10;
          } else if (dartThrow.baseValue >= 15) {
            score += 4;
          }
        } else if (dartThrow.isDouble && !dartThrow.isBull) {
          score -= 72;
        } else if (dartThrow.label == '25') {
          score -= 10;
        } else if (!dartThrow.isBull) {
          score += dartThrow.baseValue >= 15
              ? 60
              : dartThrow.baseValue >= 10
                  ? 50
                  : dartThrow.baseValue >= 6
                      ? 34
                      : 22;
        }
      }
    }

    return score;
  }

  int setupComfortScore(List<DartThrowResult> route) {
    if (route.isEmpty) {
      return 0;
    }

    var score = 0;
    for (final dartThrow in route) {
      if (dartThrow.isTriple) {
        score -= 118;
        if (dartThrow.baseValue >= 19) {
          score += 14;
        } else if (dartThrow.baseValue >= 17) {
          score += 8;
        }
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        score -= 92;
      } else if (dartThrow.label == '25') {
        score -= 16;
      } else if (!dartThrow.isBull) {
        score += dartThrow.baseValue >= 15
            ? 62
            : dartThrow.baseValue >= 10
                ? 52
                : dartThrow.baseValue >= 6
                    ? 34
                    : 22;
      }
    }

    return score;
  }

  int continuityScore(List<DartThrowResult> route) {
    var score = 0;

    for (var index = 1; index < route.length; index += 1) {
      final previous = route[index - 1];
      final current = route[index];

      if (previous.label == current.label) {
        score += 18;
        continue;
      }

      if (previous.baseValue == current.baseValue) {
        score += 10;
        continue;
      }

      if (isSingleOrOuterBull(previous) && isSingleOrOuterBull(current)) {
        score += 4;
      } else {
        score -= 8;
      }
    }

    return score;
  }

  int playStyleRouteAdjustment({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required int comfortBonus,
    required int robustnessBonus,
    required int narrowFieldPenalty,
  }) {
    if (route.isEmpty || playStyle == CheckoutPlayStyle.balanced) {
      return 0;
    }

    final first = route.first;
    final finalThrow = route.last;

    switch (playStyle) {
      case CheckoutPlayStyle.safe:
        return (comfortBonus ~/ 2) +
            (robustnessBonus ~/ 3) -
            (narrowFieldPenalty ~/ 4) -
            (route.length == 2 ? 40 : 0) +
            (first.isTriple ? 24 : 0);
      case CheckoutPlayStyle.aggressive:
        return (route.length == 2 ? 120 : 0) +
            (first.isTriple ? 36 : 0) +
            (robustnessBonus ~/ 6) +
            (narrowFieldPenalty ~/ 5) +
            (finalThrow.matchesCheckoutRequirement(checkoutRequirement)
                ? 18
                : 0);
      case CheckoutPlayStyle.balanced:
        return 0;
    }
  }

  int _targetPreference(int targetScore) {
    if (targetScore == 50) {
      return 24;
    }
    if (targetScore > 1 && targetScore <= 40 && targetScore.isEven) {
      return 180 + doublePreference(rules.createDouble(targetScore ~/ 2));
    }
    if (targetScore > 40 && targetScore <= 170) {
      return 60;
    }
    if (targetScore == 1) {
      return -260;
    }
    return 0;
  }

  int doublePreference(DartThrowResult dartThrow) {
    if (!dartThrow.isFinishDouble) {
      return 0;
    }
    if (dartThrow.isBull) {
      return -10;
    }

    const preferences = <int, int>{
      16: 140,
      20: 138,
      10: 112,
      8: 104,
      12: 100,
      18: 92,
      14: 84,
      6: 76,
      4: 68,
      2: 60,
      7: 42,
    };
    return preferences[dartThrow.baseValue] ?? 50;
  }

  bool isNarrowField(DartThrowResult dartThrow) {
    if (dartThrow.label == '25') {
      return false;
    }
    return dartThrow.isTriple || dartThrow.isDouble || dartThrow.isBull;
  }

  bool isSingleOrOuterBull(DartThrowResult dartThrow) {
    return (!dartThrow.isDouble && !dartThrow.isTriple && !dartThrow.isBull) ||
        dartThrow.label == '25';
  }

  int setupThrowBias(DartThrowResult dartThrow) {
    if (dartThrow.isBull) {
      return -80;
    }
    if (dartThrow.label == '25') {
      return -10;
    }
    if (dartThrow.isDouble) {
      return -70;
    }
    if (dartThrow.isTriple) {
      return -24;
    }
    if (dartThrow.baseValue == 20) {
      return 42;
    }
    if (dartThrow.baseValue == 19) {
      return 28;
    }
    return 8;
  }

  int _outerBullPenaltyValue(int base, int preference) {
    return base + ((preference - 50) * 2);
  }

  int _bullPenaltyValue(int base, int preference, {int scale = 2}) {
    return base + ((preference - 50) * scale);
  }
}

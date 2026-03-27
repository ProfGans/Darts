import '../bot/bot_engine.dart';
import 'checkout_planner.dart';
import 'x01_match_engine.dart';
import 'x01_models.dart';

class SimulatedPlayer {
  const SimulatedPlayer({
    required this.name,
    required this.profile,
  });

  final String name;
  final BotProfile profile;
}

class SimulatedVisitResult {
  const SimulatedVisitResult({
    required this.startScore,
    required this.newScore,
    required this.scoredPoints,
    required this.dartsThrown,
    required this.openedLeg,
    required this.checkedOut,
    required this.busted,
    required this.doubleAttempts,
    required this.throws,
    required this.targets,
    required this.targetReasons,
    required this.plannedRoutes,
    required this.finishLabel,
    required this.checkoutOpportunityDarts,
    required this.functionalDoubleOpportunity,
    required this.bullCheckoutOpportunity,
    required this.finishedOnBull,
  });

  final int startScore;
  final int newScore;
  final int scoredPoints;
  final int dartsThrown;
  final bool openedLeg;
  final bool checkedOut;
  final bool busted;
  final int doubleAttempts;
  final List<DartThrowResult> throws;
  final List<DartThrowResult> targets;
  final List<String> targetReasons;
  final List<List<DartThrowResult>> plannedRoutes;
  final String finishLabel;
  final int? checkoutOpportunityDarts;
  final bool functionalDoubleOpportunity;
  final bool bullCheckoutOpportunity;
  final bool finishedOnBull;
}

class SimulatedVisitDebug {
  const SimulatedVisitDebug({
    required this.playerName,
    required this.startScore,
    required this.endScore,
    required this.scoredPoints,
    required this.checkedOut,
    required this.busted,
    required this.targets,
    required this.throws,
    required this.targetReasons,
    required this.plannedRoutes,
  });

  final String playerName;
  final int startScore;
  final int endScore;
  final int scoredPoints;
  final bool checkedOut;
  final bool busted;
  final List<DartThrowResult> targets;
  final List<DartThrowResult> throws;
  final List<String> targetReasons;
  final List<List<DartThrowResult>> plannedRoutes;
}

class SimulatedMatchResult {
  const SimulatedMatchResult({
    required this.winner,
    required this.scoreText,
    required this.averageA,
    required this.averageB,
    required this.first9AverageA,
    required this.first9AverageB,
    required this.checkoutRateA,
    required this.checkoutRateB,
    required this.doubleAttemptsA,
    required this.doubleAttemptsB,
    required this.successfulChecksA,
    required this.successfulChecksB,
    required this.scores100PlusA,
    required this.scores100PlusB,
    required this.scores140PlusA,
    required this.scores140PlusB,
    required this.scores180A,
    required this.scores180B,
    required this.legDartsDistributionA,
    required this.legDartsDistributionB,
    required this.legSummaries,
    required this.playerStatsA,
    required this.playerStatsB,
    required this.legsA,
    required this.legsB,
    required this.setsA,
    required this.setsB,
  });

  final SimulatedPlayer winner;
  final String scoreText;
  final double averageA;
  final double averageB;
  final double first9AverageA;
  final double first9AverageB;
  final double checkoutRateA;
  final double checkoutRateB;
  final int doubleAttemptsA;
  final int doubleAttemptsB;
  final int successfulChecksA;
  final int successfulChecksB;
  final int scores100PlusA;
  final int scores100PlusB;
  final int scores140PlusA;
  final int scores140PlusB;
  final int scores180A;
  final int scores180B;
  final Map<int, int> legDartsDistributionA;
  final Map<int, int> legDartsDistributionB;
  final List<SimulatedLegSummary> legSummaries;
  final SimulatedPlayerStats playerStatsA;
  final SimulatedPlayerStats playerStatsB;
  final int legsA;
  final int legsB;
  final int setsA;
  final int setsB;
}

class SimulatedPlayerStats {
  const SimulatedPlayerStats({
    this.pointsScored = 0,
    this.dartsThrown = 0,
    this.visits = 0,
    this.legsWon = 0,
    this.legsPlayed = 0,
    this.legsStarted = 0,
    this.legsWonAsStarter = 0,
    this.legsWonWithoutStarter = 0,
    this.scores0To40 = 0,
    this.scores41To59 = 0,
    this.scores60Plus = 0,
    this.scores100Plus = 0,
    this.scores140Plus = 0,
    this.scores171Plus = 0,
    this.scores180 = 0,
    this.checkoutAttempts = 0,
    this.successfulCheckouts = 0,
    this.checkoutAttempts1Dart = 0,
    this.checkoutAttempts2Dart = 0,
    this.checkoutAttempts3Dart = 0,
    this.successfulCheckouts1Dart = 0,
    this.successfulCheckouts2Dart = 0,
    this.successfulCheckouts3Dart = 0,
    this.thirdDartCheckoutAttempts = 0,
    this.thirdDartCheckouts = 0,
    this.bullCheckoutAttempts = 0,
    this.bullCheckouts = 0,
    this.functionalDoubleAttempts = 0,
    this.functionalDoubleSuccesses = 0,
    this.firstNinePoints = 0,
    this.firstNineDarts = 0,
    this.highestFinish = 0,
    this.bestLegDarts = 0,
    this.totalFinishValue = 0,
    this.withThrowPoints = 0,
    this.withThrowDarts = 0,
    this.againstThrowPoints = 0,
    this.againstThrowDarts = 0,
    this.decidingLegPoints = 0,
    this.decidingLegDarts = 0,
    this.decidingLegsPlayed = 0,
    this.decidingLegsWon = 0,
    this.won12Darters = 0,
    this.won15Darters = 0,
    this.won18Darters = 0,
  });

  final int pointsScored;
  final int dartsThrown;
  final int visits;
  final int legsWon;
  final int legsPlayed;
  final int legsStarted;
  final int legsWonAsStarter;
  final int legsWonWithoutStarter;
  final int scores0To40;
  final int scores41To59;
  final int scores60Plus;
  final int scores100Plus;
  final int scores140Plus;
  final int scores171Plus;
  final int scores180;
  final int checkoutAttempts;
  final int successfulCheckouts;
  final int checkoutAttempts1Dart;
  final int checkoutAttempts2Dart;
  final int checkoutAttempts3Dart;
  final int successfulCheckouts1Dart;
  final int successfulCheckouts2Dart;
  final int successfulCheckouts3Dart;
  final int thirdDartCheckoutAttempts;
  final int thirdDartCheckouts;
  final int bullCheckoutAttempts;
  final int bullCheckouts;
  final int functionalDoubleAttempts;
  final int functionalDoubleSuccesses;
  final double firstNinePoints;
  final int firstNineDarts;
  final int highestFinish;
  final int bestLegDarts;
  final int totalFinishValue;
  final int withThrowPoints;
  final int withThrowDarts;
  final int againstThrowPoints;
  final int againstThrowDarts;
  final int decidingLegPoints;
  final int decidingLegDarts;
  final int decidingLegsPlayed;
  final int decidingLegsWon;
  final int won12Darters;
  final int won15Darters;
  final int won18Darters;
}

class SimulatedLegSummary {
  const SimulatedLegSummary({
    required this.legNumber,
    required this.starterKey,
    required this.winnerKey,
    required this.decidingLeg,
    required this.scoreBeforeStartA,
    required this.scoreBeforeStartB,
    required this.legDartsA,
    required this.legDartsB,
    required this.legAverageA,
    required this.legAverageB,
    required this.remainingScoreA,
    required this.remainingScoreB,
    required this.visitDebugs,
  });

  final int legNumber;
  final String starterKey;
  final String winnerKey;
  final bool decidingLeg;
  final int scoreBeforeStartA;
  final int scoreBeforeStartB;
  final int legDartsA;
  final int legDartsB;
  final double legAverageA;
  final double legAverageB;
  final int remainingScoreA;
  final int remainingScoreB;
  final List<SimulatedVisitDebug> visitDebugs;
}

class _MatchState {
  int legsA = 0;
  int legsB = 0;
  int setsA = 0;
  int setsB = 0;
  int totalScoredA = 0;
  int totalScoredB = 0;
  int dartsA = 0;
  int dartsB = 0;
  int first9ScoredA = 0;
  int first9ScoredB = 0;
  int first9DartsA = 0;
  int first9DartsB = 0;
  int doubleAttemptsA = 0;
  int doubleAttemptsB = 0;
  int successfulChecksA = 0;
  int successfulChecksB = 0;
  int scores180A = 0;
  int scores180B = 0;
  int scores140PlusA = 0;
  int scores140PlusB = 0;
  int scores100PlusA = 0;
  int scores100PlusB = 0;
  final Map<int, int> legDartsDistributionA = <int, int>{};
  final Map<int, int> legDartsDistributionB = <int, int>{};
  final List<SimulatedLegSummary> legSummaries = <SimulatedLegSummary>[];
  final _SimulatedStatsAccumulator playerStatsA = _SimulatedStatsAccumulator();
  final _SimulatedStatsAccumulator playerStatsB = _SimulatedStatsAccumulator();
  String starter = 'A';
}

class _LegResult {
  const _LegResult({
    required this.winner,
    required this.legDartsA,
    required this.legDartsB,
    required this.legAverageA,
    required this.legAverageB,
    required this.remainingScoreA,
    required this.remainingScoreB,
    required this.visitDebugs,
  });

  final String winner;
  final int legDartsA;
  final int legDartsB;
  final double legAverageA;
  final double legAverageB;
  final int remainingScoreA;
  final int remainingScoreB;
  final List<SimulatedVisitDebug> visitDebugs;
}

class _VisitLegState {
  const _VisitLegState({
    required this.score,
    required this.openedLeg,
  });

  final int score;
  final bool openedLeg;
}

class _SimulatedStatsAccumulator {
  int pointsScored = 0;
  int dartsThrown = 0;
  int visits = 0;
  int legsWon = 0;
  int legsPlayed = 0;
  int legsStarted = 0;
  int legsWonAsStarter = 0;
  int legsWonWithoutStarter = 0;
  int scores0To40 = 0;
  int scores41To59 = 0;
  int scores60Plus = 0;
  int scores100Plus = 0;
  int scores140Plus = 0;
  int scores171Plus = 0;
  int scores180 = 0;
  int checkoutAttempts = 0;
  int successfulCheckouts = 0;
  int checkoutAttempts1Dart = 0;
  int checkoutAttempts2Dart = 0;
  int checkoutAttempts3Dart = 0;
  int successfulCheckouts1Dart = 0;
  int successfulCheckouts2Dart = 0;
  int successfulCheckouts3Dart = 0;
  int thirdDartCheckoutAttempts = 0;
  int thirdDartCheckouts = 0;
  int bullCheckoutAttempts = 0;
  int bullCheckouts = 0;
  int functionalDoubleAttempts = 0;
  int functionalDoubleSuccesses = 0;
  double firstNinePoints = 0;
  int firstNineDarts = 0;
  int highestFinish = 0;
  int bestLegDarts = 0;
  int totalFinishValue = 0;
  int withThrowPoints = 0;
  int withThrowDarts = 0;
  int againstThrowPoints = 0;
  int againstThrowDarts = 0;
  int decidingLegPoints = 0;
  int decidingLegDarts = 0;
  int decidingLegsPlayed = 0;
  int decidingLegsWon = 0;
  int won12Darters = 0;
  int won15Darters = 0;
  int won18Darters = 0;
  int firstNineDartsInCurrentLeg = 0;

  SimulatedPlayerStats build() {
    return SimulatedPlayerStats(
      pointsScored: pointsScored,
      dartsThrown: dartsThrown,
      visits: visits,
      legsWon: legsWon,
      legsPlayed: legsPlayed,
      legsStarted: legsStarted,
      legsWonAsStarter: legsWonAsStarter,
      legsWonWithoutStarter: legsWonWithoutStarter,
      scores0To40: scores0To40,
      scores41To59: scores41To59,
      scores60Plus: scores60Plus,
      scores100Plus: scores100Plus,
      scores140Plus: scores140Plus,
      scores171Plus: scores171Plus,
      scores180: scores180,
      checkoutAttempts: checkoutAttempts,
      successfulCheckouts: successfulCheckouts,
      checkoutAttempts1Dart: checkoutAttempts1Dart,
      checkoutAttempts2Dart: checkoutAttempts2Dart,
      checkoutAttempts3Dart: checkoutAttempts3Dart,
      successfulCheckouts1Dart: successfulCheckouts1Dart,
      successfulCheckouts2Dart: successfulCheckouts2Dart,
      successfulCheckouts3Dart: successfulCheckouts3Dart,
      thirdDartCheckoutAttempts: thirdDartCheckoutAttempts,
      thirdDartCheckouts: thirdDartCheckouts,
      bullCheckoutAttempts: bullCheckoutAttempts,
      bullCheckouts: bullCheckouts,
      functionalDoubleAttempts: functionalDoubleAttempts,
      functionalDoubleSuccesses: functionalDoubleSuccesses,
      firstNinePoints: firstNinePoints,
      firstNineDarts: firstNineDarts,
      highestFinish: highestFinish,
      bestLegDarts: bestLegDarts,
      totalFinishValue: totalFinishValue,
      withThrowPoints: withThrowPoints,
      withThrowDarts: withThrowDarts,
      againstThrowPoints: againstThrowPoints,
      againstThrowDarts: againstThrowDarts,
      decidingLegPoints: decidingLegPoints,
      decidingLegDarts: decidingLegDarts,
      decidingLegsPlayed: decidingLegsPlayed,
      decidingLegsWon: decidingLegsWon,
      won12Darters: won12Darters,
      won15Darters: won15Darters,
      won18Darters: won18Darters,
    );
  }
}

class X01MatchSimulator {
  X01MatchSimulator({
    required this.matchEngine,
    required this.botEngine,
  }) : _checkoutPlanner = CheckoutPlanner();

  final X01MatchEngine matchEngine;
  final BotEngine botEngine;
  final CheckoutPlanner _checkoutPlanner;

  SimulatedMatchResult simulateAutoMatch({
    required SimulatedPlayer playerA,
    required SimulatedPlayer playerB,
    required MatchConfig config,
    bool detailed = true,
  }) {
    final state = _MatchState();

    while (!_isMatchFinished(state, config)) {
      final decidingLeg = _isCurrentLegDeciding(state, config);
      final legResult = _simulateLeg(
        playerA: playerA,
        playerB: playerB,
        starter: state.starter,
        state: state,
        config: config,
        detailed: detailed,
        decidingLeg: decidingLeg,
      );

      if (legResult.winner == 'A') {
        state.legsA += 1;
        state.legDartsDistributionA[legResult.legDartsA] =
            (state.legDartsDistributionA[legResult.legDartsA] ?? 0) + 1;
        state.playerStatsA.legsWon += 1;
        if (state.starter == 'A') {
          state.playerStatsA.legsWonAsStarter += 1;
        } else {
          state.playerStatsA.legsWonWithoutStarter += 1;
        }
        if (legResult.legDartsA > 0 &&
            (state.playerStatsA.bestLegDarts == 0 ||
                legResult.legDartsA < state.playerStatsA.bestLegDarts)) {
          state.playerStatsA.bestLegDarts = legResult.legDartsA;
        }
        if (legResult.legDartsA > 0 && legResult.legDartsA <= 12) {
          state.playerStatsA.won12Darters += 1;
        }
        if (legResult.legDartsA > 0 && legResult.legDartsA <= 15) {
          state.playerStatsA.won15Darters += 1;
        }
        if (legResult.legDartsA > 0 && legResult.legDartsA <= 18) {
          state.playerStatsA.won18Darters += 1;
        }
      } else {
        state.legsB += 1;
        state.legDartsDistributionB[legResult.legDartsB] =
            (state.legDartsDistributionB[legResult.legDartsB] ?? 0) + 1;
        state.playerStatsB.legsWon += 1;
        if (state.starter == 'B') {
          state.playerStatsB.legsWonAsStarter += 1;
        } else {
          state.playerStatsB.legsWonWithoutStarter += 1;
        }
        if (legResult.legDartsB > 0 &&
            (state.playerStatsB.bestLegDarts == 0 ||
                legResult.legDartsB < state.playerStatsB.bestLegDarts)) {
          state.playerStatsB.bestLegDarts = legResult.legDartsB;
        }
        if (legResult.legDartsB > 0 && legResult.legDartsB <= 12) {
          state.playerStatsB.won12Darters += 1;
        }
        if (legResult.legDartsB > 0 && legResult.legDartsB <= 15) {
          state.playerStatsB.won15Darters += 1;
        }
        if (legResult.legDartsB > 0 && legResult.legDartsB <= 18) {
          state.playerStatsB.won18Darters += 1;
        }
      }

      state.playerStatsA.legsPlayed += 1;
      state.playerStatsB.legsPlayed += 1;
      if (state.starter == 'A') {
        state.playerStatsA.legsStarted += 1;
      } else {
        state.playerStatsB.legsStarted += 1;
      }
      state.playerStatsA.firstNineDartsInCurrentLeg = 0;
      state.playerStatsB.firstNineDartsInCurrentLeg = 0;
      if (decidingLeg) {
        state.playerStatsA.decidingLegsPlayed += 1;
        state.playerStatsB.decidingLegsPlayed += 1;
        if (legResult.winner == 'A') {
          state.playerStatsA.decidingLegsWon += 1;
        } else {
          state.playerStatsB.decidingLegsWon += 1;
        }
      }

      if (detailed) {
        state.legSummaries.add(
          SimulatedLegSummary(
            legNumber: state.legSummaries.length + 1,
            starterKey: state.starter,
            winnerKey: legResult.winner,
            decidingLeg: decidingLeg,
            scoreBeforeStartA: config.startScore,
            scoreBeforeStartB: config.startScore,
            legDartsA: legResult.legDartsA,
            legDartsB: legResult.legDartsB,
            legAverageA: _formatAverageValue(
              config.startScore - legResult.remainingScoreA,
              legResult.legDartsA,
            ),
            legAverageB: _formatAverageValue(
              config.startScore - legResult.remainingScoreB,
              legResult.legDartsB,
            ),
            remainingScoreA: legResult.remainingScoreA,
            remainingScoreB: legResult.remainingScoreB,
            visitDebugs: List<SimulatedVisitDebug>.from(legResult.visitDebugs),
          ),
        );
      }

      if (config.mode == MatchMode.sets) {
        if (state.legsA >= config.legsPerSet) {
          state.setsA += 1;
          state.legsA = 0;
          state.legsB = 0;
        } else if (state.legsB >= config.legsPerSet) {
          state.setsB += 1;
          state.legsA = 0;
          state.legsB = 0;
        }
      }

      state.starter = state.starter == 'A' ? 'B' : 'A';
    }

    final winner = _isWinner(state, config, 'A') ? playerA : playerB;
    final averageA = _formatAverageValue(state.totalScoredA, state.dartsA);
    final averageB = _formatAverageValue(state.totalScoredB, state.dartsB);
    final first9AverageA = _formatAverageValue(state.first9ScoredA, state.first9DartsA);
    final first9AverageB = _formatAverageValue(state.first9ScoredB, state.first9DartsB);
    final checkoutRateA = _formatCheckoutRate(
      state.successfulChecksA,
      state.doubleAttemptsA,
    );
    final checkoutRateB = _formatCheckoutRate(
      state.successfulChecksB,
      state.doubleAttemptsB,
    );

    return SimulatedMatchResult(
      winner: winner,
      scoreText: _buildScoreText(state, config, averageA, averageB),
      averageA: averageA,
      averageB: averageB,
      first9AverageA: first9AverageA,
      first9AverageB: first9AverageB,
      checkoutRateA: checkoutRateA,
      checkoutRateB: checkoutRateB,
      doubleAttemptsA: state.doubleAttemptsA,
      doubleAttemptsB: state.doubleAttemptsB,
      successfulChecksA: state.successfulChecksA,
      successfulChecksB: state.successfulChecksB,
      scores100PlusA: state.scores100PlusA,
      scores100PlusB: state.scores100PlusB,
      scores140PlusA: state.scores140PlusA,
      scores140PlusB: state.scores140PlusB,
      scores180A: state.scores180A,
      scores180B: state.scores180B,
      legDartsDistributionA: Map<int, int>.from(state.legDartsDistributionA),
      legDartsDistributionB: Map<int, int>.from(state.legDartsDistributionB),
      legSummaries: List<SimulatedLegSummary>.from(state.legSummaries),
      playerStatsA: state.playerStatsA.build(),
      playerStatsB: state.playerStatsB.build(),
      legsA: state.legsA,
      legsB: state.legsB,
      setsA: state.setsA,
      setsB: state.setsB,
    );
  }

  _LegResult _simulateLeg({
    required SimulatedPlayer playerA,
    required SimulatedPlayer playerB,
    required String starter,
    required _MatchState state,
    required MatchConfig config,
    required bool detailed,
    required bool decidingLeg,
  }) {
    var scoreA = config.startScore;
    var scoreB = config.startScore;
    var openedA = config.startRequirement == StartRequirement.straightIn;
    var openedB = config.startRequirement == StartRequirement.straightIn;
    var turn = starter;
    var legFirst9DartsA = 0;
    var legFirst9DartsB = 0;
    var legDartsA = 0;
    var legDartsB = 0;
    var safetyTurns = 0;
    final visitDebugs = <SimulatedVisitDebug>[];

    while (true) {
      safetyTurns += 1;
      if (safetyTurns > 400) {
        return _LegResult(
          winner: scoreA <= scoreB ? 'A' : 'B',
          legDartsA: legDartsA,
          legDartsB: legDartsB,
          legAverageA: _formatAverageValue(config.startScore - scoreA, legDartsA),
          legAverageB: _formatAverageValue(config.startScore - scoreB, legDartsB),
          remainingScoreA: scoreA,
          remainingScoreB: scoreB,
          visitDebugs: List<SimulatedVisitDebug>.from(visitDebugs),
        );
      }

      if (turn == 'A') {
        final result = _simulateVisit(
          startScore: scoreA,
          hasOpenedLeg: openedA,
          startRequirement: config.startRequirement,
          player: playerA,
          checkoutRequirement: config.checkoutRequirement,
          detailed: detailed,
        );
        state.totalScoredA += result.scoredPoints;
        state.dartsA += result.dartsThrown;
        legDartsA += result.dartsThrown;
        state.doubleAttemptsA += result.doubleAttempts;
        if (result.checkedOut) {
          state.successfulChecksA += 1;
        }
        _applyFirst9A(state, result, legFirst9DartsA);
        legFirst9DartsA = (legFirst9DartsA + result.dartsThrown).clamp(0, 9);
        _recordMilestoneA(state, result.scoredPoints);
        _recordVisitStats(
          accumulator: state.playerStatsA,
          result: result,
          isWithThrow: starter == 'A',
          isDecidingLeg: decidingLeg,
          legFirstNineDarts: legFirst9DartsA - result.dartsThrown,
        );
        if (detailed) {
          visitDebugs.add(
            _buildVisitDebug(
              playerName: playerA.name,
              startScore: scoreA,
              result: result,
            ),
          );
        }
        scoreA = result.newScore;
        openedA = result.openedLeg;
        if (result.checkedOut) {
          return _LegResult(
            winner: 'A',
            legDartsA: legDartsA,
            legDartsB: legDartsB,
            legAverageA: _formatAverageValue(config.startScore - scoreA, legDartsA),
            legAverageB: _formatAverageValue(config.startScore - scoreB, legDartsB),
            remainingScoreA: scoreA,
            remainingScoreB: scoreB,
            visitDebugs: List<SimulatedVisitDebug>.from(visitDebugs),
          );
        }
        turn = 'B';
      } else {
        final result = _simulateVisit(
          startScore: scoreB,
          hasOpenedLeg: openedB,
          startRequirement: config.startRequirement,
          player: playerB,
          checkoutRequirement: config.checkoutRequirement,
          detailed: detailed,
        );
        state.totalScoredB += result.scoredPoints;
        state.dartsB += result.dartsThrown;
        legDartsB += result.dartsThrown;
        state.doubleAttemptsB += result.doubleAttempts;
        if (result.checkedOut) {
          state.successfulChecksB += 1;
        }
        _applyFirst9B(state, result, legFirst9DartsB);
        legFirst9DartsB = (legFirst9DartsB + result.dartsThrown).clamp(0, 9);
        _recordMilestoneB(state, result.scoredPoints);
        _recordVisitStats(
          accumulator: state.playerStatsB,
          result: result,
          isWithThrow: starter == 'B',
          isDecidingLeg: decidingLeg,
          legFirstNineDarts: legFirst9DartsB - result.dartsThrown,
        );
        if (detailed) {
          visitDebugs.add(
            _buildVisitDebug(
              playerName: playerB.name,
              startScore: scoreB,
              result: result,
            ),
          );
        }
        scoreB = result.newScore;
        openedB = result.openedLeg;
        if (result.checkedOut) {
          return _LegResult(
            winner: 'B',
            legDartsA: legDartsA,
            legDartsB: legDartsB,
            legAverageA: _formatAverageValue(config.startScore - scoreA, legDartsA),
            legAverageB: _formatAverageValue(config.startScore - scoreB, legDartsB),
            remainingScoreA: scoreA,
            remainingScoreB: scoreB,
            visitDebugs: List<SimulatedVisitDebug>.from(visitDebugs),
          );
        }
        turn = 'A';
      }
    }
  }

  SimulatedVisitResult _simulateVisit({
    required int startScore,
    required bool hasOpenedLeg,
    required StartRequirement startRequirement,
    required SimulatedPlayer player,
    required CheckoutRequirement checkoutRequirement,
    required bool detailed,
  }) {
    var legState = _VisitLegState(
      score: startScore,
      openedLeg: hasOpenedLeg || startRequirement == StartRequirement.straightIn,
    );
    var scoredPoints = 0;
    var dartsThrown = 0;
    final throws = <DartThrowResult>[];
    final targets = detailed ? <DartThrowResult>[] : null;
    final targetReasons = detailed ? <String>[] : null;
    final plannedRoutes = detailed ? <List<DartThrowResult>>[] : null;
    var doubleAttempts = 0;
    final checkoutOpportunityDarts = _checkoutOpportunityDarts(
      startScore,
      checkoutRequirement,
    );
    final functionalDoubleOpportunity = _isFunctionalDoubleOpportunity(startScore);
    final bullCheckoutOpportunity =
        (startScore == 50 || startScore == 25) &&
        checkoutOpportunityDarts != null;

    for (var dart = 1; dart <= 3; dart += 1) {
      final simulation = legState.openedLeg
          ? botEngine.simulateThrow(
              profile: player.profile,
              score: legState.score,
              dartsLeft: 4 - dart,
            )
          : botEngine.simulateTargetThrow(
              target: matchEngine.rules.createDouble(20),
              score: legState.score,
              profile: player.profile,
              reason: 'Double-in opener',
            );
      final hit = simulation.hit;
      dartsThrown += 1;
      throws.add(hit);
      targets?.add(simulation.target);
      targetReasons?.add(simulation.reason);
      plannedRoutes?.add(List<DartThrowResult>.from(simulation.plannedRoute));
      if (simulation.target.isDouble || simulation.target.isBull) {
        doubleAttempts += 1;
      }

      final visitState = matchEngine.evaluateVisit(
        currentScore: startScore,
        throws: List<DartThrowResult>.from(throws),
        startRequirement: startRequirement,
        hasOpenedLeg: hasOpenedLeg,
        checkoutRequirement: checkoutRequirement,
      );

      if (visitState.didBust) {
        return SimulatedVisitResult(
          startScore: startScore,
          newScore: startScore,
          scoredPoints: 0,
          dartsThrown: dartsThrown,
          openedLeg: hasOpenedLeg,
          checkedOut: false,
          busted: true,
          doubleAttempts: doubleAttempts,
          throws: detailed
              ? List<DartThrowResult>.from(throws)
              : const <DartThrowResult>[],
          targets: detailed
              ? List<DartThrowResult>.from(targets!)
              : const <DartThrowResult>[],
          targetReasons: detailed
              ? List<String>.from(targetReasons!)
              : const <String>[],
          plannedRoutes: detailed
              ? plannedRoutes!
                  .map((entry) => List<DartThrowResult>.from(entry))
                  .toList()
              : const <List<DartThrowResult>>[],
          finishLabel: '',
          checkoutOpportunityDarts: checkoutOpportunityDarts,
          functionalDoubleOpportunity: functionalDoubleOpportunity,
          bullCheckoutOpportunity: bullCheckoutOpportunity,
          finishedOnBull: false,
        );
      }

      scoredPoints = visitState.scoredPoints;
      legState = _VisitLegState(
        score: visitState.remainingScore,
        openedLeg: visitState.openedLeg,
      );
      if (legState.score == 0) {
        return SimulatedVisitResult(
          startScore: startScore,
          newScore: 0,
          scoredPoints: scoredPoints,
          dartsThrown: dartsThrown,
          openedLeg: legState.openedLeg,
          checkedOut: true,
          busted: false,
          doubleAttempts: doubleAttempts,
          throws: detailed
              ? List<DartThrowResult>.from(throws)
              : const <DartThrowResult>[],
          targets: detailed
              ? List<DartThrowResult>.from(targets!)
              : const <DartThrowResult>[],
          targetReasons: detailed
              ? List<String>.from(targetReasons!)
              : const <String>[],
          plannedRoutes: detailed
              ? plannedRoutes!
                  .map((entry) => List<DartThrowResult>.from(entry))
                  .toList()
              : const <List<DartThrowResult>>[],
          finishLabel:
              detailed ? throws.map((entry) => entry.label).join(' - ') : '',
          checkoutOpportunityDarts: checkoutOpportunityDarts,
          functionalDoubleOpportunity: functionalDoubleOpportunity,
          bullCheckoutOpportunity: bullCheckoutOpportunity,
          finishedOnBull: throws.isNotEmpty && throws.last.isBull,
        );
      }
    }

    return SimulatedVisitResult(
      startScore: startScore,
      newScore: legState.score,
      scoredPoints: scoredPoints,
      dartsThrown: dartsThrown,
      openedLeg: legState.openedLeg,
      checkedOut: false,
      busted: false,
      doubleAttempts: doubleAttempts,
      throws: detailed
          ? List<DartThrowResult>.from(throws)
          : const <DartThrowResult>[],
      targets: detailed
          ? List<DartThrowResult>.from(targets!)
          : const <DartThrowResult>[],
      targetReasons: detailed
          ? List<String>.from(targetReasons!)
          : const <String>[],
      plannedRoutes: detailed
          ? plannedRoutes!.map((entry) => List<DartThrowResult>.from(entry)).toList()
          : const <List<DartThrowResult>>[],
      finishLabel: '',
      checkoutOpportunityDarts: checkoutOpportunityDarts,
      functionalDoubleOpportunity: functionalDoubleOpportunity,
      bullCheckoutOpportunity: bullCheckoutOpportunity,
      finishedOnBull: false,
    );
  }

  void _recordVisitStats({
    required _SimulatedStatsAccumulator accumulator,
    required SimulatedVisitResult result,
    required bool isWithThrow,
    required bool isDecidingLeg,
    required int legFirstNineDarts,
  }) {
    final dartsUsed = result.dartsThrown;
    accumulator.visits += 1;
    accumulator.dartsThrown += dartsUsed;
    accumulator.pointsScored += result.scoredPoints;

    if (result.scoredPoints <= 40) {
      accumulator.scores0To40 += 1;
    } else if (result.scoredPoints <= 59) {
      accumulator.scores41To59 += 1;
    }
    if (result.scoredPoints >= 60) {
      accumulator.scores60Plus += 1;
    }
    if (result.scoredPoints >= 100) {
      accumulator.scores100Plus += 1;
    }
    if (result.scoredPoints >= 140) {
      accumulator.scores140Plus += 1;
    }
    if (result.scoredPoints >= 171) {
      accumulator.scores171Plus += 1;
    }
    if (result.scoredPoints >= 180) {
      accumulator.scores180 += 1;
    }

    final firstNineSlotsLeft = 9 - legFirstNineDarts;
    final countedFirstNineDarts =
        firstNineSlotsLeft > dartsUsed ? dartsUsed : firstNineSlotsLeft;
    if (countedFirstNineDarts > 0 && dartsUsed > 0) {
      accumulator.firstNineDarts += countedFirstNineDarts;
      accumulator.firstNinePoints +=
          (result.scoredPoints * countedFirstNineDarts) / dartsUsed;
      accumulator.firstNineDartsInCurrentLeg += countedFirstNineDarts;
    }

    final checkoutOpportunity = result.checkoutOpportunityDarts;
    if (checkoutOpportunity != null) {
      accumulator.checkoutAttempts += 1;
      switch (checkoutOpportunity) {
        case 1:
          accumulator.checkoutAttempts1Dart += 1;
          break;
        case 2:
          accumulator.checkoutAttempts2Dart += 1;
          break;
        case 3:
          accumulator.checkoutAttempts3Dart += 1;
          accumulator.thirdDartCheckoutAttempts += 1;
          break;
      }
    }

    if (result.functionalDoubleOpportunity) {
      accumulator.functionalDoubleAttempts += 1;
    }
    if (result.bullCheckoutOpportunity) {
      accumulator.bullCheckoutAttempts += 1;
    }

    if (isWithThrow) {
      accumulator.withThrowPoints += result.scoredPoints;
      accumulator.withThrowDarts += dartsUsed;
    } else {
      accumulator.againstThrowPoints += result.scoredPoints;
      accumulator.againstThrowDarts += dartsUsed;
    }

    if (isDecidingLeg) {
      accumulator.decidingLegPoints += result.scoredPoints;
      accumulator.decidingLegDarts += dartsUsed;
    }

    if (result.checkedOut) {
      accumulator.successfulCheckouts += 1;
      accumulator.totalFinishValue += result.startScore;
      if (result.startScore > accumulator.highestFinish) {
        accumulator.highestFinish = result.startScore;
      }
      switch (dartsUsed) {
        case 1:
          accumulator.successfulCheckouts1Dart += 1;
          break;
        case 2:
          accumulator.successfulCheckouts2Dart += 1;
          break;
        case 3:
          accumulator.successfulCheckouts3Dart += 1;
          accumulator.thirdDartCheckouts += 1;
          break;
      }
      if (result.finishedOnBull) {
        accumulator.bullCheckouts += 1;
      }
      if (result.functionalDoubleOpportunity) {
        accumulator.functionalDoubleSuccesses += 1;
      }
    }
  }

  SimulatedVisitDebug _buildVisitDebug({
    required String playerName,
    required int startScore,
    required SimulatedVisitResult result,
  }) {
    return SimulatedVisitDebug(
      playerName: playerName,
      startScore: startScore,
      endScore: result.newScore,
      scoredPoints: result.scoredPoints,
      checkedOut: result.checkedOut,
      busted: result.busted,
      targets: List<DartThrowResult>.from(result.targets),
      throws: List<DartThrowResult>.from(result.throws),
      targetReasons: List<String>.from(result.targetReasons),
      plannedRoutes: result.plannedRoutes
          .map((entry) => List<DartThrowResult>.from(entry))
          .toList(),
    );
  }

  void _applyFirst9A(_MatchState state, SimulatedVisitResult result, int legFirst9Darts) {
    final remainingSlots = 9 - legFirst9Darts;
    final first9DartsToAdd = remainingSlots < result.dartsThrown ? remainingSlots : result.dartsThrown;
    if (first9DartsToAdd <= 0) {
      return;
    }
    final perDart = result.dartsThrown > 0 ? result.scoredPoints / result.dartsThrown : 0;
    state.first9ScoredA += (perDart * first9DartsToAdd).round();
    state.first9DartsA += first9DartsToAdd;
  }

  void _applyFirst9B(_MatchState state, SimulatedVisitResult result, int legFirst9Darts) {
    final remainingSlots = 9 - legFirst9Darts;
    final first9DartsToAdd = remainingSlots < result.dartsThrown ? remainingSlots : result.dartsThrown;
    if (first9DartsToAdd <= 0) {
      return;
    }
    final perDart = result.dartsThrown > 0 ? result.scoredPoints / result.dartsThrown : 0;
    state.first9ScoredB += (perDart * first9DartsToAdd).round();
    state.first9DartsB += first9DartsToAdd;
  }

  void _recordMilestoneA(_MatchState state, int score) {
    if (score == 180) {
      state.scores180A += 1;
      return;
    }
    if (score >= 140) {
      state.scores140PlusA += 1;
      return;
    }
    if (score >= 100) {
      state.scores100PlusA += 1;
    }
  }

  void _recordMilestoneB(_MatchState state, int score) {
    if (score == 180) {
      state.scores180B += 1;
      return;
    }
    if (score >= 140) {
      state.scores140PlusB += 1;
      return;
    }
    if (score >= 100) {
      state.scores100PlusB += 1;
    }
  }

  bool _isMatchFinished(_MatchState state, MatchConfig config) {
    if (config.mode == MatchMode.legs) {
      return state.legsA >= config.legsToWin || state.legsB >= config.legsToWin;
    }
    return state.setsA >= config.setsToWin || state.setsB >= config.setsToWin;
  }

  bool _isCurrentLegDeciding(_MatchState state, MatchConfig config) {
    if (config.mode == MatchMode.sets) {
      final contenderA =
          state.setsA == config.setsToWin - 1 && state.legsA == config.legsPerSet - 1;
      final contenderB =
          state.setsB == config.setsToWin - 1 && state.legsB == config.legsPerSet - 1;
      return contenderA && contenderB;
    }
    return state.legsA == config.legsToWin - 1 &&
        state.legsB == config.legsToWin - 1;
  }

  bool _isWinner(_MatchState state, MatchConfig config, String key) {
    if (config.mode == MatchMode.legs) {
      return key == 'A'
          ? state.legsA >= config.legsToWin
          : state.legsB >= config.legsToWin;
    }
    return key == 'A'
        ? state.setsA >= config.setsToWin
        : state.setsB >= config.setsToWin;
  }

  String _buildScoreText(
    _MatchState state,
    MatchConfig config,
    double averageA,
    double averageB,
  ) {
    final avgA = averageA.toStringAsFixed(1);
    final avgB = averageB.toStringAsFixed(1);
    if (config.mode == MatchMode.legs) {
      return '${state.legsA}:${state.legsB} Legs | Avg $avgA / $avgB';
    }
    return '${state.setsA}:${state.setsB} Sets | Avg $avgA / $avgB';
  }

  double _formatAverageValue(int totalScored, int dartsThrown) {
    if (dartsThrown <= 0) {
      return 0;
    }
    return (totalScored / dartsThrown) * 3;
  }

  double _formatCheckoutRate(int successfulChecks, int doubleAttempts) {
    if (doubleAttempts <= 0) {
      return 0;
    }
    return (successfulChecks / doubleAttempts) * 100;
  }

  int? _checkoutOpportunityDarts(
    int score,
    CheckoutRequirement checkoutRequirement,
  ) {
    for (var dartsLeft = 1; dartsLeft <= 3; dartsLeft += 1) {
      final route = _checkoutPlanner.bestFinishRoute(
        score: score,
        dartsLeft: dartsLeft,
        checkoutRequirement: checkoutRequirement,
      );
      if (route != null && route.isNotEmpty) {
        return dartsLeft;
      }
    }
    return null;
  }

  bool _isFunctionalDoubleOpportunity(int score) {
    return (score > 1 && score <= 40 && score.isEven) || score == 50;
  }
}

import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../domain/bot/bot_engine.dart';
import '../../domain/tournament/tournament_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/checkout_planner.dart';
import '../../domain/x01/x01_match_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';

class BackgroundTaskSnapshot {
  const BackgroundTaskSnapshot({
    required this.taskType,
    required this.label,
    required this.inProgress,
    this.progress,
  });

  final String taskType;
  final String label;
  final bool inProgress;
  final double? progress;
}

class BackgroundTaskRunner extends ChangeNotifier {
  BackgroundTaskRunner._();

  static final BackgroundTaskRunner instance = BackgroundTaskRunner._();

  String? _activeTaskType;
  String _label = '';
  bool _inProgress = false;
  double? _progress;

  String? get activeTaskType => _activeTaskType;
  String get label => _label;
  bool get inProgress => _inProgress;
  double? get progress => _progress;

  Future<T> runJob<T>({
    required String taskType,
    required String initialLabel,
    required Map<String, Object?> payload,
    void Function(BackgroundTaskSnapshot snapshot)? onUpdate,
  }) async {
    final receivePort = ReceivePort();
    final errorPort = ReceivePort();
    final exitPort = ReceivePort();
    final completer = Completer<T>();
    Isolate? isolate;

    void publish({
      required String label,
      required bool inProgress,
      double? progress,
    }) {
      final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
      _activeTaskType = inProgress ? taskType : null;
      _label = label;
      _inProgress = inProgress;
      _progress = normalizedProgress;
      final snapshot = BackgroundTaskSnapshot(
        taskType: taskType,
        label: label,
        inProgress: inProgress,
        progress: normalizedProgress,
      );
      onUpdate?.call(snapshot);
      notifyListeners();
    }

    publish(label: initialLabel, inProgress: true, progress: 0);

    late final StreamSubscription<dynamic> receiveSub;
    late final StreamSubscription<dynamic> errorSub;
    late final StreamSubscription<dynamic> exitSub;

    Future<void> cleanup() async {
      await receiveSub.cancel();
      await errorSub.cancel();
      await exitSub.cancel();
      receivePort.close();
      errorPort.close();
      exitPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    receiveSub = receivePort.listen((dynamic message) {
      if (message is! Map) {
        return;
      }
      final type = message['type'];
      if (type == 'progress') {
        publish(
          label: (message['label'] as String?) ?? initialLabel,
          inProgress: true,
          progress: (message['progress'] as num?)?.toDouble(),
        );
        return;
      }
      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(message['value'] as T);
        }
      }
    });

    errorSub = errorPort.listen((dynamic error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });

    exitSub = exitPort.listen((dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Background task "$taskType" ended unexpectedly.'),
        );
      }
    });

    isolate = await Isolate.spawn<_BackgroundTaskRequest>(
      _backgroundTaskEntry,
      _BackgroundTaskRequest(
        taskType: taskType,
        payload: payload,
        sendPort: receivePort.sendPort,
      ),
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort,
    );

    try {
      final result = await completer.future;
      publish(label: initialLabel, inProgress: false, progress: 1);
      return result;
    } finally {
      await cleanup();
      publish(label: '', inProgress: false, progress: null);
    }
  }
}

class _BackgroundTaskRequest {
  const _BackgroundTaskRequest({
    required this.taskType,
    required this.payload,
    required this.sendPort,
  });

  final String taskType;
  final Map<String, Object?> payload;
  final SendPort sendPort;
}

void _backgroundTaskEntry(_BackgroundTaskRequest request) {
  switch (request.taskType) {
    case 'estimate_theo_average':
      final value = _runTheoAverageEstimate(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'simulate_bot_match':
      final value = _runBotMatchSimulation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'checkout_calculator':
      final value = _runCheckoutCalculation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
    case 'simulate_tournament':
      final value = _runTournamentSimulation(
        payload: request.payload,
        sendPort: request.sendPort,
      );
      request.sendPort.send(<String, Object?>{
        'type': 'result',
        'value': value,
      });
      return;
  }

  throw UnsupportedError(
    'Unknown background task type: ${request.taskType}',
  );
}

Map<String, Object?> _runTournamentSimulation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final bracketPayload = payload['bracket'];
  if (bracketPayload is! Map) {
    throw StateError('simulate_tournament requires a bracket payload.');
  }
  final profileEntries = ((payload['profilesById'] as Map?) ?? const <Object?, Object?>{})
      .cast<Object?, Object?>();
  final includeHumanMatches = payload['includeHumanMatches'] as bool? ?? false;
  final bracket = TournamentBracket.fromJson(
    bracketPayload.cast<String, dynamic>(),
  );
  final profilesById = <String, BotProfile>{};
  for (final entry in profileEntries.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! Map) {
      continue;
    }
    profilesById[key] = _deserializeBotProfile(value.cast<String, dynamic>());
  }

  final engine = TournamentEngine();
  engine.resetPerformanceTotals();

  final totalMatches = _countTotalMatches(bracket);
  var workingBracket = bracket;
  var simulatedMatches = 0;
  var batchSize = 32;
  var stoppedForHumanMatch = false;

  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Turnier wird simuliert: ${bracket.definition.name} (0/$totalMatches Matches)',
    'progress': totalMatches == 0 ? null : 0.0,
  });

  while (!workingBracket.isCompleted) {
    if (!includeHumanMatches && _shouldStopBeforeNextRoundBg(workingBracket)) {
      stoppedForHumanMatch = true;
      break;
    }
    final batch = engine.simulateMatchesBatch(
      bracket: workingBracket,
      profileProvider: (String participantId) =>
          profilesById[participantId] ??
          const BotProfile(
            skill: 700,
            finishingSkill: 700,
          ),
      includeHumanMatches: includeHumanMatches,
      maxMatches: batchSize,
    );
    if (!batch.madeProgress) {
      break;
    }
    workingBracket = batch.bracket;
    simulatedMatches += batch.simulatedMatches;
    final completedMatches = _countCompletedMatches(workingBracket);
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Turnier wird simuliert: ${workingBracket.definition.name} ($completedMatches/$totalMatches Matches)',
      'progress': totalMatches == 0
          ? null
          : (completedMatches / totalMatches).clamp(0.0, 1.0).toDouble(),
    });
  }

  return <String, Object?>{
    'bracket': workingBracket.toJson(),
    'simulatedMatches': simulatedMatches,
    'completed': workingBracket.isCompleted,
    'stoppedForHumanMatch': stoppedForHumanMatch,
  };
}

double _runTheoAverageEstimate({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final skill = (payload['skill'] as num?)?.toInt() ?? 1;
  final finishingSkill = (payload['finishingSkill'] as num?)?.toInt() ?? skill;
  final radiusCalibrationPercent =
      (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92;
  final simulationSpreadPercent =
      (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115;
  final matchCount = (payload['matchCount'] as num?)?.toInt() ?? 100;
  final playerName = (payload['playerName'] as String?) ?? 'Spieler';

  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(),
  );
  final profile = BotProfile(
    skill: skill,
    finishingSkill: finishingSkill,
    radiusCalibrationPercent: radiusCalibrationPercent,
    simulationSpreadPercent: simulationSpreadPercent,
  );
  const config = MatchConfig(
    startScore: 501,
    mode: MatchMode.legs,
    checkoutRequirement: CheckoutRequirement.doubleOut,
    legsToWin: 8,
  );

  var totalAverage = 0.0;
  for (var index = 0; index < matchCount; index += 1) {
    sendPort.send(<String, Object?>{
      'type': 'progress',
      'label':
          'Theo wird berechnet: $playerName (${index + 1}/$matchCount) - Referenz-Match ${index + 1}/$matchCount',
      'progress': (index + 1) / matchCount,
    });
    final player = SimulatedPlayer(
      name: 'Theo',
      profile: profile,
    );
    final result = simulator.simulateAutoMatch(
      playerA: player,
      playerB: player,
      config: config,
      detailed: false,
      random: Random(7919 * (index + 1)),
    );
    totalAverage += ((result.averageA + result.averageB) / 2)
        .clamp(0, 180)
        .toDouble();
  }

  return (totalAverage / matchCount).clamp(0, 180).toDouble();
}

Map<String, Object?> _runBotMatchSimulation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird vorbereitet',
    'progress': 0.05,
  });
  final simulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: BotEngine(),
  );
  final playerA = SimulatedPlayer(
    name: (payload['playerAName'] as String?) ?? 'Bot A',
    profile: BotProfile(
      skill: (payload['playerASkill'] as num?)?.toInt() ?? 750,
      finishingSkill: (payload['playerAFinishingSkill'] as num?)?.toInt() ?? 750,
      radiusCalibrationPercent:
          (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
      simulationSpreadPercent:
          (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
    ),
  );
  final playerB = SimulatedPlayer(
    name: (payload['playerBName'] as String?) ?? 'Bot B',
    profile: BotProfile(
      skill: (payload['playerBSkill'] as num?)?.toInt() ?? 650,
      finishingSkill: (payload['playerBFinishingSkill'] as num?)?.toInt() ?? 650,
      radiusCalibrationPercent:
          (payload['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
      simulationSpreadPercent:
          (payload['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
    ),
  );
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird simuliert',
    'progress': 0.1,
  });
  final result = simulator.simulateAutoMatch(
    playerA: playerA,
    playerB: playerB,
    config: const MatchConfig(
      startScore: 501,
      mode: MatchMode.legs,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      legsToWin: 6,
    ),
  );
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': 'Bot-Match wird aufbereitet',
    'progress': 0.95,
  });
  return _serializeSimulatedMatchResult(result);
}

Map<String, Object?> _runCheckoutCalculation({
  required Map<String, Object?> payload,
  required SendPort sendPort,
}) {
  final mode = (payload['mode'] as String?) ?? 'checkout';
  final dartsLeft = (payload['dartsLeft'] as num?)?.toInt() ?? 3;
  final checkoutRequirement = _checkoutRequirementFromName(
    payload['checkoutRequirement'] as String?,
  );
  final playStyle = _checkoutPlayStyleFromName(payload['playStyle'] as String?);
  final preferredDoubles = ((payload['preferredDoubles'] as List?) ?? const [])
      .whereType<num>()
      .map((entry) => entry.toInt())
      .toSet();
  final dislikedDoubles = ((payload['dislikedDoubles'] as List?) ?? const [])
      .whereType<num>()
      .map((entry) => entry.toInt())
      .toSet();
  const standardOuterBullPreference = 50;
  const standardBullPreference = 50;
  const standardSetupPreference = 85;
  const maxVisibleOptions = 8;

  final planner = CheckoutPlanner();
  sendPort.send(<String, Object?>{
    'type': 'progress',
    'label': mode == 'setup'
        ? 'Stellwege werden berechnet'
        : 'Checkout-Wege werden berechnet',
    'progress': 0.1,
  });

  if (mode == 'setup') {
    final startScore = (payload['startScore'] as num?)?.toInt() ?? 0;
    if (!planner.isValidSetupStartScore(startScore) || dartsLeft <= 0) {
      return <String, Object?>{
        'mode': 'setup',
        'bands': <String, Object?>{},
      };
    }
    final bandOptions = planner.bestSetupBandOptions(
      startScore: startScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: standardSetupPreference,
      outerBullPreference: standardOuterBullPreference,
      bullPreference: standardBullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
    final serializedBands = <String, Object?>{};
    for (final entry in bandOptions.entries) {
      final adjustment = planner.doublePreferenceAdjustment(
        entry.value.finishRoute.isEmpty ? null : entry.value.finishRoute.last,
        preferredDoubles: preferredDoubles,
        dislikedDoubles: dislikedDoubles,
      );
      serializedBands[entry.key.name] = <String, Object?>{
        'option': _serializeSetupLeaveOption(entry.value),
        'effectiveScore': entry.value.score + adjustment,
        'effectiveBreakdown': _serializeSetupScoreBreakdown(
          _applyDoubleAdjustmentToSetupBreakdownBg(
            entry.value.breakdown,
            entry.value.finishRoute.isEmpty ? null : entry.value.finishRoute.last,
            adjustment,
          ),
        ),
        'startScore': startScore,
        'dartsLeft': dartsLeft,
        'checkoutRequirement': checkoutRequirement.name,
        'playStyle': playStyle.name,
        'preferredDoubles': preferredDoubles.toList()..sort(),
        'dislikedDoubles': dislikedDoubles.toList()..sort(),
        'targetBand': entry.key.name,
      };
    }
    return <String, Object?>{
      'mode': 'setup',
      'bands': serializedBands,
    };
  }

  final score = (payload['score'] as num?)?.toInt() ?? 0;
  if (score <= 1 || dartsLeft <= 0) {
    return <String, Object?>{
      'mode': 'checkout',
      'options': const <Object?>[],
    };
  }
  final finishes = planner.allCheckoutRoutes(
    score: score,
    dartsLeft: dartsLeft,
    checkoutRequirement: checkoutRequirement,
    playStyle: playStyle,
  );
  if (finishes.isEmpty) {
    return <String, Object?>{
      'mode': 'checkout',
      'options': const <Object?>[],
    };
  }

  final rankedRoutes = finishes
      .map((route) {
        final adjustment = planner.doublePreferenceAdjustment(
          route.isEmpty ? null : route.last,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
        );
        final baseScore = planner.scoreRoute(
          route: route,
          startScore: score,
          totalDarts: dartsLeft,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: standardOuterBullPreference,
          bullPreference: standardBullPreference,
        );
        return <String, Object?>{
          'route': route,
          'score': baseScore + adjustment,
          'adjustment': adjustment,
        };
      })
      .toList()
    ..sort(
      (left, right) =>
          ((right['score'] as int?) ?? 0).compareTo((left['score'] as int?) ?? 0),
    );

  final options = <Object?>[];
  for (final rankedRoute in rankedRoutes.take(maxVisibleOptions)) {
    final route = (rankedRoute['route'] as List).cast<DartThrowResult>();
    final adjustment = (rankedRoute['adjustment'] as int?) ?? 0;
    final breakdown = _applyDoubleAdjustmentToBreakdownBg(
      planner.routeScoreBreakdown(
        route: route,
        startScore: score,
        totalDarts: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: standardOuterBullPreference,
        bullPreference: standardBullPreference,
      ),
      route.isEmpty ? null : route.last,
      adjustment,
    );
    final missScenarios = _buildMissScenariosBg(
      planner: planner,
      route: route,
      startScore: score,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: standardOuterBullPreference,
      bullPreference: standardBullPreference,
    );
    final fallbackHints = _buildFallbackHintsBg(
      planner: planner,
      route: route,
      startScore: score,
      totalDarts: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    options.add(<String, Object?>{
      'throws': route.map(_serializeThrow).toList(growable: false),
      'score': rankedRoute['score'],
      'breakdown': _serializeRouteScoreBreakdown(breakdown),
      'missScenarios': missScenarios,
      'fallbackHints': fallbackHints,
      'rationaleHint': _buildRationaleHintBg(
        planner: planner,
        route: route,
        startScore: score,
        totalDarts: dartsLeft,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      ),
      'badges': _buildBadgesBg(
        planner: planner,
        route: route,
        missScenarios: missScenarios,
        fallbackHints: fallbackHints,
      ),
    });
  }
  return <String, Object?>{
    'mode': 'checkout',
    'options': options,
  };
}

Map<String, Object?> _serializeSimulatedMatchResult(SimulatedMatchResult result) {
  return <String, Object?>{
    'winnerName': result.winner.name,
    'winnerProfile': _serializeBotProfile(result.winner.profile),
    'scoreText': result.scoreText,
    'averageA': result.averageA,
    'averageB': result.averageB,
    'first9AverageA': result.first9AverageA,
    'first9AverageB': result.first9AverageB,
    'checkoutRateA': result.checkoutRateA,
    'checkoutRateB': result.checkoutRateB,
    'doubleAttemptsA': result.doubleAttemptsA,
    'doubleAttemptsB': result.doubleAttemptsB,
    'successfulChecksA': result.successfulChecksA,
    'successfulChecksB': result.successfulChecksB,
    'scores100PlusA': result.scores100PlusA,
    'scores100PlusB': result.scores100PlusB,
    'scores140PlusA': result.scores140PlusA,
    'scores140PlusB': result.scores140PlusB,
    'scores180A': result.scores180A,
    'scores180B': result.scores180B,
    'legDartsDistributionA': result.legDartsDistributionA.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'legDartsDistributionB': result.legDartsDistributionB.map(
      (key, value) => MapEntry(key.toString(), value),
    ),
    'legSummaries': result.legSummaries.map(_serializeLegSummary).toList(),
    'playerStatsA': _serializePlayerStats(result.playerStatsA),
    'playerStatsB': _serializePlayerStats(result.playerStatsB),
    'legsA': result.legsA,
    'legsB': result.legsB,
    'setsA': result.setsA,
    'setsB': result.setsB,
  };
}

Map<String, Object?> _serializeBotProfile(BotProfile profile) {
  return <String, Object?>{
    'skill': profile.skill,
    'finishingSkill': profile.finishingSkill,
    'radiusCalibrationPercent': profile.radiusCalibrationPercent,
    'simulationSpreadPercent': profile.simulationSpreadPercent,
  };
}

BotProfile _deserializeBotProfile(Map<String, dynamic> json) {
  return BotProfile(
    skill: (json['skill'] as num?)?.toInt() ?? 700,
    finishingSkill: (json['finishingSkill'] as num?)?.toInt() ?? 700,
    radiusCalibrationPercent:
        (json['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
    simulationSpreadPercent:
        (json['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
  );
}

Map<String, Object?> _serializeLegSummary(SimulatedLegSummary summary) {
  return <String, Object?>{
    'legNumber': summary.legNumber,
    'starterKey': summary.starterKey,
    'winnerKey': summary.winnerKey,
    'decidingLeg': summary.decidingLeg,
    'scoreBeforeStartA': summary.scoreBeforeStartA,
    'scoreBeforeStartB': summary.scoreBeforeStartB,
    'legDartsA': summary.legDartsA,
    'legDartsB': summary.legDartsB,
    'legAverageA': summary.legAverageA,
    'legAverageB': summary.legAverageB,
    'remainingScoreA': summary.remainingScoreA,
    'remainingScoreB': summary.remainingScoreB,
    'visitDebugs': summary.visitDebugs.map(_serializeVisitDebug).toList(),
  };
}

Map<String, Object?> _serializeVisitDebug(SimulatedVisitDebug debug) {
  return <String, Object?>{
    'playerName': debug.playerName,
    'startScore': debug.startScore,
    'endScore': debug.endScore,
    'scoredPoints': debug.scoredPoints,
    'checkedOut': debug.checkedOut,
    'busted': debug.busted,
    'targets': debug.targets.map(_serializeThrow).toList(),
    'throws': debug.throws.map(_serializeThrow).toList(),
    'targetReasons': debug.targetReasons,
    'plannedRoutes': debug.plannedRoutes
        .map((route) => route.map(_serializeThrow).toList())
        .toList(),
  };
}

Map<String, Object?> _serializePlayerStats(SimulatedPlayerStats stats) {
  return <String, Object?>{
    'pointsScored': stats.pointsScored,
    'dartsThrown': stats.dartsThrown,
    'visits': stats.visits,
    'legsWon': stats.legsWon,
    'legsPlayed': stats.legsPlayed,
    'legsStarted': stats.legsStarted,
    'legsWonAsStarter': stats.legsWonAsStarter,
    'legsWonWithoutStarter': stats.legsWonWithoutStarter,
    'scores0To40': stats.scores0To40,
    'scores41To59': stats.scores41To59,
    'scores60Plus': stats.scores60Plus,
    'scores100Plus': stats.scores100Plus,
    'scores140Plus': stats.scores140Plus,
    'scores171Plus': stats.scores171Plus,
    'scores180': stats.scores180,
    'checkoutAttempts': stats.checkoutAttempts,
    'successfulCheckouts': stats.successfulCheckouts,
    'checkoutAttempts1Dart': stats.checkoutAttempts1Dart,
    'checkoutAttempts2Dart': stats.checkoutAttempts2Dart,
    'checkoutAttempts3Dart': stats.checkoutAttempts3Dart,
    'successfulCheckouts1Dart': stats.successfulCheckouts1Dart,
    'successfulCheckouts2Dart': stats.successfulCheckouts2Dart,
    'successfulCheckouts3Dart': stats.successfulCheckouts3Dart,
    'thirdDartCheckoutAttempts': stats.thirdDartCheckoutAttempts,
    'thirdDartCheckouts': stats.thirdDartCheckouts,
    'bullCheckoutAttempts': stats.bullCheckoutAttempts,
    'bullCheckouts': stats.bullCheckouts,
    'functionalDoubleAttempts': stats.functionalDoubleAttempts,
    'functionalDoubleSuccesses': stats.functionalDoubleSuccesses,
    'firstNinePoints': stats.firstNinePoints,
    'firstNineDarts': stats.firstNineDarts,
    'highestFinish': stats.highestFinish,
    'bestLegDarts': stats.bestLegDarts,
    'totalFinishValue': stats.totalFinishValue,
    'withThrowPoints': stats.withThrowPoints,
    'withThrowDarts': stats.withThrowDarts,
    'againstThrowPoints': stats.againstThrowPoints,
    'againstThrowDarts': stats.againstThrowDarts,
    'decidingLegPoints': stats.decidingLegPoints,
    'decidingLegDarts': stats.decidingLegDarts,
    'decidingLegsPlayed': stats.decidingLegsPlayed,
    'decidingLegsWon': stats.decidingLegsWon,
    'won9Darters': stats.won9Darters,
    'won12Darters': stats.won12Darters,
    'won15Darters': stats.won15Darters,
    'won18Darters': stats.won18Darters,
  };
}

Map<String, Object?> _serializeThrow(DartThrowResult entry) {
  return <String, Object?>{
    'label': entry.label,
    'baseValue': entry.baseValue,
    'scoredPoints': entry.scoredPoints,
    'isDouble': entry.isDouble,
    'isTriple': entry.isTriple,
    'isBull': entry.isBull,
    'isMiss': entry.isMiss,
  };
}

Map<String, Object?> _serializeRouteScoreBreakdown(
  CheckoutRouteScoreBreakdown breakdown,
) {
  return <String, Object?>{
    'dartPathScore': breakdown.dartPathScore,
    'comfort': breakdown.comfort,
    'robustness': breakdown.robustness,
    'doubleQuality': breakdown.doubleQuality,
    'narrowFieldPenalty': breakdown.narrowFieldPenalty,
    'bullPenalty': breakdown.bullPenalty,
    'segmentFlow': breakdown.segmentFlow,
    'dartPathDetails': breakdown.dartPathDetails,
    'comfortDetails': breakdown.comfortDetails,
    'robustnessDetails': breakdown.robustnessDetails,
    'doubleQualityDetails': breakdown.doubleQualityDetails,
    'narrowFieldDetails': breakdown.narrowFieldDetails,
    'bullPenaltyDetails': breakdown.bullPenaltyDetails,
    'segmentFlowDetails': breakdown.segmentFlowDetails,
  };
}

Map<String, Object?> _serializeSetupScoreBreakdown(
  CheckoutSetupScoreBreakdown breakdown,
) {
  return <String, Object?>{
    'setupPathScore': breakdown.setupPathScore,
    'routeGuidance': breakdown.routeGuidance,
    'leaveQuality': breakdown.leaveQuality,
    'missPenalty': breakdown.missPenalty,
    'totalScore': breakdown.totalScore,
    'setupPathDetails': breakdown.setupPathDetails,
    'routeGuidanceDetails': breakdown.routeGuidanceDetails,
    'leaveQualityDetails': breakdown.leaveQualityDetails,
    'missPenaltyDetails': breakdown.missPenaltyDetails,
  };
}

Map<String, Object?> _serializeSetupLeaveOption(CheckoutSetupLeaveOption option) {
  return <String, Object?>{
    'setupRoute': option.setupRoute.map(_serializeThrow).toList(),
    'remainingScore': option.remainingScore,
    'finishRoute': option.finishRoute.map(_serializeThrow).toList(),
    'score': option.score,
    'breakdown': _serializeSetupScoreBreakdown(option.breakdown),
  };
}

CheckoutRequirement _checkoutRequirementFromName(String? value) {
  return CheckoutRequirement.values.firstWhere(
    (entry) => entry.name == value,
    orElse: () => CheckoutRequirement.doubleOut,
  );
}

CheckoutPlayStyle _checkoutPlayStyleFromName(String? value) {
  return CheckoutPlayStyle.values.firstWhere(
    (entry) => entry.name == value,
    orElse: () => CheckoutPlayStyle.balanced,
  );
}

CheckoutRouteScoreBreakdown _applyDoubleAdjustmentToBreakdownBg(
  CheckoutRouteScoreBreakdown breakdown,
  DartThrowResult? finalThrow,
  int adjustment,
) {
  if (adjustment == 0 || finalThrow == null) {
    return breakdown;
  }

  return CheckoutRouteScoreBreakdown(
    dartPathScore: breakdown.dartPathScore,
    comfort: breakdown.comfort,
    robustness: breakdown.robustness,
    doubleQuality: breakdown.doubleQuality + adjustment,
    narrowFieldPenalty: breakdown.narrowFieldPenalty,
    bullPenalty: breakdown.bullPenalty,
    segmentFlow: breakdown.segmentFlow,
    dartPathDetails: breakdown.dartPathDetails,
    comfortDetails: breakdown.comfortDetails,
    robustnessDetails: breakdown.robustnessDetails,
    doubleQualityDetails: <String>[
      ...breakdown.doubleQualityDetails,
      if (adjustment > 0)
        'Persoenliche Doppel-Praeferenz fuer ${finalThrow.label}: +$adjustment',
      if (adjustment < 0)
        'Persoenlicher Malus fuer ${finalThrow.label}: $adjustment',
    ],
    narrowFieldDetails: breakdown.narrowFieldDetails,
    bullPenaltyDetails: breakdown.bullPenaltyDetails,
    segmentFlowDetails: breakdown.segmentFlowDetails,
  );
}

CheckoutSetupScoreBreakdown _applyDoubleAdjustmentToSetupBreakdownBg(
  CheckoutSetupScoreBreakdown breakdown,
  DartThrowResult? finalThrow,
  int adjustment,
) {
  if (adjustment == 0 || finalThrow == null) {
    return breakdown;
  }

  return CheckoutSetupScoreBreakdown(
    setupPathScore: breakdown.setupPathScore,
    routeGuidance: breakdown.routeGuidance,
    leaveQuality: breakdown.leaveQuality + adjustment,
    missPenalty: breakdown.missPenalty,
    totalScore: breakdown.totalScore + adjustment,
    setupPathDetails: breakdown.setupPathDetails,
    routeGuidanceDetails: breakdown.routeGuidanceDetails,
    leaveQualityDetails: <String>[
      ...breakdown.leaveQualityDetails,
      if (adjustment > 0)
        'Persoenliche Doppel-Praeferenz fuer ${finalThrow.label}: +$adjustment',
      if (adjustment < 0)
        'Persoenlicher Malus fuer ${finalThrow.label}: $adjustment',
    ],
    missPenaltyDetails: breakdown.missPenaltyDetails,
  );
}

List<Map<String, Object?>> _buildMissScenariosBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
  int outerBullPreference = 50,
  int bullPreference = 50,
}) {
  const rules = X01Rules();
  final scenarios = <Map<String, Object?>>[];
  var remaining = startScore;

  for (var index = 0; index < route.length; index += 1) {
    final dartThrow = route[index];
    final dartsAfterThis = totalDarts - index - 1;

    if (dartThrow.isTriple) {
      final singleRemaining = remaining - dartThrow.baseValue;
      final singleText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: singleRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (singleText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': 'Single statt ${dartThrow.label}',
          'outcome': singleText['text'],
          'state': singleText['state'],
        });
      }

      for (final neighbor in rules.adjacentSegments(dartThrow.baseValue)) {
        final neighborRemaining = remaining - neighbor;
        final neighborText = _describeMissContinuationBg(
          planner: planner,
          remainingScore: neighborRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (neighborText != null) {
          scenarios.add(<String, Object?>{
            'dartIndex': index + 1,
            'targetLabel': dartThrow.label,
            'label': 'Nachbar $neighbor statt ${dartThrow.label}',
            'outcome': neighborText['text'],
            'state': neighborText['state'],
          });
        }
      }
    } else if (dartThrow.isDouble && !dartThrow.isBull) {
      final singleRemaining = remaining - dartThrow.baseValue;
      final singleText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: singleRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (singleText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': 'Single statt ${dartThrow.label}',
          'outcome': singleText['text'],
          'state': singleText['state'],
        });
      }
    } else if (dartThrow.isBull) {
      final outerBullRemaining = remaining - 25;
      final outerBullText = _describeMissContinuationBg(
        planner: planner,
        remainingScore: outerBullRemaining,
        dartsLeft: dartsAfterThis,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        outerBullPreference: outerBullPreference,
        bullPreference: bullPreference,
      );
      if (outerBullText != null) {
        scenarios.add(<String, Object?>{
          'dartIndex': index + 1,
          'targetLabel': dartThrow.label,
          'label': '25 statt BULL',
          'outcome': outerBullText['text'],
          'state': outerBullText['state'],
        });
      }
    }

    remaining -= dartThrow.scoredPoints;
  }

  return scenarios.take(4).toList(growable: false);
}

Map<String, Object?>? _describeMissContinuationBg({
  required CheckoutPlanner planner,
  required int remainingScore,
  required int dartsLeft,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
  int outerBullPreference = 50,
  int bullPreference = 50,
}) {
  if (remainingScore <= 1 || dartsLeft <= 0) {
    return null;
  }

  final continuation = planner.bestContinuationPlan(
    score: remainingScore,
    dartsLeft: dartsLeft,
    checkoutRequirement: checkoutRequirement,
    playStyle: playStyle,
    outerBullPreference: outerBullPreference,
    bullPreference: bullPreference,
  );
  if (continuation == null || continuation.throws.isEmpty) {
    return <String, Object?>{
      'text': '$remainingScore Rest, kein guter Anschluss',
      'state': 'bad',
    };
  }

  final labels = continuation.throws.take(dartsLeft).map((e) => e.label).join(' | ');
  if (continuation.immediateFinish) {
    return <String, Object?>{
      'text': '$remainingScore Rest, Finish ueber $labels',
      'state': 'finish',
    };
  }
  return <String, Object?>{
    'text': '$remainingScore Rest, weiter mit $labels',
    'state': 'setup',
  };
}

List<String> _buildFallbackHintsBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
}) {
  final hints = <String>[];
  var remaining = startScore;
  for (var index = 0; index < route.length; index += 1) {
    final dartThrow = route[index];
    final dartsAfterThis = totalDarts - index - 1;
    final isSingleMissScenario =
        dartThrow.isTriple || (dartThrow.isDouble && !dartThrow.isBull);
    if (isSingleMissScenario) {
      final singleFallbackRemaining = remaining - dartThrow.baseValue;
      if (singleFallbackRemaining > 1 && dartsAfterThis > 0) {
        final fallbackPlan = planner.bestContinuationPlan(
          score: singleFallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
        if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
          final labels = fallbackPlan.throws.take(dartsAfterThis).map((e) => e.label).join(' | ');
          final prefix = 'Bei Single statt ${dartThrow.label}: ';
          final suffix = fallbackPlan.immediateFinish
              ? labels
              : '$labels fuer den naechsten Besuch';
          hints.add('$prefix$suffix');
        }
      }
    }
    remaining -= dartThrow.scoredPoints;
  }
  return hints.take(2).toList(growable: false);
}

String? _buildRationaleHintBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required int startScore,
  required int totalDarts,
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
}) {
  if (route.length < 2 || totalDarts < 2) {
    return null;
  }

  final first = route.first;
  final firstRemaining = startScore - first.scoredPoints;
  if (firstRemaining <= 1) {
    return null;
  }

  final second = route[1];
  final afterSecond = firstRemaining - second.scoredPoints;
  final singleOnSecondRemaining = firstRemaining - second.baseValue;
  final targetFinish = afterSecond == 0 ? second.label : _formatRemainingBg(afterSecond);

  String? fallbackText;
  if (second.isTriple && totalDarts >= 3 && singleOnSecondRemaining > 1) {
    final fallbackPlan = planner.bestContinuationPlan(
      score: singleOnSecondRemaining,
      dartsLeft: totalDarts - 2,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
      final labels = fallbackPlan.throws.take(totalDarts - 2).map((e) => e.label).join(' | ');
      fallbackText = fallbackPlan.immediateFinish
          ? labels
          : '$labels fuer den naechsten Besuch';
    }
  }

  if (first.isTriple && totalDarts >= 3) {
    final singleOnFirstRemaining = startScore - first.baseValue;
    if (singleOnFirstRemaining > 1) {
      final firstFallbackPlan = planner.bestContinuationPlan(
        score: singleOnFirstRemaining,
        dartsLeft: totalDarts - 1,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      );
      if (firstFallbackPlan != null && firstFallbackPlan.throws.isNotEmpty) {
        final firstFallbackLabels = firstFallbackPlan.throws
            .take(totalDarts - 1)
            .map((e) => e.label)
            .join(' | ');
        final firstFallbackText = firstFallbackPlan.immediateFinish
            ? firstFallbackLabels
            : '$firstFallbackLabels fuer den naechsten Besuch';
        final firstFallbackLead = firstFallbackPlan.immediateFinish
            ? 'trotzdem ein guter Weg'
            : 'ein brauchbarer Weg fuer den naechsten Besuch';
        if (fallbackText != null) {
          return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
              'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
              '$firstFallbackLead. '
              'Darum geht der 2. Dart auf ${second.label}, weil auch ein Single statt ${second.label} '
              'noch $fallbackText offenlaesst.';
        }
        return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
            'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
            '$firstFallbackLead.';
      }
    }
  }

  if (fallbackText != null) {
    return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
        'Darum geht der 2. Dart auf ${second.label}, weil dann $targetFinish bleibt '
        'und bei Single statt ${second.label} trotzdem $fallbackText offen ist.';
  }

  return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
      'Der 2. Dart geht auf ${second.label}, damit anschliessend $targetFinish bleibt.';
}

String _formatRemainingBg(int remaining) {
  if (remaining == 50) {
    return 'Bull';
  }
  if (remaining > 1 && remaining <= 40 && remaining.isEven) {
    return 'D${remaining ~/ 2}';
  }
  return '$remaining Rest';
}

List<String> _buildBadgesBg({
  required CheckoutPlanner planner,
  required List<DartThrowResult> route,
  required List<Map<String, Object?>> missScenarios,
  required List<String> fallbackHints,
}) {
  final badges = <String>[];
  final narrowFields = route.where(planner.isNarrowField).length;

  if (route.length == 2) {
    badges.add('2-Dart-Weg');
  }
  if (route.isNotEmpty && !route.last.isBull) {
    badges.add(route.last.isFinishDouble ? 'starkes Schlussdoppel' : 'klares Schlussfeld');
  }
  if (narrowFields <= 1) {
    badges.add('wenig schmale Felder');
  }
  if (route.every((entry) => !entry.isBull && entry.label != '25')) {
    badges.add('Bull vermieden');
  }
  if (_hasSameSegmentFlowBg(route)) {
    badges.add('ruhiger Segmentfluss');
  }
  if (fallbackHints.isNotEmpty) {
    badges.add('Miss-Fallback');
  }
  if (missScenarios.any((scenario) => scenario['state'] == 'finish')) {
    badges.add('robuster Miss-Fallback');
  }
  return badges.take(4).toList(growable: false);
}

bool _hasSameSegmentFlowBg(List<DartThrowResult> route) {
  for (var index = 1; index < route.length; index += 1) {
    if (route[index - 1].baseValue == route[index].baseValue) {
      return true;
    }
  }
  return false;
}

int _countTotalMatches(TournamentBracket bracket) {
  var count = 0;
  for (final round in bracket.rounds) {
    count += round.matches.length;
  }
  return count;
}

int _countCompletedMatches(TournamentBracket bracket) {
  var count = 0;
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.completed) {
        count += 1;
      }
    }
  }
  return count;
}

bool _shouldStopBeforeNextRoundBg(TournamentBracket bracket) {
  final roundNumber = _nextPendingRoundNumberBg(bracket);
  if (roundNumber == null) {
    return false;
  }
  return _hasPendingHumanMatchInRoundBg(bracket, roundNumber);
}

int? _nextPendingRoundNumberBg(TournamentBracket bracket) {
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.pending && match.isReady) {
        return round.roundNumber;
      }
    }
  }
  return null;
}

bool _hasPendingHumanMatchInRoundBg(TournamentBracket bracket, int roundNumber) {
  for (final round in bracket.rounds) {
    if (round.roundNumber != roundNumber) {
      continue;
    }
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.pending &&
          match.isReady &&
          match.isHumanMatch) {
        return true;
      }
    }
    return false;
  }
  return false;
}

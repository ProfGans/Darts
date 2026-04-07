import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/background/simulation_service.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/bot/bot_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/checkout_planner.dart';
import '../../domain/x01/x01_match_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../../domain/x01/x01_models.dart';
import 'game_mode_models.dart';
import 'match_end_screen.dart';
import 'match_result_models.dart';
import 'match_session_config.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.session,
    super.key,
  });

  final MatchSessionConfig session;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _ParticipantRuntime {
  _ParticipantRuntime({
    required this.config,
    required this.score,
  });

  final MatchParticipantConfig config;
  int score;
  bool hasOpenedLeg = true;
  int legs = 0;
  int sets = 0;
  int totalLegsWon = 0;
  int pointsScored = 0;
  int dartsThrown = 0;
  int visits = 0;
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
  int won9Darters = 0;
  int won12Darters = 0;
  int won15Darters = 0;
  int won18Darters = 0;

  double get average => dartsThrown <= 0 ? 0 : (pointsScored / dartsThrown) * 3;
  double get firstNineAverage =>
      firstNineDarts <= 0 ? 0 : (firstNinePoints / firstNineDarts) * 3;
  double get doubleQuote =>
      checkoutAttempts <= 0 ? 0 : (successfulCheckouts / checkoutAttempts) * 100;

  _ParticipantRuntimeSnapshot snapshot() {
    return _ParticipantRuntimeSnapshot(
      score: score,
      hasOpenedLeg: hasOpenedLeg,
      legs: legs,
      sets: sets,
      totalLegsWon: totalLegsWon,
      pointsScored: pointsScored,
      dartsThrown: dartsThrown,
      visits: visits,
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
      won9Darters: won9Darters,
      won12Darters: won12Darters,
      won15Darters: won15Darters,
      won18Darters: won18Darters,
    );
  }

  void restore(_ParticipantRuntimeSnapshot snapshot) {
    score = snapshot.score;
    hasOpenedLeg = snapshot.hasOpenedLeg;
    legs = snapshot.legs;
    sets = snapshot.sets;
    totalLegsWon = snapshot.totalLegsWon;
    pointsScored = snapshot.pointsScored;
    dartsThrown = snapshot.dartsThrown;
    visits = snapshot.visits;
    legsPlayed = snapshot.legsPlayed;
    legsStarted = snapshot.legsStarted;
    legsWonAsStarter = snapshot.legsWonAsStarter;
    legsWonWithoutStarter = snapshot.legsWonWithoutStarter;
    scores0To40 = snapshot.scores0To40;
    scores41To59 = snapshot.scores41To59;
    scores60Plus = snapshot.scores60Plus;
    scores100Plus = snapshot.scores100Plus;
    scores140Plus = snapshot.scores140Plus;
    scores171Plus = snapshot.scores171Plus;
    scores180 = snapshot.scores180;
    checkoutAttempts = snapshot.checkoutAttempts;
    successfulCheckouts = snapshot.successfulCheckouts;
    checkoutAttempts1Dart = snapshot.checkoutAttempts1Dart;
    checkoutAttempts2Dart = snapshot.checkoutAttempts2Dart;
    checkoutAttempts3Dart = snapshot.checkoutAttempts3Dart;
    successfulCheckouts1Dart = snapshot.successfulCheckouts1Dart;
    successfulCheckouts2Dart = snapshot.successfulCheckouts2Dart;
    successfulCheckouts3Dart = snapshot.successfulCheckouts3Dart;
    thirdDartCheckoutAttempts = snapshot.thirdDartCheckoutAttempts;
    thirdDartCheckouts = snapshot.thirdDartCheckouts;
    bullCheckoutAttempts = snapshot.bullCheckoutAttempts;
    bullCheckouts = snapshot.bullCheckouts;
    functionalDoubleAttempts = snapshot.functionalDoubleAttempts;
    functionalDoubleSuccesses = snapshot.functionalDoubleSuccesses;
    firstNinePoints = snapshot.firstNinePoints;
    firstNineDarts = snapshot.firstNineDarts;
    highestFinish = snapshot.highestFinish;
    bestLegDarts = snapshot.bestLegDarts;
    totalFinishValue = snapshot.totalFinishValue;
    withThrowPoints = snapshot.withThrowPoints;
    withThrowDarts = snapshot.withThrowDarts;
    againstThrowPoints = snapshot.againstThrowPoints;
    againstThrowDarts = snapshot.againstThrowDarts;
    decidingLegPoints = snapshot.decidingLegPoints;
    decidingLegDarts = snapshot.decidingLegDarts;
    decidingLegsPlayed = snapshot.decidingLegsPlayed;
    decidingLegsWon = snapshot.decidingLegsWon;
    won9Darters = snapshot.won9Darters;
    won12Darters = snapshot.won12Darters;
    won15Darters = snapshot.won15Darters;
    won18Darters = snapshot.won18Darters;
  }
}

class _ParticipantRuntimeSnapshot {
  const _ParticipantRuntimeSnapshot({
    required this.score,
    required this.hasOpenedLeg,
    required this.legs,
    required this.sets,
    required this.totalLegsWon,
    required this.pointsScored,
    required this.dartsThrown,
    required this.visits,
    required this.legsPlayed,
    required this.legsStarted,
    required this.legsWonAsStarter,
    required this.legsWonWithoutStarter,
    required this.scores0To40,
    required this.scores41To59,
    required this.scores60Plus,
    required this.scores100Plus,
    required this.scores140Plus,
    required this.scores171Plus,
    required this.scores180,
    required this.checkoutAttempts,
    required this.successfulCheckouts,
    required this.checkoutAttempts1Dart,
    required this.checkoutAttempts2Dart,
    required this.checkoutAttempts3Dart,
    required this.successfulCheckouts1Dart,
    required this.successfulCheckouts2Dart,
    required this.successfulCheckouts3Dart,
    required this.thirdDartCheckoutAttempts,
    required this.thirdDartCheckouts,
    required this.bullCheckoutAttempts,
    required this.bullCheckouts,
    required this.functionalDoubleAttempts,
    required this.functionalDoubleSuccesses,
    required this.firstNinePoints,
    required this.firstNineDarts,
    required this.highestFinish,
    required this.bestLegDarts,
    required this.totalFinishValue,
    required this.withThrowPoints,
    required this.withThrowDarts,
    required this.againstThrowPoints,
    required this.againstThrowDarts,
    required this.decidingLegPoints,
    required this.decidingLegDarts,
    required this.decidingLegsPlayed,
    required this.decidingLegsWon,
    required this.won9Darters,
    required this.won12Darters,
    required this.won15Darters,
    required this.won18Darters,
  });

  final int score;
  final bool hasOpenedLeg;
  final int legs;
  final int sets;
  final int totalLegsWon;
  final int pointsScored;
  final int dartsThrown;
  final int visits;
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
  final int won9Darters;
  final int won12Darters;
  final int won15Darters;
  final int won18Darters;
}

class _MatchUndoSnapshot {
  const _MatchUndoSnapshot({
    required this.participants,
    required this.currentTurnIndex,
    required this.starterIndex,
    required this.matchFinished,
    required this.showScoreStats,
    required this.status,
    required this.currentInput,
    required this.visitLog,
    required this.completedLegs,
    required this.currentLegVisits,
    required this.currentLegDarts,
    required this.currentLegScored,
    required this.turnCounter,
    required this.isBullOffActive,
    required this.bullOffRound,
    required this.bullOffTurnIndex,
    required this.bullOffOrder,
    required this.bullOffResults,
  });

  final List<_ParticipantRuntimeSnapshot> participants;
  final int currentTurnIndex;
  final int starterIndex;
  final bool matchFinished;
  final bool showScoreStats;
  final String status;
  final String currentInput;
  final List<String> visitLog;
  final List<MatchLegEntry> completedLegs;
  final List<MatchVisitEntry> currentLegVisits;
  final Map<String, int> currentLegDarts;
  final Map<String, int> currentLegScored;
  final int turnCounter;
  final bool isBullOffActive;
  final int bullOffRound;
  final int bullOffTurnIndex;
  final List<String> bullOffOrder;
  final Map<String, _BullOffResult> bullOffResults;
}

class _PlayerStatItem {
  const _PlayerStatItem({
    required this.label,
    required this.value,
    required this.description,
  });

  final String label;
  final String value;
  final String description;
}

enum _ManualFinishType {
  single('Single'),
  doubleValue('Double'),
  triple('Triple'),
  bull('Bull');

  const _ManualFinishType(this.label);

  final String label;
}

class _ManualCheckoutDetails {
  const _ManualCheckoutDetails({
    required this.dartsUsed,
    required this.doubleAttempts,
    required this.finishType,
  });

  final int dartsUsed;
  final int doubleAttempts;
  final _ManualFinishType finishType;
}

class _ManualDoubleInDetails {
  const _ManualDoubleInDetails({
    required this.dartsUsed,
  });

  final int dartsUsed;
}

enum _BullOffResult {
  bull(2, 'Bull'),
  singleBull(1, 'Single Bull'),
  outside(0, 'Outside');

  const _BullOffResult(this.rank, this.label);

  final int rank;
  final String label;
}

class _MatchScreenState extends State<MatchScreen> {
  static const CheckoutPlayStyle _suggestionPlayStyle =
      CheckoutPlayStyle.balanced;
  static const int _suggestionSetupPreference = 85;
  static const int _suggestionOuterBullPreference = 50;
  static const int _suggestionBullPreference = 50;

  late final BotEngine _botEngine;
  late final X01MatchEngine _matchEngine;
  late final X01MatchSimulator _matchSimulator;
  late final CheckoutPlanner _checkoutPlanner;
  late List<_ParticipantRuntime> _participants;

  int _currentTurnIndex = 0;
  int _starterIndex = 0;
  bool _matchFinished = false;
  bool _showScoreStats = false;
  bool _showVisitLogOverlay = false;
  final Set<String> _expandedParticipantStats = <String>{};
  final Map<String, String?> _routeSuggestionCache = <String, String?>{};
  String _status = '';
  String _currentInput = '';
  final List<String> _visitLog = <String>[];
  final List<MatchLegEntry> _completedLegs = <MatchLegEntry>[];
  List<MatchVisitEntry> _currentLegVisits = <MatchVisitEntry>[];
  final List<_MatchUndoSnapshot> _undoStack = <_MatchUndoSnapshot>[];
  final Map<String, int> _currentLegDarts = <String, int>{};
  final Map<String, int> _currentLegScored = <String, int>{};
  int _turnCounter = 0;
  bool _isBullOffActive = false;
  int _bullOffRound = 1;
  int _bullOffTurnIndex = 0;
  List<String> _bullOffOrder = <String>[];
  Map<String, _BullOffResult> _bullOffResults = <String, _BullOffResult>{};

  @override
  void initState() {
    super.initState();
    _botEngine = BotEngine();
    _matchEngine = X01MatchEngine();
    _matchSimulator = X01MatchSimulator(
      matchEngine: _matchEngine,
      botEngine: _botEngine,
    );
    SimulationService.instance.applyToX01MatchSimulator(_matchSimulator);
    _checkoutPlanner = CheckoutPlanner();
    _participants = widget.session.participants
        .map(
          (participant) => _ParticipantRuntime(
            config: participant,
            score: participant.startingScore ?? widget.session.matchConfig.startScore,
          ),
        )
        .toList();
    if (widget.session.useBullOff && _participants.length > 1) {
      _startBullOff();
      return;
    }

    final configuredStarterId = widget.session.startingParticipantId;
    if (configuredStarterId != null) {
      final configuredIndex = _participants.indexWhere(
        (participant) => participant.config.id == configuredStarterId,
      );
      if (configuredIndex >= 0) {
        _starterIndex = configuredIndex;
      }
    }
    _resetLeg(initial: true);
  }

  bool get _isHumanTurn => !_matchFinished && _currentParticipant.config.isHuman;

  _ParticipantRuntime get _currentParticipant => _participants[_currentTurnIndex];

  _ParticipantRuntime? get _currentBullOffParticipant {
    if (!_isBullOffActive || _bullOffOrder.isEmpty) {
      return null;
    }

    final currentId = _bullOffOrder[_bullOffTurnIndex];
    final index = _participants.indexWhere(
      (participant) => participant.config.id == currentId,
    );
    if (index < 0) {
      return null;
    }
    return _participants[index];
  }

  void _resetLeg({bool initial = false}) {
    for (final participant in _participants) {
      participant.score =
          participant.config.startingScore ?? widget.session.matchConfig.startScore;
      participant.hasOpenedLeg =
          widget.session.matchConfig.startRequirement == StartRequirement.straightIn;
    }
    _participants[_starterIndex].legsStarted += 1;
    _currentTurnIndex = _starterIndex;
    _currentInput = '';
    _currentLegVisits = <MatchVisitEntry>[];
    _currentLegDarts
      ..clear()
      ..addEntries(_participants.map((entry) => MapEntry(entry.config.id, 0)));
    _currentLegScored
      ..clear()
      ..addEntries(_participants.map((entry) => MapEntry(entry.config.id, 0)));
    _turnCounter = 0;
    final starterName = _participants[_starterIndex].config.name;
    _status = initial
        ? '$starterName beginnt.'
        : '$starterName beginnt das naechste Leg.';
    _visitLog.add('Neues Leg gestartet.');

    if (!_currentParticipant.config.isHuman) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runBotTurn();
      });
    }
  }

  void _advanceTurn() {
    _currentTurnIndex = (_currentTurnIndex + 1) % _participants.length;
  }

  void _startBullOff({List<String>? contenders, bool reversed = false}) {
    var order = List<String>.from(
      contenders ?? _participants.map((participant) => participant.config.id),
    );
    if (reversed) {
      order = order.reversed.toList();
    }

    setState(() {
      _isBullOffActive = true;
      _bullOffOrder = order;
      _bullOffResults = <String, _BullOffResult>{};
      _bullOffTurnIndex = 0;
      _status = _bullOffRound == 1
          ? 'Ausbullen entscheidet den Startspieler.'
          : 'Gleichstand. Wiederholung in umgekehrter Reihenfolge.';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _continueBullOffIfNeeded();
    });
  }

  void _continueBullOffIfNeeded() {
    final participant = _currentBullOffParticipant;
    if (!mounted || !_isBullOffActive || participant == null) {
      return;
    }

    if (!participant.config.isHuman) {
      _runBotBullOff(participant);
    }
  }

  Future<void> _runBotBullOff(_ParticipantRuntime participant) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_isBullOffActive) {
      return;
    }

    _submitBullOffResult(
      participantId: participant.config.id,
      result: _simulateBotBullOff(participant),
    );
  }

  _BullOffResult _simulateBotBullOff(_ParticipantRuntime participant) {
    final profile = participant.config.botProfile;
    if (profile == null) {
      return _BullOffResult.outside;
    }

    final simulation = _botEngine.simulateTargetThrow(
      target: _matchEngine.rules.createBull(),
      score: 50,
      profile: profile,
    );

    if (simulation.hit.isBull) {
      return _BullOffResult.bull;
    }
    if (simulation.hit.label == '25') {
      return _BullOffResult.singleBull;
    }
    return _BullOffResult.outside;
  }

  void _submitBullOffResult({
    required String participantId,
    required _BullOffResult result,
  }) {
    if (!_isBullOffActive) {
      return;
    }

    setState(() {
      _bullOffResults[participantId] = result;
      final participant = _participants.firstWhere(
        (entry) => entry.config.id == participantId,
      );
      _visitLog.add('${participant.config.name} Ausbullen: ${result.label}');
    });

    if (_bullOffResults.length < _bullOffOrder.length) {
      setState(() {
        _bullOffTurnIndex += 1;
      });
      _continueBullOffIfNeeded();
      return;
    }

    final bestRank = _bullOffResults.values
        .map((entry) => entry.rank)
        .reduce((best, next) => next > best ? next : best);
    final tiedIds = _bullOffOrder
        .where((participantId) => _bullOffResults[participantId]!.rank == bestRank)
        .toList();

    if (tiedIds.length == 1) {
      final winnerIndex = _participants.indexWhere(
        (participant) => participant.config.id == tiedIds.first,
      );
      setState(() {
        _isBullOffActive = false;
        _starterIndex = winnerIndex < 0 ? 0 : winnerIndex;
      });
      _resetLeg(initial: true);
      return;
    }

    _bullOffRound += 1;
    _startBullOff(contenders: tiedIds, reversed: true);
  }

  Future<void> _runBotTurn() async {
    if (!mounted || _matchFinished || _currentParticipant.config.isHuman) {
      return;
    }

    final participant = _currentParticipant;
    setState(() {
      _status = '${participant.config.name} ist am Zug...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted ||
        _matchFinished ||
        _currentParticipant.config.isHuman ||
        _currentParticipant.config.id != participant.config.id) {
      return;
    }

    final startScore = participant.score;
    final simulatedVisit = _matchSimulator.simulateBotVisit(
      startScore: startScore,
      hasOpenedLeg: participant.hasOpenedLeg,
      startRequirement: widget.session.matchConfig.startRequirement,
      player: SimulatedPlayer(
        name: participant.config.name,
        profile: participant.config.botProfile!,
      ),
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
      detailed: true,
    );
    final throws = List<DartThrowResult>.from(simulatedVisit.throws);
    final visitResult = _matchEngine.evaluateVisit(
      currentScore: startScore,
      throws: throws,
      startRequirement: widget.session.matchConfig.startRequirement,
      hasOpenedLeg: participant.hasOpenedLeg,
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
    );
    _applyVisit(
      participant: participant,
      visitResult: visitResult,
      throws: throws,
      startScore: startScore,
      manualDescription: throws.map((entry) => entry.label).join(' - '),
    );
  }

  Future<void> _submitHumanScore() async {
    await _submitHumanScoreValue();
  }

  Future<void> _submitHumanScoreValue({int? valueOverride}) async {
    if (!_isHumanTurn || _matchFinished) {
      return;
    }

    final value = valueOverride ??
        int.tryParse(_currentInput.isEmpty ? '0' : _currentInput);
    if (value == null) {
      return;
    }

    if (value < 0 || value > 180) {
      _showInfo('Ein Besuch darf zwischen 0 und 180 liegen.');
      return;
    }

    final participant = _currentParticipant;
    final requiresDoubleIn =
        widget.session.matchConfig.startRequirement == StartRequirement.doubleIn &&
            !participant.hasOpenedLeg;
    if (!_matchEngine.rules.isAchievableVisitScore(
      value,
      requireDoubleInStart: requiresDoubleIn,
    )) {
      _showInfo(
        requiresDoubleIn
            ? 'Dieser Gesamtwert ist als Double-in-Aufnahme in bis zu 3 Darts nicht moeglich.'
            : 'Dieser Gesamtwert ist als X01-Aufnahme in bis zu 3 Darts nicht moeglich.',
      );
      return;
    }
    if (value == participant.score && value > 1) {
      final checkoutDetails = await _showManualCheckoutDialog(participant.score);
      if (!mounted || checkoutDetails == null) {
        return;
      }

      final finishThrow = _sampleThrowForFinishType(checkoutDetails.finishType);
      if (!_isManualCheckoutPossible(
        score: participant.score,
        dartsUsed: checkoutDetails.dartsUsed,
        finishType: checkoutDetails.finishType,
        requireOpeningDouble: requiresDoubleIn,
      )) {
        _showInfo('Diese Checkout-Kombination ist fuer den Restscore nicht moeglich.');
        return;
      }

      final visitResult = VisitResult(
        throws: const <DartThrowResult>[],
        scoredPoints: value,
        didBust: false,
        remainingScore: 0,
        openedLeg: true,
      );
      _applyVisit(
        participant: participant,
        visitResult: visitResult,
        throws: const <DartThrowResult>[],
        startScore: participant.score,
        manualDescription:
            '$value Checkout in ${checkoutDetails.dartsUsed} Dart${checkoutDetails.dartsUsed == 1 ? '' : 's'}',
        manualDartsUsed: checkoutDetails.dartsUsed,
        manualDoubleAttempts: checkoutDetails.doubleAttempts,
        finishingThrow: finishThrow,
      );
      return;
    }

    if (requiresDoubleIn && value > 0) {
      final doubleInDetails = await _showManualDoubleInDialog();
      if (!mounted || doubleInDetails == null) {
        return;
      }

      final remaining = participant.score - value;
      final didBust = remaining < 0 ||
          (remaining == 1 &&
              widget.session.matchConfig.checkoutRequirement !=
                  CheckoutRequirement.singleOut);
      final visitResult = VisitResult(
        throws: const <DartThrowResult>[],
        scoredPoints: didBust ? 0 : value,
        didBust: didBust,
        remainingScore: didBust ? participant.score : remaining,
        openedLeg: !didBust,
      );
      int? doubleAttempts;
      if (!didBust && remaining > 1 && remaining < 50) {
        doubleAttempts = await _showManualDoubleAttemptDialog(remainingScore: remaining);
        if (!mounted) {
          return;
        }
      }
      _applyVisit(
        participant: participant,
        visitResult: visitResult,
        throws: const <DartThrowResult>[],
        startScore: participant.score,
        manualDescription: didBust
            ? '$value Punkte nach Double-in versucht'
            : '$value Punkte nach Double-in',
        manualDartsUsed: doubleInDetails.dartsUsed,
        manualDoubleAttempts: doubleAttempts,
      );
      return;
    }

    final remaining = participant.score - value;
    if (remaining < 0 ||
        (remaining == 1 &&
            widget.session.matchConfig.checkoutRequirement !=
                CheckoutRequirement.singleOut)) {
      final visitResult = VisitResult(
        throws: const <DartThrowResult>[],
        scoredPoints: 0,
        didBust: true,
        remainingScore: participant.score,
        openedLeg: participant.hasOpenedLeg,
      );
      _applyVisit(
        participant: participant,
        visitResult: visitResult,
        throws: const <DartThrowResult>[],
        startScore: participant.score,
        manualDescription: '$value Punkte eingegeben',
        manualDartsUsed: 3,
      );
      return;
    }

    final visitResult = VisitResult(
      throws: const <DartThrowResult>[],
      scoredPoints: value,
      didBust: false,
      remainingScore: remaining,
      openedLeg: participant.hasOpenedLeg,
    );
    int? doubleAttempts;
    if (remaining > 1 && remaining < 50) {
      doubleAttempts = await _showManualDoubleAttemptDialog(remainingScore: remaining);
      if (!mounted) {
        return;
      }
    }
    _applyVisit(
      participant: participant,
      visitResult: visitResult,
      throws: const <DartThrowResult>[],
      startScore: participant.score,
      manualDescription: '$value Punkte eingegeben',
      manualDartsUsed: 3,
      manualDoubleAttempts: doubleAttempts,
    );
  }

  void _applyVisit({
    required _ParticipantRuntime participant,
    required VisitResult visitResult,
    required List<DartThrowResult> throws,
    required int startScore,
    required String manualDescription,
    int? manualDartsUsed,
    int? manualDoubleAttempts,
    DartThrowResult? finishingThrow,
  }) {
    _pushUndoSnapshot();
    final dartsUsed = manualDartsUsed ?? throws.length;
    final visitEndedLeg = !visitResult.didBust && visitResult.remainingScore == 0;
    final finishingDart =
        visitEndedLeg ? (finishingThrow ?? (throws.isNotEmpty ? throws.last : null)) : null;
    final legDartsBefore = _currentLegDarts[participant.config.id] ?? 0;
    final firstNineDartsLeft = (9 - legDartsBefore).clamp(0, 9);
    final countedFirstNineDarts = firstNineDartsLeft > dartsUsed
        ? dartsUsed
        : firstNineDartsLeft;
    final countedFirstNinePoints = countedFirstNineDarts <= 0 || dartsUsed <= 0
        ? 0.0
        : (visitResult.scoredPoints * countedFirstNineDarts) / dartsUsed;
    final checkoutOpportunity = _checkoutOpportunityDarts(startScore);
    final hadCheckoutChance = checkoutOpportunity != null;
    final decidingLeg = _isCurrentLegDeciding();
    final currentLegStarterId = _participants[_starterIndex].config.id;
    final isWithThrow = participant.config.id == currentLegStarterId;
    final functionalDoubleOpportunity = _isFunctionalDoubleOpportunity(startScore);

    setState(() {
      participant.hasOpenedLeg = visitResult.openedLeg;
      if (countedFirstNineDarts > 0) {
        participant.firstNineDarts += countedFirstNineDarts;
        participant.firstNinePoints += countedFirstNinePoints;
      }
      participant.visits += 1;
      final effectiveDoubleAttempts =
          manualDoubleAttempts ?? (hadCheckoutChance ? 1 : 0);
      if (effectiveDoubleAttempts > 0) {
        participant.checkoutAttempts += effectiveDoubleAttempts;
      }
      if (hadCheckoutChance) {
        switch (checkoutOpportunity) {
          case 1:
            participant.checkoutAttempts1Dart += 1;
          case 2:
            participant.checkoutAttempts2Dart += 1;
          case 3:
            participant.checkoutAttempts3Dart += 1;
          default:
            break;
        }
      }
      if (manualDoubleAttempts != null) {
        participant.functionalDoubleAttempts += manualDoubleAttempts;
      } else if (functionalDoubleOpportunity) {
        participant.functionalDoubleAttempts += 1;
      }
      if (dartsUsed > 0) {
        if (isWithThrow) {
          participant.withThrowDarts += dartsUsed;
        } else {
          participant.againstThrowDarts += dartsUsed;
        }
        if (decidingLeg) {
          participant.decidingLegDarts += dartsUsed;
        }
      }

      if (visitResult.didBust) {
        participant.scores0To40 += 1;
        _visitLog.add('${participant.config.name}: Bust ($manualDescription)');
        _status = '${participant.config.name} bustet.';
        _currentLegVisits = <MatchVisitEntry>[
          ..._currentLegVisits,
          MatchVisitEntry(
            side: participant.config.id,
            turnNumber: ++_turnCounter,
            scoreBefore: startScore,
            scoredPoints: 0,
            remainingScore: startScore,
            dartsUsed: dartsUsed,
            bust: true,
            checkout: false,
            description: manualDescription,
            finishingThrowLabel: null,
            checkoutValue: null,
            bullCheckout: false,
          ),
        ];
        _currentInput = '';
        _advanceTurn();
      } else {
        participant.score = visitResult.remainingScore;
        participant.pointsScored += visitResult.scoredPoints;
        participant.dartsThrown += dartsUsed;
        if (visitResult.scoredPoints <= 40) {
          participant.scores0To40 += 1;
        } else if (visitResult.scoredPoints <= 59) {
          participant.scores41To59 += 1;
        }
        if (visitResult.scoredPoints >= 60) {
          participant.scores60Plus += 1;
        }
        if (visitResult.scoredPoints >= 171) {
          participant.scores171Plus += 1;
        }
        if (isWithThrow) {
          participant.withThrowPoints += visitResult.scoredPoints;
        } else {
          participant.againstThrowPoints += visitResult.scoredPoints;
        }
        if (decidingLeg) {
          participant.decidingLegPoints += visitResult.scoredPoints;
        }
        if (visitEndedLeg && hadCheckoutChance) {
          participant.successfulCheckouts += 1;
          participant.totalFinishValue += startScore;
          if (startScore > participant.highestFinish) {
            participant.highestFinish = startScore;
          }
          switch (dartsUsed) {
            case 1:
              participant.successfulCheckouts1Dart += 1;
            case 2:
              participant.successfulCheckouts2Dart += 1;
            case 3:
              participant.successfulCheckouts3Dart += 1;
              participant.thirdDartCheckouts += 1;
            default:
              break;
          }
        }
        if (hadCheckoutChance && checkoutOpportunity == 3) {
          participant.thirdDartCheckoutAttempts += 1;
        }
        if (functionalDoubleOpportunity && visitEndedLeg) {
          participant.functionalDoubleSuccesses += 1;
        }
        if ((startScore == 50 || startScore == 25) && hadCheckoutChance) {
          participant.bullCheckoutAttempts += 1;
        }
        if (visitEndedLeg && (finishingDart?.isBull ?? false)) {
          participant.bullCheckouts += 1;
        }
        _currentLegDarts[participant.config.id] =
            (_currentLegDarts[participant.config.id] ?? 0) + dartsUsed;
        _currentLegScored[participant.config.id] =
            (_currentLegScored[participant.config.id] ?? 0) +
                visitResult.scoredPoints;
        _recordMilestones(
          participant: participant,
          scoredPoints: visitResult.scoredPoints,
        );
        _currentLegVisits = <MatchVisitEntry>[
          ..._currentLegVisits,
          MatchVisitEntry(
            side: participant.config.id,
            turnNumber: ++_turnCounter,
            scoreBefore: startScore,
            scoredPoints: visitResult.scoredPoints,
            remainingScore: visitResult.remainingScore,
            dartsUsed: dartsUsed,
            bust: false,
            checkout: visitResult.remainingScore == 0,
            description: manualDescription,
            finishingThrowLabel: finishingDart?.label,
            checkoutValue: visitEndedLeg ? startScore : null,
            bullCheckout: finishingDart?.isBull ?? false,
          ),
        ];
        _visitLog.add(
          '${participant.config.name}: ${visitResult.scoredPoints} Punkte${manualDescription.isEmpty ? '' : ' ($manualDescription)'}',
        );
        _currentInput = '';

        if (visitResult.remainingScore == 0) {
          _finishLeg(winnerId: participant.config.id);
          return;
        }
        _advanceTurn();
      }

      if (!_matchFinished) {
        _status = '${_currentParticipant.config.name} ist am Zug.';
      }
    });

    if (!_matchFinished && !visitEndedLeg && !_currentParticipant.config.isHuman) {
      _runBotTurn();
    }
  }

  void _finishLeg({required String winnerId}) {
    final winner = _participants.firstWhere((entry) => entry.config.id == winnerId);
    final decidingLeg = _isCurrentLegDeciding();
    final legEntry = MatchLegEntry(
      legNumber: _completedLegs.length + 1,
      starterSide: _participants[_starterIndex].config.id,
      winnerSide: winnerId,
      decidingLeg: decidingLeg,
      participants: _participants
          .map(
            (participant) => MatchLegParticipantEntry(
              participantId: participant.config.id,
              participantName: participant.config.name,
              dartsThrown: _currentLegDarts[participant.config.id] ?? 0,
              average: _calculateAverage(
                _currentLegScored[participant.config.id] ?? 0,
                _currentLegDarts[participant.config.id] ?? 0,
              ),
              remainingScore: participant.score,
            ),
          )
          .toList(),
      visits: List<MatchVisitEntry>.from(_currentLegVisits),
    );

    setState(() {
      _completedLegs.add(legEntry);
      for (final participant in _participants) {
        participant.legsPlayed += 1;
        if (decidingLeg) {
          participant.decidingLegsPlayed += 1;
        }
      }
      winner.legs += 1;
      winner.totalLegsWon += 1;
      final winnerLegDarts = _currentLegDarts[winner.config.id] ?? 0;
      if (winner.bestLegDarts == 0 || winnerLegDarts < winner.bestLegDarts) {
        winner.bestLegDarts = winnerLegDarts;
      }
      if (winnerLegDarts == 9) {
        winner.won9Darters += 1;
      }
      if (winnerLegDarts > 0 && winnerLegDarts <= 12) {
        winner.won12Darters += 1;
      }
      if (winnerLegDarts > 0 && winnerLegDarts <= 15) {
        winner.won15Darters += 1;
      }
      if (winnerLegDarts > 0 && winnerLegDarts <= 18) {
        winner.won18Darters += 1;
      }
      if (_participants[_starterIndex].config.id == winnerId) {
        winner.legsWonAsStarter += 1;
      } else {
        winner.legsWonWithoutStarter += 1;
      }
      if (decidingLeg) {
        winner.decidingLegsWon += 1;
      }
      _visitLog.add('${winner.config.name} gewinnt das Leg.');
    });

    if (widget.session.matchConfig.mode == MatchMode.sets &&
        winner.legs >= widget.session.matchConfig.legsPerSet) {
      setState(() {
        winner.sets += 1;
        for (final participant in _participants) {
          participant.legs = 0;
        }
        _visitLog.add('${winner.config.name} gewinnt den Satz.');
      });
    }

    final hasWonMatch = widget.session.matchConfig.mode == MatchMode.sets
        ? winner.sets >= widget.session.matchConfig.setsToWin
        : winner.legs >= widget.session.matchConfig.legsToWin;

    if (hasWonMatch) {
      final result = MatchResultSummary(
        winnerParticipantId: winner.config.id,
        winnerName: winner.config.name,
        scoreText: widget.session.matchConfig.mode == MatchMode.sets
            ? _participants
                .map((entry) => '${entry.config.name}: ${entry.sets} Sets')
                .join(' | ')
            : _participants
                .map((entry) => '${entry.config.name}: ${entry.legs}')
                .join(' | '),
        participants: _participants
            .map(
              (entry) => MatchParticipantStats(
              participantId: entry.config.id,
              participantName: entry.config.name,
              isHuman: entry.config.isHuman,
              pointsScored: entry.pointsScored,
              dartsThrown: entry.dartsThrown,
              visits: entry.visits,
              legsWon: entry.totalLegsWon,
              legsPlayed: entry.legsPlayed,
              legsStarted: entry.legsStarted,
              legsWonAsStarter: entry.legsWonAsStarter,
              legsWonWithoutStarter: entry.legsWonWithoutStarter,
              scores0To40: entry.scores0To40,
              scores41To59: entry.scores41To59,
              scores60Plus: entry.scores60Plus,
              scores100Plus: entry.scores100Plus,
              scores140Plus: entry.scores140Plus,
              scores171Plus: entry.scores171Plus,
              scores180: entry.scores180,
              checkoutAttempts: entry.checkoutAttempts,
              successfulCheckouts: entry.successfulCheckouts,
              checkoutAttempts1Dart: entry.checkoutAttempts1Dart,
              checkoutAttempts2Dart: entry.checkoutAttempts2Dart,
              checkoutAttempts3Dart: entry.checkoutAttempts3Dart,
              successfulCheckouts1Dart: entry.successfulCheckouts1Dart,
              successfulCheckouts2Dart: entry.successfulCheckouts2Dart,
              successfulCheckouts3Dart: entry.successfulCheckouts3Dart,
              thirdDartCheckoutAttempts: entry.thirdDartCheckoutAttempts,
              thirdDartCheckouts: entry.thirdDartCheckouts,
              bullCheckoutAttempts: entry.bullCheckoutAttempts,
              bullCheckouts: entry.bullCheckouts,
              functionalDoubleAttempts: entry.functionalDoubleAttempts,
              functionalDoubleSuccesses: entry.functionalDoubleSuccesses,
              firstNinePoints: entry.firstNinePoints,
              firstNineDarts: entry.firstNineDarts,
              highestFinish: entry.highestFinish,
              bestLegDarts: entry.bestLegDarts,
              totalFinishValue: entry.totalFinishValue,
              withThrowPoints: entry.withThrowPoints,
              withThrowDarts: entry.withThrowDarts,
              againstThrowPoints: entry.againstThrowPoints,
              againstThrowDarts: entry.againstThrowDarts,
              decidingLegPoints: entry.decidingLegPoints,
              decidingLegDarts: entry.decidingLegDarts,
              decidingLegsPlayed: entry.decidingLegsPlayed,
              decidingLegsWon: entry.decidingLegsWon,
              won9Darters: entry.won9Darters,
              won12Darters: entry.won12Darters,
              won15Darters: entry.won15Darters,
              won18Darters: entry.won18Darters,
              ),
            )
            .toList(),
        legs: List<MatchLegEntry>.from(_completedLegs),
      );

      _recordMatchHistory(result);

      if (widget.session.tournamentMatchId != null &&
          widget.session.playerParticipantId != null &&
          widget.session.botParticipantId != null &&
          _participants.length == 2) {
        TournamentRepository.instance.completePlayedHumanMatch(
          matchId: widget.session.tournamentMatchId!,
          winnerId: winner.config.id,
          winnerName: winner.config.name,
          scoreText: widget.session.matchConfig.mode == MatchMode.sets
              ? '${_participants[0].sets}:${_participants[1].sets} Sets'
              : '${_participants[0].legs}:${_participants[1].legs} Legs',
          participantStats: result.participants
              .map(
                (entry) => TournamentPlayerMatchStats(
                  participantId: entry.participantId,
                  participantName: entry.participantName,
                  pointsScored: entry.pointsScored,
                  dartsThrown: entry.dartsThrown,
                  visits: entry.visits,
                  legsWon: entry.legsWon,
                  legsPlayed: entry.legsPlayed,
                  legsStarted: entry.legsStarted,
                  legsWonAsStarter: entry.legsWonAsStarter,
                  legsWonWithoutStarter: entry.legsWonWithoutStarter,
                  scores0To40: entry.scores0To40,
                  scores41To59: entry.scores41To59,
                  scores60Plus: entry.scores60Plus,
                  scores100Plus: entry.scores100Plus,
                  scores140Plus: entry.scores140Plus,
                  scores171Plus: entry.scores171Plus,
                  scores180: entry.scores180,
                  checkoutAttempts: entry.checkoutAttempts,
                  successfulCheckouts: entry.successfulCheckouts,
                  checkoutAttempts1Dart: entry.checkoutAttempts1Dart,
                  checkoutAttempts2Dart: entry.checkoutAttempts2Dart,
                  checkoutAttempts3Dart: entry.checkoutAttempts3Dart,
                  successfulCheckouts1Dart: entry.successfulCheckouts1Dart,
                  successfulCheckouts2Dart: entry.successfulCheckouts2Dart,
                  successfulCheckouts3Dart: entry.successfulCheckouts3Dart,
                  thirdDartCheckoutAttempts: entry.thirdDartCheckoutAttempts,
                  thirdDartCheckouts: entry.thirdDartCheckouts,
                  bullCheckoutAttempts: entry.bullCheckoutAttempts,
                  bullCheckouts: entry.bullCheckouts,
                  functionalDoubleAttempts: entry.functionalDoubleAttempts,
                  functionalDoubleSuccesses: entry.functionalDoubleSuccesses,
                  firstNinePoints: entry.firstNinePoints,
                  firstNineDarts: entry.firstNineDarts,
                  highestFinish: entry.highestFinish,
                  bestLegDarts: entry.bestLegDarts,
                  totalFinishValue: entry.totalFinishValue,
                  withThrowPoints: entry.withThrowPoints,
                  withThrowDarts: entry.withThrowDarts,
                  againstThrowPoints: entry.againstThrowPoints,
                  againstThrowDarts: entry.againstThrowDarts,
                  decidingLegPoints: entry.decidingLegPoints,
                  decidingLegDarts: entry.decidingLegDarts,
                  decidingLegsPlayed: entry.decidingLegsPlayed,
                  decidingLegsWon: entry.decidingLegsWon,
                  won9Darters: entry.won9Darters,
                  won12Darters: entry.won12Darters,
                  won15Darters: entry.won15Darters,
                  won18Darters: entry.won18Darters,
                ),
              )
              .toList(),
        );
      }

      _matchFinished = true;
      _status = '${winner.config.name} gewinnt das Match.';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MatchEndScreen(
              result: result,
              returnButtonLabel:
                  widget.session.returnButtonLabel ?? 'Zurueck',
            ),
          ),
        );
      });
      return;
    }

    setState(() {
      _starterIndex = (_starterIndex + 1) % _participants.length;
    });
    _resetLeg();
  }

  void _recordMatchHistory(MatchResultSummary result) {
    if (_participants.length != 2) {
      return;
    }

    final first = _participants[0];
    final second = _participants[1];

    if (first.config.isHuman) {
      PlayerRepository.instance.recordMatch(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: result.participants
            .firstWhere((entry) => entry.participantId == first.config.id)
            .average,
        opponentType: second.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordMatch(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: result.participants
            .firstWhere((entry) => entry.participantId == first.config.id)
            .average,
      );
    }

    if (second.config.isHuman) {
      PlayerRepository.instance.recordMatch(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: result.participants
            .firstWhere((entry) => entry.participantId == second.config.id)
            .average,
        opponentType: first.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordMatch(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: result.participants
            .firstWhere((entry) => entry.participantId == second.config.id)
            .average,
      );
    }
  }

  void _appendDigit(String digit) {
    if (!_isHumanTurn || _matchFinished) {
      return;
    }
    setState(() {
      _currentInput = _currentInput == '0' ? digit : '$_currentInput$digit';
    });
  }

  void _setQuickScore(int value) {
    if (!_isHumanTurn || _matchFinished) {
      return;
    }
    unawaited(_submitHumanScoreValue(valueOverride: value));
  }

  void _clearInput() {
    setState(() {
      _currentInput = '';
    });
  }

  bool get _canUndo => _undoStack.isNotEmpty && !_isBullOffActive;

  void _pushUndoSnapshot() {
    _undoStack.add(
      _MatchUndoSnapshot(
        participants: _participants
            .map((participant) => participant.snapshot())
            .toList(),
        currentTurnIndex: _currentTurnIndex,
        starterIndex: _starterIndex,
        matchFinished: _matchFinished,
        showScoreStats: _showScoreStats,
        status: _status,
        currentInput: _currentInput,
        visitLog: List<String>.from(_visitLog),
        completedLegs: List<MatchLegEntry>.from(_completedLegs),
        currentLegVisits: List<MatchVisitEntry>.from(_currentLegVisits),
        currentLegDarts: Map<String, int>.from(_currentLegDarts),
        currentLegScored: Map<String, int>.from(_currentLegScored),
        turnCounter: _turnCounter,
        isBullOffActive: _isBullOffActive,
        bullOffRound: _bullOffRound,
        bullOffTurnIndex: _bullOffTurnIndex,
        bullOffOrder: List<String>.from(_bullOffOrder),
        bullOffResults: Map<String, _BullOffResult>.from(_bullOffResults),
      ),
    );
  }

  void _undoLastVisit() {
    if (!_canUndo) {
      return;
    }
    final snapshot = _undoStack.removeLast();
    setState(() {
      for (var index = 0; index < _participants.length; index += 1) {
        _participants[index].restore(snapshot.participants[index]);
      }
      _currentTurnIndex = snapshot.currentTurnIndex;
      _starterIndex = snapshot.starterIndex;
      _matchFinished = snapshot.matchFinished;
      _showScoreStats = snapshot.showScoreStats;
      _status = snapshot.status;
      _currentInput = snapshot.currentInput;
      _visitLog
        ..clear()
        ..addAll(snapshot.visitLog);
      _completedLegs
        ..clear()
        ..addAll(snapshot.completedLegs);
      _currentLegVisits = List<MatchVisitEntry>.from(snapshot.currentLegVisits);
      _currentLegDarts
        ..clear()
        ..addAll(snapshot.currentLegDarts);
      _currentLegScored
        ..clear()
        ..addAll(snapshot.currentLegScored);
      _turnCounter = snapshot.turnCounter;
      _isBullOffActive = snapshot.isBullOffActive;
      _bullOffRound = snapshot.bullOffRound;
      _bullOffTurnIndex = snapshot.bullOffTurnIndex;
      _bullOffOrder = List<String>.from(snapshot.bullOffOrder);
      _bullOffResults = Map<String, _BullOffResult>.from(snapshot.bullOffResults);
    });
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<_ManualDoubleInDetails?> _showManualDoubleInDialog() {
    return showModalBottomSheet<_ManualDoubleInDetails>(
      context: context,
      builder: (context) {
        var selectedDartsUsed = 3;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Double In bestaetigen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Wie viele Darts wurden fuer diesen Besuch geworfen?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D6B78),
                      ),
                ),
                const SizedBox(height: 18),
                StatefulBuilder(
                  builder: (context, setModalState) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <int>[1, 2, 3].map((dartsUsed) {
                        return ChoiceChip(
                          label: Text('$dartsUsed Dart${dartsUsed == 1 ? '' : 's'}'),
                          selected: selectedDartsUsed == dartsUsed,
                          onSelected: (_) {
                            setModalState(() {
                              selectedDartsUsed = dartsUsed;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _ManualDoubleInDetails(
                          dartsUsed: selectedDartsUsed,
                        ),
                      );
                    },
                    child: const Text('Double In speichern'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_ManualCheckoutDetails?> _showManualCheckoutDialog(int score) {
    return showModalBottomSheet<_ManualCheckoutDetails>(
      context: context,
      builder: (context) {
        var selectedDartsUsed = _checkoutOpportunityDarts(score) ?? 3;
        _ManualFinishType selectedFinishType =
            _preferredManualFinishTypeForScore(score) ??
                _ManualFinishType.doubleValue;
        var selectedDoubleAttempts =
            _minimumDoubleAttemptsForFinishType(selectedFinishType);
        return StatefulBuilder(
          builder: (context, setModalState) {
            final finishTypes = _allowedManualFinishTypes();
            if (!finishTypes.contains(selectedFinishType)) {
              selectedFinishType = finishTypes.first;
            }
            final minimumDoubleAttempts = switch (selectedFinishType) {
              _ManualFinishType.single => 0,
              _ManualFinishType.triple => 0,
              _ManualFinishType.doubleValue || _ManualFinishType.bull => 1,
            };
            if (selectedDoubleAttempts < minimumDoubleAttempts) {
              selectedDoubleAttempts = minimumDoubleAttempts;
            }
            if (selectedDoubleAttempts > selectedDartsUsed) {
              selectedDoubleAttempts = selectedDartsUsed;
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Checkout bestaetigen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Restscore $score. Fuer genaue X01-Stats bitte Gesamt-Darts, Doppel-Darts und Finish-Art waehlen.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D6B78),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <int>[1, 2, 3].map((dartsUsed) {
                        final selected = selectedDartsUsed == dartsUsed;
                        return ChoiceChip(
                          label: Text('$dartsUsed Dart${dartsUsed == 1 ? '' : 's'}'),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() {
                              selectedDartsUsed = dartsUsed;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(
                        selectedDartsUsed + 1 - minimumDoubleAttempts,
                        (index) {
                          final doubleAttempts = minimumDoubleAttempts + index;
                          final selected =
                              selectedDoubleAttempts == doubleAttempts;
                          return ChoiceChip(
                            label: Text('$doubleAttempts aufs Doppel'),
                            selected: selected,
                            onSelected: (_) {
                              setModalState(() {
                                selectedDoubleAttempts = doubleAttempts;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: finishTypes.map((finishType) {
                        final selected = selectedFinishType == finishType;
                        return ChoiceChip(
                          label: Text(finishType.label),
                          selected: selected,
                          onSelected: (_) {
                            setModalState(() {
                              selectedFinishType = finishType;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _ManualCheckoutDetails(
                              dartsUsed: selectedDartsUsed,
                              doubleAttempts: selectedDoubleAttempts,
                              finishType: selectedFinishType,
                            ),
                          );
                        },
                        child: const Text('Checkout speichern'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<int?> _showManualDoubleAttemptDialog({
    required int remainingScore,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        var selectedAttempts = 0;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Doppelversuche erfassen',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Neuer Restscore: $remainingScore. Wie viele Darts gingen in diesem Besuch aufs Doppel?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D6B78),
                          ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <int>[0, 1, 2, 3].map((attempts) {
                        return ChoiceChip(
                          label: Text('$attempts'),
                          selected: selectedAttempts == attempts,
                          onSelected: (_) {
                            setModalState(() {
                              selectedAttempts = attempts;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(selectedAttempts);
                        },
                        child: const Text('Speichern'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_ManualFinishType> _allowedManualFinishTypes() {
    switch (widget.session.matchConfig.checkoutRequirement) {
      case CheckoutRequirement.singleOut:
        return _ManualFinishType.values;
      case CheckoutRequirement.doubleOut:
        return <_ManualFinishType>[
          _ManualFinishType.doubleValue,
          _ManualFinishType.bull,
        ];
      case CheckoutRequirement.masterOut:
        return <_ManualFinishType>[
          _ManualFinishType.doubleValue,
          _ManualFinishType.triple,
          _ManualFinishType.bull,
        ];
    }
  }

  int _minimumDoubleAttemptsForFinishType(_ManualFinishType finishType) {
    return switch (finishType) {
      _ManualFinishType.single => 0,
      _ManualFinishType.triple => 0,
      _ManualFinishType.doubleValue || _ManualFinishType.bull => 1,
    };
  }

  _ManualFinishType? _preferredManualFinishTypeForScore(int score) {
    final route = _checkoutPlanner.bestFinishRoute(
      score: score,
      dartsLeft: 3,
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
    );
    if (route == null || route.isEmpty) {
      return null;
    }

    final finalThrow = route.last;
    if (finalThrow.isBull) {
      return _ManualFinishType.bull;
    }
    if (finalThrow.isTriple) {
      return _ManualFinishType.triple;
    }
    if (finalThrow.isDouble) {
      return _ManualFinishType.doubleValue;
    }
    return _ManualFinishType.single;
  }

  bool _canCheckoutFromScore({
    required int score,
    required bool requireOpeningDouble,
  }) {
    if (score <= 0) {
      return false;
    }

    for (var dartsLeft = 1; dartsLeft <= 3; dartsLeft += 1) {
      final routes = _checkoutPlanner.allCheckoutRoutes(
        score: score,
        dartsLeft: dartsLeft,
        checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
      );
      if (routes.any((route) {
        if (route.isEmpty) {
          return false;
        }
        if (requireOpeningDouble &&
            !route.first.matchesStartRequirement(StartRequirement.doubleIn)) {
          return false;
        }
        return true;
      })) {
        return true;
      }
    }

    return false;
  }

  bool get _isCheckoutHotkeyAvailable {
    if (!_isHumanTurn || _matchFinished) {
      return false;
    }

    return _canCheckoutFromScore(
      score: _currentParticipant.score,
      requireOpeningDouble:
          widget.session.matchConfig.startRequirement == StartRequirement.doubleIn &&
              !_currentParticipant.hasOpenedLeg,
    );
  }

  Future<void> _triggerCheckoutHotkey() async {
    if (!_isCheckoutHotkeyAvailable) {
      return;
    }

    final participant = _currentParticipant;
    if (participant.score == 1 &&
        widget.session.matchConfig.checkoutRequirement ==
            CheckoutRequirement.singleOut) {
      final visitResult = VisitResult(
        throws: const <DartThrowResult>[],
        scoredPoints: 1,
        didBust: false,
        remainingScore: 0,
        openedLeg: true,
      );
      _applyVisit(
        participant: participant,
        visitResult: visitResult,
        throws: const <DartThrowResult>[],
        startScore: participant.score,
        manualDescription: '1 Checkout in 1 Dart',
        manualDartsUsed: 1,
        manualDoubleAttempts: 0,
        finishingThrow: _matchEngine.rules.createSingle(1),
      );
      return;
    }

    await _submitHumanScoreValue(valueOverride: participant.score);
  }

  DartThrowResult _sampleThrowForFinishType(_ManualFinishType finishType) {
    return switch (finishType) {
      _ManualFinishType.single => _matchEngine.rules.createSingle(1),
      _ManualFinishType.doubleValue => _matchEngine.rules.createDouble(1),
      _ManualFinishType.triple => _matchEngine.rules.createTriple(1),
      _ManualFinishType.bull => _matchEngine.rules.createBull(),
    };
  }

  bool _isManualCheckoutPossible({
    required int score,
    required int dartsUsed,
    required _ManualFinishType finishType,
    required bool requireOpeningDouble,
  }) {
    final routes = _checkoutPlanner.allCheckoutRoutes(
      score: score,
      dartsLeft: dartsUsed,
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
    );
    return routes.any((route) {
      if (route.isEmpty) {
        return false;
      }
      if (requireOpeningDouble &&
          !route.first.matchesStartRequirement(StartRequirement.doubleIn)) {
        return false;
      }
      return switch (finishType) {
        _ManualFinishType.single => route.last.isFinishSingle,
        _ManualFinishType.doubleValue => route.last.isDouble,
        _ManualFinishType.triple => route.last.isTriple,
        _ManualFinishType.bull => route.last.isBull,
      };
    });
  }

  void _recordMilestones({
    required _ParticipantRuntime participant,
    required int scoredPoints,
  }) {
    if (scoredPoints >= 180) {
      participant.scores180 += 1;
      return;
    }
    if (scoredPoints >= 140) {
      participant.scores140Plus += 1;
      return;
    }
    if (scoredPoints >= 100) {
      participant.scores100Plus += 1;
    }
  }

  int? _checkoutOpportunityDarts(int score) {
    for (var dartsLeft = 1; dartsLeft <= 3; dartsLeft += 1) {
      final route = _checkoutPlanner.bestFinishRoute(
        score: score,
        dartsLeft: dartsLeft,
        checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
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

  bool _isCurrentLegDeciding() {
    if (_participants.length < 2) {
      return false;
    }

    if (widget.session.matchConfig.mode == MatchMode.sets) {
      return _participants.where((participant) {
            return participant.sets == widget.session.matchConfig.setsToWin - 1 &&
                participant.legs == widget.session.matchConfig.legsPerSet - 1;
          }).length >= 2;
    }

    return _participants.where((participant) {
          return participant.legs == widget.session.matchConfig.legsToWin - 1;
        }).length >= 2;
  }

  double _calculateAverage(int pointsScored, int dartsThrown) {
    if (dartsThrown <= 0) {
      return 0;
    }
    return (pointsScored / dartsThrown) * 3;
  }

  @override
  Widget build(BuildContext context) {
    if (_isBullOffActive) {
      return Scaffold(
        backgroundColor: const Color(0xFFF2F5F8),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                child: _buildBullOffView(),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F8),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
              child: Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      _buildTopBar(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxHeight = constraints.maxHeight;
                            final compactLayout = maxHeight < 620;
                            final spacing = compactLayout ? 10.0 : 12.0;
                            final participantCount = _participants.length;
                            final additionalPlayers = participantCount > 1
                                ? participantCount - 1
                                : 0;
                            final scoreMinHeight = (compactLayout ? 176.0 : 204.0) +
                                (additionalPlayers * (compactLayout ? 60.0 : 72.0));
                            final inputMinHeight = compactLayout ? 358.0 : 404.0;
                            final maxScoreHeight =
                                (maxHeight - inputMinHeight - spacing)
                                    .clamp(compactLayout ? 148.0 : 176.0, maxHeight)
                                    .toDouble();
                            final scoreHeight = scoreMinHeight <= maxScoreHeight
                                ? scoreMinHeight
                                : maxScoreHeight;

                            return Column(
                              children: <Widget>[
                                SizedBox(
                                  height: scoreHeight,
                                  child: _buildScoreZone(compact: compactLayout),
                                ),
                                SizedBox(height: spacing),
                                Expanded(
                                  child: _buildInputZone(compact: compactLayout),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_showVisitLogOverlay)
                    Positioned(
                      top: 56,
                      left: MediaQuery.sizeOf(context).width < 520 ? 0 : null,
                      right: 0,
                      child: _buildVisitLogOverlay(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBullOffView() {
    final currentParticipant = _currentBullOffParticipant;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTopBar(),
          const SizedBox(height: 12),
          _buildSurface(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Ausbullen',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF152C45),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _bullOffRound == 1
                      ? 'Bull, Single Bull oder Outside bestimmen, wer beginnt.'
                      : 'Gleichstand. Nur die beteiligten Spieler werfen erneut in umgekehrter Reihenfolge.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5E6E7D),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bullOffOrder.map((participantId) {
                    final participant = _participants.firstWhere(
                      (entry) => entry.config.id == participantId,
                    );
                    final result = _bullOffResults[participantId];
                    final isCurrent =
                        currentParticipant?.config.id == participant.config.id;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? const Color(0xFF17324D)
                            : const Color(0xFFF3F6F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        result == null
                            ? participant.config.name
                            : '${participant.config.name}: ${result.label}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color:
                                  isCurrent ? Colors.white : const Color(0xFF223447),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    );
                  }).toList(),
                ),
                if (currentParticipant != null) ...<Widget>[
                  const SizedBox(height: 20),
                  Text(
                    '${currentParticipant.config.name} ist dran',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentParticipant.config.isHuman
                        ? 'Waehle jetzt das Ergebnis des Bullwurfs.'
                        : 'Computer wirft automatisch.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5E6E7D),
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (currentParticipant.config.isHuman)
                    Column(
                      children: <Widget>[
                        _buildBullOffButton(
                          label: 'Bull',
                          onPressed: () => _submitBullOffResult(
                            participantId: currentParticipant.config.id,
                            result: _BullOffResult.bull,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildBullOffButton(
                          label: 'Single Bull',
                          onPressed: () => _submitBullOffResult(
                            participantId: currentParticipant.config.id,
                            result: _BullOffResult.singleBull,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildBullOffButton(
                          label: 'Outside',
                          onPressed: () => _submitBullOffResult(
                            participantId: currentParticipant.config.id,
                            result: _BullOffResult.outside,
                          ),
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullOffButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: const Color(0xFF17324D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${widget.session.gameMode.title} Match',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                widget.session.matchConfig.mode == MatchMode.sets
                    ? 'First to ${widget.session.matchConfig.setsToWin} Sets'
                    : 'First to ${widget.session.matchConfig.legsToWin}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B78),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Matchverlauf',
          onPressed: () {
            setState(() {
              _showVisitLogOverlay = !_showVisitLogOverlay;
            });
          },
          icon: Icon(
            _showVisitLogOverlay
                ? Icons.history_toggle_off_rounded
                : Icons.history_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF152C45),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            'Leg ${_completedLegs.length + 1}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreZone({required bool compact}) {
    return _buildSurface(
      color: const Color(0xFF152C45),
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          SizedBox(height: compact ? 10 : 12),
          Expanded(
            child: _buildPrimaryScoreboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputZone({required bool compact}) {
    return _buildSurface(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _buildKeypadGrid(compact: compact),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitLogOverlay() {
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < 520;
    final overlayWidth = isNarrow
        ? (screenSize.width - 48).clamp(260.0, 380.0).toDouble()
        : 320.0;
    final overlayMaxHeight =
        (screenSize.height * (isNarrow ? 0.42 : 0.36)).clamp(230.0, 360.0).toDouble();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: overlayWidth,
        constraints: BoxConstraints(maxHeight: overlayMaxHeight),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Matchverlauf',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF152C45),
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showVisitLogOverlay = false;
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: _buildVisitLogContent(),
            ),
          ],
        ),
      ),
    );
  }

  List<int> get _quickScoreValues =>
      SettingsRepository.instance.settings.x01QuickScores;

  String? _checkoutSuggestionSummary() {
    return _participantRouteSuggestion(_currentParticipant);
  }

  String? _participantRouteSuggestion(_ParticipantRuntime participant) {
    final cacheKey = '${participant.score}|${participant.hasOpenedLeg}|'
        '${widget.session.matchConfig.checkoutRequirement.name}|'
        '$_matchFinished|$_isBullOffActive';
    if (_routeSuggestionCache.containsKey(cacheKey)) {
      return _routeSuggestionCache[cacheKey];
    }

    if (_matchFinished ||
        _isBullOffActive ||
        !participant.hasOpenedLeg ||
        participant.score <= 1) {
      return _routeSuggestionCache[cacheKey] = null;
    }

    final finishRoute = _bestCheckoutSuggestionRoute(
      score: participant.score,
      dartsLeft: 3,
    );
    if (finishRoute != null && finishRoute.isNotEmpty) {
      final routeText =
          finishRoute.take(3).map((entry) => entry.label).join(' - ');
      return _routeSuggestionCache[cacheKey] = '$routeText -> Finish';
    }

    if (participant.score > 230) {
      final setupOption = _bestSetupSuggestionRoute(
        score: participant.score,
        dartsLeft: 3,
      );
      if (setupOption != null && setupOption.setupRoute.isNotEmpty) {
        final routeText =
            setupOption.setupRoute.take(3).map((entry) => entry.label).join(' - ');
        return _routeSuggestionCache[cacheKey] =
            '$routeText -> Rest ${setupOption.remainingScore}';
      }
    }

    final continuation = finishRoute == null
        ? _checkoutPlanner.bestContinuationPlan(
            score: participant.score,
            dartsLeft: 3,
            checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
            playStyle: _suggestionPlayStyle,
            outerBullPreference: _suggestionOuterBullPreference,
            bullPreference: _suggestionBullPreference,
          )
        : null;

    final route = finishRoute ?? continuation?.throws;
    if (route == null || route.isEmpty) {
      return _routeSuggestionCache[cacheKey] = null;
    }
    final routeText = route.take(3).map((entry) => entry.label).join(' - ');
    final resultingScore = participant.score -
        route.take(3).fold<int>(
          0,
          (sum, entry) => sum + entry.scoredPoints,
        );
    final outcomeText = resultingScore <= 0
        ? 'Finish'
        : 'Rest $resultingScore';
    return _routeSuggestionCache[cacheKey] = '$routeText -> $outcomeText';
  }

  Widget _buildPadMetaTile({
    required String title,
    required String value,
    IconData? icon,
    bool disabled = false,
    VoidCallback? onPressed,
  }) {
    final isInteractive = !disabled && onPressed != null;
    final foreground = disabled
        ? const Color(0xFF93A1AE)
        : isInteractive
            ? const Color(0xFF0B5E3C)
            : const Color(0xFF152C45);
    final background = disabled
        ? const Color(0xFFE9EEF3)
        : isInteractive
            ? const Color(0xFFDDF3E7)
            : const Color(0xFFE5EBF1);
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isInteractive ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(icon, size: 16, color: foreground),
                  const SizedBox(height: 4),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickScoreButton(int value) {
    final backgroundColor =
        _isHumanTurn ? const Color(0xFFD9E2EA) : const Color(0xFFE4EAF0);
    final foregroundColor =
        _isHumanTurn ? const Color(0xFF152C45) : const Color(0xFF93A1AE);
    return SizedBox(
      height: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        onPressed: _isHumanTurn ? () => _setQuickScore(value) : null,
        child: Text('$value'),
      ),
    );
  }

  Widget _buildDisplayTile({required bool compact}) {
    final suggestion = _checkoutSuggestionSummary();
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD9E3EC),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final canShowSubtitle = constraints.maxHeight >= 62;
          final subtitle = suggestion ??
              (_currentParticipant.config.isHuman
                  ? 'Direkte Eingabe'
                  : 'Computer am Zug');
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _currentInput.isEmpty ? '0' : _currentInput,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF152C45),
                          ),
                    ),
                  ),
                ),
              ),
              if (canShowSubtitle) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF5B6C7C),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<DartThrowResult>? _bestCheckoutSuggestionRoute({
    required int score,
    required int dartsLeft,
  }) {
    final finishes = _checkoutPlanner.allCheckoutRoutes(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
      playStyle: _suggestionPlayStyle,
    );
    if (finishes.isEmpty) {
      return null;
    }

    final rankedRoutes = finishes
        .map(
          (route) => (
            route: route,
            score: _checkoutPlanner.scoreRoute(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
              playStyle: _suggestionPlayStyle,
              outerBullPreference: _suggestionOuterBullPreference,
              bullPreference: _suggestionBullPreference,
            ),
          ),
        )
        .toList()
      ..sort((left, right) => right.score.compareTo(left.score));
    return rankedRoutes.first.route;
  }

  CheckoutSetupLeaveOption? _bestSetupSuggestionRoute({
    required int score,
    required int dartsLeft,
  }) {
    final options = _checkoutPlanner.setupLeaveOptions(
      startScore: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: widget.session.matchConfig.checkoutRequirement,
      playStyle: _suggestionPlayStyle,
      leavePreference: _suggestionSetupPreference,
      outerBullPreference: _suggestionOuterBullPreference,
      bullPreference: _suggestionBullPreference,
      maxResults: 1,
      maxResultsPerNarrowCount: 20,
    );
    if (options.isEmpty) {
      return null;
    }
    return options.first;
  }

  Widget _buildSurface({
    required Widget child,
    required Color color,
    required EdgeInsets padding,
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildPrimaryScoreboard() {
    final orderedParticipants = _participants.length <= 1 || _matchFinished
        ? List<_ParticipantRuntime>.from(_participants)
        : <_ParticipantRuntime>[
            ..._participants.skip(_currentTurnIndex),
            ..._participants.take(_currentTurnIndex),
          ];
    return Scrollbar(
      thumbVisibility: orderedParticipants.length > 1,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 4, bottom: 6),
        child: Column(
          children: orderedParticipants
              .asMap()
              .entries
              .map(
                (entry) => Container(
                  padding: EdgeInsets.symmetric(
                    vertical: orderedParticipants.length > 1 ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    border: entry.key == orderedParticipants.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(
                              color: Color(0xFF2C4967),
                            ),
                          ),
                  ),
                  child: _buildParticipantScoreCard(
                    participant: entry.value,
                    isActive: !_matchFinished &&
                        _currentParticipant.config.id == entry.value.config.id,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildParticipantScoreCard({
    required _ParticipantRuntime participant,
    required bool isActive,
  }) {
    final compactCard = _participants.length > 1;
    final routeSuggestion = _participantRouteSuggestion(participant);
    final isExpanded = _expandedParticipantStats.contains(participant.config.id);
    final primaryStats = <_PlayerStatItem>[
      _PlayerStatItem(
        label: 'Avg',
        value: participant.average.toStringAsFixed(1),
        description:
            '3-Dart Average: durchschnittlich erzielte Punkte pro 3 Darts.',
      ),
      _PlayerStatItem(
        label: 'CO',
        value: '${participant.doubleQuote.toStringAsFixed(0)}%',
        description:
            'Checkout Quote: Anteil erfolgreich verwandelter Doppel-Chancen.',
      ),
    ];
    final detailedStats = _buildDetailedStats(participant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 10,
              height: compactCard ? 48 : 54,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF5BC0FF) : const Color(0xFF35516E),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        participant.config.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      ...primaryStats.map(
                        (item) => _buildInteractiveStatChip(
                          item: item,
                          backgroundColor: const Color(0xFF26425E),
                          foregroundColor: const Color(0xFFD6E4EF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.session.matchConfig.mode == MatchMode.sets
                        ? '${participant.sets} Sets | ${participant.legs} Legs'
                        : '${participant.legs} Legs',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFBBD1E4),
                        ),
                  ),
                  if (routeSuggestion != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      routeSuggestion,
                      maxLines: compactCard ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? const Color(0xFF8FD4FF)
                                : const Color(0xFF9AB6CD),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${participant.score}',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedParticipantStats.remove(participant.config.id);
              } else {
                _expandedParticipantStats.add(participant.config.id);
              }
            });
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compactCard ? 8 : 10,
              vertical: compactCard ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF203C58),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    compactCard
                        ? (isExpanded ? 'Stats ausblenden' : 'Stats einblenden')
                        : (isExpanded
                            ? 'Alle Statistiken ausblenden'
                            : 'Alle Statistiken einblenden'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFFD6E4EF),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFFD6E4EF),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: detailedStats
                .map(
                  (item) => _buildInteractiveStatChip(
                    item: item,
                    backgroundColor: const Color(0xFF26425E),
                    foregroundColor: const Color(0xFFD6E4EF),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildInteractiveStatChip({
    required _PlayerStatItem item,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _showStatInfo(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '${item.label} ${item.value}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
        ),
      ),
    );
  }

  List<_PlayerStatItem> _buildDetailedStats(_ParticipantRuntime participant) {
    return <_PlayerStatItem>[
      _PlayerStatItem(
        label: 'PPD',
        value: participant.dartsThrown <= 0
            ? '0.00'
            : (participant.pointsScored / participant.dartsThrown)
                .toStringAsFixed(2),
        description: 'Points per Dart: durchschnittliche Punkte pro geworfenem Dart.',
      ),
      _PlayerStatItem(
        label: 'PPR',
        value: participant.visits <= 0
            ? '0.0'
            : (participant.pointsScored / participant.visits).toStringAsFixed(1),
        description:
            'Points per Round: durchschnittliche Punkte pro Aufnahme bzw. Besuch.',
      ),
      _PlayerStatItem(
        label: 'F9',
        value: participant.firstNineAverage.toStringAsFixed(1),
        description:
            'First 9 Average: Durchschnitt der ersten neun Darts pro Leg.',
      ),
      _PlayerStatItem(
        label: 'CO1',
        value: _formatPercent(
          participant.checkoutAttempts1Dart <= 0
              ? 0
              : (participant.successfulCheckouts1Dart /
                      participant.checkoutAttempts1Dart) *
                  100,
        ),
        description:
            'Checkout Quote 1 Dart: Erfolgsquote bei Checkouts mit genau einem Dart.',
      ),
      _PlayerStatItem(
        label: 'CO2',
        value: _formatPercent(
          participant.checkoutAttempts2Dart <= 0
              ? 0
              : (participant.successfulCheckouts2Dart /
                      participant.checkoutAttempts2Dart) *
                  100,
        ),
        description:
            'Checkout Quote 2 Darts: Erfolgsquote bei Checkouts mit genau zwei Darts.',
      ),
      _PlayerStatItem(
        label: 'CO3',
        value: _formatPercent(
          participant.checkoutAttempts3Dart <= 0
              ? 0
              : (participant.successfulCheckouts3Dart /
                      participant.checkoutAttempts3Dart) *
                  100,
        ),
        description:
            'Checkout Quote 3 Darts: Erfolgsquote bei Checkouts mit genau drei Darts.',
      ),
      _PlayerStatItem(
        label: 'HF',
        value: '${participant.highestFinish}',
        description: 'Highest Finish: höchstes erfolgreiches Checkout-Finish.',
      ),
      _PlayerStatItem(
        label: 'BL',
        value: '${participant.bestLegDarts}',
        description: 'Best Leg: bestes gewonnenes Leg gemessen in Darts.',
      ),
      _PlayerStatItem(
        label: 'LW',
        value: '${participant.totalLegsWon}',
        description: 'Legs Won: insgesamt gewonnene Legs im Match.',
      ),
      _PlayerStatItem(
        label: '100+',
        value: '${participant.scores100Plus}',
        description: 'Anzahl aller Aufnahmen mit mindestens 100 Punkten.',
      ),
      _PlayerStatItem(
        label: '140+',
        value: '${participant.scores140Plus}',
        description: 'Anzahl aller Aufnahmen mit mindestens 140 Punkten.',
      ),
      _PlayerStatItem(
        label: '171+',
        value: '${participant.scores171Plus}',
        description: 'Anzahl aller Aufnahmen mit mindestens 171 Punkten.',
      ),
      _PlayerStatItem(
        label: '180',
        value: '${participant.scores180}',
        description: 'Anzahl geworfener 180er.',
      ),
      _PlayerStatItem(
        label: '180/L',
        value: participant.legsPlayed <= 0
            ? '0.00'
            : (participant.scores180 / participant.legsPlayed).toStringAsFixed(2),
        description: '180s per Leg: 180er im Schnitt pro gespieltem Leg.',
      ),
      _PlayerStatItem(
        label: 'DRT',
        value: '${participant.dartsThrown}',
        description: 'Darts Thrown: insgesamt geworfene Darts.',
      ),
      _PlayerStatItem(
        label: 'VIS',
        value: '${participant.visits}',
        description: 'Visits: insgesamt gespielte Aufnahmen bzw. Besuche.',
      ),
      _PlayerStatItem(
        label: 'LSt',
        value: '${participant.legsStarted}',
        description: 'Legs Started: Anzahl der begonnenen Legs.',
      ),
      _PlayerStatItem(
        label: 'LWS',
        value: '${participant.legsWonAsStarter}',
        description: 'Legs Won as Starter: gewonnene Legs mit Anwurf.',
      ),
      _PlayerStatItem(
        label: 'LWNS',
        value: '${participant.legsWonWithoutStarter}',
        description: 'Legs Won No Start: gewonnene Legs ohne Anwurf.',
      ),
      _PlayerStatItem(
        label: 'WTA',
        value: participant.withThrowDarts <= 0
            ? '0.0'
            : ((participant.withThrowPoints / participant.withThrowDarts) * 3)
                .toStringAsFixed(1),
        description: 'With Throw Average: Average in Legs, die der Spieler begonnen hat.',
      ),
      _PlayerStatItem(
        label: 'ATA',
        value: participant.againstThrowDarts <= 0
            ? '0.0'
            : ((participant.againstThrowPoints / participant.againstThrowDarts) * 3)
                .toStringAsFixed(1),
        description:
            'Against Throw Average: Average in Legs ohne eigenen Anwurf.',
      ),
      _PlayerStatItem(
        label: 'DLA',
        value: participant.decidingLegDarts <= 0
            ? '0.0'
            : ((participant.decidingLegPoints / participant.decidingLegDarts) * 3)
                .toStringAsFixed(1),
        description:
            'Deciding Leg Average: Average in entscheidenden Legs.',
      ),
      _PlayerStatItem(
        label: 'DLW%',
        value: _formatPercent(
          participant.decidingLegsPlayed <= 0
              ? 0
              : (participant.decidingLegsWon / participant.decidingLegsPlayed) *
                  100,
        ),
        description:
            'Deciding Legs Won: Gewinnquote in entscheidenden Legs.',
      ),
      _PlayerStatItem(
        label: '12D%',
        value: _formatPercent(
          participant.totalLegsWon <= 0
              ? 0
              : (participant.won12Darters / participant.totalLegsWon) * 100,
        ),
        description:
            '12-Darter Quote: Anteil gewonnener Legs in 12 Darts oder besser.',
      ),
      _PlayerStatItem(
        label: '15D%',
        value: _formatPercent(
          participant.totalLegsWon <= 0
              ? 0
              : (participant.won15Darters / participant.totalLegsWon) * 100,
        ),
        description:
            '15-Darter Quote: Anteil gewonnener Legs in 15 Darts oder besser.',
      ),
      _PlayerStatItem(
        label: '18D%',
        value: _formatPercent(
          participant.totalLegsWon <= 0
              ? 0
              : (participant.won18Darters / participant.totalLegsWon) * 100,
        ),
        description:
            '18-Darter Quote: Anteil gewonnener Legs in 18 Darts oder besser.',
      ),
      _PlayerStatItem(
        label: '3DC%',
        value: _formatPercent(
          participant.thirdDartCheckoutAttempts <= 0
              ? 0
              : (participant.thirdDartCheckouts /
                      participant.thirdDartCheckoutAttempts) *
                  100,
        ),
        description:
            '3rd Dart Checkout Quote: Quote der Checkouts mit dem letzten Dart der Hand.',
      ),
      _PlayerStatItem(
        label: 'Bull%',
        value: _formatPercent(
          participant.bullCheckoutAttempts <= 0
              ? 0
              : (participant.bullCheckouts / participant.bullCheckoutAttempts) *
                  100,
        ),
        description:
            'Bull Checkout Quote: Erfolgsquote bei Bull-Finishes.',
      ),
      _PlayerStatItem(
        label: 'FD%',
        value: _formatPercent(
          participant.functionalDoubleAttempts <= 0
              ? 0
              : (participant.functionalDoubleSuccesses /
                      participant.functionalDoubleAttempts) *
                  100,
        ),
        description:
            'Functional Doubles Quote: sinnvolle Doppelchancen, die erfolgreich genutzt wurden.',
      ),
      _PlayerStatItem(
        label: 'AvgF',
        value: participant.successfulCheckouts <= 0
            ? '0.0'
            : (participant.totalFinishValue / participant.successfulCheckouts)
                .toStringAsFixed(1),
        description:
            'Average Finish: durchschnittlicher Wert erfolgreicher Checkouts.',
      ),
      _PlayerStatItem(
        label: '0-40',
        value: '${participant.scores0To40}',
        description: 'Anzahl der Aufnahmen im Segment von 0 bis 40 Punkten.',
      ),
      _PlayerStatItem(
        label: '41-59',
        value: '${participant.scores41To59}',
        description: 'Anzahl der Aufnahmen im Segment von 41 bis 59 Punkten.',
      ),
      _PlayerStatItem(
        label: '60+',
        value: '${participant.scores60Plus}',
        description: 'Anzahl der Aufnahmen mit mindestens 60 Punkten.',
      ),
      _PlayerStatItem(
        label: 'Pts',
        value: '${participant.pointsScored}',
        description: 'Gesamtsumme aller erzielten Punkte im Match.',
      ),
      _PlayerStatItem(
        label: 'Last',
        value: _latestVisitTextFor(participant),
        description: 'Zuletzt eingetragene Aufnahme dieses Spielers.',
      ),
    ];
  }

  String _formatPercent(double value) => '${value.toStringAsFixed(0)}%';

  void _showStatInfo(_PlayerStatItem item) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item.label),
          content: Text(item.description),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDigitButton(String digit) {
    final backgroundColor =
        _isHumanTurn ? const Color(0xFFF2F5F8) : const Color(0xFFE0E6EC);
    final foregroundColor =
        _isHumanTurn ? const Color(0xFF152C45) : const Color(0xFF93A1AE);

    return SizedBox(
      height: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
          textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        onPressed: _isHumanTurn ? () => _appendDigit(digit) : null,
        child: Text(digit),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    final backgroundColor = switch (label) {
      'C' => const Color(0xFFD84C45),
      'OK' => const Color(0xFF1D8F5F),
      _ => const Color(0xFFE4EBF2),
    };
    final foregroundColor = label == 'OK' || label == 'C'
        ? Colors.white
        : const Color(0xFF152C45);

    return SizedBox(
      height: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        onPressed: _isHumanTurn ? onPressed : null,
        child: Text(label),
      ),
    );
  }

  Widget _buildKeypadGrid({required bool compact}) {
    final spacing = compact ? 8.0 : 10.0;
    final quickScores = _quickScoreValues;
    return Column(
      children: <Widget>[
        Expanded(
          child: _buildTopKeypadRow(
            spacing: spacing,
            compact: compact,
          ),
        ),
        SizedBox(height: spacing),
        Expanded(
          child: _buildKeypadRow(
            spacing: spacing,
            children: <Widget>[
              _buildQuickScoreButton(quickScores[0]),
              _buildDigitButton('1'),
              _buildDigitButton('2'),
              _buildDigitButton('3'),
              _buildQuickScoreButton(quickScores[3]),
            ],
          ),
        ),
        SizedBox(height: spacing),
        Expanded(
          child: _buildKeypadRow(
            spacing: spacing,
            children: <Widget>[
              _buildQuickScoreButton(quickScores[1]),
              _buildDigitButton('4'),
              _buildDigitButton('5'),
              _buildDigitButton('6'),
              _buildQuickScoreButton(quickScores[4]),
            ],
          ),
        ),
        SizedBox(height: spacing),
        Expanded(
          child: _buildKeypadRow(
            spacing: spacing,
            children: <Widget>[
              _buildQuickScoreButton(quickScores[2]),
              _buildDigitButton('7'),
              _buildDigitButton('8'),
              _buildDigitButton('9'),
              _buildQuickScoreButton(quickScores[5]),
            ],
          ),
        ),
        SizedBox(height: spacing),
        Expanded(
          child: _buildBottomKeypadRow(
            spacing: spacing,
          ),
        ),
      ],
    );
  }

  Widget _buildTopKeypadRow({
    required double spacing,
    required bool compact,
  }) {
    final checkoutHotkeyAvailable = _isCheckoutHotkeyAvailable;
    return Row(
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: spacing),
            child: SizedBox(
              height: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5EBF1),
                  foregroundColor: const Color(0xFF35516E),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _canUndo ? _undoLastVisit : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.undo_rounded, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      'UNDO',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: compact ? 3 : 4,
          child: Padding(
            padding: EdgeInsets.only(right: spacing),
            child: _buildDisplayTile(compact: compact),
          ),
        ),
        Expanded(
          child: _buildPadMetaTile(
            title: checkoutHotkeyAvailable ? 'CHECK' : 'REST',
            value: '${_currentParticipant.score}',
            icon: checkoutHotkeyAvailable ? Icons.flash_on_rounded : null,
            disabled: !_currentParticipant.config.isHuman,
            onPressed: checkoutHotkeyAvailable ? _triggerCheckoutHotkey : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomKeypadRow({
    required double spacing,
  }) {
    final hasInput = _currentInput.isNotEmpty;
    return Row(
      children: <Widget>[
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.only(right: spacing),
            child: _buildActionButton(
              label: 'C',
              onPressed: _clearInput,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: spacing),
            child: _buildDigitButton('0'),
          ),
        ),
        Expanded(
          flex: 2,
          child: _buildActionButton(
            label: hasInput ? 'OK' : '180',
            onPressed: hasInput
                ? _submitHumanScore
                : () => _setQuickScore(180),
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow({
    required double spacing,
    required List<Widget> children,
  }) {
    return Row(
      children: children
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key == children.length - 1 ? 0 : spacing,
                ),
                child: entry.value,
              ),
            ),
          )
          .toList(),
    );
  }

  String _latestVisitTextFor(_ParticipantRuntime participant) {
    for (var index = _currentLegVisits.length - 1; index >= 0; index -= 1) {
      final visit = _currentLegVisits[index];
      if (visit.side == participant.config.id) {
        if (visit.bust) {
          return 'Bust';
        }
        return '${visit.scoredPoints}';
      }
    }
    return participant.config.isHuman ? 'Bereit' : 'Noch offen';
  }

  Widget _buildVisitLogContent() {
    if (_visitLog.isEmpty) {
      return Center(
        child: Text(
          'Noch keine Aufnahmen im Leg.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF667685),
              ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _visitLog.length,
      itemBuilder: (context, index) {
        final reversedIndex = _visitLog.length - 1 - index;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _visitLog[reversedIndex],
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF344657),
                  height: 1.25,
                ),
          ),
        );
      },
    );
  }
}

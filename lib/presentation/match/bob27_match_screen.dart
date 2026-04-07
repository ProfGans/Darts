import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/background/simulation_service.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';
import 'bob27_end_screen.dart';
import 'bob27_result_models.dart';
import 'match_session_config.dart';

class Bob27MatchScreen extends StatefulWidget {
  const Bob27MatchScreen({
    required this.session,
    super.key,
  });

  final MatchSessionConfig session;

  @override
  State<Bob27MatchScreen> createState() => _Bob27MatchScreenState();
}

class _Bob27ParticipantRuntime {
  _Bob27ParticipantRuntime({
    required this.config,
  });

  final MatchParticipantConfig config;
  int score = 27;
  int totalHits = 0;
  int successfulRounds = 0;
  int roundsPlayed = 0;
  int dartsThrown = 0;
  int? eliminatedAtTarget;
  bool eliminated = false;
  int lastHits = 0;
  int lastDelta = 0;
  int perfectRounds = 0;
  int zeroHitRounds = 0;
  int bullHits = 0;
  int highestRoundDelta = 0;
  int lowestRoundDelta = 0;

  double get hitRate => dartsThrown <= 0 ? 0 : (totalHits / dartsThrown) * 100;
  bool get survived => !eliminated;
}

enum _BullOffResult {
  bull(2, 'Bull'),
  singleBull(1, 'Single Bull'),
  outside(0, 'Outside');

  const _BullOffResult(this.rank, this.label);

  final int rank;
  final String label;
}

class _Bob27MatchScreenState extends State<Bob27MatchScreen> {
  static const List<int> _standardTargets = <int>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    25,
  ];

  final X01Rules _rules = const X01Rules();
  late final BotEngine _botEngine;
  late final List<_Bob27ParticipantRuntime> _participants;
  late final List<int> _targets;

  final List<String> _visitLog = <String>[];
  int _roundIndex = 0;
  int _currentTurnIndex = 0;
  int _starterIndex = 0;
  bool _finished = false;
  String _status = '';

  bool _isBullOffActive = false;
  int _bullOffRound = 1;
  int _bullOffTurnIndex = 0;
  List<String> _bullOffOrder = <String>[];
  Map<String, _BullOffResult> _bullOffResults = <String, _BullOffResult>{};

  @override
  void initState() {
    super.initState();
    _botEngine = BotEngine();
    SimulationService.instance.applyToBotEngine(_botEngine);
    _participants = widget.session.participants
        .map((participant) => _Bob27ParticipantRuntime(config: participant))
        .toList();
    _targets = widget.session.bob27ReverseOrder
        ? _standardTargets.reversed.toList()
        : List<int>.from(_standardTargets);

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

    _startGame();
  }

  _Bob27ParticipantRuntime get _currentParticipant => _participants[_currentTurnIndex];

  _Bob27ParticipantRuntime? get _currentBullOffParticipant {
    if (!_isBullOffActive || _bullOffOrder.isEmpty) {
      return null;
    }
    final currentId = _bullOffOrder[_bullOffTurnIndex];
    final index = _participants.indexWhere((entry) => entry.config.id == currentId);
    return index < 0 ? null : _participants[index];
  }

  int get _currentTarget => _targets[_roundIndex];
  bool get _allowNegativeScores => widget.session.bob27AllowNegativeScores;
  bool get _bonusMode => widget.session.bob27BonusMode;

  DartThrowResult _targetThrow(int target) {
    return target == 25 ? _rules.createBull() : _rules.createDouble(target);
  }

  int _targetValue(int target) => target == 25 ? 50 : target * 2;

  String _targetLabel(int target) => target == 25 ? 'Bull' : 'D$target';

  List<_Bob27ParticipantRuntime> get _activeParticipants => _participants
      .where((participant) => _allowNegativeScores || !participant.eliminated)
      .toList();

  void _startGame() {
    _currentTurnIndex = _starterIndex;
    _status = '${_currentParticipant.config.name} beginnt auf ${_targetLabel(_currentTarget)}.';
    _visitLog.add('Bob\'s 27 gestartet.');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _continueBotIfNeeded();
    });
  }

  void _continueBotIfNeeded() {
    if (_finished || _isBullOffActive || _currentParticipant.config.isHuman) {
      return;
    }
    _runBotTurn();
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

  Future<void> _runBotBullOff(_Bob27ParticipantRuntime participant) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !_isBullOffActive) {
      return;
    }
    final profile = participant.config.botProfile;
    if (profile == null) {
      _submitBullOffResult(
        participantId: participant.config.id,
        result: _BullOffResult.outside,
      );
      return;
    }
    final simulation = _botEngine.simulateTargetThrow(
      target: _rules.createBull(),
      score: 50,
      profile: profile,
    );
    _submitBullOffResult(
      participantId: participant.config.id,
      result: simulation.hit.isBull
          ? _BullOffResult.bull
          : simulation.hit.label == '25'
              ? _BullOffResult.singleBull
              : _BullOffResult.outside,
    );
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
      final participant =
          _participants.firstWhere((entry) => entry.config.id == participantId);
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
      _startGame();
      return;
    }

    _bullOffRound += 1;
    _startBullOff(contenders: tiedIds, reversed: true);
  }

  Future<void> _runBotTurn() async {
    final participant = _currentParticipant;
    final profile = participant.config.botProfile;
    if (profile == null) {
      _applyTurn(hits: 0);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || _finished || _isBullOffActive || _currentParticipant != participant) {
      return;
    }

    final target = _targetThrow(_currentTarget);
    var hits = 0;
    for (var dart = 0; dart < 3; dart += 1) {
      final simulation = _botEngine.simulateTargetThrow(
        target: target,
        score: _targetValue(_currentTarget),
        profile: profile,
      );
      if (simulation.hit.label == target.label) {
        hits += 1;
      }
    }

    _applyTurn(hits: hits);
  }

  void _submitHumanTurn(int hits) {
    if (_finished || _isBullOffActive || !_currentParticipant.config.isHuman) {
      return;
    }
    _applyTurn(hits: hits.clamp(0, 3));
  }

  void _applyTurn({required int hits}) {
    if (_finished) {
      return;
    }

    final participant = _currentParticipant;
    final target = _currentTarget;
    final targetValue = _targetValue(target);
    final bonus = _bonusMode && hits >= 2 ? 10 : 0;
    final delta = (hits == 0 ? -targetValue : hits * targetValue) + bonus;
    final nextScore = participant.score + delta;

    setState(() {
      participant.roundsPlayed += 1;
      participant.dartsThrown += 3;
      participant.totalHits += hits;
      participant.lastHits = hits;
      participant.lastDelta = delta;
      if (hits == 3) {
        participant.perfectRounds += 1;
      }
      if (hits == 0) {
        participant.zeroHitRounds += 1;
      }
      if (_currentTarget == 25) {
        participant.bullHits += hits;
      }
      if (delta > participant.highestRoundDelta) {
        participant.highestRoundDelta = delta;
      }
      if (participant.roundsPlayed == 1 || delta < participant.lowestRoundDelta) {
        participant.lowestRoundDelta = delta;
      }
      if (hits > 0) {
        participant.successfulRounds += 1;
      }
      participant.score = nextScore;

      final sign = delta >= 0 ? '+' : '';
      _visitLog.add(
        '${participant.config.name}: ${_targetLabel(target)} / $hits Treffer ($sign$delta${bonus > 0 ? ', inkl. Bonus' : ''}) => ${participant.score}',
      );

      if (!_allowNegativeScores && participant.score <= 0) {
        participant.eliminated = true;
        participant.eliminatedAtTarget = target;
        _visitLog.add(
          '${participant.config.name} scheidet auf ${_targetLabel(target)} aus.',
        );
      }
    });

    _advanceFlow();
  }

  void _advanceFlow() {
    if (_shouldFinish()) {
      _finishGame();
      return;
    }

    final nextParticipantIndex = _findNextParticipantIndex(
      startExclusive: _currentTurnIndex,
    );

    if (nextParticipantIndex != null) {
      setState(() {
        _currentTurnIndex = nextParticipantIndex;
        _status = '${_currentParticipant.config.name} ist auf ${_targetLabel(_currentTarget)} am Zug.';
      });
      _continueBotIfNeeded();
      return;
    }

    if (_roundIndex >= _targets.length - 1) {
      _finishGame();
      return;
    }

    final nextRoundStarter = _findNextParticipantIndex(startExclusive: -1);
    if (nextRoundStarter == null) {
      _finishGame();
      return;
    }

    setState(() {
      _roundIndex += 1;
      _currentTurnIndex = nextRoundStarter;
      _status = 'Neues Ziel: ${_targetLabel(_currentTarget)}.';
    });
    _continueBotIfNeeded();
  }

  int? _findNextParticipantIndex({required int startExclusive}) {
    for (var offset = startExclusive + 1; offset < _participants.length; offset += 1) {
      if (_allowNegativeScores || !_participants[offset].eliminated) {
        return offset;
      }
    }
    return null;
  }

  bool _shouldFinish() {
    if (_roundIndex >= _targets.length - 1 &&
        _findNextParticipantIndex(startExclusive: _currentTurnIndex) == null) {
      return true;
    }
    return !_allowNegativeScores && _activeParticipants.isEmpty;
  }

  void _finishGame() {
    if (_finished) {
      return;
    }

    final orderedResults = List<_Bob27ParticipantRuntime>.from(_participants)
      ..sort((a, b) {
        if (a.score != b.score) {
          return b.score.compareTo(a.score);
        }
        if (a.totalHits != b.totalHits) {
          return b.totalHits.compareTo(a.totalHits);
        }
        return b.successfulRounds.compareTo(a.successfulRounds);
      });

    final winner = orderedResults.first;
    final result = Bob27ResultSummary(
      winnerParticipantId: winner.config.id,
      winnerName: winner.config.name,
      scoreText: orderedResults
          .map((participant) => '${participant.config.name}: ${participant.score}')
          .join(' | '),
      participants: orderedResults
          .map(
            (participant) => Bob27ParticipantStats(
              participantId: participant.config.id,
              name: participant.config.name,
              score: participant.score,
              hits: participant.totalHits,
              roundsPlayed: participant.roundsPlayed,
              successfulRounds: participant.successfulRounds,
              dartsThrown: participant.dartsThrown,
              completedTargets: participant.roundsPlayed,
              perfectRounds: participant.perfectRounds,
              zeroHitRounds: participant.zeroHitRounds,
              bullHits: participant.bullHits,
              highestRoundDelta: participant.highestRoundDelta,
              lowestRoundDelta: participant.lowestRoundDelta,
              survived: participant.survived || _allowNegativeScores,
              eliminatedAtTarget: participant.eliminatedAtTarget,
            ),
          )
          .toList(),
      visitLog: List<String>.from(_visitLog),
    );

    setState(() {
      _finished = true;
      _status = '${winner.config.name} hat Bob\'s 27 gewonnen.';
    });
    _recordMatchHistory(result);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => Bob27EndScreen(
          winnerName: winner.config.name,
          returnButtonLabel: widget.session.returnButtonLabel,
          results: result.participants,
        ),
      ),
    );
  }

  void _recordMatchHistory(Bob27ResultSummary result) {
    if (_participants.length != 2) {
      return;
    }

    final first = _participants[0];
    final second = _participants[1];

    if (first.config.isHuman) {
      PlayerRepository.instance.recordBob27Match(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: first.hitRate,
        opponentType: second.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordBob27Match(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: first.hitRate,
      );
    }

    if (second.config.isHuman) {
      PlayerRepository.instance.recordBob27Match(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: second.hitRate,
        opponentType: first.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordBob27Match(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: second.hitRate,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBullOffActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Bob\'s 27'),
        ),
        body: SafeArea(
          child: _buildBullOffView(),
        ),
      );
    }

    final current = _currentParticipant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bob\'s 27'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF17324D),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _targetLabel(_currentTarget),
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Runde ${_roundIndex + 1} von ${_targets.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: const Color(0xFFAFCCE4)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF244567),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${_targetValue(_currentTarget)} Punkte',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _TopBadge(
                        label: _allowNegativeScores ? 'Easy' : 'Classic',
                      ),
                      if (_bonusMode)
                        const _TopBadge(label: 'Bonus +10'),
                      if (widget.session.bob27ReverseOrder)
                        const _TopBadge(label: 'Reverse'),
                      _TopBadge(label: current.config.isHuman ? 'Mensch' : 'Computer'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._participants.map(
              (participant) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: participant == current
                        ? const Color(0xFFF7FBFF)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: participant == current
                          ? const Color(0xFF6DC4FF)
                          : const Color(0xFFE7EEF5),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 50,
                        decoration: BoxDecoration(
                          color: participant == current
                              ? const Color(0xFF58B4F5)
                              : const Color(0xFFD9E4EF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              participant.config.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Treffer ${participant.totalHits} | Quote ${participant.hitRate.toStringAsFixed(1)}%',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF5B6A79),
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: <Widget>[
                                _statChip('SR', '${participant.successfulRounds}'),
                                _statChip('3H', '${participant.perfectRounds}'),
                                _statChip('0H', '${participant.zeroHitRounds}'),
                                _statChip('Bull', '${participant.bullHits}'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              participant.eliminated && !_allowNegativeScores
                                  ? 'Ausgeschieden auf ${_targetLabel(participant.eliminatedAtTarget ?? _currentTarget)}'
                                  : 'Letzte Runde: ${participant.lastHits} Treffer (${participant.lastDelta >= 0 ? '+' : ''}${participant.lastDelta})',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF5B6A79),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${participant.score}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF17324D),
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: current.config.isHuman
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${current.config.name}: Wie viele Treffer auf ${_targetLabel(_currentTarget)}?',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Waehle direkt 0 bis 3 Treffer fuer diese Aufnahme.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5B6A79),
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: List<Widget>.generate(4, (index) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: index < 3 ? 10 : 0,
                                ),
                                child: FilledButton(
                                  onPressed: () => _submitHumanTurn(index),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                  ),
                                  child: Text('$index'),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${current.config.name} wirft auf ${_targetLabel(_currentTarget)}.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        const LinearProgressIndicator(minHeight: 8),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Verlauf',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ..._visitLog.reversed.take(8).map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        entry,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4F5E6C),
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBullOffView() {
    final currentParticipant = _currentBullOffParticipant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Ausbullen',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _bullOffRound == 1
                      ? 'Bull, Single Bull oder Outside bestimmen den Starter fuer Bob\'s 27.'
                      : 'Gleichstand. Nur die beteiligten Spieler werfen erneut in umgekehrter Reihenfolge.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D6B78),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 18),
                if (currentParticipant != null) ...<Widget>[
                  Text(
                    '${currentParticipant.config.name} ist dran.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentParticipant.config.isHuman
                        ? 'Waehle das Ergebnis direkt aus.'
                        : 'Computer wirft automatisch auf Bull.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D6B78),
                        ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _buildBullOffButton(
                        'Bull',
                        () => _submitBullOffResult(
                          participantId: currentParticipant!.config.id,
                          result: _BullOffResult.bull,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBullOffButton(
                        'Single Bull',
                        () => _submitBullOffResult(
                          participantId: currentParticipant!.config.id,
                          result: _BullOffResult.singleBull,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildBullOffButton(
                        'Outside',
                        () => _submitBullOffResult(
                          participantId: currentParticipant!.config.id,
                          result: _BullOffResult.outside,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListView(
                children: _visitLog.reversed
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(entry),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullOffButton(String label, VoidCallback onPressed) {
    final currentParticipant = _currentBullOffParticipant;
    final enabled = currentParticipant != null && currentParticipant.config.isHuman;
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label),
    );
  }

  Widget _statChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFF4F5E6C),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF244567),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

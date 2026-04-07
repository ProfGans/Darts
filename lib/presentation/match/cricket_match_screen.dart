import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/background/simulation_service.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';
import 'cricket_end_screen.dart';
import 'game_mode_models.dart';
import 'cricket_result_models.dart';
import 'match_session_config.dart';

class CricketMatchScreen extends StatefulWidget {
  const CricketMatchScreen({
    required this.session,
    super.key,
  });

  final MatchSessionConfig session;

  @override
  State<CricketMatchScreen> createState() => _CricketMatchScreenState();
}

class _CricketParticipantRuntime {
  _CricketParticipantRuntime({
    required this.config,
  }) : marks = <int, int>{
          for (final target in _CricketMatchScreenState._targets) target: 0,
        };

  final MatchParticipantConfig config;
  final Map<int, int> marks;
  int points = 0;
  int dartsThrown = 0;
  int turns = 0;
  int totalMarks = 0;
  int roundsWithMarks = 0;
  int highestScoringRound = 0;
  int bestMarksRound = 0;
  final Map<int, int> targetHits = <int, int>{
    20: 0,
    19: 0,
    18: 0,
    17: 0,
    16: 0,
    15: 0,
    25: 0,
  };

  double get marksPerRound => dartsThrown <= 0 ? 0 : (totalMarks / dartsThrown) * 3;
  int get closedTargets => marks.values.where((value) => value >= 3).length;
}

enum _BullOffResult {
  bull(2, 'Bull'),
  singleBull(1, 'Single Bull'),
  outside(0, 'Outside');

  const _BullOffResult(this.rank, this.label);

  final int rank;
  final String label;
}

class _CricketMatchScreenState extends State<CricketMatchScreen> {
  static const List<int> _targets = <int>[20, 19, 18, 17, 16, 15, 25];

  final X01Rules _rules = const X01Rules();
  late final BotEngine _botEngine;
  late final List<_CricketParticipantRuntime> _participants;

  int _currentTurnIndex = 0;
  int _starterIndex = 0;
  bool _matchFinished = false;
  String _status = '';
  List<DartThrowResult> _currentThrows = <DartThrowResult>[];
  final List<String> _visitLog = <String>[];

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
        .map((participant) => _CricketParticipantRuntime(config: participant))
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
    _startGame();
  }

  _CricketParticipantRuntime get _currentParticipant => _participants[_currentTurnIndex];

  _CricketParticipantRuntime? get _currentBullOffParticipant {
    if (!_isBullOffActive || _bullOffOrder.isEmpty) {
      return null;
    }
    final currentId = _bullOffOrder[_bullOffTurnIndex];
    final index = _participants.indexWhere((entry) => entry.config.id == currentId);
    return index < 0 ? null : _participants[index];
  }

  void _startGame() {
    _currentTurnIndex = _starterIndex;
    _currentThrows = <DartThrowResult>[];
    _status = '${_participants[_starterIndex].config.name} beginnt.';
    _visitLog.add('Cricket gestartet.');
    _continueBotIfNeeded();
  }

  void _advanceTurn() {
    _currentTurnIndex = (_currentTurnIndex + 1) % _participants.length;
    _currentThrows = <DartThrowResult>[];
    _status = '${_currentParticipant.config.name} ist am Zug.';
  }

  void _continueBotIfNeeded() {
    if (!_matchFinished && !_isBullOffActive && !_currentParticipant.config.isHuman) {
      _runBotTurn();
    }
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

  Future<void> _runBotBullOff(_CricketParticipantRuntime participant) async {
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

  void _appendThrow(DartThrowResult dartThrow) {
    if (_matchFinished || !_currentParticipant.config.isHuman) {
      return;
    }
    if (_currentThrows.length >= 3) {
      return;
    }
    setState(() {
      _currentThrows = <DartThrowResult>[..._currentThrows, dartThrow];
    });
  }

  void _undoThrow() {
    if (_currentThrows.isEmpty) {
      return;
    }
    setState(() {
      _currentThrows = List<DartThrowResult>.from(_currentThrows)..removeLast();
    });
  }

  Future<void> _runBotTurn() async {
    if (!mounted || _matchFinished || _currentParticipant.config.isHuman) {
      return;
    }

    final participant = _currentParticipant;
    setState(() {
      _status = '${participant.config.name} wirft...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted ||
        _matchFinished ||
        _currentParticipant.config.isHuman ||
        _currentParticipant.config.id != participant.config.id) {
      return;
    }

    final throws = <DartThrowResult>[];
    for (var dart = 0; dart < 3; dart += 1) {
      final target = _chooseBotCricketTarget(participant);
      final simulation = _botEngine.simulateTargetThrow(
        target: target,
        score: target.isBull || target.label == '25' ? 50 : 501,
        profile: participant.config.botProfile!,
      );
      throws.add(simulation.hit);
    }

    _applyVisit(participant, throws);
  }

  DartThrowResult _chooseBotCricketTarget(_CricketParticipantRuntime participant) {
    for (final target in _targets) {
      if ((participant.marks[target] ?? 0) < 3) {
        return _aimThrowForTarget(target, participant.points);
      }
    }

    final highestOpponentPoints = _participants
        .where((entry) => entry.config.id != participant.config.id)
        .map((entry) => entry.points)
        .fold<int>(0, (best, next) => next > best ? next : best);

    if (participant.points < highestOpponentPoints) {
      for (final target in _targets) {
        final anyOpponentOpen = _participants.any(
          (entry) =>
              entry.config.id != participant.config.id &&
              (entry.marks[target] ?? 0) < 3,
        );
        if (anyOpponentOpen) {
          return _aimThrowForTarget(target, participant.points);
        }
      }
    }

    return _rules.createTriple(20);
  }

  DartThrowResult _aimThrowForTarget(int target, int currentPoints) {
    if (target == 25) {
      return currentPoints >= 25 ? _rules.createBull() : _rules.createOuterBull();
    }
    return _rules.createTriple(target);
  }

  void _submitHumanVisit() {
    if (_matchFinished || !_currentParticipant.config.isHuman || _currentThrows.isEmpty) {
      return;
    }
    _applyVisit(_currentParticipant, _currentThrows);
  }

  void _applyVisit(
    _CricketParticipantRuntime participant,
    List<DartThrowResult> throws,
  ) {
    final updatedThrows = List<DartThrowResult>.from(throws);
    setState(() {
      participant.turns += 1;
      participant.dartsThrown += updatedThrows.length;
      var visitMarks = 0;
      var visitPoints = 0;

      for (final dartThrow in updatedThrows) {
        final marks = _marksForThrow(dartThrow);
        if (marks <= 0) {
          continue;
        }
        final target = dartThrow.isBull || dartThrow.label == '25'
            ? 25
            : dartThrow.baseValue;
        if (!_targets.contains(target)) {
          continue;
        }

        participant.totalMarks += marks;
        visitMarks += marks;
        participant.targetHits[target] = (participant.targetHits[target] ?? 0) + marks;
        final currentMarks = participant.marks[target] ?? 0;
        final nextMarks = (currentMarks + marks).clamp(0, 3);
        final overflow = currentMarks + marks > 3 ? currentMarks + marks - 3 : 0;
        final anyOpponentOpen = _participants.any(
          (entry) =>
              entry.config.id != participant.config.id && (entry.marks[target] ?? 0) < 3,
        );

        participant.marks[target] = nextMarks;
        if (overflow > 0 && anyOpponentOpen) {
          final overflowPoints = target == 25 ? overflow * 25 : overflow * target;
          participant.points += overflowPoints;
          visitPoints += overflowPoints;
        }
      }

      if (visitMarks > 0) {
        participant.roundsWithMarks += 1;
      }
      if (visitPoints > participant.highestScoringRound) {
        participant.highestScoringRound = visitPoints;
      }
      if (visitMarks > participant.bestMarksRound) {
        participant.bestMarksRound = visitMarks;
      }

      _visitLog.add(
        '${participant.config.name}: ${updatedThrows.map((entry) => entry.label).join(' - ')}',
      );

      if (_hasWon(participant)) {
        final result = CricketResultSummary(
          winnerParticipantId: participant.config.id,
          winnerName: participant.config.name,
          scoreText: _participants
              .map((entry) => '${entry.config.name}: ${entry.points}')
              .join(' | '),
          participants: _participants
              .map(
                (entry) => CricketParticipantStats(
                  participantId: entry.config.id,
                  name: entry.config.name,
                  points: entry.points,
                  dartsThrown: entry.dartsThrown,
                  turns: entry.turns,
                  totalMarks: entry.totalMarks,
                  closedTargets: entry.closedTargets,
                  targetHits20: entry.targetHits[20] ?? 0,
                  targetHits19: entry.targetHits[19] ?? 0,
                  targetHits18: entry.targetHits[18] ?? 0,
                  targetHits17: entry.targetHits[17] ?? 0,
                  targetHits16: entry.targetHits[16] ?? 0,
                  targetHits15: entry.targetHits[15] ?? 0,
                  bullMarks: entry.targetHits[25] ?? 0,
                  roundsWithMarks: entry.roundsWithMarks,
                  highestScoringRound: entry.highestScoringRound,
                  bestMarksRound: entry.bestMarksRound,
                ),
              )
              .toList(),
          visitLog: List<String>.from(_visitLog),
        );

        _matchFinished = true;
        _status = '${participant.config.name} gewinnt Cricket.';
        _recordMatchHistory(result);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => CricketEndScreen(
                winnerName: participant.config.name,
                results: result.participants,
                returnButtonLabel: widget.session.returnButtonLabel ?? 'Zurueck',
              ),
            ),
          );
        });
        return;
      }

      _advanceTurn();
    });

    _continueBotIfNeeded();
  }

  int _marksForThrow(DartThrowResult dartThrow) {
    if (dartThrow.isMiss) {
      return 0;
    }
    if (dartThrow.isBull) {
      return 2;
    }
    if (dartThrow.label == '25') {
      return 1;
    }
    if (dartThrow.isTriple) {
      return 3;
    }
    if (dartThrow.isDouble) {
      return 2;
    }
    return 1;
  }

  bool _hasWon(_CricketParticipantRuntime participant) {
    if (_targets.any((target) => (participant.marks[target] ?? 0) < 3)) {
      return false;
    }
    return _participants.every((entry) {
      if (entry.config.id == participant.config.id) {
        return true;
      }
      return participant.points >= entry.points;
    });
  }

  void _recordMatchHistory(CricketResultSummary result) {
    if (_participants.length != 2) {
      return;
    }

    final first = _participants[0];
    final second = _participants[1];

    if (first.config.isHuman) {
      PlayerRepository.instance.recordCricketMatch(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: first.marksPerRound,
        opponentType: second.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordCricketMatch(
        playerId: first.config.id,
        opponentName: second.config.name,
        won: result.winnerParticipantId == first.config.id,
        result: result,
        average: first.marksPerRound,
      );
    }

    if (second.config.isHuman) {
      PlayerRepository.instance.recordCricketMatch(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: second.marksPerRound,
        opponentType: first.config.isHuman
            ? PlayerOpponentKind.human
            : PlayerOpponentKind.cpu,
      );
    } else {
      ComputerRepository.instance.recordCricketMatch(
        playerId: second.config.id,
        opponentName: first.config.name,
        won: result.winnerParticipantId == second.config.id,
        result: result,
        average: second.marksPerRound,
      );
    }
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
              child: Column(
                children: <Widget>[
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Expanded(
                          flex: 36,
                          child: _buildScoreZone(),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 44,
                          child: _buildInputZone(),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          flex: 20,
                          child: _buildInfoZone(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                '${GameMode.cricket.title} Match',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                '20 bis 15 und Bull',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6B78),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreZone() {
    return _buildSurface(
      color: const Color(0xFF152C45),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _status,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _participants.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF2C4967)),
              itemBuilder: (context, index) {
                final participant = _participants[index];
                final isActive =
                    !_matchFinished && _currentParticipant.config.id == participant.config.id;
                return _buildParticipantRow(participant, isActive);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantRow(
    _CricketParticipantRuntime participant,
    bool isActive,
  ) {
    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 56,
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
              Text(
                participant.config.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Punkte ${participant.points} | MPR ${participant.marksPerRound.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBBD1E4),
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _buildTargetPill('P', '${participant.points}'),
                  _buildTargetPill('MPR', participant.marksPerRound.toStringAsFixed(2)),
                  _buildTargetPill('Hits', '${participant.totalMarks}'),
                  _buildTargetPill('Best', '${participant.bestMarksRound}M'),
                  ..._targets.map(
                    (target) => _buildTargetPill(
                      target == 25 ? 'B' : '$target',
                      '${participant.marks[target] ?? 0}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF26425E),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: const Color(0xFFD6E4EF),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  Widget _buildInputZone() {
    return _buildSurface(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _currentParticipant.config.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentParticipant.config.isHuman
                        ? 'Drei Darts direkt als S, D oder T eintragen'
                        : 'Computerzug wird automatisch gespielt',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667685),
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _currentThrows.isEmpty
                          ? <Widget>[
                              Text(
                                'Noch keine Darts erfasst',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF667685),
                                    ),
                              ),
                            ]
                          : _currentThrows
                              .map(
                                (dartThrow) => Chip(
                                  label: Text(dartThrow.label),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCompactTargetGrid(),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildSpecialThrowButton(
                          'SBull',
                          _rules.createOuterBull(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSpecialThrowButton(
                          'Bull',
                          _rules.createBull(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSpecialThrowButton(
                          'Miss',
                          _rules.createMiss(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: _currentParticipant.config.isHuman ? _undoThrow : null,
                          child: const Text('Undo'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed:
                              _currentParticipant.config.isHuman ? _submitHumanVisit : null,
                          child: const Text('Besuch buchen'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompactTargetGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _targets
              .where((target) => target != 25)
              .map(
                (target) => SizedBox(
                  width: itemWidth,
                  child: _buildTargetEntry(target),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildTargetEntry(int number) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _buildQuickThrowButton(
                    'S',
                    _rules.createSingle(number),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildQuickThrowButton(
                    'D',
                    _rules.createDouble(number),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildQuickThrowButton(
                    'T',
                    _rules.createTriple(number),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickThrowButton(String label, DartThrowResult dartThrow) {
    return FilledButton.tonal(
      onPressed: _currentParticipant.config.isHuman ? () => _appendThrow(dartThrow) : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }

  Widget _buildSpecialThrowButton(String label, DartThrowResult dartThrow) {
    return FilledButton.tonal(
      onPressed: _currentParticipant.config.isHuman ? () => _appendThrow(dartThrow) : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Text(label),
    );
  }

  Widget _buildInfoZone() {
    return _buildSurface(
      color: const Color(0xFFEAF0F4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: _visitLog.isEmpty
          ? Center(
              child: Text(
                'Noch kein Besuch.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667685),
                    ),
              ),
            )
          : ListView.builder(
              itemCount: _visitLog.length,
              itemBuilder: (context, index) {
                final reversedIndex = _visitLog.length - 1 - index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    _visitLog[reversedIndex],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBullOffView() {
    final currentParticipant = _currentBullOffParticipant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildTopBar(),
        const SizedBox(height: 12),
        Expanded(
          child: _buildSurface(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                      ? 'Bull, Single Bull oder Outside bestimmen den Starter.'
                      : 'Gleichstand. Nur die beteiligten Spieler werfen erneut in umgekehrter Reihenfolge.',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bullOffOrder.map((participantId) {
                    final participant = _participants.firstWhere(
                      (entry) => entry.config.id == participantId,
                    );
                    final result = _bullOffResults[participantId];
                    return Chip(
                      label: Text(
                        result == null
                            ? participant.config.name
                            : '${participant.config.name}: ${result.label}',
                      ),
                    );
                  }).toList(),
                ),
                const Spacer(),
                if (currentParticipant != null && currentParticipant.config.isHuman)
                  Column(
                    children: <Widget>[
                      _buildBullOffButton(
                        'Bull',
                        () => _submitBullOffResult(
                          participantId: currentParticipant.config.id,
                          result: _BullOffResult.bull,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildBullOffButton(
                        'Single Bull',
                        () => _submitBullOffResult(
                          participantId: currentParticipant.config.id,
                          result: _BullOffResult.singleBull,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildBullOffButton(
                        'Outside',
                        () => _submitBullOffResult(
                          participantId: currentParticipant.config.id,
                          result: _BullOffResult.outside,
                        ),
                      ),
                    ],
                  )
                else
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBullOffButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
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
}

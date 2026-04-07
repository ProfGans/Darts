import 'dart:math';

import '../../data/background/simulation_snapshot.dart';
import '../bot/bot_engine.dart';
import '../x01/x01_match_engine.dart';
import '../x01/x01_match_simulator.dart';
import '../x01/x01_models.dart';
import 'tournament_models.dart';

class TournamentEngine {
  TournamentEngine()
      : _simulator = X01MatchSimulator(
          matchEngine: X01MatchEngine(),
          botEngine: BotEngine(),
        );

  final X01MatchSimulator _simulator;
  bool _commonSimulationCachesPrepared = false;

  void resetPerformanceTotals() {
    _simulator.resetPerformanceTotals();
    _simulator.botEngine.resetPerformanceTotals();
  }

  bool get commonSimulationCachesPrepared => _commonSimulationCachesPrepared;

  Map<String, Object?> exportDeterministicWarmupTables() {
    return <String, Object?>{
      'version': simulationWarmupSnapshotVersion,
      'schema': simulationWarmupSnapshotSchema,
      'appVersion': simulationWarmupSnapshotAppVersion,
      'bot': _simulator.botEngine.exportDeterministicTables(),
      'x01': _simulator.exportDeterministicTables(),
    };
  }

  void importDeterministicWarmupTables(Map<String, Object?> json) {
    final bot =
        ((json['bot'] as Map?) ?? const <Object?, Object?>{})
            .cast<String, Object?>();
    final x01 =
        ((json['x01'] as Map?) ?? const <Object?, Object?>{})
            .cast<String, Object?>();
    _simulator.botEngine.importDeterministicTables(bot);
    _simulator.importDeterministicTables(x01);
  }

  Future<void> prepareCommonSimulationCaches({
    required Iterable<BotProfile> profiles,
    void Function(String label, double? progress)? onProgress,
  }) async {
    if (_commonSimulationCachesPrepared) {
      return;
    }
    final prepProfiles = <BotProfile>[
      const BotProfile(skill: 700, finishingSkill: 300),
      const BotProfile(skill: 700, finishingSkill: 700),
      ...profiles,
    ];
    final uniqueProfiles = _selectRepresentativeWarmupProfiles(prepProfiles);
    final warmupScores = _buildWarmupScores();
    final totalSteps = warmupScores.length.clamp(1, 1 << 30);
    onProgress?.call('Simulationsdaten werden vorbereitet', 0);
    await Future<void>.delayed(Duration.zero);
    for (var index = 0; index < warmupScores.length; index += 1) {
      final score = warmupScores[index];
      for (var dartsLeft = 1; dartsLeft <= 3; dartsLeft += 1) {
        for (final profile in uniqueProfiles) {
          _simulator.botEngine.decideAim(
            profile: profile,
            score: score,
            dartsRemaining: dartsLeft,
          );
        }
      }
      _simulator.botEngine.findPreferredLeaveTarget(score);
      for (final checkoutRequirement in CheckoutRequirement.values) {
        _simulator.warmCheckoutOpportunityCache(
          score: score,
          checkoutRequirement: checkoutRequirement,
        );
      }
      if ((index + 1) % 6 == 0 || index == warmupScores.length - 1) {
        onProgress?.call(
          'Simulationsdaten werden vorbereitet (${index + 1}/$totalSteps)',
          (index + 1) / totalSteps,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
    }
    _warmReferenceMatches(uniqueProfiles);
    _simulator.botEngine.compactSimulationCaches();
    _commonSimulationCachesPrepared = true;
    onProgress?.call('Simulationsdaten sind bereit', 1);
  }

  List<BotProfile> _selectRepresentativeWarmupProfiles(
    Iterable<BotProfile> profiles,
  ) {
    final byBucket = <String, BotProfile>{};
    for (final profile in profiles) {
      final skillBucket = (profile.skill / 180).floor().clamp(0, 6);
      final finishingBucket =
          (profile.finishingSkill / 180).floor().clamp(0, 6);
      final key =
          '$skillBucket|$finishingBucket|${profile.radiusCalibrationPercent}|${profile.simulationSpreadPercent}';
      byBucket.putIfAbsent(key, () => profile);
      if (byBucket.length >= 3) {
        break;
      }
    }
    return byBucket.values.toList(growable: false);
  }

  List<int> _buildWarmupScores() {
    const scores = <int>[
      2,
      4,
      8,
      16,
      20,
      24,
      32,
      36,
      40,
      48,
      50,
      56,
      60,
      61,
      62,
      64,
      66,
      68,
      70,
      72,
      75,
      78,
      80,
      81,
      82,
      85,
      90,
      95,
      97,
      99,
      100,
      101,
      104,
      107,
      110,
      115,
      120,
      121,
      124,
      127,
      130,
      132,
      135,
      138,
      140,
      145,
      150,
      155,
      160,
      164,
      167,
      170,
    ];
    return scores.toList(growable: false);
  }

  void _warmReferenceMatches(List<BotProfile> profiles) {
    if (profiles.isEmpty) {
      return;
    }
    final sampleProfile =
        profiles.length > 1 ? profiles[profiles.length ~/ 2] : profiles.first;
    const config = MatchConfig(
      startScore: 501,
      mode: MatchMode.legs,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      legsToWin: 1,
    );
    final player = SimulatedPlayer(
      name: 'Warmup',
      profile: sampleProfile,
    );
    _simulator.simulateAutoMatch(
      playerA: player,
      playerB: player,
      config: config,
      detailed: false,
      random: Random(7000),
    );
  }

  void compactSimulationCaches() {
    _simulator.botEngine.compactSimulationCaches();
    _simulator.compactSimulationCaches();
  }

  TournamentSimulationBatch simulateMatchesBatch({
    required TournamentBracket bracket,
    required BotProfile Function(String participantId) profileProvider,
    required bool includeHumanMatches,
    required int maxMatches,
  }) {
    return _simulateMatchesBatchFast(
      bracket: bracket,
      profileProvider: profileProvider,
      includeHumanMatches: includeHumanMatches,
      maxMatches: maxMatches,
    );
  }

  TournamentSimulationBatch _simulateMatchesBatchFast({
    required TournamentBracket bracket,
    required BotProfile Function(String participantId) profileProvider,
    required bool includeHumanMatches,
    required int maxMatches,
  }) {
    final rounds = _cloneRounds(bracket.rounds);
    var workingBracket = TournamentBracket(
      definition: bracket.definition,
      participants: bracket.participants,
      rounds: rounds,
    );
    var simulatedMatches = 0;

    while (!workingBracket.isCompleted && simulatedMatches < maxMatches) {
      if (workingBracket.definition.format == TournamentFormat.leaguePlayoff &&
          workingBracket.playoffRounds.isEmpty &&
          _allRoundsCompleted(workingBracket.leagueRounds)) {
        final playoffRounds = _buildPlayoffRounds(workingBracket);
        if (playoffRounds.isNotEmpty) {
          rounds.addAll(playoffRounds);
          workingBracket = TournamentBracket(
            definition: workingBracket.definition,
            participants: workingBracket.participants,
            rounds: rounds,
          );
          _autoAdvanceByesInPlace(
            participants: workingBracket.participants,
            rounds: rounds,
          );
          workingBracket = TournamentBracket(
            definition: workingBracket.definition,
            participants: workingBracket.participants,
            rounds: rounds,
          );
          continue;
        }
      }

      final nextMatchRef = _findNextSimulatableMatch(
        rounds,
        includeHumanMatches: includeHumanMatches,
      );
      if (nextMatchRef == null) {
        return TournamentSimulationBatch(
          bracket: workingBracket,
          simulatedMatches: simulatedMatches,
          madeProgress: false,
        );
      }

      final match = rounds[nextMatchRef.roundIndex].matches[nextMatchRef.matchIndex];
      final playerA = match.playerA!;
      final playerB = match.playerB!;
      final matchConfig = MatchConfig(
        startScore: workingBracket.definition.startScore,
        mode: workingBracket.definition.matchMode,
        startRequirement: workingBracket.definition.startRequirement,
        checkoutRequirement: workingBracket.definition.checkoutRequirement,
        legsToWin: _legsToWinForMatch(
          bracket: workingBracket,
          roundNumber: match.roundNumber,
        ),
        setsToWin: _setsToWinForMatch(
          bracket: workingBracket,
          roundNumber: match.roundNumber,
        ),
        legsPerSet: workingBracket.definition.legsPerSet,
      );
      final simulation = _simulator.simulateAutoMatch(
        playerA: SimulatedPlayer(
          name: playerA.name,
          profile: profileProvider(playerA.id),
        ),
        playerB: SimulatedPlayer(
          name: playerB.name,
          profile: profileProvider(playerB.id),
        ),
        config: matchConfig,
        detailed: false,
      );
      final winner = simulation.winner.name == playerA.name ? playerA : playerB;
      final result = TournamentMatchResult(
        winnerId: winner.id,
        winnerName: winner.name,
        scoreText: simulation.scoreText,
        participantStats: _participantStatsFromSimulation(
          simulation: simulation,
          playerA: playerA,
          playerB: playerB,
        ),
      );

      _applyResultInPlace(
        rounds: rounds,
        participants: workingBracket.participants,
        roundIndex: nextMatchRef.roundIndex,
        matchIndex: nextMatchRef.matchIndex,
        result: result,
        format: workingBracket.definition.format,
      );
      simulatedMatches += 1;
      workingBracket = TournamentBracket(
        definition: workingBracket.definition,
        participants: workingBracket.participants,
        rounds: rounds,
      );
    }

    return TournamentSimulationBatch(
      bracket: workingBracket,
      simulatedMatches: simulatedMatches,
      madeProgress: simulatedMatches > 0,
    );
  }

  TournamentBracket buildBracket({
    required TournamentDefinition definition,
    required List<TournamentParticipant> participants,
  }) {
    final orderedParticipants = List<TournamentParticipant>.from(participants)
      ..sort((left, right) {
        final leftSeed = left.seedNumber ?? 1 << 20;
        final rightSeed = right.seedNumber ?? 1 << 20;
        final seedCompare = leftSeed.compareTo(rightSeed);
        if (seedCompare != 0) {
          return seedCompare;
        }
        return right.average.compareTo(left.average);
      });

    final seededParticipants = <TournamentParticipant>[];
    for (var index = 0; index < orderedParticipants.length; index += 1) {
      final participant = orderedParticipants[index];
      seededParticipants.add(
        TournamentParticipant(
          id: participant.id,
          name: participant.name,
          type: participant.type,
          average: participant.average,
          entryRound: participant.entryRound,
          seedNumber: participant.seedNumber ?? index + 1,
          qualificationReason: participant.qualificationReason,
          botSkill: participant.botSkill,
          botFinishingSkill: participant.botFinishingSkill,
        ),
      );
    }

    if (definition.format == TournamentFormat.league ||
        definition.format == TournamentFormat.leaguePlayoff) {
      return TournamentBracket(
        definition: definition,
        participants: seededParticipants,
        rounds: _buildLeagueRounds(
          participants: seededParticipants,
          repeatCount: definition.roundRobinRepeats,
        ),
      );
    }

    final bracketSize = _bracketSizeFor(
      max(definition.fieldSize, seededParticipants.length),
    );
    final rounds = <TournamentRound>[
      TournamentRound(
        roundNumber: 1,
        title: _roundTitle(1, bracketSize),
        matches: List<TournamentMatch>.generate(
          bracketSize ~/ 2,
          (index) => TournamentMatch(
            id: 'r1-m${index + 1}',
            roundNumber: 1,
            matchNumber: index + 1,
            playerA: null,
            playerB: null,
            status: TournamentMatchStatus.pending,
          ),
        ),
      ),
    ];

    var matchesInRound = bracketSize ~/ 2;
    var roundNumber = 2;
    while (matchesInRound > 1) {
      matchesInRound ~/= 2;
      rounds.add(
        TournamentRound(
          roundNumber: roundNumber,
          title: _roundTitle(roundNumber, bracketSize),
          matches: List<TournamentMatch>.generate(
            matchesInRound,
            (index) => TournamentMatch(
              id: 'r$roundNumber-m${index + 1}',
              roundNumber: roundNumber,
              matchNumber: index + 1,
              playerA: null,
              playerB: null,
              status: TournamentMatchStatus.pending,
            ),
          ),
        ),
      );
      roundNumber += 1;
    }

    return _autoAdvanceByes(
      TournamentBracket(
        definition: definition,
        participants: seededParticipants,
        rounds: _assignKnockoutParticipants(
          rounds: rounds,
          participants: seededParticipants,
          bracketSize: bracketSize,
        ),
      ),
    );
  }

  List<TournamentRound> buildLeagueRounds({
    required List<TournamentParticipant> participants,
    required int repeatCount,
  }) {
    return _buildLeagueRounds(
      participants: participants,
      repeatCount: repeatCount,
    );
  }

  TournamentBracket ensureLeaguePlayoffRounds(TournamentBracket bracket) {
    if (bracket.definition.format != TournamentFormat.leaguePlayoff) {
      return bracket;
    }
    if (bracket.playoffRounds.isNotEmpty) {
      return _advancePlayoffWinners(bracket);
    }
    if (!_allRoundsCompleted(bracket.leagueRounds)) {
      return bracket;
    }
    return _autoAdvanceByes(
      TournamentBracket(
        definition: bracket.definition,
        participants: bracket.participants,
        rounds: <TournamentRound>[
          ...bracket.rounds,
          ..._buildPlayoffRounds(bracket),
        ],
      ),
    );
  }

  List<TournamentRound> _assignKnockoutParticipants({
    required List<TournamentRound> rounds,
    required List<TournamentParticipant> participants,
    required int bracketSize,
  }) {
    final nextRounds = rounds
        .map(
          (round) => TournamentRound(
            roundNumber: round.roundNumber,
            title: round.title,
            stage: round.stage,
            matches: List<TournamentMatch>.from(round.matches),
          ),
        )
        .toList();
    final reservedLeaves = List<bool>.filled(bracketSize, false);

    for (final participant in participants) {
      final entryRound = participant.entryRound < 1
          ? 1
          : (participant.entryRound > nextRounds.length
              ? nextRounds.length
              : participant.entryRound);
      final blockSize = 1 << (entryRound - 1);
      final slotCount = bracketSize ~/ blockSize;
      int? selectedSlot;

      for (final slot in _slotOrderForRound(
        bracketSize: bracketSize,
        roundNumber: entryRound,
      )) {
        if (slot < 0 || slot >= slotCount) {
          continue;
        }
        final leafStart = slot * blockSize;
        var isFree = true;
        for (var leafIndex = leafStart;
            leafIndex < leafStart + blockSize;
            leafIndex += 1) {
          if (reservedLeaves[leafIndex]) {
            isFree = false;
            break;
          }
        }
        if (isFree) {
          selectedSlot = slot;
          for (var leafIndex = leafStart;
              leafIndex < leafStart + blockSize;
              leafIndex += 1) {
            reservedLeaves[leafIndex] = true;
          }
          break;
        }
      }

      if (selectedSlot == null) {
        continue;
      }

      final roundIndex = entryRound - 1;
      final matchIndex = selectedSlot ~/ 2;
      final match = nextRounds[roundIndex].matches[matchIndex];
      final updatedMatch = selectedSlot.isEven
          ? match.copyWith(playerA: participant)
          : match.copyWith(playerB: participant);
      final updatedMatches = List<TournamentMatch>.from(nextRounds[roundIndex].matches)
        ..[matchIndex] = updatedMatch;
      nextRounds[roundIndex] = TournamentRound(
        roundNumber: nextRounds[roundIndex].roundNumber,
        title: nextRounds[roundIndex].title,
        stage: nextRounds[roundIndex].stage,
        matches: updatedMatches,
      );
    }

    return nextRounds;
  }

  TournamentBracket _autoAdvanceByes(TournamentBracket bracket) {
    var workingBracket = bracket;
    while (true) {
      final nextEmptyMatch = _nextEmptyMatch(workingBracket);
      if (nextEmptyMatch != null) {
        workingBracket = applyResult(
          bracket: workingBracket,
          matchId: nextEmptyMatch.id,
          result: const TournamentMatchResult(
            scoreText: 'Kein Match',
          ),
        );
        continue;
      }
      final nextByeMatch = _nextByeMatch(workingBracket);
      if (nextByeMatch == null) {
        return workingBracket;
      }
      final winner = nextByeMatch.playerA ?? nextByeMatch.playerB;
      if (winner == null) {
        return workingBracket;
      }
      workingBracket = applyResult(
        bracket: workingBracket,
        matchId: nextByeMatch.id,
        result: TournamentMatchResult(
          winnerId: winner.id,
          winnerName: winner.name,
          scoreText: 'Freilos',
        ),
      );
    }
  }

  TournamentMatch? _nextEmptyMatch(TournamentBracket bracket) {
    for (var roundIndex = 0; roundIndex < bracket.rounds.length; roundIndex += 1) {
      final round = bracket.rounds[roundIndex];
      for (var matchIndex = 0; matchIndex < round.matches.length; matchIndex += 1) {
        final match = round.matches[matchIndex];
        final isEmptyMatch = match.playerA == null && match.playerB == null;
        if (match.status != TournamentMatchStatus.pending || !isEmptyMatch) {
          continue;
        }
        if (_canResolveByeMatch(
          bracket: bracket,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        )) {
          return match;
        }
      }
    }
    return null;
  }

  TournamentMatch? _nextByeMatch(TournamentBracket bracket) {
    for (var roundIndex = 0; roundIndex < bracket.rounds.length; roundIndex += 1) {
      final round = bracket.rounds[roundIndex];
      for (var matchIndex = 0; matchIndex < round.matches.length; matchIndex += 1) {
        final match = round.matches[matchIndex];
        final hasSinglePlayer =
            (match.playerA != null) != (match.playerB != null);
        if (match.status != TournamentMatchStatus.pending || !hasSinglePlayer) {
          continue;
        }
        if (_canResolveByeMatch(
          bracket: bracket,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        )) {
          return match;
        }
      }
    }
    return null;
  }

  bool _canResolveByeMatch({
    required TournamentBracket bracket,
    required int roundIndex,
    required int matchIndex,
  }) {
    if (roundIndex == 0) {
      return true;
    }
    if (bracket.rounds[roundIndex].stage != bracket.rounds[roundIndex - 1].stage) {
      return true;
    }

    return _isBranchResolved(
          bracket: bracket,
          roundIndex: roundIndex - 1,
          matchIndex: matchIndex * 2,
        ) &&
        _isBranchResolved(
          bracket: bracket,
          roundIndex: roundIndex - 1,
          matchIndex: (matchIndex * 2) + 1,
        );
  }

  bool _isBranchResolved({
    required TournamentBracket bracket,
    required int roundIndex,
    required int matchIndex,
  }) {
    if (matchIndex < 0 || matchIndex >= bracket.rounds[roundIndex].matches.length) {
      return true;
    }
    final match = bracket.rounds[roundIndex].matches[matchIndex];
    if (match.status == TournamentMatchStatus.completed) {
      return true;
    }
    if (match.playerA == null && match.playerB == null) {
      return true;
    }
    if (roundIndex == 0) {
      return false;
    }
    return _isBranchResolved(
          bracket: bracket,
          roundIndex: roundIndex - 1,
          matchIndex: matchIndex * 2,
        ) &&
        _isBranchResolved(
          bracket: bracket,
          roundIndex: roundIndex - 1,
          matchIndex: (matchIndex * 2) + 1,
        );
  }

  int _bracketSizeFor(int entrants) {
    var size = 2;
    while (size < entrants) {
      size *= 2;
    }
    return size;
  }

  List<int> _slotOrderForRound({
    required int bracketSize,
    required int roundNumber,
  }) {
    final blockSize = 1 << (roundNumber - 1);
    final slotCount = bracketSize ~/ blockSize;
    final order = <int>[];
    final seen = <int>{};
    for (final seedPosition in _buildSeedOrder(bracketSize)) {
      final slot = (seedPosition - 1) ~/ blockSize;
      if (slot >= slotCount || !seen.add(slot)) {
        continue;
      }
      order.add(slot);
    }
    for (var slot = 0; slot < slotCount; slot += 1) {
      if (seen.add(slot)) {
        order.add(slot);
      }
    }
    return order;
  }

  TournamentBracket _withAdvancedWinners(TournamentBracket bracket) {
    final progressed = _advanceWinners(
      participants: bracket.participants,
      rounds: bracket.rounds,
    );
    return TournamentBracket(
      definition: bracket.definition,
      participants: bracket.participants,
      rounds: progressed,
    );
  }

  TournamentBracket applyResult({
    required TournamentBracket bracket,
    required String matchId,
    required TournamentMatchResult result,
  }) {
    final updatedRounds = <TournamentRound>[];

    for (final round in bracket.rounds) {
      final matches = round.matches.map((match) {
        if (match.id != matchId) {
          return match;
        }
        return match.copyWith(
          status: TournamentMatchStatus.completed,
          result: result,
        );
      }).toList();

      updatedRounds.add(
        TournamentRound(
          roundNumber: round.roundNumber,
          title: round.title,
          stage: round.stage,
          matches: matches,
        ),
      );
    }

    final updatedBracket = TournamentBracket(
      definition: bracket.definition,
      participants: bracket.participants,
      rounds: updatedRounds,
    );
    if (bracket.definition.format == TournamentFormat.league) {
      return updatedBracket;
    }
    if (bracket.definition.format == TournamentFormat.leaguePlayoff) {
      if (updatedBracket.playoffRounds.isEmpty &&
          _allRoundsCompleted(updatedBracket.leagueRounds)) {
        return _autoAdvanceByes(
          TournamentBracket(
            definition: updatedBracket.definition,
            participants: updatedBracket.participants,
            rounds: <TournamentRound>[
              ...updatedBracket.rounds,
              ..._buildPlayoffRounds(updatedBracket),
            ],
          ),
        );
      }

      return _advancePlayoffWinners(updatedBracket);
    }

    return _autoAdvanceByes(_withAdvancedWinners(updatedBracket));
  }

  List<TournamentRound> _cloneRounds(List<TournamentRound> rounds) {
    return rounds
        .map(
          (round) => TournamentRound(
            roundNumber: round.roundNumber,
            title: round.title,
            stage: round.stage,
            matches: List<TournamentMatch>.from(round.matches),
          ),
        )
        .toList();
  }

  _RoundMatchRef? _findNextSimulatableMatch(
    List<TournamentRound> rounds, {
    required bool includeHumanMatches,
  }) {
    for (var roundIndex = 0; roundIndex < rounds.length; roundIndex += 1) {
      final round = rounds[roundIndex];
      for (var matchIndex = 0; matchIndex < round.matches.length; matchIndex += 1) {
        final match = round.matches[matchIndex];
        if (match.status != TournamentMatchStatus.pending ||
            !match.isReady ||
            (match.isHumanMatch && !includeHumanMatches)) {
          continue;
        }
        return _RoundMatchRef(roundIndex: roundIndex, matchIndex: matchIndex);
      }
    }
    return null;
  }

  void _applyResultInPlace({
    required List<TournamentRound> rounds,
    required List<TournamentParticipant> participants,
    required int roundIndex,
    required int matchIndex,
    required TournamentMatchResult result,
    required TournamentFormat format,
  }) {
    final match = rounds[roundIndex].matches[matchIndex];
    rounds[roundIndex].matches[matchIndex] = match.copyWith(
      status: TournamentMatchStatus.completed,
      result: result,
    );

    if (format == TournamentFormat.league) {
      return;
    }

    if (format == TournamentFormat.leaguePlayoff &&
        rounds[roundIndex].stage == TournamentRoundStage.league) {
      return;
    }

    _advanceWinnerFromMatchInPlace(
      rounds: rounds,
      participants: participants,
      roundIndex: roundIndex,
      matchIndex: matchIndex,
      winnerId: result.winnerId,
    );
    _autoAdvanceByesInPlace(participants: participants, rounds: rounds);
  }

  void _advanceWinnerFromMatchInPlace({
    required List<TournamentRound> rounds,
    required List<TournamentParticipant> participants,
    required int roundIndex,
    required int matchIndex,
    required String? winnerId,
  }) {
    if (winnerId == null || roundIndex >= rounds.length - 1) {
      return;
    }
    final winner = _findParticipant(participants, winnerId);
    if (winner == null) {
      return;
    }
    final targetIndex = matchIndex ~/ 2;
    final target = rounds[roundIndex + 1].matches[targetIndex];
    final updatedTarget = matchIndex.isEven
        ? target.copyWith(playerA: winner)
        : target.copyWith(playerB: winner);
    final shouldReopenMatch =
        updatedTarget.isReady &&
        updatedTarget.status == TournamentMatchStatus.completed &&
        updatedTarget.result?.winnerId == null;
    rounds[roundIndex + 1].matches[targetIndex] = shouldReopenMatch
        ? updatedTarget.copyWith(
            status: TournamentMatchStatus.pending,
            clearResult: true,
          )
        : updatedTarget;
  }

  void _autoAdvanceByesInPlace({
    required List<TournamentParticipant> participants,
    required List<TournamentRound> rounds,
  }) {
    while (true) {
      final emptyRef = _nextEmptyMatchRef(rounds);
      if (emptyRef != null) {
        _applyResultInPlace(
          rounds: rounds,
          participants: participants,
          roundIndex: emptyRef.roundIndex,
          matchIndex: emptyRef.matchIndex,
          result: const TournamentMatchResult(scoreText: 'Kein Match'),
          format: TournamentFormat.knockout,
        );
        continue;
      }

      final byeRef = _nextByeMatchRef(rounds);
      if (byeRef == null) {
        return;
      }
      final match = rounds[byeRef.roundIndex].matches[byeRef.matchIndex];
      final winner = match.playerA ?? match.playerB;
      if (winner == null) {
        return;
      }
      _applyResultInPlace(
        rounds: rounds,
        participants: participants,
        roundIndex: byeRef.roundIndex,
        matchIndex: byeRef.matchIndex,
        result: TournamentMatchResult(
          winnerId: winner.id,
          winnerName: winner.name,
          scoreText: 'Freilos',
        ),
        format: TournamentFormat.knockout,
      );
    }
  }

  _RoundMatchRef? _nextEmptyMatchRef(List<TournamentRound> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length; roundIndex += 1) {
      final round = rounds[roundIndex];
      for (var matchIndex = 0; matchIndex < round.matches.length; matchIndex += 1) {
        final match = round.matches[matchIndex];
        final isEmptyMatch = match.playerA == null && match.playerB == null;
        if (match.status != TournamentMatchStatus.pending || !isEmptyMatch) {
          continue;
        }
        if (_canResolveByeMatchInRounds(
          rounds: rounds,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        )) {
          return _RoundMatchRef(roundIndex: roundIndex, matchIndex: matchIndex);
        }
      }
    }
    return null;
  }

  _RoundMatchRef? _nextByeMatchRef(List<TournamentRound> rounds) {
    for (var roundIndex = 0; roundIndex < rounds.length; roundIndex += 1) {
      final round = rounds[roundIndex];
      for (var matchIndex = 0; matchIndex < round.matches.length; matchIndex += 1) {
        final match = round.matches[matchIndex];
        final hasSinglePlayer = (match.playerA != null) != (match.playerB != null);
        if (match.status != TournamentMatchStatus.pending || !hasSinglePlayer) {
          continue;
        }
        if (_canResolveByeMatchInRounds(
          rounds: rounds,
          roundIndex: roundIndex,
          matchIndex: matchIndex,
        )) {
          return _RoundMatchRef(roundIndex: roundIndex, matchIndex: matchIndex);
        }
      }
    }
    return null;
  }

  bool _canResolveByeMatchInRounds({
    required List<TournamentRound> rounds,
    required int roundIndex,
    required int matchIndex,
  }) {
    if (roundIndex == 0) {
      return true;
    }
    if (rounds[roundIndex].stage != rounds[roundIndex - 1].stage) {
      return true;
    }

    return _isBranchResolvedInRounds(
          rounds: rounds,
          roundIndex: roundIndex - 1,
          matchIndex: matchIndex * 2,
        ) &&
        _isBranchResolvedInRounds(
          rounds: rounds,
          roundIndex: roundIndex - 1,
          matchIndex: (matchIndex * 2) + 1,
        );
  }

  bool _isBranchResolvedInRounds({
    required List<TournamentRound> rounds,
    required int roundIndex,
    required int matchIndex,
  }) {
    if (matchIndex < 0 || matchIndex >= rounds[roundIndex].matches.length) {
      return true;
    }
    final match = rounds[roundIndex].matches[matchIndex];
    if (match.status == TournamentMatchStatus.completed) {
      return true;
    }
    if (match.playerA == null && match.playerB == null) {
      return true;
    }
    if (roundIndex == 0) {
      return false;
    }
    return _isBranchResolvedInRounds(
          rounds: rounds,
          roundIndex: roundIndex - 1,
          matchIndex: matchIndex * 2,
        ) &&
        _isBranchResolvedInRounds(
          rounds: rounds,
          roundIndex: roundIndex - 1,
          matchIndex: (matchIndex * 2) + 1,
        );
  }

  TournamentBracket simulateNextCpuMatch({
    required TournamentBracket bracket,
    required BotProfile Function(String participantId) profileProvider,
  }) {
    return simulateNextMatch(
      bracket: bracket,
      profileProvider: profileProvider,
      includeHumanMatches: false,
    );
  }

  TournamentBracket simulateNextMatch({
    required TournamentBracket bracket,
    required BotProfile Function(String participantId) profileProvider,
    required bool includeHumanMatches,
  }) {
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        if (match.status != TournamentMatchStatus.pending || !match.isReady) {
          continue;
        }
        if (match.isHumanMatch && !includeHumanMatches) {
          continue;
        }

        final playerA = match.playerA!;
        final playerB = match.playerB!;
        final matchConfig = MatchConfig(
          startScore: bracket.definition.startScore,
          mode: bracket.definition.matchMode,
          startRequirement: bracket.definition.startRequirement,
          checkoutRequirement: bracket.definition.checkoutRequirement,
          legsToWin: _legsToWinForMatch(
            bracket: bracket,
            roundNumber: match.roundNumber,
          ),
          setsToWin: _setsToWinForMatch(
            bracket: bracket,
            roundNumber: match.roundNumber,
          ),
          legsPerSet: bracket.definition.legsPerSet,
        );
        final simulation = _simulator.simulateAutoMatch(
          playerA: SimulatedPlayer(
            name: playerA.name,
            profile: profileProvider(playerA.id),
          ),
          playerB: SimulatedPlayer(
            name: playerB.name,
            profile: profileProvider(playerB.id),
          ),
          config: matchConfig,
          detailed: false,
        );

        final winner = simulation.winner.name == playerA.name ? playerA : playerB;
        return applyResult(
          bracket: bracket,
          matchId: match.id,
          result: TournamentMatchResult(
            winnerId: winner.id,
            winnerName: winner.name,
            scoreText: simulation.scoreText,
            participantStats: _participantStatsFromSimulation(
              simulation: simulation,
              playerA: playerA,
              playerB: playerB,
            ),
          ),
        );
      }
    }

    return bracket;
  }

  TournamentBracket simulateSpecificMatch({
    required TournamentBracket bracket,
    required String matchId,
    required BotProfile Function(String participantId) profileProvider,
  }) {
    TournamentMatch? targetMatch;
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        if (match.id == matchId) {
          targetMatch = match;
          break;
        }
      }
      if (targetMatch != null) {
        break;
      }
    }

    if (targetMatch == null ||
        targetMatch.status != TournamentMatchStatus.pending ||
        !targetMatch.isReady ||
        targetMatch.isHumanMatch) {
      return bracket;
    }

    final playerA = targetMatch.playerA!;
    final playerB = targetMatch.playerB!;
    final matchConfig = MatchConfig(
      startScore: bracket.definition.startScore,
      mode: bracket.definition.matchMode,
      startRequirement: bracket.definition.startRequirement,
      checkoutRequirement: bracket.definition.checkoutRequirement,
      legsToWin: _legsToWinForMatch(
        bracket: bracket,
        roundNumber: targetMatch.roundNumber,
      ),
      setsToWin: _setsToWinForMatch(
        bracket: bracket,
        roundNumber: targetMatch.roundNumber,
      ),
      legsPerSet: bracket.definition.legsPerSet,
    );
    final simulation = _simulator.simulateAutoMatch(
      playerA: SimulatedPlayer(
        name: playerA.name,
        profile: profileProvider(playerA.id),
      ),
      playerB: SimulatedPlayer(
        name: playerB.name,
        profile: profileProvider(playerB.id),
      ),
      config: matchConfig,
      detailed: false,
    );

    final winner = simulation.winner.name == playerA.name ? playerA : playerB;
    return applyResult(
      bracket: bracket,
      matchId: targetMatch.id,
      result: TournamentMatchResult(
        winnerId: winner.id,
        winnerName: winner.name,
        scoreText: simulation.scoreText,
        participantStats: _participantStatsFromSimulation(
          simulation: simulation,
          playerA: playerA,
          playerB: playerB,
        ),
      ),
    );
  }

  List<TournamentPlayerMatchStats> _participantStatsFromSimulation({
    required SimulatedMatchResult simulation,
    required TournamentParticipant playerA,
    required TournamentParticipant playerB,
  }) {
    return <TournamentPlayerMatchStats>[
      _playerMatchStatsFromSimulated(
        participantId: playerA.id,
        participantName: playerA.name,
        stats: simulation.playerStatsA,
      ),
      _playerMatchStatsFromSimulated(
        participantId: playerB.id,
        participantName: playerB.name,
        stats: simulation.playerStatsB,
      ),
    ];
  }

  TournamentPlayerMatchStats _playerMatchStatsFromSimulated({
    required String participantId,
    required String participantName,
    required SimulatedPlayerStats stats,
  }) {
    return TournamentPlayerMatchStats(
      participantId: participantId,
      participantName: participantName,
      pointsScored: stats.pointsScored,
      dartsThrown: stats.dartsThrown,
      visits: stats.visits,
      legsWon: stats.legsWon,
      legsPlayed: stats.legsPlayed,
      legsStarted: stats.legsStarted,
      legsWonAsStarter: stats.legsWonAsStarter,
      legsWonWithoutStarter: stats.legsWonWithoutStarter,
      scores0To40: stats.scores0To40,
      scores41To59: stats.scores41To59,
      scores60Plus: stats.scores60Plus,
      scores100Plus: stats.scores100Plus,
      scores140Plus: stats.scores140Plus,
      scores171Plus: stats.scores171Plus,
      scores180: stats.scores180,
      checkoutAttempts: stats.checkoutAttempts,
      successfulCheckouts: stats.successfulCheckouts,
      checkoutAttempts1Dart: stats.checkoutAttempts1Dart,
      checkoutAttempts2Dart: stats.checkoutAttempts2Dart,
      checkoutAttempts3Dart: stats.checkoutAttempts3Dart,
      successfulCheckouts1Dart: stats.successfulCheckouts1Dart,
      successfulCheckouts2Dart: stats.successfulCheckouts2Dart,
      successfulCheckouts3Dart: stats.successfulCheckouts3Dart,
      thirdDartCheckoutAttempts: stats.thirdDartCheckoutAttempts,
      thirdDartCheckouts: stats.thirdDartCheckouts,
      bullCheckoutAttempts: stats.bullCheckoutAttempts,
      bullCheckouts: stats.bullCheckouts,
      functionalDoubleAttempts: stats.functionalDoubleAttempts,
      functionalDoubleSuccesses: stats.functionalDoubleSuccesses,
      firstNinePoints: stats.firstNinePoints,
      firstNineDarts: stats.firstNineDarts,
      highestFinish: stats.highestFinish,
      bestLegDarts: stats.bestLegDarts,
      totalFinishValue: stats.totalFinishValue,
      withThrowPoints: stats.withThrowPoints,
      withThrowDarts: stats.withThrowDarts,
      againstThrowPoints: stats.againstThrowPoints,
      againstThrowDarts: stats.againstThrowDarts,
      decidingLegPoints: stats.decidingLegPoints,
      decidingLegDarts: stats.decidingLegDarts,
      decidingLegsPlayed: stats.decidingLegsPlayed,
      decidingLegsWon: stats.decidingLegsWon,
      won9Darters: stats.won9Darters,
      won12Darters: stats.won12Darters,
      won15Darters: stats.won15Darters,
      won18Darters: stats.won18Darters,
    );
  }

  List<TournamentRound> _advanceWinners({
    required List<TournamentParticipant> participants,
    required List<TournamentRound> rounds,
  }) {
    final nextRounds = rounds
        .map(
          (round) => TournamentRound(
            roundNumber: round.roundNumber,
            title: round.title,
            stage: round.stage,
            matches: List<TournamentMatch>.from(round.matches),
          ),
        )
        .toList();

    for (var roundIndex = 0; roundIndex < nextRounds.length - 1; roundIndex += 1) {
      final currentRound = nextRounds[roundIndex];
      final followingRound = nextRounds[roundIndex + 1];
      final updatedFollowingMatches = List<TournamentMatch>.from(followingRound.matches);

      for (var matchIndex = 0; matchIndex < currentRound.matches.length; matchIndex += 1) {
        final match = currentRound.matches[matchIndex];
        final winnerId = match.result?.winnerId;
        if (winnerId == null) {
          continue;
        }
        final winner = _findParticipant(participants, winnerId);
        if (winner == null) {
          continue;
        }
        final targetIndex = matchIndex ~/ 2;
        final target = updatedFollowingMatches[targetIndex];
        final updatedTarget = matchIndex.isEven
            ? target.copyWith(playerA: winner)
            : target.copyWith(playerB: winner);
        final shouldReopenMatch =
            updatedTarget.isReady &&
            updatedTarget.status == TournamentMatchStatus.completed &&
            updatedTarget.result?.winnerId == null;
        updatedFollowingMatches[targetIndex] = shouldReopenMatch
            ? updatedTarget.copyWith(
                status: TournamentMatchStatus.pending,
                clearResult: true,
              )
            : updatedTarget;
      }

      nextRounds[roundIndex + 1] = TournamentRound(
        roundNumber: followingRound.roundNumber,
        title: followingRound.title,
        stage: followingRound.stage,
        matches: updatedFollowingMatches,
      );
    }

    return nextRounds;
  }

  List<TournamentRound> _buildLeagueRounds({
    required List<TournamentParticipant> participants,
    required int repeatCount,
  }) {
    if (participants.length < 2) {
      return const <TournamentRound>[];
    }

    final baseParticipants = List<TournamentParticipant?>.from(participants);
    if (baseParticipants.length.isOdd) {
      baseParticipants.add(null);
    }

    final matchdayTemplates = <List<List<TournamentParticipant?>>>{};
    var rotation = List<TournamentParticipant?>.from(baseParticipants);
    final roundsPerCycle = rotation.length - 1;

    for (var roundIndex = 0; roundIndex < roundsPerCycle; roundIndex += 1) {
      final pairings = <List<TournamentParticipant?>>[];
      for (var pairIndex = 0; pairIndex < rotation.length ~/ 2; pairIndex += 1) {
        final left = rotation[pairIndex];
        final right = rotation[rotation.length - 1 - pairIndex];
        pairings.add(<TournamentParticipant?>[
          if (roundIndex.isOdd) right else left,
          if (roundIndex.isOdd) left else right,
        ]);
      }
      matchdayTemplates.add(pairings);
      rotation = <TournamentParticipant?>[
        rotation.first,
        rotation.last,
        ...rotation.sublist(1, rotation.length - 1),
      ];
    }

    final rounds = <TournamentRound>[];
    var roundNumber = 1;
    for (var cycle = 0; cycle < repeatCount; cycle += 1) {
      for (final pairings in matchdayTemplates) {
        final matches = <TournamentMatch>[];
        for (var matchIndex = 0; matchIndex < pairings.length; matchIndex += 1) {
          final pairing = pairings[matchIndex];
          final playerA = cycle.isOdd ? pairing[1] : pairing[0];
          final playerB = cycle.isOdd ? pairing[0] : pairing[1];
          if (playerA == null || playerB == null) {
            continue;
          }
          matches.add(
            TournamentMatch(
              id: 'r$roundNumber-m${matchIndex + 1}',
              roundNumber: roundNumber,
              matchNumber: matchIndex + 1,
              playerA: playerA,
              playerB: playerB,
              status: TournamentMatchStatus.pending,
            ),
          );
        }
        rounds.add(
          TournamentRound(
            roundNumber: roundNumber,
            title: 'Spieltag $roundNumber',
            matches: matches,
            stage: TournamentRoundStage.league,
          ),
        );
        roundNumber += 1;
      }
    }
    return rounds;
  }

  bool _allRoundsCompleted(List<TournamentRound> rounds) {
    return rounds.isNotEmpty &&
        rounds.every((round) => round.isCompleted);
  }

  List<TournamentRound> _buildPlayoffRounds(TournamentBracket bracket) {
    final qualified = bracket.standings
        .take(bracket.definition.playoffQualifierCount)
        .toList();
    if (qualified.length < 2) {
      return const <TournamentRound>[];
    }

    final seeded = <TournamentParticipant>[
      for (var index = 0; index < qualified.length; index += 1)
        TournamentParticipant(
          id: qualified[index].participant.id,
          name: qualified[index].participant.name,
          type: qualified[index].participant.type,
          average: qualified[index].participant.average,
          seedNumber: index + 1,
          qualificationReason: 'Liga Platz ${index + 1}',
          botSkill: qualified[index].participant.botSkill,
          botFinishingSkill: qualified[index].participant.botFinishingSkill,
        ),
    ];

    final bracketSize = _bracketSizeFor(seeded.length);
    final firstPlayoffRoundNumber = bracket.rounds.length + 1;
    final rounds = <TournamentRound>[
      TournamentRound(
        roundNumber: firstPlayoffRoundNumber,
        title: _playoffRoundTitle(1, bracketSize),
        matches: List<TournamentMatch>.generate(
          bracketSize ~/ 2,
          (index) => TournamentMatch(
            id: 'r$firstPlayoffRoundNumber-m${index + 1}',
            roundNumber: firstPlayoffRoundNumber,
            matchNumber: index + 1,
            playerA: null,
            playerB: null,
            status: TournamentMatchStatus.pending,
          ),
        ),
        stage: TournamentRoundStage.playoff,
      ),
    ];

    var matchesInRound = bracketSize ~/ 2;
    var roundOffset = 2;
    while (matchesInRound > 1) {
      matchesInRound ~/= 2;
      final roundNumber = bracket.rounds.length + roundOffset;
      rounds.add(
        TournamentRound(
          roundNumber: roundNumber,
          title: _playoffRoundTitle(roundOffset - 1, bracketSize),
          stage: TournamentRoundStage.playoff,
          matches: List<TournamentMatch>.generate(
            matchesInRound,
            (index) => TournamentMatch(
              id: 'r$roundNumber-m${index + 1}',
              roundNumber: roundNumber,
              matchNumber: index + 1,
              playerA: null,
              playerB: null,
              status: TournamentMatchStatus.pending,
            ),
          ),
        ),
      );
      roundOffset += 1;
    }

    return _assignKnockoutParticipants(
      rounds: rounds,
      participants: seeded,
      bracketSize: bracketSize,
    );
  }

  TournamentBracket _advancePlayoffWinners(TournamentBracket bracket) {
    final leagueRounds = bracket.leagueRounds;
    final playoffRounds = bracket.playoffRounds;
    if (playoffRounds.isEmpty) {
      return bracket;
    }

    final progressedPlayoffs = _advanceWinners(
      participants: bracket.participants,
      rounds: playoffRounds,
    );
    return _autoAdvanceByes(
      TournamentBracket(
        definition: bracket.definition,
        participants: bracket.participants,
        rounds: <TournamentRound>[
          ...leagueRounds,
          ...progressedPlayoffs,
        ],
      ),
    );
  }

  String _playoffRoundTitle(int playoffRoundNumber, int fieldSize) {
    final remainingMatches = fieldSize ~/ pow(2, playoffRoundNumber).toInt();
    if (remainingMatches <= 1) {
      return 'Playoff Finale';
    }
    if (remainingMatches == 2) {
      return 'Playoff Halbfinale';
    }
    if (remainingMatches == 4) {
      return 'Playoff Viertelfinale';
    }
    return 'Playoff Runde $playoffRoundNumber';
  }

  int _legsToWinForMatch({
    required TournamentBracket bracket,
    required int roundNumber,
  }) {
    if (bracket.definition.matchMode != MatchMode.legs) {
      return bracket.definition.legsToWin;
    }
    if (bracket.definition.format == TournamentFormat.leaguePlayoff &&
        bracket.stageForRound(roundNumber) == TournamentRoundStage.playoff) {
      return bracket.definition.distanceForRound(
        bracket.stageRoundIndex(roundNumber),
      );
    }
    return bracket.definition.distanceForRound(roundNumber);
  }

  int _setsToWinForMatch({
    required TournamentBracket bracket,
    required int roundNumber,
  }) {
    if (bracket.definition.matchMode != MatchMode.sets) {
      return bracket.definition.setsToWin;
    }
    if (bracket.definition.format == TournamentFormat.leaguePlayoff &&
        bracket.stageForRound(roundNumber) == TournamentRoundStage.playoff) {
      return bracket.definition.distanceForRound(
        bracket.stageRoundIndex(roundNumber),
      );
    }
    return bracket.definition.distanceForRound(roundNumber);
  }

  TournamentParticipant? _findParticipant(
    List<TournamentParticipant> participants,
    String participantId,
  ) {
    for (final participant in participants) {
      if (participant.id == participantId) {
        return participant;
      }
    }
    return null;
  }

  List<int> _buildSeedOrder(int fieldSize) {
    if (fieldSize <= 2) {
      return <int>[1, 2];
    }

    var order = <int>[1, 2];
    while (order.length < fieldSize) {
      final bracketSize = order.length * 2 + 1;
      final next = <int>[];
      for (final seed in order) {
        next.add(seed);
        next.add(bracketSize - seed);
      }
      order = next;
    }
    return order;
  }

  String _roundTitle(int roundNumber, int fieldSize) {
    final remainingMatches = fieldSize ~/ pow(2, roundNumber).toInt();
    if (remainingMatches <= 1) {
      return 'Finale';
    }
    if (remainingMatches == 2) {
      return 'Halbfinale';
    }
    if (remainingMatches == 4) {
      return 'Viertelfinale';
    }
    return 'Runde $roundNumber';
  }
}

class TournamentSimulationBatch {
  const TournamentSimulationBatch({
    required this.bracket,
    required this.simulatedMatches,
    required this.madeProgress,
  });

  final TournamentBracket bracket;
  final int simulatedMatches;
  final bool madeProgress;
}

class _RoundMatchRef {
  const _RoundMatchRef({
    required this.roundIndex,
    required this.matchIndex,
  });

  final int roundIndex;
  final int matchIndex;
}

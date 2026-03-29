import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../background/background_task_runner.dart';
import '../debug/app_debug.dart';
import '../../domain/career/career_models.dart';
import '../../domain/rankings/ranking_engine.dart';
import '../../domain/tournament/tournament_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import '../models/computer_player.dart';
import '../storage/app_storage.dart';
import 'career_repository.dart';
import 'computer_repository.dart';
import 'player_repository.dart';
import 'settings_repository.dart';

class TournamentRepository extends ChangeNotifier {
  TournamentRepository._();

  static final TournamentRepository instance = TournamentRepository._();

  static const _storageKey = 'tournament_state';
  static const int _maxArchiveEntries = 160;
  static const int _maxCareerArchiveEntries = 96;

  final TournamentEngine _engine = TournamentEngine();
  TournamentBracket? _currentBracket;
  CareerTournamentContext? _careerContext;
  final List<TournamentArchiveEntry> _archive = <TournamentArchiveEntry>[];
  final List<TournamentComputerSelectionPreset> _savedComputerSelections =
      <TournamentComputerSelectionPreset>[];
  bool _simulationInProgress = false;
  String _simulationProgressLabel = '';
  double? _simulationProgress;

  TournamentBracket? get currentBracket => _currentBracket;
  CareerTournamentContext? get careerContext => _careerContext;
  bool get isCareerTournament => _careerContext != null;
  bool get hasActiveTournament => _currentBracket != null;
  bool get simulationInProgress => _simulationInProgress;
  String get simulationProgressLabel => _simulationProgressLabel;
  double? get simulationProgress => _simulationProgress;
  List<TournamentArchiveEntry> get archive =>
      List<TournamentArchiveEntry>.unmodifiable(_archive);
  List<TournamentComputerSelectionPreset> get savedComputerSelections =>
      List<TournamentComputerSelectionPreset>.unmodifiable(
        _savedComputerSelections,
      );

  Future<void> initialize() async {
    final json = await AppStorage.instance.readJsonMap(_storageKey);
    if (json == null) {
      return;
    }
    final bracketJson = json['currentBracket'];
    if (bracketJson is Map) {
      _currentBracket =
          TournamentBracket.fromJson(bracketJson.cast<String, dynamic>());
    }
    final contextJson = json['careerContext'];
    if (contextJson is Map) {
      _careerContext = CareerTournamentContext.fromJson(
        contextJson.cast<String, dynamic>(),
      );
    }
    _archive
      ..clear()
      ..addAll(
        (json['archive'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => TournamentArchiveEntry.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .map(_normalizeArchiveEntry),
      );
    _pruneArchive();
    _savedComputerSelections
      ..clear()
      ..addAll(
        (json['savedComputerSelections'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => TournamentComputerSelectionPreset.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            ),
      );
    await _persist();
    notifyListeners();
  }

  void createTournament({
    required String name,
    TournamentGame game = TournamentGame.x01,
    TournamentFormat format = TournamentFormat.knockout,
    required int fieldSize,
    MatchMode matchMode = MatchMode.legs,
    required int legsToWin,
    required int startScore,
    StartRequirement startRequirement = StartRequirement.straightIn,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    int setsToWin = 1,
    int legsPerSet = 1,
    List<int> roundDistanceValues = const <int>[],
    int pointsForWin = 2,
    int pointsForDraw = 1,
    int roundRobinRepeats = 1,
    int playoffQualifierCount = 4,
    required bool includeHumanPlayer,
    int? computerOpponentCount,
    double? minimumComputerAverage,
    double? maximumComputerAverage,
    List<String> selectedComputerIds = const <String>[],
  }) {
    final participants = <TournamentParticipant>[];
    final activePlayer = PlayerRepository.instance.activePlayer;
    if (includeHumanPlayer && activePlayer != null) {
      participants.add(
        TournamentParticipant(
          id: activePlayer.id,
          name: activePlayer.name,
          type: TournamentParticipantType.human,
          average: activePlayer.average,
          qualificationReason: 'Aktiver Spieler',
        ),
      );
    }

    final minimumAverage = minimumComputerAverage ?? 0;
    final maximumAverage = maximumComputerAverage ?? 180;
    final desiredComputerCount =
        computerOpponentCount ?? (fieldSize - participants.length);
    final averageFloor =
        minimumAverage <= maximumAverage ? minimumAverage : maximumAverage;
    final averageCeiling =
        minimumAverage <= maximumAverage ? maximumAverage : minimumAverage;
    final computersById = <String, ComputerPlayer>{
      for (final player in ComputerRepository.instance.players) player.id: player,
    };
    final addedSelectedComputerIds = <String>{};

    for (final computerId in selectedComputerIds) {
      if (addedSelectedComputerIds.length >= desiredComputerCount) {
        break;
      }
      final computer = computersById[computerId];
      if (computer == null || !addedSelectedComputerIds.add(computer.id)) {
        continue;
      }
      participants.add(
        TournamentParticipant(
          id: computer.id,
          name: computer.name,
          type: TournamentParticipantType.computer,
          average: computer.theoreticalAverage,
          qualificationReason: 'Aus Datenbank gewaehlt',
          botSkill: computer.skill,
          botFinishingSkill: computer.finishingSkill,
        ),
      );
    }

    final generatedComputerCount = desiredComputerCount > addedSelectedComputerIds.length
        ? desiredComputerCount - addedSelectedComputerIds.length
        : 0;

    for (var index = 0; index < generatedComputerCount; index += 1) {
      final targetAverage = _generatedTargetAverage(
        index: index,
        totalCount: generatedComputerCount,
        minimumAverage: averageFloor,
        maximumAverage: averageCeiling,
      );
      final resolution = ComputerRepository.instance
          .resolveSkillsForTheoreticalAverage(targetAverage);
      participants.add(
        TournamentParticipant(
          id: 'generated-computer-${DateTime.now().microsecondsSinceEpoch}-$index',
          name: _generatedComputerName(index + 1),
          type: TournamentParticipantType.computer,
          average: targetAverage,
          qualificationReason:
              'Erstellt fuer ${averageFloor.toStringAsFixed(0)}-${averageCeiling.toStringAsFixed(0)} Avg',
          botSkill: resolution.skill,
          botFinishingSkill: resolution.finishingSkill,
        ),
      );
    }

    _currentBracket = _engine.buildBracket(
      definition: TournamentDefinition(
        name: name,
        game: game,
        format: format,
        fieldSize: fieldSize,
        matchMode: matchMode,
        legsToWin: legsToWin,
        startScore: startScore,
        startRequirement: startRequirement,
        checkoutRequirement: checkoutRequirement,
        setsToWin: setsToWin,
        legsPerSet: legsPerSet,
        roundDistanceValues: roundDistanceValues,
        pointsForWin: pointsForWin,
        pointsForDraw: pointsForDraw,
        roundRobinRepeats: roundRobinRepeats,
        playoffQualifierCount: playoffQualifierCount,
        includeHumanPlayer: includeHumanPlayer,
      ),
      participants: participants,
    );
    _careerContext = null;
    notifyListeners();
    unawaited(_persist());
  }

  Future<TournamentComputerSelectionPreset?> saveComputerSelectionPreset({
    String? existingPresetId,
    required String name,
    required List<String> computerIds,
  }) async {
    final trimmedName = name.trim();
    final normalizedIds = <String>[];
    for (final id in computerIds) {
      final trimmedId = id.trim();
      if (trimmedId.isEmpty || normalizedIds.contains(trimmedId)) {
        continue;
      }
      normalizedIds.add(trimmedId);
    }
    if (trimmedName.isEmpty || normalizedIds.isEmpty) {
      return null;
    }

    final preset = TournamentComputerSelectionPreset(
      id:
          existingPresetId ??
          'preset-${DateTime.now().microsecondsSinceEpoch}-${normalizedIds.length}',
      name: trimmedName,
      computerIds: normalizedIds,
    );

    final existingIndex = _savedComputerSelections.indexWhere(
      (entry) => entry.id == preset.id,
    );
    if (existingIndex >= 0) {
      _savedComputerSelections[existingIndex] = preset;
    } else {
      _savedComputerSelections.insert(0, preset);
    }
    notifyListeners();
    await _persist();
    return preset;
  }

  Future<void> deleteComputerSelectionPreset(String presetId) async {
    _savedComputerSelections.removeWhere((entry) => entry.id == presetId);
    notifyListeners();
    await _persist();
  }

  void createCareerTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
    bool silent = false,
  }) {
    if (item.isLeagueSeriesItem) {
      _createCareerLeagueSeriesTournament(
        career: career,
        item: item,
        silent: silent,
      );
      return;
    }
    final existingContext = _careerContext;
    if (_currentBracket != null &&
        existingContext?.careerId == career.id &&
        existingContext?.seasonNumber == career.currentSeason.seasonNumber &&
        existingContext?.calendarItem.id == item.id) {
      return;
    }
    final action = AppDebug.instance.startAction(
      'Turnier',
      'Karriere-Turnier "${item.name}" aufbauen',
    );
    _logProcessMemory('vor Aufbau "${item.name}"');
    final participantsStopwatch = Stopwatch()..start();
    final participants = _buildCareerParticipants(
      career: career,
      item: item,
    );
    participantsStopwatch.stop();
    AppDebug.instance.info(
      'Performance',
      'Teilnehmeraufbau "${item.name}": ${participantsStopwatch.elapsedMilliseconds} ms',
    );
    if (participants.isEmpty) {
      AppDebug.instance.info(
        'Turnier',
        'Karriere-Turnier "${item.name}" wird uebersprungen, weil keine Teilnehmer gefunden wurden.',
      );
      CareerRepository.instance.skipCurrentTournament(item: item);
      _currentBracket = null;
      _careerContext = null;
      if (!silent) {
        notifyListeners();
        unawaited(_persist());
      }
      action.complete('uebersprungen');
      return;
    }

    final bracketStopwatch = Stopwatch()..start();
    _currentBracket = _engine.buildBracket(
      definition: TournamentDefinition(
        name: item.name,
        game: item.game,
        format: item.format,
        fieldSize: item.fieldSize,
        matchMode: item.matchMode,
        legsToWin: item.legsToWin,
        startScore: item.startScore,
        startRequirement: StartRequirement.straightIn,
        checkoutRequirement: item.checkoutRequirement,
        setsToWin: item.setsToWin,
        legsPerSet: item.legsPerSet,
        roundDistanceValues: item.roundDistanceValues,
        pointsForWin: item.pointsForWin,
        pointsForDraw: item.pointsForDraw,
        roundRobinRepeats: item.roundRobinRepeats,
        playoffQualifierCount: item.playoffQualifierCount,
        includeHumanPlayer:
            career.participantMode == CareerParticipantMode.withHuman,
      ),
      participants: participants,
    );
    bracketStopwatch.stop();
    AppDebug.instance.info(
      'Performance',
      'Bracket-Build "${item.name}": ${bracketStopwatch.elapsedMilliseconds} ms',
    );
    _careerContext = CareerTournamentContext(
      careerId: career.id,
      seasonNumber: career.currentSeason.seasonNumber,
      calendarItem: item,
    );
    if (!silent) {
      notifyListeners();
      unawaited(_persist());
    }
    action.complete('${participants.length} Teilnehmer');
    _logProcessMemory('nach Aufbau "${item.name}"');
  }

  void _createCareerLeagueSeriesTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
    bool silent = false,
  }) {
    final existingContext = _careerContext;
    if (_currentBracket != null &&
        existingContext?.careerId == career.id &&
        existingContext?.seasonNumber == career.currentSeason.seasonNumber &&
        existingContext?.calendarItem.id == item.id) {
      return;
    }

    var seriesState = _leagueSeriesState(career, item.seriesGroupId!);
    final seriesName = seriesState?.baseName ?? _baseNameForSeriesItem(item);
    final participants = _participantsForLeagueSeriesItem(
      career: career,
      item: item,
      existingState: seriesState,
      seriesName: seriesName,
    );
    if (participants.isEmpty) {
      CareerRepository.instance.skipCurrentTournament(item: item);
      _currentBracket = null;
      _careerContext = null;
      if (!silent) {
        notifyListeners();
        unawaited(_persist());
      }
      return;
    }
    seriesState = _leagueSeriesState(
          CareerRepository.instance.activeCareer ?? career,
          item.seriesGroupId!,
        ) ??
        seriesState;

    final definition = TournamentDefinition(
      name: item.name,
      game: item.game,
      format: item.format,
      fieldSize: item.fieldSize,
      matchMode: item.matchMode,
      legsToWin: item.legsToWin,
      startScore: item.startScore,
      startRequirement: StartRequirement.straightIn,
      checkoutRequirement: item.checkoutRequirement,
      setsToWin: item.setsToWin,
      legsPerSet: item.legsPerSet,
      roundDistanceValues: item.roundDistanceValues,
      pointsForWin: item.pointsForWin,
      pointsForDraw: item.pointsForDraw,
      roundRobinRepeats: item.roundRobinRepeats,
      playoffQualifierCount: item.playoffQualifierCount,
      includeHumanPlayer:
          career.participantMode == CareerParticipantMode.withHuman,
    );

    final historicalRounds = _historicalSeriesRounds(seriesState);
    final historicalParticipants = _participantsFromRounds(historicalRounds);

    TournamentBracket nextBracket;
    if (item.seriesStage == CareerLeagueSeriesStage.playoffRound) {
      final aggregateBracket = TournamentBracket(
        definition: definition,
        participants: historicalParticipants,
        rounds: historicalRounds,
      );
      final playoffBracket = _engine.ensureLeaguePlayoffRounds(aggregateBracket);
      final currentRound = _roundForSeriesItem(
        playoffBracket.rounds,
        item.seriesIndex,
      );
      if (currentRound == null) {
        CareerRepository.instance.skipCurrentTournament(item: item);
        _currentBracket = null;
        _careerContext = null;
        if (!silent) {
          notifyListeners();
          unawaited(_persist());
        }
        return;
      }
      nextBracket = TournamentBracket(
        definition: playoffBracket.definition,
        participants: _mergeParticipants(
          historicalParticipants,
          playoffBracket.participants,
        ),
        rounds: <TournamentRound>[...historicalRounds, currentRound],
      );
    } else {
      final fullBracket = _engine.buildBracket(
        definition: definition,
        participants: participants,
      );
      final currentRound = _roundForSeriesItem(
        fullBracket.rounds,
        item.seriesIndex,
      );
      if (currentRound == null) {
        CareerRepository.instance.skipCurrentTournament(item: item);
        _currentBracket = null;
        _careerContext = null;
        if (!silent) {
          notifyListeners();
          unawaited(_persist());
        }
        return;
      }
      nextBracket = TournamentBracket(
        definition: fullBracket.definition,
        participants: _mergeParticipants(
          historicalParticipants,
          fullBracket.participants,
        ),
        rounds: <TournamentRound>[...historicalRounds, currentRound],
      );
    }

    _currentBracket = nextBracket;
    _careerContext = CareerTournamentContext(
      careerId: career.id,
      seasonNumber: career.currentSeason.seasonNumber,
      calendarItem: item,
    );
    if (!silent) {
      notifyListeners();
      unawaited(_persist());
    }
  }

  void resolveHumanMatch({
    required String matchId,
    required String winnerId,
  }) {
    final bracket = _currentBracket;
    if (bracket == null) {
      return;
    }

    TournamentParticipant? winner;
    for (final participant in bracket.participants) {
      if (participant.id == winnerId) {
        winner = participant;
        break;
      }
    }
    if (winner == null) {
      return;
    }

    final roundNumber = _roundNumberForMatch(bracket, matchId);
    _currentBracket = _engine.applyResult(
      bracket: bracket,
      matchId: matchId,
      result: TournamentMatchResult(
        winnerId: winner.id,
        winnerName: winner.name,
        scoreText: 'Manuell entschieden',
      ),
    );
    _simulateRemainingCpuMatchesForRound(roundNumber);
    notifyListeners();
    unawaited(_persist());
  }

  void completePlayedHumanMatch({
    required String matchId,
    required String winnerId,
    required String winnerName,
    required String scoreText,
    List<TournamentPlayerMatchStats> participantStats =
        const <TournamentPlayerMatchStats>[],
  }) {
    final bracket = _currentBracket;
    if (bracket == null) {
      return;
    }

    int? roundNumber;
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        if (match.id == matchId) {
          roundNumber = round.roundNumber;
          break;
        }
      }
      if (roundNumber != null) {
        break;
      }
    }

    _currentBracket = _engine.applyResult(
      bracket: bracket,
      matchId: matchId,
      result: TournamentMatchResult(
        winnerId: winnerId,
        winnerName: winnerName,
        scoreText: scoreText,
        participantStats: participantStats,
      ),
    );

    _simulateRemainingCpuMatchesForRound(roundNumber);

    notifyListeners();
    unawaited(_persist());
  }

  void resolveMatchAsDraw({
    required String matchId,
  }) {
    final bracket = _currentBracket;
    if (bracket == null) {
      return;
    }
    final roundNumber = _roundNumberForMatch(bracket, matchId);
    _currentBracket = _engine.applyResult(
      bracket: bracket,
      matchId: matchId,
      result: const TournamentMatchResult(
        scoreText: 'Unentschieden',
        isDraw: true,
      ),
    );
    _simulateRemainingCpuMatchesForRound(roundNumber);
    notifyListeners();
    unawaited(_persist());
  }

  void simulateRemainingCpuMatchesInRound(int roundNumber) {
    _simulateRemainingCpuMatchesForRound(roundNumber);
    notifyListeners();
    unawaited(_persist());
  }

  void simulateNextCpuMatch() {
    _simulateNextMatch(includeHumanMatches: false);
  }

  void simulateNextMatch({
    bool includeHumanMatches = false,
  }) {
    _simulateNextMatch(includeHumanMatches: includeHumanMatches);
  }

  void simulateRemainingCpuMatches() {
    simulateRemainingMatches(includeHumanMatches: false);
  }

  void simulateNextRound() {
    final bracket = _currentBracket;
    if (bracket == null || bracket.isCompleted) {
      return;
    }
    final roundNumber = _nextPendingRoundNumber(bracket);
    if (roundNumber == null) {
      return;
    }
    _simulateRemainingCpuMatchesForRound(roundNumber);
    notifyListeners();
    unawaited(_persist());
  }

  void simulateRemainingMatches({
    bool includeHumanMatches = false,
  }) {
    while (true) {
      final before = _currentBracket;
      if (before == null || before.isCompleted) {
        break;
      }
      if (!includeHumanMatches && _shouldStopBeforeNextRound(before)) {
        break;
      }
      _simulateNextMatch(includeHumanMatches: includeHumanMatches);
      if (identical(before, _currentBracket)) {
        break;
      }
    }
  }

  Future<void> simulateCurrentTournamentUntilComplete({
    bool includeHumanMatches = false,
    bool emitProgressUpdates = true,
  }) async {
    final bracket = _currentBracket;
    if (bracket == null || bracket.isCompleted) {
      return;
    }

    final action = AppDebug.instance.startAction(
      'Turnier',
      'Simulation "${bracket.definition.name}"',
    );
    final totalMatches = _countTotalMatches(bracket);
    _setSimulationProgress(
      inProgress: true,
      label: 'Turnier wird vorbereitet: ${bracket.definition.name}',
      progress: totalMatches == 0 ? null : 0,
    );
    _logProcessMemory('vor Simulation "${bracket.definition.name}"');
    await Future<void>.delayed(Duration.zero);
    final simulationResult =
        _shouldPreferLowMemorySimulation(bracket: bracket)
            ? await _simulateTournamentLowMemory(
                bracket: bracket,
                includeHumanMatches: includeHumanMatches,
                emitProgressUpdates: emitProgressUpdates,
                totalMatches: totalMatches,
              )
            : await BackgroundTaskRunner.instance.runJob<Map<String, Object?>>(
                taskType: 'simulate_tournament',
                initialLabel: 'Turnier wird simuliert: ${bracket.definition.name}',
                payload: <String, Object?>{
                  'bracket': bracket.toJson(),
                  'profilesById': _serializedProfilesForBracket(bracket),
                  'includeHumanMatches': includeHumanMatches,
                },
                onUpdate: (snapshot) {
                  _setSimulationProgress(
                    inProgress: snapshot.inProgress,
                    label: snapshot.label,
                    progress: snapshot.progress,
                  );
                },
              );

    final simulatedBracket = TournamentBracket.fromJson(
      (simulationResult['bracket'] as Map).cast<String, dynamic>(),
    );
    final simulatedMatches =
        (simulationResult['simulatedMatches'] as num?)?.toInt() ?? 0;
    final stoppedForHumanMatch =
        simulationResult['stoppedForHumanMatch'] as bool? ?? false;
    final madeProgress = simulatedMatches > 0;

    if (!madeProgress && !stoppedForHumanMatch) {
      AppDebug.instance.error(
        'Turnier',
        'Turnier "${bracket.definition.name}" macht keinen Fortschritt mehr.',
      );
      action.fail('kein Fortschritt mehr');
    }

    _currentBracket = simulatedBracket;
    AppDebug.instance.info(
      'Turnier',
      'Turnier "${simulatedBracket.definition.name}" abgeschlossen: ${simulatedBracket.isCompleted}.',
    );
    action.complete('$simulatedMatches Matches');
    _logProcessMemory('nach Simulation "${simulatedBracket.definition.name}"');
    if (emitProgressUpdates) {
      notifyListeners();
    }
    await _persist();
    _setSimulationProgress(
      inProgress: true,
      label: 'Turniersimulation abgeschlossen: ${simulatedBracket.definition.name}',
      progress: 1,
    );
  }

  bool _shouldPreferLowMemorySimulation({
    required TournamentBracket bracket,
  }) {
    return true;
  }

  Future<Map<String, Object?>> _simulateTournamentLowMemory({
    required TournamentBracket bracket,
    required bool includeHumanMatches,
    required bool emitProgressUpdates,
    required int totalMatches,
  }) async {
    _engine.resetPerformanceTotals();
    var workingBracket = bracket;
    final profileProvider = _profileProviderForBracket(bracket);
    var simulatedMatches = 0;
    var batchSize = 1;
    var stoppedForHumanMatch = false;

    while (!workingBracket.isCompleted) {
      if (!includeHumanMatches && _shouldStopBeforeNextRound(workingBracket)) {
        stoppedForHumanMatch = true;
        break;
      }
      final batchStopwatch = Stopwatch()..start();
      final batch = _engine.simulateMatchesBatch(
        bracket: workingBracket,
        profileProvider: profileProvider,
        includeHumanMatches: includeHumanMatches,
        maxMatches: batchSize,
      );
      batchStopwatch.stop();
      if (!batch.madeProgress) {
        break;
      }
      workingBracket = batch.bracket;
      simulatedMatches += batch.simulatedMatches;
      final completedMatches = _countCompletedMatchesLowMemory(workingBracket);
      _setSimulationProgress(
        inProgress: true,
        label:
            'Turnier wird simuliert: ${workingBracket.definition.name} ($completedMatches/$totalMatches Matches)',
        progress: totalMatches == 0
            ? null
            : (completedMatches / totalMatches).clamp(0.0, 1.0).toDouble(),
      );
      if (emitProgressUpdates) {
        _currentBracket = workingBracket;
        notifyListeners();
      }
      await Future<void>.delayed(Duration.zero);
      final batchDurationMs = batchStopwatch.elapsedMilliseconds;
      if (batchDurationMs >= 80) {
        batchSize = 1;
      } else if (batchDurationMs >= 40) {
        batchSize = 2;
      } else if (batchDurationMs >= 20) {
        batchSize = 4;
      } else if (batchDurationMs >= 10) {
        batchSize = 6;
      } else {
        batchSize = 8;
      }
    }

    return <String, Object?>{
      'bracket': workingBracket.toJson(),
      'simulatedMatches': simulatedMatches,
      'completed': workingBracket.isCompleted,
      'stoppedForHumanMatch': stoppedForHumanMatch,
    };
  }

  void _simulateNextMatch({
    required bool includeHumanMatches,
  }) {
    final bracket = _currentBracket;
    if (bracket == null) {
      return;
    }
    if (!includeHumanMatches && _shouldStopBeforeNextRound(bracket)) {
      return;
    }

    _currentBracket = _engine.simulateNextMatch(
      bracket: bracket,
      profileProvider: _profileForParticipant,
      includeHumanMatches: includeHumanMatches,
    );
    notifyListeners();
    unawaited(_persist());
  }

  void commitCurrentCareerTournament({
    bool silent = false,
  }) {
    final bracket = _currentBracket;
    final context = _careerContext;
    if (bracket == null || context == null || !bracket.isCompleted) {
      return;
    }

    final action = AppDebug.instance.startAction(
      'Turnier',
      'Karriere-Turnier committen',
    );
    _setSimulationProgress(
      inProgress: true,
      label: 'Turnier wird uebernommen: ${context.calendarItem.name}',
      progress: 1,
    );
    _logProcessMemory('vor Commit "${context.calendarItem.name}"');

    final career = CareerRepository.instance.activeCareer;
    if (career == null || career.id != context.careerId) {
      action.fail('aktive Karriere passt nicht zum Turnierkontext');
      return;
    }

    if (context.calendarItem.isLeagueSeriesItem) {
      final commitStopwatch = Stopwatch()..start();
      final seriesName = _leagueSeriesState(career, context.calendarItem.seriesGroupId!)?.baseName ??
          _baseNameForSeriesItem(context.calendarItem);
      CareerRepository.instance.completeLeagueSeriesRound(
        item: context.calendarItem,
        roundBracket: _roundOnlyBracketForSeriesItem(
          item: context.calendarItem,
          bracket: bracket,
        ),
        seriesName: seriesName,
      );
      commitStopwatch.stop();
      AppDebug.instance.info(
        'Performance',
        'Liga-Commit "${context.calendarItem.name}": ${commitStopwatch.elapsedMilliseconds} ms',
      );
      AppDebug.instance.info(
        'Turnier',
        'Liga-Spieltag "${context.calendarItem.name}" wurde in die Karriere uebernommen.',
      );
      _storeArchive(
        TournamentArchiveEntry(
          id: 'archive-${DateTime.now().microsecondsSinceEpoch}',
          name: context.calendarItem.name,
          bracket: _lightweightArchiveBracket(bracket),
          careerId: context.careerId,
          seasonNumber: context.seasonNumber,
          calendarItemId: context.calendarItem.id,
        ),
      );
      _careerContext = null;
      if (!silent) {
        notifyListeners();
        unawaited(_persist());
      }
      action.complete(context.calendarItem.name);
      _logProcessMemory(
        'nach Liga-Commit "${context.calendarItem.name}" | Archiv ${_archive.length}',
      );
      _setSimulationProgress(
        inProgress: false,
        label: '',
        progress: null,
      );
      return;
    }

    final commitStopwatch = Stopwatch()..start();
    CareerRepository.instance.completeCurrentTournament(
      item: context.calendarItem,
      bracket: bracket,
    );
    commitStopwatch.stop();
    AppDebug.instance.info(
      'Performance',
      'Karriere-Commit "${bracket.definition.name}": ${commitStopwatch.elapsedMilliseconds} ms',
    );
    AppDebug.instance.info(
      'Turnier',
      'Karriere-Turnier "${bracket.definition.name}" wurde in die Karriere übernommen.',
    );
    _storeArchive(
      TournamentArchiveEntry(
        id: 'archive-${DateTime.now().microsecondsSinceEpoch}',
        name: bracket.definition.name,
        bracket: _lightweightArchiveBracket(bracket),
        careerId: context.careerId,
        seasonNumber: context.seasonNumber,
        calendarItemId: context.calendarItem.id,
      ),
    );
    _careerContext = null;
    if (!silent) {
      notifyListeners();
      unawaited(_persist());
    }
    action.complete(context.calendarItem.name);
    _logProcessMemory(
      'nach Commit "${context.calendarItem.name}" | Archiv ${_archive.length}',
    );
    _setSimulationProgress(
      inProgress: false,
      label: '',
      progress: null,
    );
  }

  TournamentArchiveEntry? archiveForCareerItem({
    required String careerId,
    required int seasonNumber,
    required String calendarItemId,
  }) {
    for (final entry in _archive) {
      if (entry.careerId == careerId &&
          entry.seasonNumber == seasonNumber &&
          entry.calendarItemId == calendarItemId) {
        return entry;
      }
    }
    return null;
  }

  void clearSimulationProgress() {
    _setSimulationProgress(
      inProgress: false,
      label: '',
      progress: null,
    );
  }

  int _countTotalMatches(TournamentBracket bracket) {
    var count = 0;
    for (final round in bracket.rounds) {
      count += round.matches.length;
    }
    return count;
  }

  void _setSimulationProgress({
    required bool inProgress,
    required String label,
    required double? progress,
  }) {
    final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
    if (_simulationInProgress == inProgress &&
        _simulationProgressLabel == label &&
        _simulationProgress == normalizedProgress) {
      return;
    }
    _simulationInProgress = inProgress;
    _simulationProgressLabel = label;
    _simulationProgress = normalizedProgress;
    notifyListeners();
  }

  List<TournamentParticipant> previewCareerParticipants({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    return List<TournamentParticipant>.unmodifiable(
      _buildCareerParticipants(career: career, item: item),
    );
  }

  void openArchive(String archiveId) {
    for (final entry in _archive) {
      if (entry.id == archiveId) {
        _currentBracket = entry.bracket;
        _careerContext = null;
        notifyListeners();
        unawaited(_persist());
        return;
      }
    }
  }

  List<TournamentParticipant> _buildCareerParticipants({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    final pool = _careerPool(career);
    final rankingsById = <String, CareerRankingDefinition>{
      for (final ranking in career.rankings) ranking.id: ranking,
    };
    final standingsCache = <String, List<RankingStanding>>{};
    final orderedPool = pool.values.toList()
      ..sort((left, right) {
        if (left.type == TournamentParticipantType.human &&
            right.type != TournamentParticipantType.human) {
          return -1;
        }
        if (right.type == TournamentParticipantType.human &&
            left.type != TournamentParticipantType.human) {
          return 1;
        }
        return right.average.compareTo(left.average);
      });

    final selected = <_CareerPoolEntry>[];
    final selectedIds = <String>{};

    final slotRules = item.effectiveSlotRules;
    if (slotRules.isNotEmpty) {
      for (final slotRule in slotRules) {
        if (slotRule.sourceType == CareerTournamentSlotSourceType.careerTag) {
          final needed = slotRule.slotCount > 0
              ? slotRule.slotCount
              : item.fieldSize;
          var taken = 0;
          for (final entry in orderedPool) {
            if (selected.length >= item.fieldSize || taken >= needed) {
              break;
            }
            if (selectedIds.contains(entry.id)) {
              continue;
            }
            if (!_matchesCareerTags(
              entry,
              requiredTags: slotRule.requiredCareerTags,
              excludedTags: slotRule.excludedCareerTags,
            )) {
              continue;
            }
            selected.add(
              entry.copyWith(
                entryRound: slotRule.entryRound,
                qualificationReason:
                    'Karriere-Tag'
                    '${slotRule.requiredCareerTags.isEmpty ? '' : ' ${slotRule.requiredCareerTags.join(', ')}'}'
                    '${slotRule.excludedCareerTags.isEmpty ? '' : ' | Ohne ${slotRule.excludedCareerTags.join(', ')}'}'
                    '${slotRule.slotCount > 0 ? ' | Slots ${slotRule.slotCount}' : ''}'
                    '${slotRule.entryRound > 1 ? ' | ab Runde ${slotRule.entryRound}' : ''}',
              ),
            );
            selectedIds.add(entry.id);
            taken += 1;
          }
          continue;
        }
        final rankingId = slotRule.rankingId;
        if (rankingId == null) {
          continue;
        }
        final rankedEntries = _rankingCandidates(
          pool: pool,
          orderedPool: orderedPool,
          rankingId: rankingId,
          standingsCache: standingsCache,
          requiredTags: slotRule.requiredCareerTags,
          excludedTags: slotRule.excludedCareerTags,
        );
        final start = slotRule.fromRank <= slotRule.toRank
            ? slotRule.fromRank
            : slotRule.toRank;
        final end = slotRule.fromRank <= slotRule.toRank
            ? slotRule.toRank
            : slotRule.fromRank;
        final needed = slotRule.slotCount > 0
            ? slotRule.slotCount
            : end - start + 1;
        var taken = 0;
        for (final rankedEntry in rankedEntries) {
          if (rankedEntry.rank < start) {
            continue;
          }
          if (slotRule.slotCount <= 0 && rankedEntry.rank > end) {
            break;
          }
          if (selectedIds.contains(rankedEntry.entry.id)) {
            continue;
          }
          final rankingName = rankingsById[rankingId]?.name ?? rankingId;
          selected.add(
            rankedEntry.entry.copyWith(
              entryRound: slotRule.entryRound,
              qualificationReason:
                  '$rankingName ${slotRule.fromRank}-${slotRule.toRank}'
                  '${slotRule.slotCount > 0 ? ' | Slots ${slotRule.slotCount}' : ''}'
                  '${slotRule.requiredCareerTags.isEmpty ? '' : ' | Tags ${slotRule.requiredCareerTags.join(', ')}'}'
                  '${slotRule.excludedCareerTags.isEmpty ? '' : ' | Ohne ${slotRule.excludedCareerTags.join(', ')}'}'
                  '${rankedEntry.isFallback ? ' | Saisonstart-Fallback' : ''}'
                  ' | ab Runde ${slotRule.entryRound}'
                  ' (Platz ${rankedEntry.rank})',
            ),
          );
          selectedIds.add(rankedEntry.entry.id);
          taken += 1;
          if (taken >= needed || selected.length >= item.fieldSize) {
            break;
          }
        }
      }
    }

    for (final fillRule in item.effectiveFillRules) {
      if (fillRule.sourceType == CareerTournamentFillSourceType.ranking &&
          fillRule.rankingId != null) {
        final rankedEntries = _rankingCandidates(
          pool: pool,
          orderedPool: orderedPool,
          rankingId: fillRule.rankingId!,
          standingsCache: standingsCache,
          requiredTags: fillRule.requiredCareerTags,
          excludedTags: fillRule.excludedCareerTags,
        );
        final rankingName =
            rankingsById[fillRule.rankingId!]?.name ?? fillRule.rankingId!;
        var fillCount = 0;
        final needed = fillRule.maxCount > 0 ? fillRule.maxCount : item.fieldSize;
        for (final rankedEntry in rankedEntries) {
          if (selected.length >= item.fieldSize || fillCount >= needed) {
            break;
          }
          if (selectedIds.contains(rankedEntry.entry.id)) {
            continue;
          }
          selected.add(
            rankedEntry.entry.copyWith(
              entryRound: 1,
              qualificationReason: 'Auffuellung ueber $rankingName'
                  '${fillRule.requiredCareerTags.isEmpty ? '' : ' | Tags ${fillRule.requiredCareerTags.join(', ')}'}'
                  '${fillRule.excludedCareerTags.isEmpty ? '' : ' | Ohne ${fillRule.excludedCareerTags.join(', ')}'}'
                  '${rankedEntry.isFallback ? ' | Saisonstart-Fallback' : ''}'
                  ' (Platz ${rankedEntry.rank})',
            ),
          );
          selectedIds.add(rankedEntry.entry.id);
          fillCount += 1;
        }
        continue;
      }

      var fillCount = 0;
      for (final entry in orderedPool) {
        if (selected.length >= item.fieldSize) {
          break;
        }
        if (!_matchesCareerTags(
          entry,
          requiredTags: fillRule.requiredCareerTags,
          excludedTags: fillRule.excludedCareerTags,
        )) {
          continue;
        }
        if (fillRule.maxCount > 0 && fillCount >= fillRule.maxCount) {
          break;
        }
        if (selectedIds.add(entry.id)) {
          selected.add(
            entry.copyWith(
              entryRound: 1,
              qualificationReason: fillRule.requiredCareerTags.isEmpty
                  ? (fillRule.excludedCareerTags.isEmpty
                      ? 'Auffuellung nach Average'
                      : 'Auffuellung nach Average | Ohne ${fillRule.excludedCareerTags.join(', ')}')
                  : 'Auffuellung nach Average | Tags ${fillRule.requiredCareerTags.join(', ')}'
                      '${fillRule.excludedCareerTags.isEmpty ? '' : ' | Ohne ${fillRule.excludedCareerTags.join(', ')}'}',
            ),
          );
          fillCount += 1;
        }
      }
    }

    final seedMap = <String, int>{};
    if (item.seedingRankingId != null && item.seedCount > 0) {
      final rankedEntries = _rankingCandidates(
        pool: pool,
        orderedPool: orderedPool,
        rankingId: item.seedingRankingId!,
        standingsCache: standingsCache,
        requiredTags: const <String>[],
        excludedTags: const <String>[],
      );
      var nextSeed = 1;
      for (final rankedEntry in rankedEntries) {
        if (nextSeed > item.seedCount) {
          break;
        }
        if (!selectedIds.contains(rankedEntry.entry.id)) {
          continue;
        }
        seedMap[rankedEntry.entry.id] = nextSeed;
        nextSeed += 1;
      }
    }

    return selected.take(item.fieldSize).map((entry) {
      return TournamentParticipant(
        id: entry.id,
        name: entry.name,
        type: entry.type,
        average: entry.average,
        entryRound: entry.entryRound,
        seedNumber: seedMap[entry.id],
        qualificationReason: entry.qualificationReason,
        botSkill: entry.botSkill,
        botFinishingSkill: entry.botFinishingSkill,
      );
    }).toList();
  }

  List<_CareerRankedEntry> _rankingCandidates({
    required Map<String, _CareerPoolEntry> pool,
    required List<_CareerPoolEntry> orderedPool,
    required String rankingId,
    required Map<String, List<RankingStanding>> standingsCache,
    required List<String> requiredTags,
    required List<String> excludedTags,
  }) {
    final standings = standingsCache.putIfAbsent(
      rankingId,
      () => CareerRepository.instance.standingsForRanking(rankingId),
    );
    final shouldFallback =
        standings.isEmpty ||
        standings.every(
          (standing) => standing.money <= 0 && standing.titles <= 0,
        );

    if (!shouldFallback) {
      final rankedEntries = <_CareerRankedEntry>[];
      for (final standing in standings) {
        final entry = pool[standing.id];
        if (entry == null) {
          continue;
        }
        if (!_matchesCareerTags(
          entry,
          requiredTags: requiredTags,
          excludedTags: excludedTags,
        )) {
          continue;
        }
        rankedEntries.add(
          _CareerRankedEntry(
            rank: standing.rank,
            entry: entry,
          ),
        );
      }
      if (rankedEntries.isNotEmpty) {
        return rankedEntries;
      }
    }

    final fallbackEntries = <_CareerRankedEntry>[];
    var rank = 1;
    for (final entry in orderedPool) {
      if (!_matchesCareerTags(
        entry,
        requiredTags: requiredTags,
        excludedTags: excludedTags,
      )) {
        continue;
      }
      fallbackEntries.add(
        _CareerRankedEntry(
          rank: rank,
          entry: entry,
          isFallback: true,
        ),
      );
      rank += 1;
    }
    return fallbackEntries;
  }

  Map<String, _CareerPoolEntry> _careerPool(CareerDefinition career) {
    final pool = <String, _CareerPoolEntry>{};
    _CareerPoolEntry? selectedHuman;
    if (career.participantMode == CareerParticipantMode.withHuman) {
      final activePlayer = career.playerProfileId == null
          ? PlayerRepository.instance.activePlayer
          : PlayerRepository.instance.playerById(career.playerProfileId!);
      if (activePlayer != null) {
        selectedHuman = _CareerPoolEntry(
          id: activePlayer.id,
          name: activePlayer.name,
          type: TournamentParticipantType.human,
          average: activePlayer.average,
          qualificationReason: 'Karriere-Spieler',
        );
      }
    }

    final availableComputers = <String, ComputerPlayer>{
      for (final ComputerPlayer player in ComputerRepository.instance.players)
        player.id: player,
    };

    ComputerPlayer? weakestComputer;
    _CareerPoolEntry? weakestPoolEntry;
    final sourcePlayers = career.databasePlayers.isEmpty
        ? ComputerRepository.instance.players
            .map(
              (player) => CareerDatabasePlayer(
                databasePlayerId: player.id,
                name: player.name,
                average: player.theoreticalAverage,
                skill: player.skill,
                finishingSkill: player.finishingSkill,
              ),
            )
            .toList()
        : career.databasePlayers;

      for (final sourcePlayer in sourcePlayers) {
        final databasePlayer = availableComputers[sourcePlayer.databasePlayerId];
        final effectiveName = databasePlayer?.name ?? sourcePlayer.name;
        final useCareerOverrides = career.databasePlayers.isNotEmpty;
        final effectiveAverage = useCareerOverrides
            ? sourcePlayer.average
            : (databasePlayer?.theoreticalAverage ?? sourcePlayer.average);
        final effectiveSkill = useCareerOverrides
            ? sourcePlayer.skill
            : (databasePlayer?.skill ?? sourcePlayer.skill);
        final effectiveFinishingSkill = useCareerOverrides
            ? sourcePlayer.finishingSkill
            : (databasePlayer?.finishingSkill ?? sourcePlayer.finishingSkill);
        if (databasePlayer != null &&
            (weakestComputer == null ||
                databasePlayer.theoreticalAverage <
                  weakestComputer.theoreticalAverage)) {
        weakestComputer = databasePlayer;
      }
      final poolEntry = _CareerPoolEntry(
        id: sourcePlayer.databasePlayerId,
        name: effectiveName,
        type: TournamentParticipantType.computer,
        average: effectiveAverage,
        careerTags: sourcePlayer.activeTagNames,
        qualificationReason: sourcePlayer.activeTagNames.isEmpty
            ? null
            : 'Tags: ${sourcePlayer.activeTagNames.join(', ')}',
        botSkill: effectiveSkill,
        botFinishingSkill: effectiveFinishingSkill,
      );
      pool[sourcePlayer.databasePlayerId] = poolEntry;
      if (weakestPoolEntry == null || poolEntry.average < weakestPoolEntry.average) {
        weakestPoolEntry = poolEntry;
      }
    }

    if (career.databasePlayers.isEmpty) {
      for (final ComputerPlayer player in ComputerRepository.instance.players) {
        weakestComputer ??= player;
      }
    }

    if (selectedHuman != null) {
      final existingHumanEntry = pool[selectedHuman.id];
      final inheritedTags = existingHumanEntry?.careerTags ??
          (career.replaceWeakestPlayerWithHuman
              ? (weakestPoolEntry?.careerTags ?? const <String>[])
              : (career.careerTagDefinitions.any(
                    (definition) => definition.name == 'Non-Tour',
                  )
                  ? const <String>['Non-Tour']
                  : const <String>[]));
      final humanAlreadyInPool = existingHumanEntry != null;
      if (career.replaceWeakestPlayerWithHuman &&
          !humanAlreadyInPool &&
          weakestComputer != null) {
        pool.remove(weakestComputer.id);
      }
      pool[selectedHuman.id] = _CareerPoolEntry(
        id: selectedHuman.id,
        name: selectedHuman.name,
        type: selectedHuman.type,
        average: existingHumanEntry?.average ?? selectedHuman.average,
        careerTags: inheritedTags,
        qualificationReason: inheritedTags.isEmpty
            ? 'Karriere-Spieler'
            : 'Karriere-Spieler | Tags: ${inheritedTags.join(', ')}',
        botSkill: existingHumanEntry?.botSkill,
        botFinishingSkill: existingHumanEntry?.botFinishingSkill,
      );
    }

    return pool;
  }

  bool _matchesCareerTags(
    _CareerPoolEntry entry, {
    required List<String> requiredTags,
    required List<String> excludedTags,
  }) {
    if (requiredTags.isEmpty) {
      for (final tag in excludedTags) {
        if (entry.careerTags.contains(tag)) {
          return false;
        }
      }
      return true;
    }
    for (final tag in requiredTags) {
      if (!entry.careerTags.contains(tag)) {
        return false;
      }
    }
    for (final tag in excludedTags) {
      if (entry.careerTags.contains(tag)) {
        return false;
      }
    }
    return true;
  }

  BotProfile _profileForParticipant(String participantId) {
    final bracket = _currentBracket;
    if (bracket != null) {
      for (final participant in bracket.participants) {
        if (participant.id != participantId) {
          continue;
        }
        if (participant.botSkill != null && participant.botFinishingSkill != null) {
          return SettingsRepository.instance.createBotProfile(
            skill: participant.botSkill!,
            finishingSkill: participant.botFinishingSkill!,
          );
        }
        break;
      }
    }

    final playerProfile = PlayerRepository.instance.activePlayer;
    if (playerProfile != null && playerProfile.id == participantId) {
      return _profileForAverage(playerProfile.average);
    }

    for (final player in ComputerRepository.instance.players) {
      if (player.id == participantId) {
        return SettingsRepository.instance.createBotProfile(
          skill: player.skill,
          finishingSkill: player.finishingSkill,
        );
      }
    }

    return SettingsRepository.instance.createBotProfile(
      skill: 700,
      finishingSkill: 700,
    );
  }

  BotProfile Function(String participantId) _profileProviderForBracket(
    TournamentBracket bracket,
  ) {
    final participantProfiles = _profilesForBracket(bracket);
    final defaultProfile = SettingsRepository.instance.createBotProfile(
      skill: 700,
      finishingSkill: 700,
    );
    return (String participantId) =>
        participantProfiles[participantId] ?? defaultProfile;
  }

  Map<String, BotProfile> _profilesForBracket(TournamentBracket bracket) {
    final activePlayer = PlayerRepository.instance.activePlayer;
    final computerProfiles = <String, BotProfile>{
      for (final player in ComputerRepository.instance.players)
        player.id: SettingsRepository.instance.createBotProfile(
          skill: player.skill,
          finishingSkill: player.finishingSkill,
        ),
    };
    final participantProfiles = <String, BotProfile>{};

    for (final participant in bracket.participants) {
      if (participant.botSkill != null && participant.botFinishingSkill != null) {
        participantProfiles[participant.id] =
            SettingsRepository.instance.createBotProfile(
              skill: participant.botSkill!,
              finishingSkill: participant.botFinishingSkill!,
            );
        continue;
      }
      if (activePlayer != null && activePlayer.id == participant.id) {
        participantProfiles[participant.id] = _profileForAverage(
          activePlayer.average,
        );
        continue;
      }
      final computerProfile = computerProfiles[participant.id];
      if (computerProfile != null) {
        participantProfiles[participant.id] = computerProfile;
        continue;
      }
      participantProfiles[participant.id] = _profileForAverage(
        participant.average,
      );
    }
    return participantProfiles;
  }

  Map<String, Object?> _serializedProfilesForBracket(TournamentBracket bracket) {
    final result = <String, Object?>{};
    _profilesForBracket(bracket).forEach((participantId, profile) {
      result[participantId] = <String, Object?>{
        'skill': profile.skill,
        'finishingSkill': profile.finishingSkill,
        'radiusCalibrationPercent': profile.radiusCalibrationPercent,
        'simulationSpreadPercent': profile.simulationSpreadPercent,
      };
    });
    return result;
  }

  int _countCompletedMatchesLowMemory(TournamentBracket bracket) {
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

  BotProfile _profileForAverage(double average) {
    final normalizedAverage = average > 0 ? average : 65;
    final players = ComputerRepository.instance.players;
    if (players.isEmpty) {
      return SettingsRepository.instance.createBotProfile(
        skill: 700,
        finishingSkill: 700,
      );
    }

    ComputerPlayer? bestMatch;
    var bestDistance = double.infinity;
    for (final player in players) {
      final distance = (player.theoreticalAverage - normalizedAverage).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestMatch = player;
      }
    }

    if (bestMatch == null) {
      return SettingsRepository.instance.createBotProfile(
        skill: 700,
        finishingSkill: 700,
      );
    }

    return SettingsRepository.instance.createBotProfile(
      skill: bestMatch.skill,
      finishingSkill: bestMatch.finishingSkill,
    );
  }

  BotProfile profileForParticipant(String participantId) {
    return _profileForParticipant(participantId);
  }

  double _generatedTargetAverage({
    required int index,
    required int totalCount,
    required double minimumAverage,
    required double maximumAverage,
  }) {
    if (totalCount <= 1 || (maximumAverage - minimumAverage).abs() < 0.001) {
      return minimumAverage;
    }
    final factor = index / (totalCount - 1);
    return minimumAverage + ((maximumAverage - minimumAverage) * factor);
  }

  String _generatedComputerName(int number) {
    return 'CPU $number';
  }

  int? _roundNumberForMatch(TournamentBracket bracket, String matchId) {
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        if (match.id == matchId) {
          return round.roundNumber;
        }
      }
    }
    return null;
  }

  int? _nextPendingRoundNumber(TournamentBracket bracket) {
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        if (match.status == TournamentMatchStatus.pending && match.isReady) {
          return round.roundNumber;
        }
      }
    }
    return null;
  }

  bool _shouldStopBeforeNextRound(TournamentBracket bracket) {
    final roundNumber = _nextPendingRoundNumber(bracket);
    if (roundNumber == null) {
      return false;
    }
    return _hasPendingHumanMatchInRound(bracket, roundNumber);
  }

  bool _hasPendingHumanMatchInRound(TournamentBracket bracket, int roundNumber) {
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

  void _simulateRemainingCpuMatchesForRound(int? roundNumber) {
    if (roundNumber == null) {
      return;
    }
    final bracket = _currentBracket;
    if (bracket == null) {
      return;
    }

    var workingBracket = bracket;
    final profileProvider = _profileProviderForBracket(bracket);
    while (true) {
      TournamentMatch? nextCpuMatch;
      for (final round in workingBracket.rounds) {
        if (round.roundNumber != roundNumber) {
          continue;
        }
        for (final match in round.matches) {
          if (match.status == TournamentMatchStatus.pending &&
              match.isReady &&
              !match.isHumanMatch) {
            nextCpuMatch = match;
            break;
          }
        }
        break;
      }

      if (nextCpuMatch == null) {
        break;
      }

      final nextBracket = _engine.simulateSpecificMatch(
        bracket: workingBracket,
        matchId: nextCpuMatch.id,
        profileProvider: profileProvider,
      );
      if (identical(nextBracket, workingBracket)) {
        break;
      }
      workingBracket = nextBracket;
    }

    _currentBracket = workingBracket;
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, dynamic>{
        'currentBracket': _currentBracket?.toJson(),
        'careerContext': _careerContext?.toJson(),
        'archive': _archive.map((entry) => entry.toJson()).toList(),
        'savedComputerSelections': _savedComputerSelections
            .map((entry) => entry.toJson())
            .toList(),
      },
    );
  }

  void _storeArchive(TournamentArchiveEntry nextEntry) {
    _archive.removeWhere(
      (entry) =>
          entry.careerId == nextEntry.careerId &&
          entry.seasonNumber == nextEntry.seasonNumber &&
          entry.calendarItemId == nextEntry.calendarItemId,
    );
    _archive.insert(0, _normalizeArchiveEntry(nextEntry));
    _pruneArchive();
  }

  TournamentArchiveEntry _normalizeArchiveEntry(TournamentArchiveEntry entry) {
    return TournamentArchiveEntry(
      id: entry.id,
      name: entry.name,
      bracket: _lightweightArchiveBracket(entry.bracket),
      careerId: entry.careerId,
      seasonNumber: entry.seasonNumber,
      calendarItemId: entry.calendarItemId,
    );
  }

  TournamentBracket _lightweightArchiveBracket(TournamentBracket bracket) {
    return TournamentBracket(
      definition: bracket.definition,
      participants: bracket.participants,
      rounds: bracket.rounds
          .map(
            (round) => TournamentRound(
              roundNumber: round.roundNumber,
              title: round.title,
              stage: round.stage,
              matches: round.matches
                  .map(
                    (match) => TournamentMatch(
                      id: match.id,
                      roundNumber: match.roundNumber,
                      matchNumber: match.matchNumber,
                      playerA: match.playerA,
                      playerB: match.playerB,
                      status: match.status,
                      result: match.result == null
                          ? null
                          : TournamentMatchResult(
                              winnerId: match.result!.winnerId,
                              winnerName: match.result!.winnerName,
                              scoreText: match.result!.scoreText,
                              isDraw: match.result!.isDraw,
                            ),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  void _pruneArchive() {
    if (_archive.isEmpty) {
      return;
    }
    final nextArchive = <TournamentArchiveEntry>[];
    var keptCareerEntries = 0;
    for (final entry in _archive) {
      final isCareerEntry = entry.careerId != null;
      if (isCareerEntry && keptCareerEntries >= _maxCareerArchiveEntries) {
        continue;
      }
      if (nextArchive.length >= _maxArchiveEntries) {
        break;
      }
      nextArchive.add(entry);
      if (isCareerEntry) {
        keptCareerEntries += 1;
      }
    }
    if (nextArchive.length == _archive.length) {
      return;
    }
    _archive
      ..clear()
      ..addAll(nextArchive);
  }

  CareerLeagueSeriesState? _leagueSeriesState(
    CareerDefinition career,
    String seriesId,
  ) {
    for (final entry in career.leagueSeriesStates) {
      if (entry.id == seriesId) {
        return entry;
      }
    }
    return null;
  }

  List<TournamentParticipant> _participantsForLeagueSeriesItem({
    required CareerDefinition career,
    required CareerCalendarItem item,
    required CareerLeagueSeriesState? existingState,
    required String seriesName,
  }) {
    if (item.leagueSeriesQualificationMode ==
        CareerLeagueSeriesQualificationMode.recheckEachMatchday) {
      return _buildCareerParticipants(career: career, item: item);
    }
    final fixedIds = existingState?.fixedParticipantIds ?? const <String>[];
    if (fixedIds.isNotEmpty) {
      return _participantsByIds(career, fixedIds);
    }
    final initialParticipants = _buildCareerParticipants(career: career, item: item);
    if (initialParticipants.isEmpty) {
      return initialParticipants;
    }
    CareerRepository.instance.setLeagueSeriesState(
      CareerLeagueSeriesState(
        id: item.seriesGroupId!,
        baseName: seriesName,
        format: item.format,
        qualificationMode: item.leagueSeriesQualificationMode,
        fixedParticipantIds: initialParticipants
            .map((entry) => entry.id)
            .toList(),
      ),
    );
    return initialParticipants;
  }

  List<TournamentParticipant> _participantsByIds(
    CareerDefinition career,
    List<String> ids,
  ) {
    final pool = _careerPool(career);
    final result = <TournamentParticipant>[];
    for (final id in ids) {
      final entry = pool[id];
      if (entry == null) {
        continue;
      }
      result.add(
        TournamentParticipant(
          id: entry.id,
          name: entry.name,
          type: entry.type,
          average: entry.average,
          entryRound: entry.entryRound,
          qualificationReason: entry.qualificationReason,
          botSkill: entry.botSkill,
          botFinishingSkill: entry.botFinishingSkill,
        ),
      );
    }
    return result;
  }

  List<TournamentRound> _historicalSeriesRounds(CareerLeagueSeriesState? state) {
    if (state == null) {
      return const <TournamentRound>[];
    }
    final rounds = <TournamentRound>[];
    for (final entry in state.completedRounds) {
      rounds.addAll(entry.bracket.rounds);
    }
    rounds.sort((left, right) => left.roundNumber.compareTo(right.roundNumber));
    return rounds;
  }

  List<TournamentParticipant> _participantsFromRounds(
    List<TournamentRound> rounds,
  ) {
    final byId = <String, TournamentParticipant>{};
    for (final round in rounds) {
      for (final match in round.matches) {
        final playerA = match.playerA;
        final playerB = match.playerB;
        if (playerA != null) {
          byId[playerA.id] = playerA;
        }
        if (playerB != null) {
          byId[playerB.id] = playerB;
        }
      }
    }
    return byId.values.toList();
  }

  List<TournamentParticipant> _mergeParticipants(
    List<TournamentParticipant> left,
    List<TournamentParticipant> right,
  ) {
    final merged = <String, TournamentParticipant>{};
    for (final participant in left) {
      merged[participant.id] = participant;
    }
    for (final participant in right) {
      merged[participant.id] = participant;
    }
    return merged.values.toList();
  }

  TournamentRound? _roundForSeriesItem(
    List<TournamentRound> rounds,
    int? roundNumber,
  ) {
    if (roundNumber == null) {
      return null;
    }
    for (final round in rounds) {
      if (round.roundNumber == roundNumber) {
        return round;
      }
    }
    return null;
  }

  TournamentBracket _roundOnlyBracketForSeriesItem({
    required CareerCalendarItem item,
    required TournamentBracket bracket,
  }) {
    final currentRound = _roundForSeriesItem(bracket.rounds, item.seriesIndex);
    if (currentRound == null) {
      return bracket;
    }
    return TournamentBracket(
      definition: bracket.definition,
      participants: bracket.participants,
      rounds: <TournamentRound>[currentRound],
    );
  }

  String _baseNameForSeriesItem(CareerCalendarItem item) {
    const matchdayDivider = ' - Spieltag ';
    const playoffDivider = ' - Playoff ';
    if (item.name.contains(matchdayDivider)) {
      return item.name.split(matchdayDivider).first.trim();
    }
    if (item.name.contains(playoffDivider)) {
      return item.name.split(playoffDivider).first.trim();
    }
    return item.name;
  }

  void _logProcessMemory(String label) {
    try {
      final rssBytes = ProcessInfo.currentRss;
      AppDebug.instance.info(
        'Memory',
        '$label | RSS ${_formatMemory(rssBytes)}',
      );
    } catch (_) {
      // Ignore environments where process memory is unavailable.
    }
  }

  String _formatMemory(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    }
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(0)} MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}

class _CareerPoolEntry {
  const _CareerPoolEntry({
    required this.id,
    required this.name,
    required this.type,
    required this.average,
    this.entryRound = 1,
    this.careerTags = const <String>[],
    this.qualificationReason,
    this.botSkill,
    this.botFinishingSkill,
  });

  final String id;
  final String name;
  final TournamentParticipantType type;
  final double average;
  final int entryRound;
  final List<String> careerTags;
  final String? qualificationReason;
  final int? botSkill;
  final int? botFinishingSkill;

  _CareerPoolEntry copyWith({
    String? qualificationReason,
    int? entryRound,
  }) {
    return _CareerPoolEntry(
      id: id,
      name: name,
      type: type,
      average: average,
      entryRound: entryRound ?? this.entryRound,
      careerTags: careerTags,
      qualificationReason: qualificationReason ?? this.qualificationReason,
      botSkill: botSkill,
      botFinishingSkill: botFinishingSkill,
    );
  }
}

class _CareerRankedEntry {
  const _CareerRankedEntry({
    required this.rank,
    required this.entry,
    this.isFallback = false,
  });

  final int rank;
  final _CareerPoolEntry entry;
  final bool isFallback;
}

class CareerTournamentContext {
  const CareerTournamentContext({
    required this.careerId,
    required this.seasonNumber,
    required this.calendarItem,
  });

  final String careerId;
  final int seasonNumber;
  final CareerCalendarItem calendarItem;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'careerId': careerId,
      'seasonNumber': seasonNumber,
      'calendarItem': calendarItem.toJson(),
    };
  }

  static CareerTournamentContext fromJson(Map<String, dynamic> json) {
    return CareerTournamentContext(
      careerId: json['careerId'] as String,
      seasonNumber: (json['seasonNumber'] as num).toInt(),
      calendarItem: CareerCalendarItem.fromJson(
        (json['calendarItem'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class TournamentArchiveEntry {
  const TournamentArchiveEntry({
    required this.id,
    required this.name,
    required this.bracket,
    this.careerId,
    this.seasonNumber,
    this.calendarItemId,
  });

  final String id;
  final String name;
  final TournamentBracket bracket;
  final String? careerId;
  final int? seasonNumber;
  final String? calendarItemId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'bracket': bracket.toJson(),
      'careerId': careerId,
      'seasonNumber': seasonNumber,
      'calendarItemId': calendarItemId,
    };
  }

  static TournamentArchiveEntry fromJson(Map<String, dynamic> json) {
    return TournamentArchiveEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      bracket: TournamentBracket.fromJson(
        (json['bracket'] as Map).cast<String, dynamic>(),
      ),
      careerId: json['careerId'] as String?,
      seasonNumber: (json['seasonNumber'] as num?)?.toInt(),
      calendarItemId: json['calendarItemId'] as String?,
    );
  }
}

class TournamentComputerSelectionPreset {
  const TournamentComputerSelectionPreset({
    required this.id,
    required this.name,
    required this.computerIds,
  });

  final String id;
  final String name;
  final List<String> computerIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'computerIds': computerIds,
    };
  }

  static TournamentComputerSelectionPreset fromJson(
    Map<String, dynamic> json,
  ) {
    return TournamentComputerSelectionPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      computerIds:
          (json['computerIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .toList(),
    );
  }
}

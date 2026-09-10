import 'dart:math';

import '../../domain/career/career_models.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';

enum TournamentCreationMode {
  singleTournament,
  tournamentSeries,
}

class TournamentPhaseTournamentFormData {
  const TournamentPhaseTournamentFormData({
    this.format = TournamentFormat.knockout,
    this.qualificationRules = const <TournamentQualificationRuleFormData>[],
  });

  final TournamentFormat format;
  final List<TournamentQualificationRuleFormData> qualificationRules;

  TournamentPhaseTournamentFormData copyWith({
    TournamentFormat? format,
    List<TournamentQualificationRuleFormData>? qualificationRules,
  }) {
    return TournamentPhaseTournamentFormData(
      format: format ?? this.format,
      qualificationRules: qualificationRules ?? this.qualificationRules,
    );
  }
}

class TournamentQualificationRuleFormData {
  const TournamentQualificationRuleFormData({
    this.startPlacement = 1,
    this.endPlacement = 1,
    this.targetPhaseNumber,
    this.targetTournamentNumber,
  });

  final int startPlacement;
  final int endPlacement;
  final int? targetPhaseNumber;
  final int? targetTournamentNumber;

  TournamentQualificationRuleFormData copyWith({
    int? startPlacement,
    int? endPlacement,
    int? targetPhaseNumber,
    bool clearTargetPhaseNumber = false,
    int? targetTournamentNumber,
    bool clearTargetTournamentNumber = false,
  }) {
    return TournamentQualificationRuleFormData(
      startPlacement: startPlacement ?? this.startPlacement,
      endPlacement: endPlacement ?? this.endPlacement,
      targetPhaseNumber: clearTargetPhaseNumber
          ? null
          : targetPhaseNumber ?? this.targetPhaseNumber,
      targetTournamentNumber: clearTargetTournamentNumber
          ? null
          : targetTournamentNumber ?? this.targetTournamentNumber,
    );
  }
}

class TournamentFormData {
  const TournamentFormData({
    this.creationMode = TournamentCreationMode.singleTournament,
    this.game = TournamentGame.x01,
    this.format = TournamentFormat.knockout,
    this.phaseCount = 1,
    this.phaseTournamentCounts = const <int>[1],
    this.phaseTournaments = const <List<TournamentPhaseTournamentFormData>>[
      <TournamentPhaseTournamentFormData>[
        TournamentPhaseTournamentFormData(
          format: TournamentFormat.knockout,
        ),
      ],
    ],
    this.tierInput = '1',
    this.fieldSizeInput = '16',
    this.matchMode = MatchMode.legs,
    this.legsValue = 6,
    this.setsToWin = 3,
    this.startScoreInput = '501',
    this.startRequirement = StartRequirement.straightIn,
    this.checkoutRequirement = CheckoutRequirement.doubleOut,
    this.roundDistanceValues = const <int>[],
    this.pointsForWin = 2,
    this.pointsForDraw = 1,
    this.roundRobinRepeats = 1,
    this.maxLeagueMatchesPerParticipant = 0,
    this.playoffQualifierCount = 4,
    this.groupCount = 2,
    this.playersPerGroup = 4,
  });

  final TournamentCreationMode creationMode;
  final TournamentGame game;
  final TournamentFormat format;
  final int phaseCount;
  final List<int> phaseTournamentCounts;
  final List<List<TournamentPhaseTournamentFormData>> phaseTournaments;
  final String tierInput;
  final String fieldSizeInput;
  final MatchMode matchMode;
  final int legsValue;
  final int setsToWin;
  final String startScoreInput;
  final StartRequirement startRequirement;
  final CheckoutRequirement checkoutRequirement;
  final List<int> roundDistanceValues;
  final int pointsForWin;
  final int pointsForDraw;
  final int roundRobinRepeats;
  final int maxLeagueMatchesPerParticipant;
  final int playoffQualifierCount;
  final int groupCount;
  final int playersPerGroup;

  TournamentFormat get primaryFormat => effectivePhaseTournaments.first.first.format;
  bool get isSeriesMode =>
      creationMode == TournamentCreationMode.tournamentSeries;
  int get effectiveLegsToWin => matchMode == MatchMode.legs ? legsValue : 3;
  int get effectiveSetsToWin => matchMode == MatchMode.legs ? 1 : setsToWin;
  int get effectiveLegsPerSet => matchMode == MatchMode.legs ? 1 : legsValue;
  int? get parsedTier => int.tryParse(tierInput.trim());
  int? get parsedFieldSize => int.tryParse(fieldSizeInput.trim());
  int? get parsedStartScore => int.tryParse(startScoreInput.trim());
  int get configuredGroupFieldSize =>
      (groupCount < 1 ? 1 : groupCount) * (playersPerGroup < 1 ? 1 : playersPerGroup);
  int? get effectiveFieldSize =>
      primaryFormat == TournamentFormat.groupStage
          ? configuredGroupFieldSize
          : parsedFieldSize;
  List<int> get effectivePhaseTournamentCounts {
    final safePhaseCount = phaseCount < 1 ? 1 : phaseCount;
    final counts = List<int>.from(phaseTournamentCounts);
    if (counts.isEmpty) {
      counts.add(1);
    }
    while (counts.length < safePhaseCount) {
      counts.add(counts.last);
    }
    if (counts.length > safePhaseCount) {
      counts.removeRange(safePhaseCount, counts.length);
    }
    return counts.map((value) => value < 1 ? 1 : value).toList();
  }

  List<List<TournamentPhaseTournamentFormData>> get effectivePhaseTournaments {
    final counts = effectivePhaseTournamentCounts;
    final phases = <List<TournamentPhaseTournamentFormData>>[];
    for (var phaseIndex = 0; phaseIndex < counts.length; phaseIndex += 1) {
      final requiredCount = counts[phaseIndex];
      final existing = phaseIndex < phaseTournaments.length
          ? List<TournamentPhaseTournamentFormData>.from(
              phaseTournaments[phaseIndex],
            )
          : <TournamentPhaseTournamentFormData>[];
      if (existing.isEmpty) {
        existing.add(
          TournamentPhaseTournamentFormData(
            format: phaseIndex == 0 ? format : TournamentFormat.knockout,
          ),
        );
      }
      while (existing.length < requiredCount) {
        existing.add(existing.last);
      }
      if (existing.length > requiredCount) {
        existing.removeRange(requiredCount, existing.length);
      }
      phases.add(existing);
    }
    return phases;
  }

  int get roundCount {
    final entrants = parsedFieldSize;
    if (primaryFormat == TournamentFormat.league ||
        primaryFormat == TournamentFormat.groupStage) {
      return 0;
    }
    final int playoffEntrants = primaryFormat == TournamentFormat.leaguePlayoff
        ? playoffQualifierCount
        : (entrants ?? 0);
    if (playoffEntrants < 2) {
      return 0;
    }
    var bracketSize = 2;
    while (bracketSize < playoffEntrants) {
      bracketSize *= 2;
    }
    return (log(bracketSize) / log(2)).round();
  }

  List<int> get effectiveRoundDistanceValues {
    final rounds = roundCount;
    if (rounds <= 0) {
      return const <int>[];
    }
    final fallbackValue =
        matchMode == MatchMode.legs ? effectiveLegsToWin : effectiveSetsToWin;
    return List<int>.generate(rounds, (index) {
      if (index < roundDistanceValues.length) {
        return max(1, roundDistanceValues[index]);
      }
      return fallbackValue;
    });
  }

  TournamentFormData copyWith({
    TournamentCreationMode? creationMode,
    TournamentGame? game,
    TournamentFormat? format,
    int? phaseCount,
    List<int>? phaseTournamentCounts,
    List<List<TournamentPhaseTournamentFormData>>? phaseTournaments,
    String? tierInput,
    String? fieldSizeInput,
    MatchMode? matchMode,
    int? legsValue,
    int? setsToWin,
    String? startScoreInput,
    StartRequirement? startRequirement,
    CheckoutRequirement? checkoutRequirement,
    List<int>? roundDistanceValues,
    int? pointsForWin,
    int? pointsForDraw,
    int? roundRobinRepeats,
    int? maxLeagueMatchesPerParticipant,
    int? playoffQualifierCount,
    int? groupCount,
    int? playersPerGroup,
  }) {
    final nextPhaseCount = phaseCount ?? this.phaseCount;
    final nextCounts = List<int>.from(
      phaseTournamentCounts ?? this.phaseTournamentCounts,
    );
    if (nextCounts.isEmpty) {
      nextCounts.add(1);
    }
    while (nextCounts.length < nextPhaseCount) {
      nextCounts.add(nextCounts.last);
    }
    if (nextCounts.length > nextPhaseCount) {
      nextCounts.removeRange(nextPhaseCount, nextCounts.length);
    }
    final nextPhaseEntries = (phaseTournaments ?? this.phaseTournaments)
        .map((entry) => List<TournamentPhaseTournamentFormData>.from(entry))
        .toList();
    while (nextPhaseEntries.length < nextPhaseCount) {
      nextPhaseEntries.add(<TournamentPhaseTournamentFormData>[
        TournamentPhaseTournamentFormData(
          format: nextPhaseEntries.isEmpty
              ? (format ?? this.format)
              : nextPhaseEntries.last.last.format,
        ),
      ]);
    }
    if (nextPhaseEntries.length > nextPhaseCount) {
      nextPhaseEntries.removeRange(nextPhaseCount, nextPhaseEntries.length);
    }
    for (var phaseIndex = 0; phaseIndex < nextCounts.length; phaseIndex += 1) {
      final requiredCount = nextCounts[phaseIndex] < 1 ? 1 : nextCounts[phaseIndex];
      while (nextPhaseEntries[phaseIndex].length < requiredCount) {
        nextPhaseEntries[phaseIndex].add(nextPhaseEntries[phaseIndex].last);
      }
      if (nextPhaseEntries[phaseIndex].length > requiredCount) {
        nextPhaseEntries[phaseIndex].removeRange(
          requiredCount,
          nextPhaseEntries[phaseIndex].length,
        );
      }
    }
    if (format != null && nextPhaseEntries.isNotEmpty && nextPhaseEntries.first.isNotEmpty) {
      nextPhaseEntries.first[0] =
          nextPhaseEntries.first[0].copyWith(format: format);
    }
    return TournamentFormData(
      creationMode: creationMode ?? this.creationMode,
      game: game ?? this.game,
      format: nextPhaseEntries.first.first.format,
      phaseCount: nextPhaseCount,
      phaseTournamentCounts: nextCounts,
      phaseTournaments: nextPhaseEntries,
      tierInput: tierInput ?? this.tierInput,
      fieldSizeInput: fieldSizeInput ?? this.fieldSizeInput,
      matchMode: matchMode ?? this.matchMode,
      legsValue: legsValue ?? this.legsValue,
      setsToWin: setsToWin ?? this.setsToWin,
      startScoreInput: startScoreInput ?? this.startScoreInput,
      startRequirement: startRequirement ?? this.startRequirement,
      checkoutRequirement: checkoutRequirement ?? this.checkoutRequirement,
      roundDistanceValues: roundDistanceValues ?? this.roundDistanceValues,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      roundRobinRepeats: roundRobinRepeats ?? this.roundRobinRepeats,
      maxLeagueMatchesPerParticipant:
          maxLeagueMatchesPerParticipant ?? this.maxLeagueMatchesPerParticipant,
      playoffQualifierCount:
          playoffQualifierCount ?? this.playoffQualifierCount,
      groupCount: groupCount ?? this.groupCount,
      playersPerGroup: playersPerGroup ?? this.playersPerGroup,
    );
  }

  static TournamentFormData fromCareerItem(CareerCalendarItem item) {
    return TournamentFormData(
      creationMode: TournamentCreationMode.singleTournament,
      game: item.game,
      format: item.format,
      phaseCount: 1,
      phaseTournamentCounts: const <int>[1],
      phaseTournaments: <List<TournamentPhaseTournamentFormData>>[
        <TournamentPhaseTournamentFormData>[
          TournamentPhaseTournamentFormData(format: item.format),
        ],
      ],
      tierInput: '${item.tier}',
      fieldSizeInput: '${item.fieldSize}',
      matchMode: item.matchMode,
      legsValue:
          item.matchMode == MatchMode.legs ? item.legsToWin : item.legsPerSet,
      setsToWin: item.setsToWin,
      startScoreInput: '${item.startScore}',
      startRequirement: StartRequirement.straightIn,
      checkoutRequirement: item.checkoutRequirement,
      roundDistanceValues: item.roundDistanceValues,
      pointsForWin: item.pointsForWin,
      pointsForDraw: item.pointsForDraw,
      roundRobinRepeats: item.roundRobinRepeats,
      maxLeagueMatchesPerParticipant: item.maxLeagueMatchesPerParticipant,
      playoffQualifierCount: item.playoffQualifierCount,
      groupCount: item.groupCount,
      playersPerGroup: item.playersPerGroup,
    );
  }
}

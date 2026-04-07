import '../x01/x01_models.dart';

enum TournamentGame {
  x01,
}

enum TournamentFormat {
  knockout,
  league,
  leaguePlayoff,
}

enum TournamentRoundStage {
  knockout,
  league,
  playoff,
}

enum TournamentParticipantType {
  human,
  computer,
}

enum TournamentMatchStatus {
  pending,
  completed,
}

class TournamentParticipant {
  const TournamentParticipant({
    required this.id,
    required this.name,
    required this.type,
    required this.average,
    this.entryRound = 1,
    this.seedNumber,
    this.qualificationReason,
    this.botSkill,
    this.botFinishingSkill,
  });

  final String id;
  final String name;
  final TournamentParticipantType type;
  final double average;
  final int entryRound;
  final int? seedNumber;
  final String? qualificationReason;
  final int? botSkill;
  final int? botFinishingSkill;

  bool get isHuman => type == TournamentParticipantType.human;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type.name,
      'average': average,
      'entryRound': entryRound,
      'seedNumber': seedNumber,
      'qualificationReason': qualificationReason,
      'botSkill': botSkill,
      'botFinishingSkill': botFinishingSkill,
    };
  }

  static TournamentParticipant fromJson(Map<String, dynamic> json) {
    return TournamentParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      type: TournamentParticipantType.values.byName(json['type'] as String),
      average: (json['average'] as num).toDouble(),
      entryRound: (json['entryRound'] as num?)?.toInt() ?? 1,
      seedNumber: (json['seedNumber'] as num?)?.toInt(),
      qualificationReason: json['qualificationReason'] as String?,
      botSkill: (json['botSkill'] as num?)?.toInt(),
      botFinishingSkill: (json['botFinishingSkill'] as num?)?.toInt(),
    );
  }
}

class TournamentDefinition {
  const TournamentDefinition({
    required this.name,
    this.game = TournamentGame.x01,
    this.format = TournamentFormat.knockout,
    required this.fieldSize,
    this.matchMode = MatchMode.legs,
    required this.legsToWin,
    required this.startScore,
    this.startRequirement = StartRequirement.straightIn,
    this.checkoutRequirement = CheckoutRequirement.doubleOut,
    this.setsToWin = 1,
    this.legsPerSet = 1,
    this.roundDistanceValues = const <int>[],
    this.pointsForWin = 2,
    this.pointsForDraw = 1,
    this.roundRobinRepeats = 1,
    this.playoffQualifierCount = 4,
    required this.includeHumanPlayer,
  });

  final String name;
  final TournamentGame game;
  final TournamentFormat format;
  final int fieldSize;
  final MatchMode matchMode;
  final int legsToWin;
  final int startScore;
  final StartRequirement startRequirement;
  final CheckoutRequirement checkoutRequirement;
  final int setsToWin;
  final int legsPerSet;
  final List<int> roundDistanceValues;
  final int pointsForWin;
  final int pointsForDraw;
  final int roundRobinRepeats;
  final int playoffQualifierCount;
  final bool includeHumanPlayer;

  int distanceForRound(int roundNumber) {
    final index = roundNumber - 1;
    if (index >= 0 && index < roundDistanceValues.length) {
      return roundDistanceValues[index];
    }
    return matchMode == MatchMode.legs ? legsToWin : setsToWin;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'game': game.name,
      'format': format.name,
      'fieldSize': fieldSize,
      'matchMode': matchMode.name,
      'legsToWin': legsToWin,
      'startScore': startScore,
      'startRequirement': startRequirement.name,
      'checkoutRequirement': checkoutRequirement.name,
      'setsToWin': setsToWin,
      'legsPerSet': legsPerSet,
      'roundDistanceValues': roundDistanceValues,
      'pointsForWin': pointsForWin,
      'pointsForDraw': pointsForDraw,
      'roundRobinRepeats': roundRobinRepeats,
      'playoffQualifierCount': playoffQualifierCount,
      'includeHumanPlayer': includeHumanPlayer,
    };
  }

  static TournamentDefinition fromJson(Map<String, dynamic> json) {
    return TournamentDefinition(
      name: json['name'] as String,
      game: TournamentGame.values.byName(
        json['game'] as String? ?? TournamentGame.x01.name,
      ),
      format: TournamentFormat.values.byName(
        json['format'] as String? ?? TournamentFormat.knockout.name,
      ),
      fieldSize: (json['fieldSize'] as num).toInt(),
      matchMode: MatchMode.values.byName(
        json['matchMode'] as String? ?? MatchMode.legs.name,
      ),
      legsToWin: (json['legsToWin'] as num).toInt(),
      startScore: (json['startScore'] as num).toInt(),
      startRequirement: StartRequirement.values.byName(
        json['startRequirement'] as String? ?? StartRequirement.straightIn.name,
      ),
      checkoutRequirement: CheckoutRequirement.values.byName(
        json['checkoutRequirement'] as String? ??
            CheckoutRequirement.doubleOut.name,
      ),
      setsToWin: (json['setsToWin'] as num?)?.toInt() ?? 1,
      legsPerSet: (json['legsPerSet'] as num?)?.toInt() ?? 1,
      roundDistanceValues:
          (json['roundDistanceValues'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => (entry as num).toInt())
              .toList(),
      pointsForWin: (json['pointsForWin'] as num?)?.toInt() ?? 2,
      pointsForDraw: (json['pointsForDraw'] as num?)?.toInt() ?? 1,
      roundRobinRepeats: (json['roundRobinRepeats'] as num?)?.toInt() ?? 1,
      playoffQualifierCount:
          (json['playoffQualifierCount'] as num?)?.toInt() ?? 4,
      includeHumanPlayer: json['includeHumanPlayer'] as bool? ?? false,
    );
  }
}

class TournamentMatchResult {
  const TournamentMatchResult({
    this.winnerId,
    this.winnerName,
    required this.scoreText,
    this.isDraw = false,
    this.participantStats = const <TournamentPlayerMatchStats>[],
  });

  final String? winnerId;
  final String? winnerName;
  final String scoreText;
  final bool isDraw;
  final List<TournamentPlayerMatchStats> participantStats;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'winnerId': winnerId,
      'winnerName': winnerName,
      'scoreText': scoreText,
      'isDraw': isDraw,
      'participantStats': participantStats.map((entry) => entry.toJson()).toList(),
    };
  }

  static TournamentMatchResult fromJson(Map<String, dynamic> json) {
    return TournamentMatchResult(
      winnerId: json['winnerId'] as String?,
      winnerName: json['winnerName'] as String?,
      scoreText: json['scoreText'] as String,
      isDraw: json['isDraw'] as bool? ?? false,
      participantStats:
          (json['participantStats'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => TournamentPlayerMatchStats.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }
}

class TournamentPlayerMatchStats {
  const TournamentPlayerMatchStats({
    required this.participantId,
    required this.participantName,
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
    this.won9Darters = 0,
    this.won12Darters = 0,
    this.won15Darters = 0,
    this.won18Darters = 0,
  });

  final String participantId;
  final String participantName;
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
  final int won9Darters;
  final int won12Darters;
  final int won15Darters;
  final int won18Darters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'participantId': participantId,
      'participantName': participantName,
      'pointsScored': pointsScored,
      'dartsThrown': dartsThrown,
      'visits': visits,
      'legsWon': legsWon,
      'legsPlayed': legsPlayed,
      'legsStarted': legsStarted,
      'legsWonAsStarter': legsWonAsStarter,
      'legsWonWithoutStarter': legsWonWithoutStarter,
      'scores0To40': scores0To40,
      'scores41To59': scores41To59,
      'scores60Plus': scores60Plus,
      'scores100Plus': scores100Plus,
      'scores140Plus': scores140Plus,
      'scores171Plus': scores171Plus,
      'scores180': scores180,
      'checkoutAttempts': checkoutAttempts,
      'successfulCheckouts': successfulCheckouts,
      'checkoutAttempts1Dart': checkoutAttempts1Dart,
      'checkoutAttempts2Dart': checkoutAttempts2Dart,
      'checkoutAttempts3Dart': checkoutAttempts3Dart,
      'successfulCheckouts1Dart': successfulCheckouts1Dart,
      'successfulCheckouts2Dart': successfulCheckouts2Dart,
      'successfulCheckouts3Dart': successfulCheckouts3Dart,
      'thirdDartCheckoutAttempts': thirdDartCheckoutAttempts,
      'thirdDartCheckouts': thirdDartCheckouts,
      'bullCheckoutAttempts': bullCheckoutAttempts,
      'bullCheckouts': bullCheckouts,
      'functionalDoubleAttempts': functionalDoubleAttempts,
      'functionalDoubleSuccesses': functionalDoubleSuccesses,
      'firstNinePoints': firstNinePoints,
      'firstNineDarts': firstNineDarts,
      'highestFinish': highestFinish,
      'bestLegDarts': bestLegDarts,
      'totalFinishValue': totalFinishValue,
      'withThrowPoints': withThrowPoints,
      'withThrowDarts': withThrowDarts,
      'againstThrowPoints': againstThrowPoints,
      'againstThrowDarts': againstThrowDarts,
      'decidingLegPoints': decidingLegPoints,
      'decidingLegDarts': decidingLegDarts,
      'decidingLegsPlayed': decidingLegsPlayed,
      'decidingLegsWon': decidingLegsWon,
      'won9Darters': won9Darters,
      'won12Darters': won12Darters,
      'won15Darters': won15Darters,
      'won18Darters': won18Darters,
    };
  }

  static TournamentPlayerMatchStats fromJson(Map<String, dynamic> json) {
    final pointsScored = (json['pointsScored'] as num?)?.toInt() ?? 0;
    final dartsThrown = (json['dartsThrown'] as num?)?.toInt() ?? 0;
    final legsPlayed = (json['legsPlayed'] as num?)?.toInt() ?? 0;
    final normalizedFirstNine = _normalizeFirstNineSample(
      pointsScored: pointsScored,
      dartsThrown: dartsThrown,
      legsPlayed: legsPlayed,
      firstNinePoints: (json['firstNinePoints'] as num?)?.toDouble() ?? 0,
      firstNineDarts: (json['firstNineDarts'] as num?)?.toInt() ?? 0,
    );
    return TournamentPlayerMatchStats(
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      pointsScored: pointsScored,
      dartsThrown: dartsThrown,
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      legsWon: (json['legsWon'] as num?)?.toInt() ?? 0,
      legsPlayed: legsPlayed,
      legsStarted: (json['legsStarted'] as num?)?.toInt() ?? 0,
      legsWonAsStarter: (json['legsWonAsStarter'] as num?)?.toInt() ?? 0,
      legsWonWithoutStarter:
          (json['legsWonWithoutStarter'] as num?)?.toInt() ?? 0,
      scores0To40: (json['scores0To40'] as num?)?.toInt() ?? 0,
      scores41To59: (json['scores41To59'] as num?)?.toInt() ?? 0,
      scores60Plus: (json['scores60Plus'] as num?)?.toInt() ?? 0,
      scores100Plus: (json['scores100Plus'] as num?)?.toInt() ?? 0,
      scores140Plus: (json['scores140Plus'] as num?)?.toInt() ?? 0,
      scores171Plus: (json['scores171Plus'] as num?)?.toInt() ?? 0,
      scores180: (json['scores180'] as num?)?.toInt() ?? 0,
      checkoutAttempts: (json['checkoutAttempts'] as num?)?.toInt() ?? 0,
      successfulCheckouts: (json['successfulCheckouts'] as num?)?.toInt() ?? 0,
      checkoutAttempts1Dart:
          (json['checkoutAttempts1Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts2Dart:
          (json['checkoutAttempts2Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts3Dart:
          (json['checkoutAttempts3Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts1Dart:
          (json['successfulCheckouts1Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts2Dart:
          (json['successfulCheckouts2Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts3Dart:
          (json['successfulCheckouts3Dart'] as num?)?.toInt() ?? 0,
      thirdDartCheckoutAttempts:
          (json['thirdDartCheckoutAttempts'] as num?)?.toInt() ?? 0,
      thirdDartCheckouts: (json['thirdDartCheckouts'] as num?)?.toInt() ?? 0,
      bullCheckoutAttempts:
          (json['bullCheckoutAttempts'] as num?)?.toInt() ?? 0,
      bullCheckouts: (json['bullCheckouts'] as num?)?.toInt() ?? 0,
      functionalDoubleAttempts:
          (json['functionalDoubleAttempts'] as num?)?.toInt() ?? 0,
      functionalDoubleSuccesses:
          (json['functionalDoubleSuccesses'] as num?)?.toInt() ?? 0,
      firstNinePoints: normalizedFirstNine.points,
      firstNineDarts: normalizedFirstNine.darts,
      highestFinish: (json['highestFinish'] as num?)?.toInt() ?? 0,
      bestLegDarts: (json['bestLegDarts'] as num?)?.toInt() ?? 0,
      totalFinishValue: (json['totalFinishValue'] as num?)?.toInt() ?? 0,
      withThrowPoints: (json['withThrowPoints'] as num?)?.toInt() ?? 0,
      withThrowDarts: (json['withThrowDarts'] as num?)?.toInt() ?? 0,
      againstThrowPoints: (json['againstThrowPoints'] as num?)?.toInt() ?? 0,
      againstThrowDarts: (json['againstThrowDarts'] as num?)?.toInt() ?? 0,
      decidingLegPoints: (json['decidingLegPoints'] as num?)?.toInt() ?? 0,
      decidingLegDarts: (json['decidingLegDarts'] as num?)?.toInt() ?? 0,
      decidingLegsPlayed:
          (json['decidingLegsPlayed'] as num?)?.toInt() ?? 0,
      decidingLegsWon: (json['decidingLegsWon'] as num?)?.toInt() ?? 0,
      won9Darters: (json['won9Darters'] as num?)?.toInt() ?? 0,
      won12Darters: (json['won12Darters'] as num?)?.toInt() ?? 0,
      won15Darters: (json['won15Darters'] as num?)?.toInt() ?? 0,
      won18Darters: (json['won18Darters'] as num?)?.toInt() ?? 0,
    );
  }

  static ({double points, int darts}) _normalizeFirstNineSample({
    required int pointsScored,
    required int dartsThrown,
    required int legsPlayed,
    required double firstNinePoints,
    required int firstNineDarts,
  }) {
    final safePoints = firstNinePoints < 0 ? 0.0 : firstNinePoints;
    final safeDarts = firstNineDarts < 0 ? 0 : firstNineDarts;
    final maxFirstNineDarts = legsPlayed <= 0
        ? dartsThrown
        : ((legsPlayed * 9) < dartsThrown ? (legsPlayed * 9) : dartsThrown);
    final legacyTotalSample = safeDarts == dartsThrown &&
        safePoints == pointsScored.toDouble() &&
        dartsThrown > maxFirstNineDarts;
    final impossibleSample =
        safeDarts > maxFirstNineDarts || safePoints > pointsScored;
    if (legacyTotalSample || impossibleSample) {
      return (points: 0.0, darts: 0);
    }
    return (points: safePoints, darts: safeDarts);
  }
}

class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.roundNumber,
    required this.matchNumber,
    required this.playerA,
    required this.playerB,
    required this.status,
    this.result,
  });

  final String id;
  final int roundNumber;
  final int matchNumber;
  final TournamentParticipant? playerA;
  final TournamentParticipant? playerB;
  final TournamentMatchStatus status;
  final TournamentMatchResult? result;

  bool get isReady => playerA != null && playerB != null;
  bool get isHumanMatch => (playerA?.isHuman ?? false) || (playerB?.isHuman ?? false);

  TournamentMatch copyWith({
    TournamentParticipant? playerA,
    TournamentParticipant? playerB,
    bool clearPlayerA = false,
    bool clearPlayerB = false,
    TournamentMatchStatus? status,
    TournamentMatchResult? result,
    bool clearResult = false,
  }) {
    return TournamentMatch(
      id: id,
      roundNumber: roundNumber,
      matchNumber: matchNumber,
      playerA: clearPlayerA ? null : (playerA ?? this.playerA),
      playerB: clearPlayerB ? null : (playerB ?? this.playerB),
      status: status ?? this.status,
      result: clearResult ? null : (result ?? this.result),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'roundNumber': roundNumber,
      'matchNumber': matchNumber,
      'playerA': playerA?.toJson(),
      'playerB': playerB?.toJson(),
      'status': status.name,
      'result': result?.toJson(),
    };
  }

  static TournamentMatch fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      id: json['id'] as String,
      roundNumber: (json['roundNumber'] as num).toInt(),
      matchNumber: (json['matchNumber'] as num).toInt(),
      playerA: json['playerA'] == null
          ? null
          : TournamentParticipant.fromJson(
              (json['playerA'] as Map).cast<String, dynamic>(),
            ),
      playerB: json['playerB'] == null
          ? null
          : TournamentParticipant.fromJson(
              (json['playerB'] as Map).cast<String, dynamic>(),
            ),
      status: TournamentMatchStatus.values.byName(json['status'] as String),
      result: json['result'] == null
          ? null
          : TournamentMatchResult.fromJson(
              (json['result'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class TournamentRound {
  const TournamentRound({
    required this.roundNumber,
    required this.title,
    required this.matches,
    this.stage = TournamentRoundStage.knockout,
  });

  final int roundNumber;
  final String title;
  final List<TournamentMatch> matches;
  final TournamentRoundStage stage;

  bool get isCompleted =>
      matches.isNotEmpty &&
      matches.every((match) => match.status == TournamentMatchStatus.completed);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'roundNumber': roundNumber,
      'title': title,
      'matches': matches.map((entry) => entry.toJson()).toList(),
      'stage': stage.name,
    };
  }

  static TournamentRound fromJson(Map<String, dynamic> json) {
    return TournamentRound(
      roundNumber: (json['roundNumber'] as num).toInt(),
      title: json['title'] as String,
      stage: TournamentRoundStage.values.byName(
        json['stage'] as String? ?? TournamentRoundStage.knockout.name,
      ),
      matches: (json['matches'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => TournamentMatch.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class TournamentBracket {
  const TournamentBracket({
    required this.definition,
    required this.participants,
    required this.rounds,
  });

  final TournamentDefinition definition;
  final List<TournamentParticipant> participants;
  final List<TournamentRound> rounds;

  bool get isCompleted {
    if (definition.format == TournamentFormat.leaguePlayoff) {
      return playoffRounds.isNotEmpty &&
          playoffRounds.every((round) => round.isCompleted);
    }
    return rounds.isNotEmpty && rounds.every((round) => round.isCompleted);
  }

  List<TournamentRound> get leagueRounds => rounds
      .where((round) => round.stage == TournamentRoundStage.league)
      .toList();
  List<TournamentRound> get playoffRounds => rounds
      .where((round) => round.stage == TournamentRoundStage.playoff)
      .toList();

  TournamentRoundStage stageForRound(int roundNumber) {
    for (final round in rounds) {
      if (round.roundNumber == roundNumber) {
        return round.stage;
      }
    }
    return TournamentRoundStage.knockout;
  }

  int stageRoundIndex(int roundNumber) {
    var index = 0;
    for (final round in rounds) {
      if (round.stage != stageForRound(roundNumber)) {
        continue;
      }
      index += 1;
      if (round.roundNumber == roundNumber) {
        return index;
      }
    }
    return roundNumber;
  }

  TournamentParticipant? get champion {
    if (!isCompleted || participants.isEmpty) {
      return null;
    }
    if (definition.format == TournamentFormat.league) {
      final table = standings;
      return table.isEmpty ? null : table.first.participant;
    }
    final finalRounds = definition.format == TournamentFormat.leaguePlayoff
        ? playoffRounds
        : rounds;
    if (finalRounds.isEmpty || finalRounds.last.matches.isEmpty) {
      return null;
    }
    final result = finalRounds.last.matches.first.result;
    if (result == null) {
      return null;
    }

    for (final participant in participants) {
      if (participant.id == result.winnerId) {
        return participant;
      }
    }
    return null;
  }

  TournamentParticipant? get runnerUp {
    if (!isCompleted) {
      return null;
    }
    if (definition.format == TournamentFormat.league) {
      final table = standings;
      return table.length < 2 ? null : table[1].participant;
    }
    final finalRounds = definition.format == TournamentFormat.leaguePlayoff
        ? playoffRounds
        : rounds;
    if (finalRounds.isEmpty || finalRounds.last.matches.isEmpty) {
      return null;
    }
    final finalMatch = finalRounds.last.matches.first;
    final winnerId = finalMatch.result?.winnerId;
    if (winnerId == null) {
      return null;
    }
    if (finalMatch.playerA != null && finalMatch.playerA!.id != winnerId) {
      return finalMatch.playerA;
    }
    if (finalMatch.playerB != null && finalMatch.playerB!.id != winnerId) {
      return finalMatch.playerB;
    }
    return null;
  }

  List<TournamentStanding> get standings {
    final byId = <String, TournamentStandingBuilder>{
      for (final participant in participants)
        participant.id: TournamentStandingBuilder(participant),
    };
    final headToHead = <String, Map<String, TournamentHeadToHeadRecord>>{};

    for (final round in leagueRounds) {
      for (final match in round.matches) {
        final result = match.result;
        final playerA = match.playerA;
        final playerB = match.playerB;
        if (result == null || playerA == null || playerB == null) {
          continue;
        }
        final builderA = byId[playerA.id];
        final builderB = byId[playerB.id];
        if (builderA == null || builderB == null) {
          continue;
        }
        final score = TournamentMatchScoreSummary.fromMatch(
          match: match,
          definition: definition,
        );
        builderA.played += 1;
        builderB.played += 1;
        builderA.legsFor += score.legsA;
        builderA.legsAgainst += score.legsB;
        builderB.legsFor += score.legsB;
        builderB.legsAgainst += score.legsA;
        builderA.setsFor += score.setsA;
        builderA.setsAgainst += score.setsB;
        builderB.setsFor += score.setsB;
        builderB.setsAgainst += score.setsA;

        if (result.isDraw) {
          builderA.draws += 1;
          builderB.draws += 1;
          builderA.points += definition.pointsForDraw;
          builderB.points += definition.pointsForDraw;
          _updateHeadToHead(
            headToHead: headToHead,
            playerAId: playerA.id,
            playerBId: playerB.id,
            pointsA: definition.pointsForDraw,
            pointsB: definition.pointsForDraw,
            wonA: false,
            wonB: false,
          );
          continue;
        }

        if (result.winnerId == playerA.id) {
          builderA.wins += 1;
          builderB.losses += 1;
          builderA.points += definition.pointsForWin;
          _updateHeadToHead(
            headToHead: headToHead,
            playerAId: playerA.id,
            playerBId: playerB.id,
            pointsA: definition.pointsForWin,
            pointsB: 0,
            wonA: true,
            wonB: false,
          );
        } else if (result.winnerId == playerB.id) {
          builderB.wins += 1;
          builderA.losses += 1;
          builderB.points += definition.pointsForWin;
          _updateHeadToHead(
            headToHead: headToHead,
            playerAId: playerA.id,
            playerBId: playerB.id,
            pointsA: 0,
            pointsB: definition.pointsForWin,
            wonA: false,
            wonB: true,
          );
        }
      }
    }

    final table = byId.values.map((entry) => entry.build()).toList();
    table.sort((left, right) {
      final pointsCompare = right.points.compareTo(left.points);
      if (pointsCompare != 0) {
        return pointsCompare;
      }
      final headToHeadCompare = _compareHeadToHead(
        left: left,
        right: right,
        headToHead: headToHead,
      );
      if (headToHeadCompare != 0) {
        return headToHeadCompare;
      }
      if (definition.matchMode == MatchMode.sets) {
        final setDiffCompare = right.setDifference.compareTo(left.setDifference);
        if (setDiffCompare != 0) {
          return setDiffCompare;
        }
        final setsForCompare = right.setsFor.compareTo(left.setsFor);
        if (setsForCompare != 0) {
          return setsForCompare;
        }
      }
      final legDiffCompare = right.legDifference.compareTo(left.legDifference);
      if (legDiffCompare != 0) {
        return legDiffCompare;
      }
      final legsForCompare = right.legsFor.compareTo(left.legsFor);
      if (legsForCompare != 0) {
        return legsForCompare;
      }
      final winsCompare = right.wins.compareTo(left.wins);
      if (winsCompare != 0) {
        return winsCompare;
      }
      final avgCompare =
          right.participant.average.compareTo(left.participant.average);
      if (avgCompare != 0) {
        return avgCompare;
      }
      return left.participant.name.compareTo(right.participant.name);
    });
    return table;
  }

  List<TournamentParticipant> losersForRound(int roundNumber) {
    if (definition.format == TournamentFormat.league) {
      return const <TournamentParticipant>[];
    }
    final result = <TournamentParticipant>[];
    TournamentRound? targetRound;
    for (final round in rounds) {
      if (round.roundNumber == roundNumber) {
        targetRound = round;
        break;
      }
    }
    if (targetRound == null) {
      return result;
    }

    for (final match in targetRound.matches) {
      final winnerId = match.result?.winnerId;
      if (winnerId == null) {
        continue;
      }
      if (match.playerA != null && match.playerA!.id != winnerId) {
        result.add(match.playerA!);
      } else if (match.playerB != null && match.playerB!.id != winnerId) {
        result.add(match.playerB!);
      }
    }

    return result;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'definition': definition.toJson(),
      'participants': participants.map((entry) => entry.toJson()).toList(),
      'rounds': rounds.map((entry) => entry.toJson()).toList(),
    };
  }

  static TournamentBracket fromJson(Map<String, dynamic> json) {
    return TournamentBracket(
      definition: TournamentDefinition.fromJson(
        (json['definition'] as Map).cast<String, dynamic>(),
      ),
      participants:
          (json['participants'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => TournamentParticipant.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      rounds: (json['rounds'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => TournamentRound.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class TournamentStanding {
  const TournamentStanding({
    required this.participant,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.points,
    this.legsFor = 0,
    this.legsAgainst = 0,
    this.setsFor = 0,
    this.setsAgainst = 0,
  });

  final TournamentParticipant participant;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int points;
  final int legsFor;
  final int legsAgainst;
  final int setsFor;
  final int setsAgainst;

  int get legDifference => legsFor - legsAgainst;
  int get setDifference => setsFor - setsAgainst;
}

class TournamentStandingBuilder {
  TournamentStandingBuilder(this.participant);

  final TournamentParticipant participant;
  int played = 0;
  int wins = 0;
  int draws = 0;
  int losses = 0;
  int points = 0;
  int legsFor = 0;
  int legsAgainst = 0;
  int setsFor = 0;
  int setsAgainst = 0;

  TournamentStanding build() {
    return TournamentStanding(
      participant: participant,
      played: played,
      wins: wins,
      draws: draws,
      losses: losses,
      points: points,
      legsFor: legsFor,
      legsAgainst: legsAgainst,
      setsFor: setsFor,
      setsAgainst: setsAgainst,
    );
  }
}

class TournamentHeadToHeadRecord {
  const TournamentHeadToHeadRecord({
    this.points = 0,
    this.wins = 0,
  });

  final int points;
  final int wins;

  TournamentHeadToHeadRecord add({
    required int points,
    required bool win,
  }) {
    return TournamentHeadToHeadRecord(
      points: this.points + points,
      wins: wins + (win ? 1 : 0),
    );
  }
}

class TournamentMatchScoreSummary {
  const TournamentMatchScoreSummary({
    this.legsA = 0,
    this.legsB = 0,
    this.setsA = 0,
    this.setsB = 0,
  });

  final int legsA;
  final int legsB;
  final int setsA;
  final int setsB;

  static TournamentMatchScoreSummary fromMatch({
    required TournamentMatch match,
    required TournamentDefinition definition,
  }) {
    final result = match.result;
    if (result == null) {
      return const TournamentMatchScoreSummary();
    }
    final stats = result.participantStats;
    if (stats.length >= 2 &&
        match.playerA != null &&
        match.playerB != null) {
      TournamentPlayerMatchStats? statsA;
      TournamentPlayerMatchStats? statsB;
      for (final entry in stats) {
        if (entry.participantId == match.playerA!.id) {
          statsA = entry;
        } else if (entry.participantId == match.playerB!.id) {
          statsB = entry;
        }
      }
      if (statsA != null && statsB != null) {
        return TournamentMatchScoreSummary(
          legsA: statsA.legsWon,
          legsB: statsB.legsWon,
        );
      }
    }

    final parsed = _parseScoreText(result.scoreText);
    if (parsed != null) {
      return parsed.$3 == MatchMode.sets
          ? TournamentMatchScoreSummary(
              setsA: parsed.$1,
              setsB: parsed.$2,
            )
          : TournamentMatchScoreSummary(
              legsA: parsed.$1,
              legsB: parsed.$2,
            );
    }

    if (result.isDraw) {
      return const TournamentMatchScoreSummary();
    }
    if (result.winnerId == null ||
        match.playerA == null ||
        match.playerB == null) {
      return const TournamentMatchScoreSummary();
    }

    if (definition.matchMode == MatchMode.sets) {
      final winnerSets = definition.distanceForRound(match.roundNumber);
      return result.winnerId == match.playerA!.id
          ? TournamentMatchScoreSummary(setsA: winnerSets)
          : TournamentMatchScoreSummary(setsB: winnerSets);
    }
    final winnerLegs = definition.distanceForRound(match.roundNumber);
    return result.winnerId == match.playerA!.id
        ? TournamentMatchScoreSummary(legsA: winnerLegs)
        : TournamentMatchScoreSummary(legsB: winnerLegs);
  }

  static (int, int, MatchMode)? _parseScoreText(String scoreText) {
    final normalized = scoreText.trim();
    final parts = normalized.split('|').first.trim().split(' ');
    if (parts.length < 2) {
      return null;
    }
    final score = parts.first.split(':');
    if (score.length != 2) {
      return null;
    }
    final left = int.tryParse(score[0]);
    final right = int.tryParse(score[1]);
    if (left == null || right == null) {
      return null;
    }
    final modeLabel = parts[1].toLowerCase();
    if (modeLabel.startsWith('set')) {
      return (left, right, MatchMode.sets);
    }
    if (modeLabel.startsWith('leg')) {
      return (left, right, MatchMode.legs);
    }
    return null;
  }
}

void _updateHeadToHead({
  required Map<String, Map<String, TournamentHeadToHeadRecord>> headToHead,
  required String playerAId,
  required String playerBId,
  required int pointsA,
  required int pointsB,
  required bool wonA,
  required bool wonB,
}) {
  final recordsA = headToHead.putIfAbsent(
    playerAId,
    () => <String, TournamentHeadToHeadRecord>{},
  );
  final recordsB = headToHead.putIfAbsent(
    playerBId,
    () => <String, TournamentHeadToHeadRecord>{},
  );
  recordsA[playerBId] = (recordsA[playerBId] ?? const TournamentHeadToHeadRecord())
      .add(points: pointsA, win: wonA);
  recordsB[playerAId] = (recordsB[playerAId] ?? const TournamentHeadToHeadRecord())
      .add(points: pointsB, win: wonB);
}

int _compareHeadToHead({
  required TournamentStanding left,
  required TournamentStanding right,
  required Map<String, Map<String, TournamentHeadToHeadRecord>> headToHead,
}) {
  final leftRecord = headToHead[left.participant.id]?[right.participant.id];
  final rightRecord = headToHead[right.participant.id]?[left.participant.id];
  if (leftRecord == null || rightRecord == null) {
    return 0;
  }
  final pointsCompare = rightRecord.points.compareTo(leftRecord.points);
  if (pointsCompare != 0) {
    return pointsCompare;
  }
  return rightRecord.wins.compareTo(leftRecord.wins);
}

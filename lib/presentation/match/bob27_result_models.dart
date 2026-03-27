class Bob27ParticipantStats {
  const Bob27ParticipantStats({
    required this.participantId,
    required this.name,
    required this.score,
    required this.hits,
    required this.roundsPlayed,
    required this.successfulRounds,
    required this.dartsThrown,
    required this.completedTargets,
    required this.perfectRounds,
    required this.zeroHitRounds,
    required this.bullHits,
    required this.highestRoundDelta,
    required this.lowestRoundDelta,
    required this.survived,
    this.eliminatedAtTarget,
  });

  final String participantId;
  final String name;
  final int score;
  final int hits;
  final int roundsPlayed;
  final int successfulRounds;
  final int dartsThrown;
  final int completedTargets;
  final int perfectRounds;
  final int zeroHitRounds;
  final int bullHits;
  final int highestRoundDelta;
  final int lowestRoundDelta;
  final bool survived;
  final int? eliminatedAtTarget;

  double get hitRate => dartsThrown <= 0 ? 0 : (hits / dartsThrown) * 100;
  double get successRate =>
      roundsPlayed <= 0 ? 0 : (successfulRounds / roundsPlayed) * 100;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'participantId': participantId,
      'name': name,
      'score': score,
      'hits': hits,
      'roundsPlayed': roundsPlayed,
      'successfulRounds': successfulRounds,
      'dartsThrown': dartsThrown,
      'completedTargets': completedTargets,
      'perfectRounds': perfectRounds,
      'zeroHitRounds': zeroHitRounds,
      'bullHits': bullHits,
      'highestRoundDelta': highestRoundDelta,
      'lowestRoundDelta': lowestRoundDelta,
      'survived': survived,
      'eliminatedAtTarget': eliminatedAtTarget,
    };
  }

  static Bob27ParticipantStats fromJson(Map<String, dynamic> json) {
    return Bob27ParticipantStats(
      participantId: json['participantId'] as String,
      name: json['name'] as String,
      score: (json['score'] as num?)?.toInt() ?? 0,
      hits: (json['hits'] as num?)?.toInt() ?? 0,
      roundsPlayed: (json['roundsPlayed'] as num?)?.toInt() ?? 0,
      successfulRounds: (json['successfulRounds'] as num?)?.toInt() ?? 0,
      dartsThrown: (json['dartsThrown'] as num?)?.toInt() ?? 0,
      completedTargets: (json['completedTargets'] as num?)?.toInt() ?? 0,
      perfectRounds: (json['perfectRounds'] as num?)?.toInt() ?? 0,
      zeroHitRounds: (json['zeroHitRounds'] as num?)?.toInt() ?? 0,
      bullHits: (json['bullHits'] as num?)?.toInt() ?? 0,
      highestRoundDelta: (json['highestRoundDelta'] as num?)?.toInt() ?? 0,
      lowestRoundDelta: (json['lowestRoundDelta'] as num?)?.toInt() ?? 0,
      survived: json['survived'] as bool? ?? false,
      eliminatedAtTarget: (json['eliminatedAtTarget'] as num?)?.toInt(),
    );
  }
}

class Bob27ResultSummary {
  const Bob27ResultSummary({
    required this.winnerParticipantId,
    required this.winnerName,
    required this.scoreText,
    required this.participants,
    required this.visitLog,
  });

  final String winnerParticipantId;
  final String winnerName;
  final String scoreText;
  final List<Bob27ParticipantStats> participants;
  final List<String> visitLog;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'winnerParticipantId': winnerParticipantId,
      'winnerName': winnerName,
      'scoreText': scoreText,
      'participants': participants.map((entry) => entry.toJson()).toList(),
      'visitLog': visitLog,
    };
  }

  static Bob27ResultSummary fromJson(Map<String, dynamic> json) {
    return Bob27ResultSummary(
      winnerParticipantId: json['winnerParticipantId'] as String,
      winnerName: json['winnerName'] as String,
      scoreText: json['scoreText'] as String,
      participants: (json['participants'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => Bob27ParticipantStats.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      visitLog: (json['visitLog'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => '$entry')
          .toList(),
    );
  }
}

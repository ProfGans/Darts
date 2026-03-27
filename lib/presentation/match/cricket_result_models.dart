class CricketParticipantStats {
  const CricketParticipantStats({
    required this.participantId,
    required this.name,
    required this.points,
    required this.dartsThrown,
    required this.turns,
    required this.totalMarks,
    required this.closedTargets,
    required this.targetHits20,
    required this.targetHits19,
    required this.targetHits18,
    required this.targetHits17,
    required this.targetHits16,
    required this.targetHits15,
    required this.bullMarks,
    required this.roundsWithMarks,
    required this.highestScoringRound,
    required this.bestMarksRound,
  });

  final String participantId;
  final String name;
  final int points;
  final int dartsThrown;
  final int turns;
  final int totalMarks;
  final int closedTargets;
  final int targetHits20;
  final int targetHits19;
  final int targetHits18;
  final int targetHits17;
  final int targetHits16;
  final int targetHits15;
  final int bullMarks;
  final int roundsWithMarks;
  final int highestScoringRound;
  final int bestMarksRound;

  double get marksPerRound => dartsThrown <= 0 ? 0 : (totalMarks / dartsThrown) * 3;
  double get hitRate => dartsThrown <= 0 ? 0 : (totalMarks / dartsThrown) * 100;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'participantId': participantId,
      'name': name,
      'points': points,
      'dartsThrown': dartsThrown,
      'turns': turns,
      'totalMarks': totalMarks,
      'closedTargets': closedTargets,
      'targetHits20': targetHits20,
      'targetHits19': targetHits19,
      'targetHits18': targetHits18,
      'targetHits17': targetHits17,
      'targetHits16': targetHits16,
      'targetHits15': targetHits15,
      'bullMarks': bullMarks,
      'roundsWithMarks': roundsWithMarks,
      'highestScoringRound': highestScoringRound,
      'bestMarksRound': bestMarksRound,
    };
  }

  static CricketParticipantStats fromJson(Map<String, dynamic> json) {
    return CricketParticipantStats(
      participantId: json['participantId'] as String,
      name: json['name'] as String,
      points: (json['points'] as num?)?.toInt() ?? 0,
      dartsThrown: (json['dartsThrown'] as num?)?.toInt() ?? 0,
      turns: (json['turns'] as num?)?.toInt() ?? 0,
      totalMarks: (json['totalMarks'] as num?)?.toInt() ?? 0,
      closedTargets: (json['closedTargets'] as num?)?.toInt() ?? 0,
      targetHits20: (json['targetHits20'] as num?)?.toInt() ?? 0,
      targetHits19: (json['targetHits19'] as num?)?.toInt() ?? 0,
      targetHits18: (json['targetHits18'] as num?)?.toInt() ?? 0,
      targetHits17: (json['targetHits17'] as num?)?.toInt() ?? 0,
      targetHits16: (json['targetHits16'] as num?)?.toInt() ?? 0,
      targetHits15: (json['targetHits15'] as num?)?.toInt() ?? 0,
      bullMarks: (json['bullMarks'] as num?)?.toInt() ?? 0,
      roundsWithMarks: (json['roundsWithMarks'] as num?)?.toInt() ?? 0,
      highestScoringRound: (json['highestScoringRound'] as num?)?.toInt() ?? 0,
      bestMarksRound: (json['bestMarksRound'] as num?)?.toInt() ?? 0,
    );
  }
}

class CricketResultSummary {
  const CricketResultSummary({
    required this.winnerParticipantId,
    required this.winnerName,
    required this.scoreText,
    required this.participants,
    required this.visitLog,
  });

  final String winnerParticipantId;
  final String winnerName;
  final String scoreText;
  final List<CricketParticipantStats> participants;
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

  static CricketResultSummary fromJson(Map<String, dynamic> json) {
    return CricketResultSummary(
      winnerParticipantId: json['winnerParticipantId'] as String,
      winnerName: json['winnerName'] as String,
      scoreText: json['scoreText'] as String,
      participants: (json['participants'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CricketParticipantStats.fromJson(
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

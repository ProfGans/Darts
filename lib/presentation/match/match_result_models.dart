class MatchVisitEntry {
  const MatchVisitEntry({
    required this.side,
    required this.turnNumber,
    required this.scoreBefore,
    required this.scoredPoints,
    required this.remainingScore,
    required this.dartsUsed,
    required this.bust,
    required this.checkout,
    required this.description,
    this.finishingThrowLabel,
    this.checkoutValue,
    this.bullCheckout = false,
  });

  final String side;
  final int turnNumber;
  final int scoreBefore;
  final int scoredPoints;
  final int remainingScore;
  final int dartsUsed;
  final bool bust;
  final bool checkout;
  final String description;
  final String? finishingThrowLabel;
  final int? checkoutValue;
  final bool bullCheckout;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'side': side,
      'turnNumber': turnNumber,
      'scoreBefore': scoreBefore,
      'scoredPoints': scoredPoints,
      'remainingScore': remainingScore,
      'dartsUsed': dartsUsed,
      'bust': bust,
      'checkout': checkout,
      'description': description,
      'finishingThrowLabel': finishingThrowLabel,
      'checkoutValue': checkoutValue,
      'bullCheckout': bullCheckout,
    };
  }

  static MatchVisitEntry fromJson(Map<String, dynamic> json) {
    return MatchVisitEntry(
      side: json['side'] as String,
      turnNumber: (json['turnNumber'] as num).toInt(),
      scoreBefore: (json['scoreBefore'] as num).toInt(),
      scoredPoints: (json['scoredPoints'] as num).toInt(),
      remainingScore: (json['remainingScore'] as num).toInt(),
      dartsUsed: (json['dartsUsed'] as num).toInt(),
      bust: json['bust'] as bool? ?? false,
      checkout: json['checkout'] as bool? ?? false,
      description: json['description'] as String,
      finishingThrowLabel: json['finishingThrowLabel'] as String?,
      checkoutValue: (json['checkoutValue'] as num?)?.toInt(),
      bullCheckout: json['bullCheckout'] as bool? ?? false,
    );
  }
}

class MatchLegParticipantEntry {
  const MatchLegParticipantEntry({
    required this.participantId,
    required this.participantName,
    required this.dartsThrown,
    required this.average,
    required this.remainingScore,
  });

  final String participantId;
  final String participantName;
  final int dartsThrown;
  final double average;
  final int remainingScore;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'participantId': participantId,
      'participantName': participantName,
      'dartsThrown': dartsThrown,
      'average': average,
      'remainingScore': remainingScore,
    };
  }

  static MatchLegParticipantEntry fromJson(Map<String, dynamic> json) {
    return MatchLegParticipantEntry(
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      dartsThrown: (json['dartsThrown'] as num).toInt(),
      average: (json['average'] as num).toDouble(),
      remainingScore: (json['remainingScore'] as num).toInt(),
    );
  }
}

class MatchLegEntry {
  const MatchLegEntry({
    required this.legNumber,
    required this.starterSide,
    required this.winnerSide,
    required this.participants,
    required this.visits,
    this.decidingLeg = false,
  });

  final int legNumber;
  final String starterSide;
  final String winnerSide;
  final List<MatchLegParticipantEntry> participants;
  final List<MatchVisitEntry> visits;
  final bool decidingLeg;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'legNumber': legNumber,
      'starterSide': starterSide,
      'winnerSide': winnerSide,
      'participants': participants.map((entry) => entry.toJson()).toList(),
      'visits': visits.map((entry) => entry.toJson()).toList(),
      'decidingLeg': decidingLeg,
    };
  }

  static MatchLegEntry fromJson(Map<String, dynamic> json) {
    final participantsJson =
        (json['participants'] as List<dynamic>? ?? const <dynamic>[]);
    if (participantsJson.isNotEmpty) {
      return MatchLegEntry(
        legNumber: (json['legNumber'] as num).toInt(),
        starterSide: json['starterSide'] as String,
        winnerSide: json['winnerSide'] as String,
        decidingLeg: json['decidingLeg'] as bool? ?? false,
        participants: participantsJson
            .map(
              (entry) => MatchLegParticipantEntry.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        visits: (json['visits'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => MatchVisitEntry.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
    }

    return MatchLegEntry(
      legNumber: (json['legNumber'] as num).toInt(),
      starterSide: json['starterSide'] as String,
      winnerSide: json['winnerSide'] as String,
      decidingLeg: json['decidingLeg'] as bool? ?? false,
      participants: <MatchLegParticipantEntry>[
        MatchLegParticipantEntry(
          participantId: 'legacy-player',
          participantName: 'Spieler',
          dartsThrown: (json['playerDarts'] as num?)?.toInt() ?? 0,
          average: (json['playerAverage'] as num?)?.toDouble() ?? 0,
          remainingScore: (json['playerScoreRemaining'] as num?)?.toInt() ?? 0,
        ),
        MatchLegParticipantEntry(
          participantId: 'legacy-bot',
          participantName: 'Bot',
          dartsThrown: (json['botDarts'] as num?)?.toInt() ?? 0,
          average: (json['botAverage'] as num?)?.toDouble() ?? 0,
          remainingScore: (json['botScoreRemaining'] as num?)?.toInt() ?? 0,
        ),
      ],
      visits: (json['visits'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => MatchVisitEntry.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class MatchParticipantStats {
  const MatchParticipantStats({
    required this.participantId,
    required this.participantName,
    required this.pointsScored,
    required this.dartsThrown,
    required this.visits,
    required this.legsWon,
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
    required this.won12Darters,
    required this.won15Darters,
    required this.won18Darters,
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
  final int won12Darters;
  final int won15Darters;
  final int won18Darters;

  double get average => dartsThrown <= 0 ? 0 : (pointsScored / dartsThrown) * 3;
  double get pointsPerDart => dartsThrown <= 0 ? 0 : pointsScored / dartsThrown;
  double get pointsPerRound => visits <= 0 ? 0 : pointsScored / visits;
  double get firstNineAverage =>
      firstNineDarts <= 0 ? 0 : (firstNinePoints / firstNineDarts) * 3;
  double get checkoutQuote =>
      checkoutAttempts <= 0 ? 0 : (successfulCheckouts / checkoutAttempts) * 100;
  double get checkoutQuote1Dart => checkoutAttempts1Dart <= 0
      ? 0
      : (successfulCheckouts1Dart / checkoutAttempts1Dart) * 100;
  double get checkoutQuote2Dart => checkoutAttempts2Dart <= 0
      ? 0
      : (successfulCheckouts2Dart / checkoutAttempts2Dart) * 100;
  double get checkoutQuote3Dart => checkoutAttempts3Dart <= 0
      ? 0
      : (successfulCheckouts3Dart / checkoutAttempts3Dart) * 100;
  double get thirdDartCheckoutQuote => thirdDartCheckoutAttempts <= 0
      ? 0
      : (thirdDartCheckouts / thirdDartCheckoutAttempts) * 100;
  double get bullCheckoutQuote =>
      bullCheckoutAttempts <= 0 ? 0 : (bullCheckouts / bullCheckoutAttempts) * 100;
  double get functionalDoubleQuote => functionalDoubleAttempts <= 0
      ? 0
      : (functionalDoubleSuccesses / functionalDoubleAttempts) * 100;
  double get averageFinish =>
      successfulCheckouts <= 0 ? 0 : totalFinishValue / successfulCheckouts;
  double get withThrowAverage =>
      withThrowDarts <= 0 ? 0 : (withThrowPoints / withThrowDarts) * 3;
  double get againstThrowAverage =>
      againstThrowDarts <= 0 ? 0 : (againstThrowPoints / againstThrowDarts) * 3;
  double get decidingLegAverage =>
      decidingLegDarts <= 0 ? 0 : (decidingLegPoints / decidingLegDarts) * 3;
  double get decidingLegsWonQuote => decidingLegsPlayed <= 0
      ? 0
      : (decidingLegsWon / decidingLegsPlayed) * 100;
  double get score180sPerLeg =>
      legsPlayed <= 0 ? 0 : scores180 / legsPlayed;
  double get won12DarterQuote => legsWon <= 0 ? 0 : (won12Darters / legsWon) * 100;
  double get won15DarterQuote => legsWon <= 0 ? 0 : (won15Darters / legsWon) * 100;
  double get won18DarterQuote => legsWon <= 0 ? 0 : (won18Darters / legsWon) * 100;

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
      'won12Darters': won12Darters,
      'won15Darters': won15Darters,
      'won18Darters': won18Darters,
    };
  }

  static MatchParticipantStats fromJson(Map<String, dynamic> json) {
    return MatchParticipantStats(
      participantId: json['participantId'] as String,
      participantName: json['participantName'] as String,
      pointsScored: (json['pointsScored'] as num?)?.toInt() ?? 0,
      dartsThrown: (json['dartsThrown'] as num?)?.toInt() ?? 0,
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      legsWon: (json['legsWon'] as num?)?.toInt() ?? 0,
      legsPlayed: (json['legsPlayed'] as num?)?.toInt() ?? 0,
      legsStarted: (json['legsStarted'] as num?)?.toInt() ?? 0,
      legsWonAsStarter: (json['legsWonAsStarter'] as num?)?.toInt() ?? 0,
      legsWonWithoutStarter: (json['legsWonWithoutStarter'] as num?)?.toInt() ?? 0,
      scores0To40: (json['scores0To40'] as num?)?.toInt() ?? 0,
      scores41To59: (json['scores41To59'] as num?)?.toInt() ?? 0,
      scores60Plus: (json['scores60Plus'] as num?)?.toInt() ?? 0,
      scores100Plus: (json['scores100Plus'] as num?)?.toInt() ?? 0,
      scores140Plus: (json['scores140Plus'] as num?)?.toInt() ?? 0,
      scores171Plus: (json['scores171Plus'] as num?)?.toInt() ?? 0,
      scores180: (json['scores180'] as num?)?.toInt() ?? 0,
      checkoutAttempts: (json['checkoutAttempts'] as num?)?.toInt() ?? 0,
      successfulCheckouts: (json['successfulCheckouts'] as num?)?.toInt() ?? 0,
      checkoutAttempts1Dart: (json['checkoutAttempts1Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts2Dart: (json['checkoutAttempts2Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts3Dart: (json['checkoutAttempts3Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts1Dart:
          (json['successfulCheckouts1Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts2Dart:
          (json['successfulCheckouts2Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts3Dart:
          (json['successfulCheckouts3Dart'] as num?)?.toInt() ?? 0,
      thirdDartCheckoutAttempts:
          (json['thirdDartCheckoutAttempts'] as num?)?.toInt() ?? 0,
      thirdDartCheckouts: (json['thirdDartCheckouts'] as num?)?.toInt() ?? 0,
      bullCheckoutAttempts: (json['bullCheckoutAttempts'] as num?)?.toInt() ?? 0,
      bullCheckouts: (json['bullCheckouts'] as num?)?.toInt() ?? 0,
      functionalDoubleAttempts:
          (json['functionalDoubleAttempts'] as num?)?.toInt() ?? 0,
      functionalDoubleSuccesses:
          (json['functionalDoubleSuccesses'] as num?)?.toInt() ?? 0,
      firstNinePoints: (json['firstNinePoints'] as num?)?.toDouble() ?? 0,
      firstNineDarts: (json['firstNineDarts'] as num?)?.toInt() ?? 0,
      highestFinish: (json['highestFinish'] as num?)?.toInt() ?? 0,
      bestLegDarts: (json['bestLegDarts'] as num?)?.toInt() ?? 0,
      totalFinishValue: (json['totalFinishValue'] as num?)?.toInt() ?? 0,
      withThrowPoints: (json['withThrowPoints'] as num?)?.toInt() ?? 0,
      withThrowDarts: (json['withThrowDarts'] as num?)?.toInt() ?? 0,
      againstThrowPoints: (json['againstThrowPoints'] as num?)?.toInt() ?? 0,
      againstThrowDarts: (json['againstThrowDarts'] as num?)?.toInt() ?? 0,
      decidingLegPoints: (json['decidingLegPoints'] as num?)?.toInt() ?? 0,
      decidingLegDarts: (json['decidingLegDarts'] as num?)?.toInt() ?? 0,
      decidingLegsPlayed: (json['decidingLegsPlayed'] as num?)?.toInt() ?? 0,
      decidingLegsWon: (json['decidingLegsWon'] as num?)?.toInt() ?? 0,
      won12Darters: (json['won12Darters'] as num?)?.toInt() ?? 0,
      won15Darters: (json['won15Darters'] as num?)?.toInt() ?? 0,
      won18Darters: (json['won18Darters'] as num?)?.toInt() ?? 0,
    );
  }
}

class MatchResultSummary {
  const MatchResultSummary({
    required this.winnerParticipantId,
    required this.winnerName,
    required this.scoreText,
    required this.participants,
    required this.legs,
  });

  final String winnerParticipantId;
  final String winnerName;
  final String scoreText;
  final List<MatchParticipantStats> participants;
  final List<MatchLegEntry> legs;

  String get playerName =>
      participants.isNotEmpty ? participants.first.participantName : 'Spieler';

  String get botName => participants.length > 1
      ? participants[1].participantName
      : (participants.isNotEmpty ? participants.first.participantName : 'Bot');

  MatchParticipantStats get playerStats => participants.first;

  MatchParticipantStats get botStats =>
      participants.length > 1 ? participants[1] : participants.first;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'winnerParticipantId': winnerParticipantId,
      'winnerName': winnerName,
      'scoreText': scoreText,
      'participants': participants.map((entry) => entry.toJson()).toList(),
      'legs': legs.map((entry) => entry.toJson()).toList(),
    };
  }

  static MatchResultSummary fromJson(Map<String, dynamic> json) {
    final participantsJson =
        (json['participants'] as List<dynamic>? ?? const <dynamic>[]);
    if (participantsJson.isNotEmpty) {
      return MatchResultSummary(
        winnerParticipantId: json['winnerParticipantId'] as String? ??
            json['winnerName'] as String? ??
            '',
        winnerName: json['winnerName'] as String,
        scoreText: json['scoreText'] as String,
        participants: participantsJson
            .map(
              (entry) => MatchParticipantStats.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
        legs: (json['legs'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => MatchLegEntry.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .toList(),
      );
    }

    final playerName = json['playerName'] as String? ?? 'Spieler';
    final botName = json['botName'] as String? ?? 'Bot';
    final winnerName = json['winnerName'] as String? ?? playerName;

    return MatchResultSummary(
      winnerParticipantId: winnerName == playerName ? 'legacy-player' : 'legacy-bot',
      winnerName: winnerName,
      scoreText: json['scoreText'] as String,
      participants: <MatchParticipantStats>[
        MatchParticipantStats.fromJson(
          <String, dynamic>{
            'participantId': 'legacy-player',
            'participantName': playerName,
            ...((json['playerStats'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{}),
          },
        ),
        MatchParticipantStats.fromJson(
          <String, dynamic>{
            'participantId': 'legacy-bot',
            'participantName': botName,
            ...((json['botStats'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{}),
          },
        ),
      ],
      legs: (json['legs'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => MatchLegEntry.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

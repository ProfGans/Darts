import '../../presentation/match/bob27_result_models.dart';
import '../../presentation/match/cricket_result_models.dart';
import '../../presentation/match/match_result_models.dart';

enum PlayerProfileSource {
  imported,
  manual,
  guest,
}

extension PlayerProfileSourceSerialization on PlayerProfileSource {
  String get storageValue {
    switch (this) {
      case PlayerProfileSource.imported:
        return 'imported';
      case PlayerProfileSource.manual:
        return 'manual';
      case PlayerProfileSource.guest:
        return 'guest';
    }
  }

  static PlayerProfileSource fromStorageValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'imported':
        return PlayerProfileSource.imported;
      case 'guest':
        return PlayerProfileSource.guest;
      case 'manual':
      default:
        return PlayerProfileSource.manual;
    }
  }
}

enum PlayerOpponentKind {
  human,
  cpu,
  unknown,
}

extension PlayerOpponentKindSerialization on PlayerOpponentKind {
  String get storageValue {
    switch (this) {
      case PlayerOpponentKind.human:
        return 'human';
      case PlayerOpponentKind.cpu:
        return 'cpu';
      case PlayerOpponentKind.unknown:
        return 'unknown';
    }
  }

  static PlayerOpponentKind fromStorageValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'human':
        return PlayerOpponentKind.human;
      case 'cpu':
        return PlayerOpponentKind.cpu;
      case 'unknown':
      default:
        return PlayerOpponentKind.unknown;
    }
  }
}

class PlayerEquipmentSetup {
  const PlayerEquipmentSetup({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.barrelWeight,
    this.barrelModel,
    this.barrelMaterial,
    this.pointType,
    this.pointLength,
    this.shaftType,
    this.shaftLength,
    this.flightShape,
    this.flightSystem,
    this.gripWax,
    this.notes,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? barrelWeight;
  final String? barrelModel;
  final String? barrelMaterial;
  final String? pointType;
  final String? pointLength;
  final String? shaftType;
  final String? shaftLength;
  final String? flightShape;
  final String? flightSystem;
  final String? gripWax;
  final String? notes;

  String get summary {
    final parts = <String>[
      if (barrelWeight != null) '${barrelWeight!.toStringAsFixed(1)} g',
      if ((barrelModel ?? '').isNotEmpty) barrelModel!,
      if ((shaftType ?? '').isNotEmpty) shaftType!,
      if ((flightShape ?? '').isNotEmpty) flightShape!,
    ];
    return parts.isEmpty ? name : '$name · ${parts.join(' · ')}';
  }

  PlayerEquipmentSetup copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? barrelWeight,
    bool clearBarrelWeight = false,
    String? barrelModel,
    bool clearBarrelModel = false,
    String? barrelMaterial,
    bool clearBarrelMaterial = false,
    String? pointType,
    bool clearPointType = false,
    String? pointLength,
    bool clearPointLength = false,
    String? shaftType,
    bool clearShaftType = false,
    String? shaftLength,
    bool clearShaftLength = false,
    String? flightShape,
    bool clearFlightShape = false,
    String? flightSystem,
    bool clearFlightSystem = false,
    String? gripWax,
    bool clearGripWax = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return PlayerEquipmentSetup(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      barrelWeight:
          clearBarrelWeight ? null : barrelWeight ?? this.barrelWeight,
      barrelModel: clearBarrelModel ? null : barrelModel ?? this.barrelModel,
      barrelMaterial: clearBarrelMaterial
          ? null
          : barrelMaterial ?? this.barrelMaterial,
      pointType: clearPointType ? null : pointType ?? this.pointType,
      pointLength: clearPointLength ? null : pointLength ?? this.pointLength,
      shaftType: clearShaftType ? null : shaftType ?? this.shaftType,
      shaftLength: clearShaftLength ? null : shaftLength ?? this.shaftLength,
      flightShape: clearFlightShape ? null : flightShape ?? this.flightShape,
      flightSystem:
          clearFlightSystem ? null : flightSystem ?? this.flightSystem,
      gripWax: clearGripWax ? null : gripWax ?? this.gripWax,
      notes: clearNotes ? null : notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'barrelWeight': barrelWeight,
        'barrelModel': barrelModel,
        'barrelMaterial': barrelMaterial,
        'pointType': pointType,
        'pointLength': pointLength,
        'shaftType': shaftType,
        'shaftLength': shaftLength,
        'flightShape': flightShape,
        'flightSystem': flightSystem,
        'gripWax': gripWax,
        'notes': notes,
      };

  static PlayerEquipmentSetup fromJson(Map<String, dynamic> json) {
    return PlayerEquipmentSetup(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Setup',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      barrelWeight: (json['barrelWeight'] as num?)?.toDouble(),
      barrelModel: (json['barrelModel'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['barrelModel'] as String?)?.trim(),
      barrelMaterial:
          (json['barrelMaterial'] as String?)?.trim().isEmpty ?? true
              ? null
              : (json['barrelMaterial'] as String?)?.trim(),
      pointType: (json['pointType'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['pointType'] as String?)?.trim(),
      pointLength: (json['pointLength'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['pointLength'] as String?)?.trim(),
      shaftType: (json['shaftType'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['shaftType'] as String?)?.trim(),
      shaftLength: (json['shaftLength'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['shaftLength'] as String?)?.trim(),
      flightShape: (json['flightShape'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['flightShape'] as String?)?.trim(),
      flightSystem: (json['flightSystem'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['flightSystem'] as String?)?.trim(),
      gripWax: (json['gripWax'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['gripWax'] as String?)?.trim(),
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String?)?.trim(),
    );
  }
}

class PlayerProfilePreferences {
  const PlayerProfilePreferences({
    this.preferredView = 'overview',
    this.defaultTrainingMode = 'X01',
    this.defaultMatchMode = 'X01',
    this.accentColor = '#1565C0',
    this.displayName,
    this.avatarEmoji = '🎯',
    this.avatarColor = '#1565C0',
    this.favoriteFormats = const <String>[],
  });

  final String preferredView;
  final String defaultTrainingMode;
  final String defaultMatchMode;
  final String accentColor;
  final String? displayName;
  final String avatarEmoji;
  final String avatarColor;
  final List<String> favoriteFormats;

  PlayerProfilePreferences copyWith({
    String? preferredView,
    String? defaultTrainingMode,
    String? defaultMatchMode,
    String? accentColor,
    String? displayName,
    bool clearDisplayName = false,
    String? avatarEmoji,
    String? avatarColor,
    List<String>? favoriteFormats,
  }) {
    return PlayerProfilePreferences(
      preferredView: preferredView ?? this.preferredView,
      defaultTrainingMode: defaultTrainingMode ?? this.defaultTrainingMode,
      defaultMatchMode: defaultMatchMode ?? this.defaultMatchMode,
      accentColor: accentColor ?? this.accentColor,
      displayName: clearDisplayName ? null : displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColor: avatarColor ?? this.avatarColor,
      favoriteFormats: favoriteFormats ?? this.favoriteFormats,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'preferredView': preferredView,
      'defaultTrainingMode': defaultTrainingMode,
      'defaultMatchMode': defaultMatchMode,
      'accentColor': accentColor,
      'displayName': displayName,
      'avatarEmoji': avatarEmoji,
      'avatarColor': avatarColor,
      'favoriteFormats': favoriteFormats,
    };
  }

  static PlayerProfilePreferences fromJson(Map<String, dynamic> json) {
    return PlayerProfilePreferences(
      preferredView: json['preferredView'] as String? ?? 'overview',
      defaultTrainingMode: json['defaultTrainingMode'] as String? ?? 'X01',
      defaultMatchMode: json['defaultMatchMode'] as String? ?? 'X01',
      accentColor: json['accentColor'] as String? ?? '#1565C0',
      displayName: (json['displayName'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['displayName'] as String?)?.trim(),
      avatarEmoji: json['avatarEmoji'] as String? ?? '🎯',
      avatarColor: json['avatarColor'] as String? ?? '#1565C0',
      favoriteFormats:
          (json['favoriteFormats'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString())
              .where((entry) => entry.trim().isNotEmpty)
              .toList(),
    );
  }
}

class PlayerCricketStats {
  const PlayerCricketStats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.points = 0,
    this.dartsThrown = 0,
    this.turns = 0,
    this.totalMarks = 0,
    this.closedTargets = 0,
    this.targetHits20 = 0,
    this.targetHits19 = 0,
    this.targetHits18 = 0,
    this.targetHits17 = 0,
    this.targetHits16 = 0,
    this.targetHits15 = 0,
    this.bullMarks = 0,
    this.roundsWithMarks = 0,
    this.highestScoringRound = 0,
    this.bestMarksRound = 0,
  });

  final int matchesPlayed;
  final int matchesWon;
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
  double get winRate => matchesPlayed <= 0 ? 0 : (matchesWon / matchesPlayed) * 100;

  PlayerCricketStats merge(PlayerCricketStats other) {
    return PlayerCricketStats(
      matchesPlayed: matchesPlayed + other.matchesPlayed,
      matchesWon: matchesWon + other.matchesWon,
      points: points + other.points,
      dartsThrown: dartsThrown + other.dartsThrown,
      turns: turns + other.turns,
      totalMarks: totalMarks + other.totalMarks,
      closedTargets: closedTargets + other.closedTargets,
      targetHits20: targetHits20 + other.targetHits20,
      targetHits19: targetHits19 + other.targetHits19,
      targetHits18: targetHits18 + other.targetHits18,
      targetHits17: targetHits17 + other.targetHits17,
      targetHits16: targetHits16 + other.targetHits16,
      targetHits15: targetHits15 + other.targetHits15,
      bullMarks: bullMarks + other.bullMarks,
      roundsWithMarks: roundsWithMarks + other.roundsWithMarks,
      highestScoringRound: highestScoringRound > other.highestScoringRound
          ? highestScoringRound
          : other.highestScoringRound,
      bestMarksRound: bestMarksRound > other.bestMarksRound
          ? bestMarksRound
          : other.bestMarksRound,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchesPlayed': matchesPlayed,
        'matchesWon': matchesWon,
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

  static PlayerCricketStats fromJson(Map<String, dynamic> json) {
    return PlayerCricketStats(
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
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

  static PlayerCricketStats fromParticipantStats(
    CricketParticipantStats stats, {
    required bool won,
  }) {
    return PlayerCricketStats(
      matchesPlayed: 1,
      matchesWon: won ? 1 : 0,
      points: stats.points,
      dartsThrown: stats.dartsThrown,
      turns: stats.turns,
      totalMarks: stats.totalMarks,
      closedTargets: stats.closedTargets,
      targetHits20: stats.targetHits20,
      targetHits19: stats.targetHits19,
      targetHits18: stats.targetHits18,
      targetHits17: stats.targetHits17,
      targetHits16: stats.targetHits16,
      targetHits15: stats.targetHits15,
      bullMarks: stats.bullMarks,
      roundsWithMarks: stats.roundsWithMarks,
      highestScoringRound: stats.highestScoringRound,
      bestMarksRound: stats.bestMarksRound,
    );
  }
}

class PlayerBob27Stats {
  const PlayerBob27Stats({
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.score = 0,
    this.hits = 0,
    this.roundsPlayed = 0,
    this.successfulRounds = 0,
    this.dartsThrown = 0,
    this.completedTargets = 0,
    this.perfectRounds = 0,
    this.zeroHitRounds = 0,
    this.bullHits = 0,
    this.highestRoundDelta = 0,
    this.lowestRoundDelta = 0,
    this.survivedMatches = 0,
    this.bestEliminationTarget = 0,
  });

  final int matchesPlayed;
  final int matchesWon;
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
  final int survivedMatches;
  final int bestEliminationTarget;

  double get hitRate => dartsThrown <= 0 ? 0 : (hits / dartsThrown) * 100;
  double get successRate => roundsPlayed <= 0 ? 0 : (successfulRounds / roundsPlayed) * 100;
  double get winRate => matchesPlayed <= 0 ? 0 : (matchesWon / matchesPlayed) * 100;

  PlayerBob27Stats merge(PlayerBob27Stats other) {
    return PlayerBob27Stats(
      matchesPlayed: matchesPlayed + other.matchesPlayed,
      matchesWon: matchesWon + other.matchesWon,
      score: score + other.score,
      hits: hits + other.hits,
      roundsPlayed: roundsPlayed + other.roundsPlayed,
      successfulRounds: successfulRounds + other.successfulRounds,
      dartsThrown: dartsThrown + other.dartsThrown,
      completedTargets: completedTargets + other.completedTargets,
      perfectRounds: perfectRounds + other.perfectRounds,
      zeroHitRounds: zeroHitRounds + other.zeroHitRounds,
      bullHits: bullHits + other.bullHits,
      highestRoundDelta: highestRoundDelta > other.highestRoundDelta
          ? highestRoundDelta
          : other.highestRoundDelta,
      lowestRoundDelta: lowestRoundDelta < other.lowestRoundDelta
          ? lowestRoundDelta
          : other.lowestRoundDelta,
      survivedMatches: survivedMatches + other.survivedMatches,
      bestEliminationTarget: bestEliminationTarget > other.bestEliminationTarget
          ? bestEliminationTarget
          : other.bestEliminationTarget,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'matchesPlayed': matchesPlayed,
        'matchesWon': matchesWon,
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
        'survivedMatches': survivedMatches,
        'bestEliminationTarget': bestEliminationTarget,
      };

  static PlayerBob27Stats fromJson(Map<String, dynamic> json) {
    return PlayerBob27Stats(
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
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
      survivedMatches: (json['survivedMatches'] as num?)?.toInt() ?? 0,
      bestEliminationTarget: (json['bestEliminationTarget'] as num?)?.toInt() ?? 0,
    );
  }

  static PlayerBob27Stats fromParticipantStats(
    Bob27ParticipantStats stats, {
    required bool won,
  }) {
    return PlayerBob27Stats(
      matchesPlayed: 1,
      matchesWon: won ? 1 : 0,
      score: stats.score,
      hits: stats.hits,
      roundsPlayed: stats.roundsPlayed,
      successfulRounds: stats.successfulRounds,
      dartsThrown: stats.dartsThrown,
      completedTargets: stats.completedTargets,
      perfectRounds: stats.perfectRounds,
      zeroHitRounds: stats.zeroHitRounds,
      bullHits: stats.bullHits,
      highestRoundDelta: stats.highestRoundDelta,
      lowestRoundDelta: stats.lowestRoundDelta,
      survivedMatches: stats.survived ? 1 : 0,
      bestEliminationTarget: stats.eliminatedAtTarget ?? 0,
    );
  }
}

class PlayerTrainingEntry {
  const PlayerTrainingEntry({
    required this.id,
    required this.mode,
    required this.scoreLabel,
    required this.playedAt,
    this.equipmentId,
    this.equipmentName,
    this.average,
    this.notes,
  });

  final String id;
  final String mode;
  final String scoreLabel;
  final DateTime playedAt;
  final String? equipmentId;
  final String? equipmentName;
  final double? average;
  final String? notes;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mode': mode,
        'scoreLabel': scoreLabel,
        'playedAt': playedAt.toIso8601String(),
        'equipmentId': equipmentId,
        'equipmentName': equipmentName,
        'average': average,
        'notes': notes,
      };

  static PlayerTrainingEntry fromJson(Map<String, dynamic> json) {
    return PlayerTrainingEntry(
      id: json['id'] as String,
      mode: json['mode'] as String? ?? 'Training',
      scoreLabel: json['scoreLabel'] as String? ?? '-',
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ?? DateTime.now(),
      equipmentId: (json['equipmentId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['equipmentId'] as String?)?.trim(),
      equipmentName: (json['equipmentName'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['equipmentName'] as String?)?.trim(),
      average: (json['average'] as num?)?.toDouble(),
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String?)?.trim(),
    );
  }
}

class PlayerProfileStats {
  const PlayerProfileStats({
    this.pointsScored = 0,
    this.dartsThrown = 0,
    this.visits = 0,
    this.legsPlayed = 0,
    this.legsWon = 0,
    this.legsStarted = 0,
    this.legsWonAsStarter = 0,
    this.legsWonWithoutStarter = 0,
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
    this.functionalDoubleAttempts = 0,
    this.functionalDoubleSuccesses = 0,
    this.bullCheckoutAttempts = 0,
    this.bullCheckouts = 0,
    this.hundredPlusCheckouts = 0,
    this.firstThreePoints = 0,
    this.firstThreeDarts = 0,
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
    this.won12Darters = 0,
    this.won15Darters = 0,
    this.won18Darters = 0,
  });

  final int pointsScored;
  final int dartsThrown;
  final int visits;
  final int legsPlayed;
  final int legsWon;
  final int legsStarted;
  final int legsWonAsStarter;
  final int legsWonWithoutStarter;
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
  final int functionalDoubleAttempts;
  final int functionalDoubleSuccesses;
  final int bullCheckoutAttempts;
  final int bullCheckouts;
  final int hundredPlusCheckouts;
  final double firstThreePoints;
  final int firstThreeDarts;
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
  double get firstNineAverage =>
      firstNineDarts <= 0 ? 0 : (firstNinePoints / firstNineDarts) * 3;
  double get firstThreeAverage =>
      firstThreeDarts <= 0 ? 0 : (firstThreePoints / firstThreeDarts) * 3;
  double get checkoutQuote => checkoutAttempts <= 0
      ? 0
      : (successfulCheckouts / checkoutAttempts) * 100;
  double get checkoutQuote1Dart => checkoutAttempts1Dart <= 0
      ? 0
      : (successfulCheckouts1Dart / checkoutAttempts1Dart) * 100;
  double get checkoutQuote2Dart => checkoutAttempts2Dart <= 0
      ? 0
      : (successfulCheckouts2Dart / checkoutAttempts2Dart) * 100;
  double get checkoutQuote3Dart => checkoutAttempts3Dart <= 0
      ? 0
      : (successfulCheckouts3Dart / checkoutAttempts3Dart) * 100;
  double get doubleQuote => functionalDoubleAttempts <= 0
      ? 0
      : (functionalDoubleSuccesses / functionalDoubleAttempts) * 100;
  double get bullCheckoutQuote => bullCheckoutAttempts <= 0
      ? 0
      : (bullCheckouts / bullCheckoutAttempts) * 100;
  double get withThrowAverage =>
      withThrowDarts <= 0 ? 0 : (withThrowPoints / withThrowDarts) * 3;
  double get againstThrowAverage =>
      againstThrowDarts <= 0 ? 0 : (againstThrowPoints / againstThrowDarts) * 3;
  double get decidingLegAverage => decidingLegDarts <= 0
      ? 0
      : (decidingLegPoints / decidingLegDarts) * 3;
  double get decidingLegsWonQuote => decidingLegsPlayed <= 0
      ? 0
      : (decidingLegsWon / decidingLegsPlayed) * 100;

  PlayerProfileStats copyWith({
    int? pointsScored,
    int? dartsThrown,
    int? visits,
    int? legsPlayed,
    int? legsWon,
    int? legsStarted,
    int? legsWonAsStarter,
    int? legsWonWithoutStarter,
    int? scores100Plus,
    int? scores140Plus,
    int? scores171Plus,
    int? scores180,
    int? checkoutAttempts,
    int? successfulCheckouts,
    int? checkoutAttempts1Dart,
    int? checkoutAttempts2Dart,
    int? checkoutAttempts3Dart,
    int? successfulCheckouts1Dart,
    int? successfulCheckouts2Dart,
    int? successfulCheckouts3Dart,
    int? functionalDoubleAttempts,
    int? functionalDoubleSuccesses,
    int? bullCheckoutAttempts,
    int? bullCheckouts,
    int? hundredPlusCheckouts,
    double? firstThreePoints,
    int? firstThreeDarts,
    double? firstNinePoints,
    int? firstNineDarts,
    int? highestFinish,
    int? bestLegDarts,
    int? totalFinishValue,
    int? withThrowPoints,
    int? withThrowDarts,
    int? againstThrowPoints,
    int? againstThrowDarts,
    int? decidingLegPoints,
    int? decidingLegDarts,
    int? decidingLegsPlayed,
    int? decidingLegsWon,
    int? won12Darters,
    int? won15Darters,
    int? won18Darters,
  }) {
    return PlayerProfileStats(
      pointsScored: pointsScored ?? this.pointsScored,
      dartsThrown: dartsThrown ?? this.dartsThrown,
      visits: visits ?? this.visits,
      legsPlayed: legsPlayed ?? this.legsPlayed,
      legsWon: legsWon ?? this.legsWon,
      legsStarted: legsStarted ?? this.legsStarted,
      legsWonAsStarter: legsWonAsStarter ?? this.legsWonAsStarter,
      legsWonWithoutStarter:
          legsWonWithoutStarter ?? this.legsWonWithoutStarter,
      scores100Plus: scores100Plus ?? this.scores100Plus,
      scores140Plus: scores140Plus ?? this.scores140Plus,
      scores171Plus: scores171Plus ?? this.scores171Plus,
      scores180: scores180 ?? this.scores180,
      checkoutAttempts: checkoutAttempts ?? this.checkoutAttempts,
      successfulCheckouts:
          successfulCheckouts ?? this.successfulCheckouts,
      checkoutAttempts1Dart:
          checkoutAttempts1Dart ?? this.checkoutAttempts1Dart,
      checkoutAttempts2Dart:
          checkoutAttempts2Dart ?? this.checkoutAttempts2Dart,
      checkoutAttempts3Dart:
          checkoutAttempts3Dart ?? this.checkoutAttempts3Dart,
      successfulCheckouts1Dart:
          successfulCheckouts1Dart ?? this.successfulCheckouts1Dart,
      successfulCheckouts2Dart:
          successfulCheckouts2Dart ?? this.successfulCheckouts2Dart,
      successfulCheckouts3Dart:
          successfulCheckouts3Dart ?? this.successfulCheckouts3Dart,
      functionalDoubleAttempts:
          functionalDoubleAttempts ?? this.functionalDoubleAttempts,
      functionalDoubleSuccesses:
          functionalDoubleSuccesses ?? this.functionalDoubleSuccesses,
      bullCheckoutAttempts:
          bullCheckoutAttempts ?? this.bullCheckoutAttempts,
      bullCheckouts: bullCheckouts ?? this.bullCheckouts,
      hundredPlusCheckouts:
          hundredPlusCheckouts ?? this.hundredPlusCheckouts,
      firstThreePoints: firstThreePoints ?? this.firstThreePoints,
      firstThreeDarts: firstThreeDarts ?? this.firstThreeDarts,
      firstNinePoints: firstNinePoints ?? this.firstNinePoints,
      firstNineDarts: firstNineDarts ?? this.firstNineDarts,
      highestFinish: highestFinish ?? this.highestFinish,
      bestLegDarts: bestLegDarts ?? this.bestLegDarts,
      totalFinishValue: totalFinishValue ?? this.totalFinishValue,
      withThrowPoints: withThrowPoints ?? this.withThrowPoints,
      withThrowDarts: withThrowDarts ?? this.withThrowDarts,
      againstThrowPoints: againstThrowPoints ?? this.againstThrowPoints,
      againstThrowDarts: againstThrowDarts ?? this.againstThrowDarts,
      decidingLegPoints: decidingLegPoints ?? this.decidingLegPoints,
      decidingLegDarts: decidingLegDarts ?? this.decidingLegDarts,
      decidingLegsPlayed: decidingLegsPlayed ?? this.decidingLegsPlayed,
      decidingLegsWon: decidingLegsWon ?? this.decidingLegsWon,
      won12Darters: won12Darters ?? this.won12Darters,
      won15Darters: won15Darters ?? this.won15Darters,
      won18Darters: won18Darters ?? this.won18Darters,
    );
  }

  PlayerProfileStats merge(PlayerProfileStats other) {
    return PlayerProfileStats(
      pointsScored: pointsScored + other.pointsScored,
      dartsThrown: dartsThrown + other.dartsThrown,
      visits: visits + other.visits,
      legsPlayed: legsPlayed + other.legsPlayed,
      legsWon: legsWon + other.legsWon,
      legsStarted: legsStarted + other.legsStarted,
      legsWonAsStarter: legsWonAsStarter + other.legsWonAsStarter,
      legsWonWithoutStarter:
          legsWonWithoutStarter + other.legsWonWithoutStarter,
      scores100Plus: scores100Plus + other.scores100Plus,
      scores140Plus: scores140Plus + other.scores140Plus,
      scores171Plus: scores171Plus + other.scores171Plus,
      scores180: scores180 + other.scores180,
      checkoutAttempts: checkoutAttempts + other.checkoutAttempts,
      successfulCheckouts:
          successfulCheckouts + other.successfulCheckouts,
      checkoutAttempts1Dart:
          checkoutAttempts1Dart + other.checkoutAttempts1Dart,
      checkoutAttempts2Dart:
          checkoutAttempts2Dart + other.checkoutAttempts2Dart,
      checkoutAttempts3Dart:
          checkoutAttempts3Dart + other.checkoutAttempts3Dart,
      successfulCheckouts1Dart:
          successfulCheckouts1Dart + other.successfulCheckouts1Dart,
      successfulCheckouts2Dart:
          successfulCheckouts2Dart + other.successfulCheckouts2Dart,
      successfulCheckouts3Dart:
          successfulCheckouts3Dart + other.successfulCheckouts3Dart,
      functionalDoubleAttempts:
          functionalDoubleAttempts + other.functionalDoubleAttempts,
      functionalDoubleSuccesses:
          functionalDoubleSuccesses + other.functionalDoubleSuccesses,
      bullCheckoutAttempts:
          bullCheckoutAttempts + other.bullCheckoutAttempts,
      bullCheckouts: bullCheckouts + other.bullCheckouts,
      hundredPlusCheckouts:
          hundredPlusCheckouts + other.hundredPlusCheckouts,
      firstThreePoints: firstThreePoints + other.firstThreePoints,
      firstThreeDarts: firstThreeDarts + other.firstThreeDarts,
      firstNinePoints: firstNinePoints + other.firstNinePoints,
      firstNineDarts: firstNineDarts + other.firstNineDarts,
      highestFinish: highestFinish > other.highestFinish
          ? highestFinish
          : other.highestFinish,
      bestLegDarts: _bestLegValue(bestLegDarts, other.bestLegDarts),
      totalFinishValue: totalFinishValue + other.totalFinishValue,
      withThrowPoints: withThrowPoints + other.withThrowPoints,
      withThrowDarts: withThrowDarts + other.withThrowDarts,
      againstThrowPoints: againstThrowPoints + other.againstThrowPoints,
      againstThrowDarts: againstThrowDarts + other.againstThrowDarts,
      decidingLegPoints: decidingLegPoints + other.decidingLegPoints,
      decidingLegDarts: decidingLegDarts + other.decidingLegDarts,
      decidingLegsPlayed: decidingLegsPlayed + other.decidingLegsPlayed,
      decidingLegsWon: decidingLegsWon + other.decidingLegsWon,
      won12Darters: won12Darters + other.won12Darters,
      won15Darters: won15Darters + other.won15Darters,
      won18Darters: won18Darters + other.won18Darters,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pointsScored': pointsScored,
      'dartsThrown': dartsThrown,
      'visits': visits,
      'legsPlayed': legsPlayed,
      'legsWon': legsWon,
      'legsStarted': legsStarted,
      'legsWonAsStarter': legsWonAsStarter,
      'legsWonWithoutStarter': legsWonWithoutStarter,
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
      'functionalDoubleAttempts': functionalDoubleAttempts,
      'functionalDoubleSuccesses': functionalDoubleSuccesses,
      'bullCheckoutAttempts': bullCheckoutAttempts,
      'bullCheckouts': bullCheckouts,
      'hundredPlusCheckouts': hundredPlusCheckouts,
      'firstThreePoints': firstThreePoints,
      'firstThreeDarts': firstThreeDarts,
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

  static PlayerProfileStats fromJson(Map<String, dynamic> json) {
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
    return PlayerProfileStats(
      pointsScored: pointsScored,
      dartsThrown: dartsThrown,
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      legsPlayed: legsPlayed,
      legsWon: (json['legsWon'] as num?)?.toInt() ?? 0,
      legsStarted: (json['legsStarted'] as num?)?.toInt() ?? 0,
      legsWonAsStarter: (json['legsWonAsStarter'] as num?)?.toInt() ?? 0,
      legsWonWithoutStarter:
          (json['legsWonWithoutStarter'] as num?)?.toInt() ?? 0,
      scores100Plus: (json['scores100Plus'] as num?)?.toInt() ?? 0,
      scores140Plus: (json['scores140Plus'] as num?)?.toInt() ?? 0,
      scores171Plus: (json['scores171Plus'] as num?)?.toInt() ?? 0,
      scores180: (json['scores180'] as num?)?.toInt() ?? 0,
      checkoutAttempts: (json['checkoutAttempts'] as num?)?.toInt() ?? 0,
      successfulCheckouts:
          (json['successfulCheckouts'] as num?)?.toInt() ?? 0,
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
      functionalDoubleAttempts:
          (json['functionalDoubleAttempts'] as num?)?.toInt() ?? 0,
      functionalDoubleSuccesses:
          (json['functionalDoubleSuccesses'] as num?)?.toInt() ?? 0,
      bullCheckoutAttempts:
          (json['bullCheckoutAttempts'] as num?)?.toInt() ?? 0,
      bullCheckouts: (json['bullCheckouts'] as num?)?.toInt() ?? 0,
      hundredPlusCheckouts:
          (json['hundredPlusCheckouts'] as num?)?.toInt() ?? 0,
      firstThreePoints: (json['firstThreePoints'] as num?)?.toDouble() ?? 0,
      firstThreeDarts: (json['firstThreeDarts'] as num?)?.toInt() ?? 0,
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
      decidingLegsPlayed: (json['decidingLegsPlayed'] as num?)?.toInt() ?? 0,
      decidingLegsWon: (json['decidingLegsWon'] as num?)?.toInt() ?? 0,
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

  static PlayerProfileStats fromMatchParticipantStats(
    MatchParticipantStats stats,
  ) {
    return PlayerProfileStats(
      pointsScored: stats.pointsScored,
      dartsThrown: stats.dartsThrown,
      visits: stats.visits,
      legsPlayed: stats.legsPlayed,
      legsWon: stats.legsWon,
      legsStarted: stats.legsStarted,
      legsWonAsStarter: stats.legsWonAsStarter,
      legsWonWithoutStarter: stats.legsWonWithoutStarter,
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
      functionalDoubleAttempts: stats.functionalDoubleAttempts,
      functionalDoubleSuccesses: stats.functionalDoubleSuccesses,
      bullCheckoutAttempts: stats.bullCheckoutAttempts,
      bullCheckouts: stats.bullCheckouts,
      hundredPlusCheckouts: 0,
      firstThreePoints: 0,
      firstThreeDarts: 0,
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
      won12Darters: stats.won12Darters,
      won15Darters: stats.won15Darters,
      won18Darters: stats.won18Darters,
    );
  }

  static int _bestLegValue(int left, int right) {
    if (left <= 0) {
      return right;
    }
    if (right <= 0) {
      return left;
    }
    return left < right ? left : right;
  }
}

class PlayerMatchHistoryEntry {
  const PlayerMatchHistoryEntry({
    required this.id,
    required this.opponentName,
    required this.won,
    required this.average,
    required this.scoreText,
    required this.playedAt,
    this.opponentType = PlayerOpponentKind.unknown,
    this.equipmentId,
    this.equipmentName,
    this.match,
    this.cricketMatch,
    this.bob27Match,
  });

  final String id;
  final String opponentName;
  final bool won;
  final double average;
  final String scoreText;
  final DateTime playedAt;
  final PlayerOpponentKind opponentType;
  final String? equipmentId;
  final String? equipmentName;
  final MatchResultSummary? match;
  final CricketResultSummary? cricketMatch;
  final Bob27ResultSummary? bob27Match;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'opponentName': opponentName,
      'won': won,
      'average': average,
      'scoreText': scoreText,
      'playedAt': playedAt.toIso8601String(),
      'opponentType': opponentType.storageValue,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      if (match != null) 'match': match!.toJson(),
      if (cricketMatch != null) 'cricketMatch': cricketMatch!.toJson(),
      if (bob27Match != null) 'bob27Match': bob27Match!.toJson(),
    };
  }

  static PlayerMatchHistoryEntry fromJson(Map<String, dynamic> json) {
    return PlayerMatchHistoryEntry(
      id: json['id'] as String,
      opponentName: json['opponentName'] as String,
      won: json['won'] as bool? ?? false,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      scoreText: json['scoreText'] as String? ?? '',
      playedAt: DateTime.tryParse(json['playedAt'] as String? ?? '') ??
          DateTime.now(),
      opponentType: PlayerOpponentKindSerialization.fromStorageValue(
        json['opponentType'] as String?,
      ),
      equipmentId: (json['equipmentId'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['equipmentId'] as String?)?.trim(),
      equipmentName: (json['equipmentName'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['equipmentName'] as String?)?.trim(),
      match: json['match'] == null
          ? null
          : MatchResultSummary.fromJson(
              (json['match'] as Map).cast<String, dynamic>(),
            ),
      cricketMatch: json['cricketMatch'] == null
          ? null
          : CricketResultSummary.fromJson(
              (json['cricketMatch'] as Map).cast<String, dynamic>(),
            ),
      bob27Match: json['bob27Match'] == null
          ? null
          : Bob27ResultSummary.fromJson(
              (json['bob27Match'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModifiedReason,
    this.source = PlayerProfileSource.manual,
    this.isFavorite = false,
    this.isProtected = false,
    this.age,
    this.nationality,
    this.favoriteDouble,
    this.hatedDouble,
    this.tags = const <String>[],
    this.notes,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.average = 0,
    this.history = const <PlayerMatchHistoryEntry>[],
    this.trainingHistory = const <PlayerTrainingEntry>[],
    this.equipmentSetups = const <PlayerEquipmentSetup>[],
    this.activeEquipmentId,
    this.stats = const PlayerProfileStats(),
    this.cricketStats = const PlayerCricketStats(),
    this.bob27Stats = const PlayerBob27Stats(),
    this.preferences = const PlayerProfilePreferences(),
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedReason;
  final PlayerProfileSource source;
  final bool isFavorite;
  final bool isProtected;
  final int? age;
  final String? nationality;
  final String? favoriteDouble;
  final String? hatedDouble;
  final List<String> tags;
  final String? notes;
  final int matchesPlayed;
  final int matchesWon;
  final double average;
  final List<PlayerMatchHistoryEntry> history;
  final List<PlayerTrainingEntry> trainingHistory;
  final List<PlayerEquipmentSetup> equipmentSetups;
  final String? activeEquipmentId;
  final PlayerProfileStats stats;
  final PlayerCricketStats cricketStats;
  final PlayerBob27Stats bob27Stats;
  final PlayerProfilePreferences preferences;

  double get winRate =>
      matchesPlayed <= 0 ? 0 : (matchesWon / matchesPlayed) * 100;

  PlayerProfile copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedReason,
    PlayerProfileSource? source,
    bool? isFavorite,
    bool? isProtected,
    int? age,
    bool clearAge = false,
    String? nationality,
    bool clearNationality = false,
    String? favoriteDouble,
    bool clearFavoriteDouble = false,
    String? hatedDouble,
    bool clearHatedDouble = false,
    List<String>? tags,
    String? notes,
    bool clearNotes = false,
    int? matchesPlayed,
    int? matchesWon,
    double? average,
    List<PlayerMatchHistoryEntry>? history,
    List<PlayerTrainingEntry>? trainingHistory,
    List<PlayerEquipmentSetup>? equipmentSetups,
    String? activeEquipmentId,
    bool clearActiveEquipmentId = false,
    PlayerProfileStats? stats,
    PlayerCricketStats? cricketStats,
    PlayerBob27Stats? bob27Stats,
    PlayerProfilePreferences? preferences,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedReason: lastModifiedReason ?? this.lastModifiedReason,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      isProtected: isProtected ?? this.isProtected,
      age: clearAge ? null : age ?? this.age,
      nationality: clearNationality ? null : nationality ?? this.nationality,
      favoriteDouble:
          clearFavoriteDouble ? null : favoriteDouble ?? this.favoriteDouble,
      hatedDouble: clearHatedDouble ? null : hatedDouble ?? this.hatedDouble,
      tags: tags ?? this.tags,
      notes: clearNotes ? null : notes ?? this.notes,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      average: average ?? this.average,
      history: history ?? this.history,
      trainingHistory: trainingHistory ?? this.trainingHistory,
      equipmentSetups: equipmentSetups ?? this.equipmentSetups,
      activeEquipmentId: clearActiveEquipmentId
          ? null
          : activeEquipmentId ?? this.activeEquipmentId,
      stats: stats ?? this.stats,
      cricketStats: cricketStats ?? this.cricketStats,
      bob27Stats: bob27Stats ?? this.bob27Stats,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastModifiedReason': lastModifiedReason,
      'source': source.storageValue,
      'isFavorite': isFavorite,
      'isProtected': isProtected,
      'age': age,
      'nationality': nationality,
      'favoriteDouble': favoriteDouble,
      'hatedDouble': hatedDouble,
      'tags': tags,
      'notes': notes,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'average': average,
      'history': history.map((entry) => entry.toJson()).toList(),
      'trainingHistory':
          trainingHistory.map((entry) => entry.toJson()).toList(),
      'equipmentSetups':
          equipmentSetups.map((entry) => entry.toJson()).toList(),
      'activeEquipmentId': activeEquipmentId,
      'stats': stats.toJson(),
      'cricketStats': cricketStats.toJson(),
      'bob27Stats': bob27Stats.toJson(),
      'preferences': preferences.toJson(),
    };
  }

  static PlayerProfile fromJson(Map<String, dynamic> json) {
    final rawNationality = (json['nationality'] as String?)?.trim();
    final parsedTags = (json['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    return PlayerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastModifiedReason:
          json['lastModifiedReason'] as String? ?? 'legacy_import',
      source: PlayerProfileSourceSerialization.fromStorageValue(
        json['source'] as String?,
      ),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isProtected: json['isProtected'] as bool? ?? false,
      age: (json['age'] as num?)?.toInt(),
      nationality:
          rawNationality == null || rawNationality.isEmpty ? null : rawNationality,
      favoriteDouble: (json['favoriteDouble'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['favoriteDouble'] as String?)?.trim(),
      hatedDouble: (json['hatedDouble'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['hatedDouble'] as String?)?.trim(),
      tags: parsedTags,
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String?)?.trim(),
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      history: (json['history'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => PlayerMatchHistoryEntry.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      trainingHistory:
          (json['trainingHistory'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => PlayerTrainingEntry.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      equipmentSetups:
          (json['equipmentSetups'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => PlayerEquipmentSetup.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      activeEquipmentId:
          (json['activeEquipmentId'] as String?)?.trim().isEmpty ?? true
              ? null
              : (json['activeEquipmentId'] as String?)?.trim(),
      stats: (json['stats'] as Map?) == null
          ? const PlayerProfileStats()
          : PlayerProfileStats.fromJson(
              (json['stats'] as Map).cast<String, dynamic>(),
            ),
      cricketStats: (json['cricketStats'] as Map?) == null
          ? const PlayerCricketStats()
          : PlayerCricketStats.fromJson(
              (json['cricketStats'] as Map).cast<String, dynamic>(),
            ),
      bob27Stats: (json['bob27Stats'] as Map?) == null
          ? const PlayerBob27Stats()
          : PlayerBob27Stats.fromJson(
              (json['bob27Stats'] as Map).cast<String, dynamic>(),
            ),
      preferences: (json['preferences'] as Map?) == null
          ? const PlayerProfilePreferences()
          : PlayerProfilePreferences.fromJson(
              (json['preferences'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

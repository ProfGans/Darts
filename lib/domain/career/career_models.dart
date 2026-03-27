import '../tournament/tournament_models.dart';
import '../x01/x01_models.dart';

enum CareerParticipantMode {
  withHuman,
  cpuOnly,
}

enum CareerRankingMetric {
  money,
  points,
}

class CareerRankingDefinition {
  const CareerRankingDefinition({
    required this.id,
    required this.name,
    required this.validSeasons,
    this.metric = CareerRankingMetric.money,
    this.resetAtSeasonEnd = false,
    this.countedCategories = const <String>[],
    this.bestOfCount,
    this.discardWorstCount = 0,
    this.seasonBonus = 0,
    this.playoffBonus = 0,
  });

  final String id;
  final String name;
  final int validSeasons;
  final CareerRankingMetric metric;
  final bool resetAtSeasonEnd;
  final List<String> countedCategories;
  final int? bestOfCount;
  final int discardWorstCount;
  final int seasonBonus;
  final int playoffBonus;

  CareerRankingDefinition copyWith({
    String? id,
    String? name,
    int? validSeasons,
    CareerRankingMetric? metric,
    bool? resetAtSeasonEnd,
    List<String>? countedCategories,
    int? bestOfCount,
    int? discardWorstCount,
    int? seasonBonus,
    int? playoffBonus,
    bool clearBestOfCount = false,
  }) {
    return CareerRankingDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      validSeasons: validSeasons ?? this.validSeasons,
      metric: metric ?? this.metric,
      resetAtSeasonEnd: resetAtSeasonEnd ?? this.resetAtSeasonEnd,
      countedCategories: countedCategories ?? this.countedCategories,
      bestOfCount: clearBestOfCount ? null : (bestOfCount ?? this.bestOfCount),
      discardWorstCount: discardWorstCount ?? this.discardWorstCount,
      seasonBonus: seasonBonus ?? this.seasonBonus,
      playoffBonus: playoffBonus ?? this.playoffBonus,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'validSeasons': validSeasons,
      'metric': metric.name,
      'resetAtSeasonEnd': resetAtSeasonEnd,
      'countedCategories': countedCategories,
      'bestOfCount': bestOfCount,
      'discardWorstCount': discardWorstCount,
      'seasonBonus': seasonBonus,
      'playoffBonus': playoffBonus,
    };
  }

  static CareerRankingDefinition fromJson(Map<String, dynamic> json) {
    return CareerRankingDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      validSeasons: (json['validSeasons'] as num).toInt(),
      metric: CareerRankingMetric.values.byName(
        json['metric'] as String? ?? CareerRankingMetric.money.name,
      ),
      resetAtSeasonEnd: json['resetAtSeasonEnd'] as bool? ?? false,
      countedCategories:
          (json['countedCategories'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      bestOfCount: (json['bestOfCount'] as num?)?.toInt(),
      discardWorstCount: (json['discardWorstCount'] as num?)?.toInt() ?? 0,
      seasonBonus: (json['seasonBonus'] as num?)?.toInt() ?? 0,
      playoffBonus: (json['playoffBonus'] as num?)?.toInt() ?? 0,
    );
  }
}

class CareerQualificationCondition {
  const CareerQualificationCondition({
    this.rankingId,
    this.fromRank = 1,
    this.toRank = 1,
    this.entryRound = 1,
    this.slotCount,
    this.type = CareerQualificationConditionType.rankingRange,
    this.requiredCareerTags = const <String>[],
    this.excludedCareerTags = const <String>[],
  });

  final String? rankingId;
  final int fromRank;
  final int toRank;
  final int entryRound;
  final int? slotCount;
  final CareerQualificationConditionType type;
  final List<String> requiredCareerTags;
  final List<String> excludedCareerTags;

  CareerQualificationCondition copyWith({
    String? rankingId,
    int? fromRank,
    int? toRank,
    int? entryRound,
    int? slotCount,
    CareerQualificationConditionType? type,
    List<String>? requiredCareerTags,
    List<String>? excludedCareerTags,
    bool clearRankingId = false,
    bool clearSlotCount = false,
  }) {
    return CareerQualificationCondition(
      rankingId: clearRankingId ? null : (rankingId ?? this.rankingId),
      fromRank: fromRank ?? this.fromRank,
      toRank: toRank ?? this.toRank,
      entryRound: entryRound ?? this.entryRound,
      slotCount: clearSlotCount ? null : (slotCount ?? this.slotCount),
      type: type ?? this.type,
      requiredCareerTags: requiredCareerTags ?? this.requiredCareerTags,
      excludedCareerTags: excludedCareerTags ?? this.excludedCareerTags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rankingId': rankingId,
      'fromRank': fromRank,
      'toRank': toRank,
      'entryRound': entryRound,
      'slotCount': slotCount,
      'type': type.name,
      'requiredCareerTags': requiredCareerTags,
      'excludedCareerTags': excludedCareerTags,
    };
  }

  static CareerQualificationCondition fromJson(Map<String, dynamic> json) {
    return CareerQualificationCondition(
      rankingId: json['rankingId'] as String?,
      fromRank: (json['fromRank'] as num?)?.toInt() ?? 1,
      toRank: (json['toRank'] as num?)?.toInt() ?? 1,
      entryRound: (json['entryRound'] as num?)?.toInt() ?? 1,
      slotCount: (json['slotCount'] as num?)?.toInt(),
      type: CareerQualificationConditionType.values.byName(
        json['type'] as String? ??
            CareerQualificationConditionType.rankingRange.name,
      ),
      requiredCareerTags:
          (json['requiredCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      excludedCareerTags:
          (json['excludedCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
    );
  }
}

enum CareerQualificationConditionType {
  rankingRange,
  careerTagOnly,
}

enum CareerTournamentSlotSourceType {
  rankingRange,
  careerTag,
}

class CareerTournamentSlotRule {
  const CareerTournamentSlotRule({
    required this.id,
    required this.sourceType,
    this.rankingId,
    this.requiredCareerTags = const <String>[],
    this.excludedCareerTags = const <String>[],
    this.fromRank = 1,
    this.toRank = 1,
    this.slotCount = 1,
    this.entryRound = 1,
  });

  final String id;
  final CareerTournamentSlotSourceType sourceType;
  final String? rankingId;
  final List<String> requiredCareerTags;
  final List<String> excludedCareerTags;
  final int fromRank;
  final int toRank;
  final int slotCount;
  final int entryRound;

  CareerTournamentSlotRule copyWith({
    String? id,
    CareerTournamentSlotSourceType? sourceType,
    String? rankingId,
    bool clearRankingId = false,
    List<String>? requiredCareerTags,
    List<String>? excludedCareerTags,
    int? fromRank,
    int? toRank,
    int? slotCount,
    int? entryRound,
  }) {
    return CareerTournamentSlotRule(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      rankingId: clearRankingId ? null : (rankingId ?? this.rankingId),
      requiredCareerTags: requiredCareerTags ?? this.requiredCareerTags,
      excludedCareerTags: excludedCareerTags ?? this.excludedCareerTags,
      fromRank: fromRank ?? this.fromRank,
      toRank: toRank ?? this.toRank,
      slotCount: slotCount ?? this.slotCount,
      entryRound: entryRound ?? this.entryRound,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceType': sourceType.name,
      'rankingId': rankingId,
      'requiredCareerTags': requiredCareerTags,
      'excludedCareerTags': excludedCareerTags,
      'fromRank': fromRank,
      'toRank': toRank,
      'slotCount': slotCount,
      'entryRound': entryRound,
    };
  }

  static CareerTournamentSlotRule fromJson(Map<String, dynamic> json) {
    return CareerTournamentSlotRule(
      id: json['id'] as String,
      sourceType: CareerTournamentSlotSourceType.values.byName(
        json['sourceType'] as String? ??
            CareerTournamentSlotSourceType.rankingRange.name,
      ),
      rankingId: json['rankingId'] as String?,
      requiredCareerTags:
          (json['requiredCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      excludedCareerTags:
          (json['excludedCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      fromRank: (json['fromRank'] as num?)?.toInt() ?? 1,
      toRank: (json['toRank'] as num?)?.toInt() ?? 1,
      slotCount: (json['slotCount'] as num?)?.toInt() ?? 1,
      entryRound: (json['entryRound'] as num?)?.toInt() ?? 1,
    );
  }

  static CareerTournamentSlotRule fromLegacyCondition(
    CareerQualificationCondition condition,
    int index,
  ) {
    return CareerTournamentSlotRule(
      id: 'legacy-slot-$index',
      sourceType:
          condition.type == CareerQualificationConditionType.careerTagOnly
              ? CareerTournamentSlotSourceType.careerTag
              : CareerTournamentSlotSourceType.rankingRange,
      rankingId: condition.rankingId,
      requiredCareerTags: condition.requiredCareerTags,
      excludedCareerTags: condition.excludedCareerTags,
      fromRank: condition.fromRank,
      toRank: condition.toRank,
      slotCount: condition.slotCount ??
          (condition.type == CareerQualificationConditionType.rankingRange
              ? ((condition.toRank - condition.fromRank).abs() + 1)
              : 1),
      entryRound: condition.entryRound,
    );
  }
}

enum CareerTournamentFillSourceType {
  ranking,
  average,
}

class CareerTournamentFillRule {
  const CareerTournamentFillRule({
    required this.id,
    required this.sourceType,
    this.rankingId,
    this.requiredCareerTags = const <String>[],
    this.excludedCareerTags = const <String>[],
    this.maxCount = 0,
  });

  final String id;
  final CareerTournamentFillSourceType sourceType;
  final String? rankingId;
  final List<String> requiredCareerTags;
  final List<String> excludedCareerTags;
  final int maxCount;

  CareerTournamentFillRule copyWith({
    String? id,
    CareerTournamentFillSourceType? sourceType,
    String? rankingId,
    bool clearRankingId = false,
    List<String>? requiredCareerTags,
    List<String>? excludedCareerTags,
    int? maxCount,
  }) {
    return CareerTournamentFillRule(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      rankingId: clearRankingId ? null : (rankingId ?? this.rankingId),
      requiredCareerTags: requiredCareerTags ?? this.requiredCareerTags,
      excludedCareerTags: excludedCareerTags ?? this.excludedCareerTags,
      maxCount: maxCount ?? this.maxCount,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceType': sourceType.name,
      'rankingId': rankingId,
      'requiredCareerTags': requiredCareerTags,
      'excludedCareerTags': excludedCareerTags,
      'maxCount': maxCount,
    };
  }

  static CareerTournamentFillRule fromJson(Map<String, dynamic> json) {
    return CareerTournamentFillRule(
      id: json['id'] as String,
      sourceType: CareerTournamentFillSourceType.values.byName(
        json['sourceType'] as String? ??
            CareerTournamentFillSourceType.average.name,
      ),
      rankingId: json['rankingId'] as String?,
      requiredCareerTags:
          (json['requiredCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      excludedCareerTags:
          (json['excludedCareerTags'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      maxCount: (json['maxCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CareerTagAttribute {
  const CareerTagAttribute({
    required this.key,
    required this.value,
  });

  final String key;
  final String value;

  CareerTagAttribute copyWith({
    String? key,
    String? value,
  }) {
    return CareerTagAttribute(
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'value': value,
    };
  }

  static CareerTagAttribute fromJson(Map<String, dynamic> json) {
    return CareerTagAttribute(
      key: json['key'] as String,
      value: json['value'] as String,
    );
  }
}

class CareerTagDefinition {
  const CareerTagDefinition({
    required this.id,
    required this.name,
    this.attributes = const <CareerTagAttribute>[],
    this.playerLimit,
    this.initialValiditySeasons,
    this.extensionValiditySeasons,
    this.tagsToAddOnExpiry = const <String>[],
    this.tagsToRemoveOnInitialAssignment = const <String>[],
    this.tagsToRemoveOnExtension = const <String>[],
    this.fillUpToPlayerCount,
    this.fillUpByRankingId,
    this.fillUpRequiredCareerTags = const <String>[],
    this.fillUpExcludedCareerTags = const <String>[],
  });

  final String id;
  final String name;
  final List<CareerTagAttribute> attributes;
  final int? playerLimit;
  final int? initialValiditySeasons;
  final int? extensionValiditySeasons;
  final List<String> tagsToAddOnExpiry;
  final List<String> tagsToRemoveOnInitialAssignment;
  final List<String> tagsToRemoveOnExtension;
  final int? fillUpToPlayerCount;
  final String? fillUpByRankingId;
  final List<String> fillUpRequiredCareerTags;
  final List<String> fillUpExcludedCareerTags;

  CareerTagDefinition copyWith({
    String? id,
    String? name,
    List<CareerTagAttribute>? attributes,
    int? playerLimit,
    int? initialValiditySeasons,
    int? extensionValiditySeasons,
    List<String>? tagsToAddOnExpiry,
    List<String>? tagsToRemoveOnInitialAssignment,
    List<String>? tagsToRemoveOnExtension,
    int? fillUpToPlayerCount,
    String? fillUpByRankingId,
    List<String>? fillUpRequiredCareerTags,
    List<String>? fillUpExcludedCareerTags,
    bool clearPlayerLimit = false,
    bool clearInitialValiditySeasons = false,
    bool clearExtensionValiditySeasons = false,
    bool clearFillUpToPlayerCount = false,
    bool clearFillUpByRankingId = false,
  }) {
    return CareerTagDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      attributes: attributes ?? this.attributes,
      playerLimit: clearPlayerLimit ? null : (playerLimit ?? this.playerLimit),
      initialValiditySeasons: clearInitialValiditySeasons
          ? null
          : (initialValiditySeasons ?? this.initialValiditySeasons),
      extensionValiditySeasons: clearExtensionValiditySeasons
          ? null
          : (extensionValiditySeasons ?? this.extensionValiditySeasons),
      tagsToAddOnExpiry: tagsToAddOnExpiry ?? this.tagsToAddOnExpiry,
      tagsToRemoveOnInitialAssignment: tagsToRemoveOnInitialAssignment ??
          this.tagsToRemoveOnInitialAssignment,
      tagsToRemoveOnExtension:
          tagsToRemoveOnExtension ?? this.tagsToRemoveOnExtension,
      fillUpToPlayerCount: clearFillUpToPlayerCount
          ? null
          : (fillUpToPlayerCount ?? this.fillUpToPlayerCount),
      fillUpByRankingId: clearFillUpByRankingId
          ? null
          : (fillUpByRankingId ?? this.fillUpByRankingId),
      fillUpRequiredCareerTags:
          fillUpRequiredCareerTags ?? this.fillUpRequiredCareerTags,
      fillUpExcludedCareerTags:
          fillUpExcludedCareerTags ?? this.fillUpExcludedCareerTags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'attributes': attributes.map((entry) => entry.toJson()).toList(),
      'playerLimit': playerLimit,
      'initialValiditySeasons': initialValiditySeasons,
      'extensionValiditySeasons': extensionValiditySeasons,
      'tagsToAddOnExpiry': tagsToAddOnExpiry,
      'tagsToRemoveOnInitialAssignment': tagsToRemoveOnInitialAssignment,
      'tagsToRemoveOnExtension': tagsToRemoveOnExtension,
      'fillUpToPlayerCount': fillUpToPlayerCount,
      'fillUpByRankingId': fillUpByRankingId,
      'fillUpRequiredCareerTags': fillUpRequiredCareerTags,
      'fillUpExcludedCareerTags': fillUpExcludedCareerTags,
    };
  }

  static CareerTagDefinition fromJson(Map<String, dynamic> json) {
    return CareerTagDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      attributes: (json['attributes'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerTagAttribute.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      playerLimit: (json['playerLimit'] as num?)?.toInt(),
      initialValiditySeasons:
          (json['initialValiditySeasons'] as num?)?.toInt(),
      extensionValiditySeasons:
          (json['extensionValiditySeasons'] as num?)?.toInt(),
      tagsToAddOnExpiry:
          (json['tagsToAddOnExpiry'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      tagsToRemoveOnInitialAssignment:
          (json['tagsToRemoveOnInitialAssignment'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      tagsToRemoveOnExtension:
          (json['tagsToRemoveOnExtension'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      fillUpToPlayerCount: (json['fillUpToPlayerCount'] as num?)?.toInt(),
      fillUpByRankingId: json['fillUpByRankingId'] as String?,
      fillUpRequiredCareerTags:
          (json['fillUpRequiredCareerTags'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      fillUpExcludedCareerTags:
          (json['fillUpExcludedCareerTags'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
    );
  }
}

enum CareerSeasonTagRuleAction {
  add,
  remove,
}

enum CareerSeasonTagRuleRankMode {
  range,
  greaterThanRank,
}

enum CareerSeasonTagRuleCheckMode {
  none,
  tagValidityAtMost,
  tagValidityAtLeast,
}

class CareerSeasonTagRule {
  const CareerSeasonTagRule({
    required this.id,
    required this.tagName,
    required this.rankingId,
    required this.fromRank,
    required this.toRank,
    required this.action,
    this.rankMode = CareerSeasonTagRuleRankMode.range,
    this.referenceRank,
    this.checkMode = CareerSeasonTagRuleCheckMode.none,
    this.checkTagName,
    this.checkRemainingSeasons,
  });

  final String id;
  final String tagName;
  final String rankingId;
  final int fromRank;
  final int toRank;
  final CareerSeasonTagRuleAction action;
  final CareerSeasonTagRuleRankMode rankMode;
  final int? referenceRank;
  final CareerSeasonTagRuleCheckMode checkMode;
  final String? checkTagName;
  final int? checkRemainingSeasons;

  CareerSeasonTagRule copyWith({
    String? id,
    String? tagName,
    String? rankingId,
    int? fromRank,
    int? toRank,
    CareerSeasonTagRuleAction? action,
    CareerSeasonTagRuleRankMode? rankMode,
    int? referenceRank,
    CareerSeasonTagRuleCheckMode? checkMode,
    String? checkTagName,
    int? checkRemainingSeasons,
    bool clearReferenceRank = false,
    bool clearCheckTagName = false,
    bool clearCheckRemainingSeasons = false,
  }) {
    return CareerSeasonTagRule(
      id: id ?? this.id,
      tagName: tagName ?? this.tagName,
      rankingId: rankingId ?? this.rankingId,
      fromRank: fromRank ?? this.fromRank,
      toRank: toRank ?? this.toRank,
      action: action ?? this.action,
      rankMode: rankMode ?? this.rankMode,
      referenceRank:
          clearReferenceRank ? null : (referenceRank ?? this.referenceRank),
      checkMode: checkMode ?? this.checkMode,
      checkTagName:
          clearCheckTagName ? null : (checkTagName ?? this.checkTagName),
      checkRemainingSeasons: clearCheckRemainingSeasons
          ? null
          : (checkRemainingSeasons ?? this.checkRemainingSeasons),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'tagName': tagName,
      'rankingId': rankingId,
      'fromRank': fromRank,
      'toRank': toRank,
      'action': action.name,
      'rankMode': rankMode.name,
      'referenceRank': referenceRank,
      'checkMode': checkMode.name,
      'checkTagName': checkTagName,
      'checkRemainingSeasons': checkRemainingSeasons,
    };
  }

  static CareerSeasonTagRule fromJson(Map<String, dynamic> json) {
    return CareerSeasonTagRule(
      id: json['id'] as String,
      tagName: json['tagName'] as String,
      rankingId: json['rankingId'] as String,
      fromRank: (json['fromRank'] as num).toInt(),
      toRank: (json['toRank'] as num).toInt(),
      action: CareerSeasonTagRuleAction.values.byName(
        json['action'] as String? ?? CareerSeasonTagRuleAction.add.name,
      ),
      rankMode: CareerSeasonTagRuleRankMode.values.byName(
        json['rankMode'] as String? ?? CareerSeasonTagRuleRankMode.range.name,
      ),
      referenceRank: (json['referenceRank'] as num?)?.toInt(),
      checkMode: CareerSeasonTagRuleCheckMode.values.byName(
        json['checkMode'] as String? ?? CareerSeasonTagRuleCheckMode.none.name,
      ),
      checkTagName: json['checkTagName'] as String?,
      checkRemainingSeasons:
          (json['checkRemainingSeasons'] as num?)?.toInt(),
    );
  }
}

class CareerPlayerTag {
  const CareerPlayerTag({
    required this.tagName,
    this.remainingSeasons,
  });

  final String tagName;
  final int? remainingSeasons;

  CareerPlayerTag copyWith({
    String? tagName,
    int? remainingSeasons,
    bool clearRemainingSeasons = false,
  }) {
    return CareerPlayerTag(
      tagName: tagName ?? this.tagName,
      remainingSeasons: clearRemainingSeasons
          ? null
          : (remainingSeasons ?? this.remainingSeasons),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tagName': tagName,
      'remainingSeasons': remainingSeasons,
    };
  }

  static CareerPlayerTag fromJson(dynamic json) {
    if (json is String) {
      return CareerPlayerTag(tagName: json);
    }
    final map = (json as Map).cast<String, dynamic>();
    return CareerPlayerTag(
      tagName: map['tagName'] as String,
      remainingSeasons: (map['remainingSeasons'] as num?)?.toInt(),
    );
  }
}

class CareerDatabasePlayer {
  const CareerDatabasePlayer({
    required this.databasePlayerId,
    required this.name,
    required this.average,
    required this.skill,
    required this.finishingSkill,
    this.careerTags = const <CareerPlayerTag>[],
  });

  final String databasePlayerId;
  final String name;
  final double average;
  final int skill;
  final int finishingSkill;
  final List<CareerPlayerTag> careerTags;

  List<String> get activeTagNames {
    return careerTags.map((entry) => entry.tagName).toList();
  }

  CareerDatabasePlayer copyWith({
    String? databasePlayerId,
    String? name,
    double? average,
    int? skill,
    int? finishingSkill,
    List<CareerPlayerTag>? careerTags,
  }) {
    return CareerDatabasePlayer(
      databasePlayerId: databasePlayerId ?? this.databasePlayerId,
      name: name ?? this.name,
      average: average ?? this.average,
      skill: skill ?? this.skill,
      finishingSkill: finishingSkill ?? this.finishingSkill,
      careerTags: careerTags ?? this.careerTags,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'databasePlayerId': databasePlayerId,
      'name': name,
      'average': average,
      'skill': skill,
      'finishingSkill': finishingSkill,
      'careerTags': careerTags.map((entry) => entry.toJson()).toList(),
    };
  }

  static CareerDatabasePlayer fromJson(Map<String, dynamic> json) {
    return CareerDatabasePlayer(
      databasePlayerId: json['databasePlayerId'] as String,
      name: json['name'] as String,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      skill: (json['skill'] as num?)?.toInt() ?? 700,
      finishingSkill: (json['finishingSkill'] as num?)?.toInt() ?? 700,
      careerTags: (json['careerTags'] as List<dynamic>? ?? const <dynamic>[])
          .map(CareerPlayerTag.fromJson)
          .where((entry) => entry.tagName.trim().isNotEmpty)
          .toList(),
    );
  }
}

class CareerTournamentTagGate {
  const CareerTournamentTagGate({
    required this.tagName,
    required this.minimumPlayerCount,
    this.tournamentOccursWhenMet = true,
  });

  final String tagName;
  final int minimumPlayerCount;
  final bool tournamentOccursWhenMet;

  CareerTournamentTagGate copyWith({
    String? tagName,
    int? minimumPlayerCount,
    bool? tournamentOccursWhenMet,
  }) {
    return CareerTournamentTagGate(
      tagName: tagName ?? this.tagName,
      minimumPlayerCount: minimumPlayerCount ?? this.minimumPlayerCount,
      tournamentOccursWhenMet:
          tournamentOccursWhenMet ?? this.tournamentOccursWhenMet,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tagName': tagName,
      'minimumPlayerCount': minimumPlayerCount,
      'tournamentOccursWhenMet': tournamentOccursWhenMet,
    };
  }

  static CareerTournamentTagGate fromJson(Map<String, dynamic> json) {
    return CareerTournamentTagGate(
      tagName: json['tagName'] as String,
      minimumPlayerCount: (json['minimumPlayerCount'] as num).toInt(),
      tournamentOccursWhenMet:
          json['tournamentOccursWhenMet'] as bool? ?? true,
    );
  }
}

enum CareerTournamentTagRuleAction {
  add,
  remove,
}

enum CareerTournamentTagRuleTarget {
  winner,
  runnerUp,
  semiFinalists,
  quarterFinalists,
}

enum CareerLeagueSeriesQualificationMode {
  fixedAtStart,
  recheckEachMatchday,
}

enum CareerLeagueSeriesStage {
  leagueMatchday,
  playoffRound,
}

class CareerTournamentTagRule {
  const CareerTournamentTagRule({
    required this.tagName,
    required this.action,
    required this.target,
  });

  final String tagName;
  final CareerTournamentTagRuleAction action;
  final CareerTournamentTagRuleTarget target;

  CareerTournamentTagRule copyWith({
    String? tagName,
    CareerTournamentTagRuleAction? action,
    CareerTournamentTagRuleTarget? target,
  }) {
    return CareerTournamentTagRule(
      tagName: tagName ?? this.tagName,
      action: action ?? this.action,
      target: target ?? this.target,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tagName': tagName,
      'action': action.name,
      'target': target.name,
    };
  }

  static CareerTournamentTagRule fromJson(Map<String, dynamic> json) {
    return CareerTournamentTagRule(
      tagName: json['tagName'] as String,
      action: CareerTournamentTagRuleAction.values.byName(
        json['action'] as String? ?? CareerTournamentTagRuleAction.add.name,
      ),
      target: CareerTournamentTagRuleTarget.values.byName(
        json['target'] as String? ?? CareerTournamentTagRuleTarget.winner.name,
      ),
    );
  }
}

class CareerLeagueSeriesRoundState {
  const CareerLeagueSeriesRoundState({
    required this.calendarItemId,
    required this.bracket,
  });

  final String calendarItemId;
  final TournamentBracket bracket;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'calendarItemId': calendarItemId,
      'bracket': bracket.toJson(),
    };
  }

  static CareerLeagueSeriesRoundState fromJson(Map<String, dynamic> json) {
    return CareerLeagueSeriesRoundState(
      calendarItemId: json['calendarItemId'] as String,
      bracket: TournamentBracket.fromJson(
        (json['bracket'] as Map).cast<String, dynamic>(),
      ),
    );
  }
}

class CareerLeagueSeriesState {
  const CareerLeagueSeriesState({
    required this.id,
    required this.baseName,
    required this.format,
    required this.qualificationMode,
    this.fixedParticipantIds = const <String>[],
    this.completedRounds = const <CareerLeagueSeriesRoundState>[],
  });

  final String id;
  final String baseName;
  final TournamentFormat format;
  final CareerLeagueSeriesQualificationMode qualificationMode;
  final List<String> fixedParticipantIds;
  final List<CareerLeagueSeriesRoundState> completedRounds;

  CareerLeagueSeriesState copyWith({
    String? id,
    String? baseName,
    TournamentFormat? format,
    CareerLeagueSeriesQualificationMode? qualificationMode,
    List<String>? fixedParticipantIds,
    List<CareerLeagueSeriesRoundState>? completedRounds,
  }) {
    return CareerLeagueSeriesState(
      id: id ?? this.id,
      baseName: baseName ?? this.baseName,
      format: format ?? this.format,
      qualificationMode: qualificationMode ?? this.qualificationMode,
      fixedParticipantIds: fixedParticipantIds ?? this.fixedParticipantIds,
      completedRounds: completedRounds ?? this.completedRounds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'baseName': baseName,
      'format': format.name,
      'qualificationMode': qualificationMode.name,
      'fixedParticipantIds': fixedParticipantIds,
      'completedRounds': completedRounds.map((entry) => entry.toJson()).toList(),
    };
  }

  static CareerLeagueSeriesState fromJson(Map<String, dynamic> json) {
    return CareerLeagueSeriesState(
      id: json['id'] as String,
      baseName: json['baseName'] as String,
      format: TournamentFormat.values.byName(
        json['format'] as String? ?? TournamentFormat.league.name,
      ),
      qualificationMode: CareerLeagueSeriesQualificationMode.values.byName(
        json['qualificationMode'] as String? ??
            CareerLeagueSeriesQualificationMode.fixedAtStart.name,
      ),
      fixedParticipantIds:
          (json['fixedParticipantIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      completedRounds:
          (json['completedRounds'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerLeagueSeriesRoundState.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
    );
  }
}

class CareerCalendarItem {
  const CareerCalendarItem({
    required this.id,
    required this.name,
    this.categoryName = 'Standard',
    this.game = TournamentGame.x01,
    this.format = TournamentFormat.knockout,
    required this.fieldSize,
    this.matchMode = MatchMode.legs,
    required this.legsToWin,
    required this.startScore,
    this.checkoutRequirement = CheckoutRequirement.doubleOut,
    required this.prizePool,
    this.knockoutPrizeValues = const <int>[],
    this.leaguePositionPrizeValues = const <int>[],
    this.setsToWin = 1,
    this.legsPerSet = 1,
    this.roundDistanceValues = const <int>[],
    this.pointsForWin = 2,
    this.pointsForDraw = 1,
    this.roundRobinRepeats = 1,
    this.playoffQualifierCount = 4,
    required this.countsForRankingIds,
    this.seedingRankingId,
    this.seedCount = 0,
    this.qualificationConditions = const <CareerQualificationCondition>[],
    this.slotRules = const <CareerTournamentSlotRule>[],
    this.fillRequiredCareerTags = const <String>[],
    this.fillExcludedCareerTags = const <String>[],
    this.fillRankingId,
    this.fillTopByRankingCount = 0,
    this.fillTopByAverageCount = 0,
    this.fillRules = const <CareerTournamentFillRule>[],
    this.tagGate,
    this.tournamentTagRules = const <CareerTournamentTagRule>[],
    this.seriesGroupId,
    this.seriesIndex,
    this.seriesLength,
    this.seriesStage,
    this.leagueSeriesQualificationMode =
        CareerLeagueSeriesQualificationMode.fixedAtStart,
  });

  final String id;
  final String name;
  final String categoryName;
  final TournamentGame game;
  final TournamentFormat format;
  final int fieldSize;
  final MatchMode matchMode;
  final int legsToWin;
  final int startScore;
  final CheckoutRequirement checkoutRequirement;
  final int prizePool;
  final List<int> knockoutPrizeValues;
  final List<int> leaguePositionPrizeValues;
  final int setsToWin;
  final int legsPerSet;
  final List<int> roundDistanceValues;
  final int pointsForWin;
  final int pointsForDraw;
  final int roundRobinRepeats;
  final int playoffQualifierCount;
  final List<String> countsForRankingIds;
  final String? seedingRankingId;
  final int seedCount;
  final List<CareerQualificationCondition> qualificationConditions;
  final List<CareerTournamentSlotRule> slotRules;
  final List<String> fillRequiredCareerTags;
  final List<String> fillExcludedCareerTags;
  final String? fillRankingId;
  final int fillTopByRankingCount;
  final int fillTopByAverageCount;
  final List<CareerTournamentFillRule> fillRules;
  final CareerTournamentTagGate? tagGate;
  final List<CareerTournamentTagRule> tournamentTagRules;
  final String? seriesGroupId;
  final int? seriesIndex;
  final int? seriesLength;
  final CareerLeagueSeriesStage? seriesStage;
  final CareerLeagueSeriesQualificationMode leagueSeriesQualificationMode;

  bool get isLeagueSeriesItem => seriesGroupId != null && seriesIndex != null;

  List<CareerTournamentSlotRule> get effectiveSlotRules {
    if (slotRules.isNotEmpty) {
      return slotRules;
    }
    return qualificationConditions
        .asMap()
        .entries
        .map(
          (entry) => CareerTournamentSlotRule.fromLegacyCondition(
            entry.value,
            entry.key,
          ),
        )
        .toList();
  }

  List<CareerTournamentFillRule> get effectiveFillRules {
    if (fillRules.isNotEmpty) {
      return fillRules;
    }
    final result = <CareerTournamentFillRule>[];
    if (fillRankingId != null) {
      result.add(
        CareerTournamentFillRule(
          id: 'legacy-fill-ranking',
          sourceType: CareerTournamentFillSourceType.ranking,
          rankingId: fillRankingId,
          requiredCareerTags: fillRequiredCareerTags,
          excludedCareerTags: fillExcludedCareerTags,
          maxCount: fillTopByRankingCount,
        ),
      );
    }
    if (fillTopByAverageCount > 0 ||
        fillRequiredCareerTags.isNotEmpty ||
        fillExcludedCareerTags.isNotEmpty ||
        fillRankingId == null) {
      result.add(
        CareerTournamentFillRule(
          id: 'legacy-fill-average',
          sourceType: CareerTournamentFillSourceType.average,
          requiredCareerTags: fillRequiredCareerTags,
          excludedCareerTags: fillExcludedCareerTags,
          maxCount: fillTopByAverageCount,
        ),
      );
    }
    return result;
  }

  CareerCalendarItem copyWith({
    String? id,
    String? name,
    String? categoryName,
    TournamentGame? game,
    TournamentFormat? format,
    int? fieldSize,
    MatchMode? matchMode,
    int? legsToWin,
    int? startScore,
    CheckoutRequirement? checkoutRequirement,
    int? prizePool,
    List<int>? knockoutPrizeValues,
    List<int>? leaguePositionPrizeValues,
    int? setsToWin,
    int? legsPerSet,
    List<int>? roundDistanceValues,
    int? pointsForWin,
    int? pointsForDraw,
    int? roundRobinRepeats,
    int? playoffQualifierCount,
    List<String>? countsForRankingIds,
    String? seedingRankingId,
    bool clearSeedingRankingId = false,
    int? seedCount,
    List<CareerQualificationCondition>? qualificationConditions,
    List<CareerTournamentSlotRule>? slotRules,
    List<String>? fillRequiredCareerTags,
    List<String>? fillExcludedCareerTags,
    String? fillRankingId,
    bool clearFillRankingId = false,
    int? fillTopByRankingCount,
    int? fillTopByAverageCount,
    List<CareerTournamentFillRule>? fillRules,
    CareerTournamentTagGate? tagGate,
    bool clearTagGate = false,
    List<CareerTournamentTagRule>? tournamentTagRules,
    String? seriesGroupId,
    bool clearSeriesGroupId = false,
    int? seriesIndex,
    bool clearSeriesIndex = false,
    int? seriesLength,
    bool clearSeriesLength = false,
    CareerLeagueSeriesStage? seriesStage,
    bool clearSeriesStage = false,
    CareerLeagueSeriesQualificationMode? leagueSeriesQualificationMode,
  }) {
    return CareerCalendarItem(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryName: categoryName ?? this.categoryName,
      game: game ?? this.game,
      format: format ?? this.format,
      fieldSize: fieldSize ?? this.fieldSize,
      matchMode: matchMode ?? this.matchMode,
      legsToWin: legsToWin ?? this.legsToWin,
      startScore: startScore ?? this.startScore,
      checkoutRequirement: checkoutRequirement ?? this.checkoutRequirement,
      prizePool: prizePool ?? this.prizePool,
      knockoutPrizeValues: knockoutPrizeValues ?? this.knockoutPrizeValues,
      leaguePositionPrizeValues:
          leaguePositionPrizeValues ?? this.leaguePositionPrizeValues,
      setsToWin: setsToWin ?? this.setsToWin,
      legsPerSet: legsPerSet ?? this.legsPerSet,
      roundDistanceValues: roundDistanceValues ?? this.roundDistanceValues,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      roundRobinRepeats: roundRobinRepeats ?? this.roundRobinRepeats,
      playoffQualifierCount: playoffQualifierCount ?? this.playoffQualifierCount,
      countsForRankingIds: countsForRankingIds ?? this.countsForRankingIds,
      seedingRankingId: clearSeedingRankingId
          ? null
          : (seedingRankingId ?? this.seedingRankingId),
      seedCount: seedCount ?? this.seedCount,
      qualificationConditions:
          qualificationConditions ?? this.qualificationConditions,
      slotRules: slotRules ?? this.slotRules,
      fillRequiredCareerTags:
          fillRequiredCareerTags ?? this.fillRequiredCareerTags,
      fillExcludedCareerTags:
          fillExcludedCareerTags ?? this.fillExcludedCareerTags,
      fillRankingId:
          clearFillRankingId ? null : (fillRankingId ?? this.fillRankingId),
      fillTopByRankingCount:
          fillTopByRankingCount ?? this.fillTopByRankingCount,
      fillTopByAverageCount:
          fillTopByAverageCount ?? this.fillTopByAverageCount,
      fillRules: fillRules ?? this.fillRules,
      tagGate: clearTagGate ? null : (tagGate ?? this.tagGate),
      tournamentTagRules: tournamentTagRules ?? this.tournamentTagRules,
      seriesGroupId:
          clearSeriesGroupId ? null : (seriesGroupId ?? this.seriesGroupId),
      seriesIndex: clearSeriesIndex ? null : (seriesIndex ?? this.seriesIndex),
      seriesLength:
          clearSeriesLength ? null : (seriesLength ?? this.seriesLength),
      seriesStage: clearSeriesStage ? null : (seriesStage ?? this.seriesStage),
      leagueSeriesQualificationMode:
          leagueSeriesQualificationMode ?? this.leagueSeriesQualificationMode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'categoryName': categoryName,
      'game': game.name,
      'format': format.name,
      'fieldSize': fieldSize,
      'matchMode': matchMode.name,
      'legsToWin': legsToWin,
      'startScore': startScore,
      'checkoutRequirement': checkoutRequirement.name,
      'prizePool': prizePool,
      'knockoutPrizeValues': knockoutPrizeValues,
      'leaguePositionPrizeValues': leaguePositionPrizeValues,
      'setsToWin': setsToWin,
      'legsPerSet': legsPerSet,
      'roundDistanceValues': roundDistanceValues,
      'pointsForWin': pointsForWin,
      'pointsForDraw': pointsForDraw,
      'roundRobinRepeats': roundRobinRepeats,
      'playoffQualifierCount': playoffQualifierCount,
      'countsForRankingIds': countsForRankingIds,
      'seedingRankingId': seedingRankingId,
      'seedCount': seedCount,
      'qualificationConditions': qualificationConditions
          .map((entry) => entry.toJson())
          .toList(),
      'slotRules': slotRules.map((entry) => entry.toJson()).toList(),
      'fillRequiredCareerTags': fillRequiredCareerTags,
      'fillExcludedCareerTags': fillExcludedCareerTags,
      'fillRankingId': fillRankingId,
      'fillTopByRankingCount': fillTopByRankingCount,
      'fillTopByAverageCount': fillTopByAverageCount,
      'fillRules': fillRules.map((entry) => entry.toJson()).toList(),
      'tagGate': tagGate?.toJson(),
      'tournamentTagRules':
          tournamentTagRules.map((entry) => entry.toJson()).toList(),
      'seriesGroupId': seriesGroupId,
      'seriesIndex': seriesIndex,
      'seriesLength': seriesLength,
      'seriesStage': seriesStage?.name,
      'leagueSeriesQualificationMode': leagueSeriesQualificationMode.name,
    };
  }

  static CareerCalendarItem fromJson(Map<String, dynamic> json) {
    return CareerCalendarItem(
      id: json['id'] as String,
      name: json['name'] as String,
      categoryName: json['categoryName'] as String? ?? 'Standard',
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
      checkoutRequirement: CheckoutRequirement.values.byName(
        json['checkoutRequirement'] as String? ??
            CheckoutRequirement.doubleOut.name,
      ),
      prizePool: (json['prizePool'] as num).toInt(),
      knockoutPrizeValues:
          (json['knockoutPrizeValues'] as List<dynamic>? ?? const <dynamic>[])
              .map((entry) => (entry as num).toInt())
              .toList(),
      leaguePositionPrizeValues:
          (json['leaguePositionPrizeValues'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => (entry as num).toInt())
              .toList(),
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
      countsForRankingIds:
          (json['countsForRankingIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      seedingRankingId: json['seedingRankingId'] as String?,
      seedCount: (json['seedCount'] as num?)?.toInt() ?? 0,
      qualificationConditions:
          (json['qualificationConditions'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerQualificationCondition.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      slotRules: (json['slotRules'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerTournamentSlotRule.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      fillRequiredCareerTags:
          (json['fillRequiredCareerTags'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      fillExcludedCareerTags:
          (json['fillExcludedCareerTags'] as List<dynamic>? ??
                  const <dynamic>[])
              .map((entry) => entry.toString().trim())
              .where((entry) => entry.isNotEmpty)
              .toList(),
      fillRankingId: json['fillRankingId'] as String?,
      fillTopByRankingCount:
          (json['fillTopByRankingCount'] as num?)?.toInt() ?? 0,
      fillTopByAverageCount:
          (json['fillTopByAverageCount'] as num?)?.toInt() ?? 0,
      fillRules: (json['fillRules'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerTournamentFillRule.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      tagGate: json['tagGate'] is Map
          ? CareerTournamentTagGate.fromJson(
              (json['tagGate'] as Map).cast<String, dynamic>(),
            )
          : null,
      tournamentTagRules:
          (json['tournamentTagRules'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerTournamentTagRule.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      seriesGroupId: json['seriesGroupId'] as String?,
      seriesIndex: (json['seriesIndex'] as num?)?.toInt(),
      seriesLength: (json['seriesLength'] as num?)?.toInt(),
      seriesStage: json['seriesStage'] == null
          ? null
          : CareerLeagueSeriesStage.values.byName(
              json['seriesStage'] as String,
            ),
      leagueSeriesQualificationMode:
          CareerLeagueSeriesQualificationMode.values.byName(
        json['leagueSeriesQualificationMode'] as String? ??
            CareerLeagueSeriesQualificationMode.fixedAtStart.name,
      ),
    );
  }
}

class CareerSeason {
  const CareerSeason({
    required this.seasonNumber,
    required this.calendar,
    this.isCompleted = false,
    this.completedItemIds = const <String>[],
  });

  final int seasonNumber;
  final List<CareerCalendarItem> calendar;
  final bool isCompleted;
  final List<String> completedItemIds;

  CareerSeason copyWith({
    int? seasonNumber,
    List<CareerCalendarItem>? calendar,
    bool? isCompleted,
    List<String>? completedItemIds,
  }) {
    return CareerSeason(
      seasonNumber: seasonNumber ?? this.seasonNumber,
      calendar: calendar ?? this.calendar,
      isCompleted: isCompleted ?? this.isCompleted,
      completedItemIds: completedItemIds ?? this.completedItemIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'seasonNumber': seasonNumber,
      'calendar': calendar.map((entry) => entry.toJson()).toList(),
      'isCompleted': isCompleted,
      'completedItemIds': completedItemIds,
    };
  }

  static CareerSeason fromJson(Map<String, dynamic> json) {
    return CareerSeason(
      seasonNumber: (json['seasonNumber'] as num).toInt(),
      calendar: (json['calendar'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerCalendarItem.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedItemIds:
          (json['completedItemIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
    );
  }
}

class CareerCompletedTournament {
  const CareerCompletedTournament({
    required this.seasonNumber,
    required this.calendarItemId,
    required this.calendarIndex,
    required this.name,
    this.categoryName = 'Standard',
    required this.fieldSize,
    required this.winnerId,
    required this.winnerName,
    this.runnerUpId,
    this.runnerUpName,
    this.semiFinalistIds = const <String>[],
    this.quarterFinalistIds = const <String>[],
    required this.prizePool,
    this.playerPayouts = const <String, int>{},
    this.playerResultLabels = const <String, String>{},
    this.playerX01Stats = const <String, CareerX01PlayerStats>{},
    required this.countsForRankingIds,
  });

  final int seasonNumber;
  final String calendarItemId;
  final int calendarIndex;
  final String name;
  final String categoryName;
  final int fieldSize;
  final String winnerId;
  final String winnerName;
  final String? runnerUpId;
  final String? runnerUpName;
  final List<String> semiFinalistIds;
  final List<String> quarterFinalistIds;
  final int prizePool;
  final Map<String, int> playerPayouts;
  final Map<String, String> playerResultLabels;
  final Map<String, CareerX01PlayerStats> playerX01Stats;
  final List<String> countsForRankingIds;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'seasonNumber': seasonNumber,
      'calendarItemId': calendarItemId,
      'calendarIndex': calendarIndex,
      'name': name,
      'categoryName': categoryName,
      'fieldSize': fieldSize,
      'winnerId': winnerId,
      'winnerName': winnerName,
      'runnerUpId': runnerUpId,
      'runnerUpName': runnerUpName,
      'semiFinalistIds': semiFinalistIds,
      'quarterFinalistIds': quarterFinalistIds,
        'prizePool': prizePool,
        'playerPayouts': playerPayouts,
        'playerResultLabels': playerResultLabels,
        'playerX01Stats': playerX01Stats.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
        'countsForRankingIds': countsForRankingIds,
      };
    }

  static CareerCompletedTournament fromJson(Map<String, dynamic> json) {
    return CareerCompletedTournament(
      seasonNumber: (json['seasonNumber'] as num).toInt(),
      calendarItemId: json['calendarItemId'] as String,
      calendarIndex: (json['calendarIndex'] as num?)?.toInt() ?? -1,
      name: json['name'] as String,
      categoryName: json['categoryName'] as String? ?? 'Standard',
      fieldSize: (json['fieldSize'] as num).toInt(),
      winnerId: json['winnerId'] as String,
      winnerName: json['winnerName'] as String,
      runnerUpId: json['runnerUpId'] as String?,
      runnerUpName: json['runnerUpName'] as String?,
      semiFinalistIds:
          (json['semiFinalistIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      quarterFinalistIds:
          (json['quarterFinalistIds'] as List<dynamic>? ?? const <dynamic>[])
              .cast<String>(),
      prizePool: (json['prizePool'] as num).toInt(),
      playerPayouts:
          ((json['playerPayouts'] as Map?)?.cast<String, dynamic>() ??
                  const <String, dynamic>{})
              .map((key, value) => MapEntry(key, (value as num).toInt())),
        playerResultLabels:
            ((json['playerResultLabels'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{})
                .map((key, value) => MapEntry(key, value.toString())),
        playerX01Stats:
            ((json['playerX01Stats'] as Map?)?.cast<String, dynamic>() ??
                    const <String, dynamic>{})
                .map(
                  (key, value) => MapEntry(
                    key,
                    CareerX01PlayerStats.fromJson(
                      (value as Map).cast<String, dynamic>(),
                    ),
                  ),
                ),
        countsForRankingIds:
            (json['countsForRankingIds'] as List<dynamic>? ?? const <dynamic>[])
                .cast<String>(),
      );
    }
  }

class CareerX01PlayerStats {
  const CareerX01PlayerStats({
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
    this.won12Darters = 0,
    this.won15Darters = 0,
    this.won18Darters = 0,
  });

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
  double get score180sPerLeg => legsPlayed <= 0 ? 0 : scores180 / legsPlayed;
  double get won12DarterQuote => legsWon <= 0 ? 0 : (won12Darters / legsWon) * 100;
  double get won15DarterQuote => legsWon <= 0 ? 0 : (won15Darters / legsWon) * 100;
  double get won18DarterQuote => legsWon <= 0 ? 0 : (won18Darters / legsWon) * 100;

  CareerX01PlayerStats copyWith({
    int? pointsScored,
    int? dartsThrown,
    int? visits,
    int? legsWon,
    int? legsPlayed,
    int? legsStarted,
    int? legsWonAsStarter,
    int? legsWonWithoutStarter,
    int? scores0To40,
    int? scores41To59,
    int? scores60Plus,
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
    int? thirdDartCheckoutAttempts,
    int? thirdDartCheckouts,
    int? bullCheckoutAttempts,
    int? bullCheckouts,
    int? functionalDoubleAttempts,
    int? functionalDoubleSuccesses,
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
    return CareerX01PlayerStats(
      pointsScored: pointsScored ?? this.pointsScored,
      dartsThrown: dartsThrown ?? this.dartsThrown,
      visits: visits ?? this.visits,
      legsWon: legsWon ?? this.legsWon,
      legsPlayed: legsPlayed ?? this.legsPlayed,
      legsStarted: legsStarted ?? this.legsStarted,
      legsWonAsStarter: legsWonAsStarter ?? this.legsWonAsStarter,
      legsWonWithoutStarter:
          legsWonWithoutStarter ?? this.legsWonWithoutStarter,
      scores0To40: scores0To40 ?? this.scores0To40,
      scores41To59: scores41To59 ?? this.scores41To59,
      scores60Plus: scores60Plus ?? this.scores60Plus,
      scores100Plus: scores100Plus ?? this.scores100Plus,
      scores140Plus: scores140Plus ?? this.scores140Plus,
      scores171Plus: scores171Plus ?? this.scores171Plus,
      scores180: scores180 ?? this.scores180,
      checkoutAttempts: checkoutAttempts ?? this.checkoutAttempts,
      successfulCheckouts: successfulCheckouts ?? this.successfulCheckouts,
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
      thirdDartCheckoutAttempts:
          thirdDartCheckoutAttempts ?? this.thirdDartCheckoutAttempts,
      thirdDartCheckouts: thirdDartCheckouts ?? this.thirdDartCheckouts,
      bullCheckoutAttempts: bullCheckoutAttempts ?? this.bullCheckoutAttempts,
      bullCheckouts: bullCheckouts ?? this.bullCheckouts,
      functionalDoubleAttempts:
          functionalDoubleAttempts ?? this.functionalDoubleAttempts,
      functionalDoubleSuccesses:
          functionalDoubleSuccesses ?? this.functionalDoubleSuccesses,
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

  CareerX01PlayerStats add(CareerX01PlayerStats other) {
    return CareerX01PlayerStats(
      pointsScored: pointsScored + other.pointsScored,
      dartsThrown: dartsThrown + other.dartsThrown,
      visits: visits + other.visits,
      legsWon: legsWon + other.legsWon,
      legsPlayed: legsPlayed + other.legsPlayed,
      legsStarted: legsStarted + other.legsStarted,
      legsWonAsStarter: legsWonAsStarter + other.legsWonAsStarter,
      legsWonWithoutStarter:
          legsWonWithoutStarter + other.legsWonWithoutStarter,
      scores0To40: scores0To40 + other.scores0To40,
      scores41To59: scores41To59 + other.scores41To59,
      scores60Plus: scores60Plus + other.scores60Plus,
      scores100Plus: scores100Plus + other.scores100Plus,
      scores140Plus: scores140Plus + other.scores140Plus,
      scores171Plus: scores171Plus + other.scores171Plus,
      scores180: scores180 + other.scores180,
      checkoutAttempts: checkoutAttempts + other.checkoutAttempts,
      successfulCheckouts: successfulCheckouts + other.successfulCheckouts,
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
      thirdDartCheckoutAttempts:
          thirdDartCheckoutAttempts + other.thirdDartCheckoutAttempts,
      thirdDartCheckouts: thirdDartCheckouts + other.thirdDartCheckouts,
      bullCheckoutAttempts: bullCheckoutAttempts + other.bullCheckoutAttempts,
      bullCheckouts: bullCheckouts + other.bullCheckouts,
      functionalDoubleAttempts:
          functionalDoubleAttempts + other.functionalDoubleAttempts,
      functionalDoubleSuccesses:
          functionalDoubleSuccesses + other.functionalDoubleSuccesses,
      firstNinePoints: firstNinePoints + other.firstNinePoints,
      firstNineDarts: firstNineDarts + other.firstNineDarts,
      highestFinish: highestFinish > other.highestFinish
          ? highestFinish
          : other.highestFinish,
      bestLegDarts: _mergeBestLegDarts(bestLegDarts, other.bestLegDarts),
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

  static CareerX01PlayerStats fromJson(Map<String, dynamic> json) {
    return CareerX01PlayerStats(
      pointsScored: (json['pointsScored'] as num?)?.toInt() ?? 0,
      dartsThrown: (json['dartsThrown'] as num?)?.toInt() ?? 0,
      visits: (json['visits'] as num?)?.toInt() ?? 0,
      legsWon: (json['legsWon'] as num?)?.toInt() ?? 0,
      legsPlayed: (json['legsPlayed'] as num?)?.toInt() ?? 0,
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
      decidingLegsPlayed:
          (json['decidingLegsPlayed'] as num?)?.toInt() ?? 0,
      decidingLegsWon: (json['decidingLegsWon'] as num?)?.toInt() ?? 0,
      won12Darters: (json['won12Darters'] as num?)?.toInt() ?? 0,
      won15Darters: (json['won15Darters'] as num?)?.toInt() ?? 0,
      won18Darters: (json['won18Darters'] as num?)?.toInt() ?? 0,
    );
  }

  static int _mergeBestLegDarts(int left, int right) {
    if (left <= 0) {
      return right;
    }
    if (right <= 0) {
      return left;
    }
    return left < right ? left : right;
  }
}

class CareerDefinition {
  const CareerDefinition({
    required this.id,
    required this.name,
    required this.participantMode,
    this.playerProfileId,
    this.replaceWeakestPlayerWithHuman = false,
    this.databasePlayers = const <CareerDatabasePlayer>[],
    this.careerTagDefinitions = const <CareerTagDefinition>[],
    this.seasonTagRules = const <CareerSeasonTagRule>[],
    required this.rankings,
    required this.currentSeason,
    this.completedSeasons = const <CareerSeason>[],
    this.completedTournaments = const <CareerCompletedTournament>[],
    this.leagueSeriesStates = const <CareerLeagueSeriesState>[],
    this.isStarted = false,
  });

  final String id;
  final String name;
  final CareerParticipantMode participantMode;
  final String? playerProfileId;
  final bool replaceWeakestPlayerWithHuman;
  final List<CareerDatabasePlayer> databasePlayers;
  final List<CareerTagDefinition> careerTagDefinitions;
  final List<CareerSeasonTagRule> seasonTagRules;
  final List<CareerRankingDefinition> rankings;
  final CareerSeason currentSeason;
  final List<CareerSeason> completedSeasons;
  final List<CareerCompletedTournament> completedTournaments;
  final List<CareerLeagueSeriesState> leagueSeriesStates;
  final bool isStarted;

  CareerDefinition copyWith({
    String? id,
    String? name,
    CareerParticipantMode? participantMode,
    String? playerProfileId,
    bool clearPlayerProfileId = false,
    bool? replaceWeakestPlayerWithHuman,
    List<CareerDatabasePlayer>? databasePlayers,
    List<CareerTagDefinition>? careerTagDefinitions,
    List<CareerSeasonTagRule>? seasonTagRules,
    List<CareerRankingDefinition>? rankings,
    CareerSeason? currentSeason,
    List<CareerSeason>? completedSeasons,
    List<CareerCompletedTournament>? completedTournaments,
    List<CareerLeagueSeriesState>? leagueSeriesStates,
    bool? isStarted,
  }) {
    return CareerDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      participantMode: participantMode ?? this.participantMode,
      playerProfileId:
          clearPlayerProfileId ? null : (playerProfileId ?? this.playerProfileId),
      replaceWeakestPlayerWithHuman:
          replaceWeakestPlayerWithHuman ?? this.replaceWeakestPlayerWithHuman,
      databasePlayers: databasePlayers ?? this.databasePlayers,
      careerTagDefinitions: careerTagDefinitions ?? this.careerTagDefinitions,
      seasonTagRules: seasonTagRules ?? this.seasonTagRules,
      rankings: rankings ?? this.rankings,
      currentSeason: currentSeason ?? this.currentSeason,
      completedSeasons: completedSeasons ?? this.completedSeasons,
      completedTournaments: completedTournaments ?? this.completedTournaments,
      leagueSeriesStates: leagueSeriesStates ?? this.leagueSeriesStates,
      isStarted: isStarted ?? this.isStarted,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'participantMode': participantMode.name,
      'playerProfileId': playerProfileId,
      'replaceWeakestPlayerWithHuman': replaceWeakestPlayerWithHuman,
      'databasePlayers': databasePlayers.map((entry) => entry.toJson()).toList(),
      'careerTagDefinitions':
          careerTagDefinitions.map((entry) => entry.toJson()).toList(),
      'seasonTagRules': seasonTagRules.map((entry) => entry.toJson()).toList(),
      'rankings': rankings.map((entry) => entry.toJson()).toList(),
      'currentSeason': currentSeason.toJson(),
      'completedSeasons': completedSeasons.map((entry) => entry.toJson()).toList(),
      'completedTournaments':
          completedTournaments.map((entry) => entry.toJson()).toList(),
      'leagueSeriesStates':
          leagueSeriesStates.map((entry) => entry.toJson()).toList(),
      'isStarted': isStarted,
    };
  }

  static CareerDefinition fromJson(Map<String, dynamic> json) {
    return CareerDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      participantMode: CareerParticipantMode.values.byName(
        json['participantMode'] as String,
      ),
      playerProfileId: json['playerProfileId'] as String?,
      replaceWeakestPlayerWithHuman:
          json['replaceWeakestPlayerWithHuman'] as bool? ?? false,
      databasePlayers:
          (json['databasePlayers'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerDatabasePlayer.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      careerTagDefinitions:
          (json['careerTagDefinitions'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerTagDefinition.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      seasonTagRules:
          (json['seasonTagRules'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerSeasonTagRule.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      rankings: (json['rankings'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => CareerRankingDefinition.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      currentSeason: CareerSeason.fromJson(
        (json['currentSeason'] as Map).cast<String, dynamic>(),
      ),
      completedSeasons:
          (json['completedSeasons'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerSeason.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      completedTournaments:
          (json['completedTournaments'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerCompletedTournament.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      leagueSeriesStates:
          (json['leagueSeriesStates'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (entry) => CareerLeagueSeriesState.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              )
              .toList(),
      isStarted: json['isStarted'] as bool? ?? false,
    );
  }
}

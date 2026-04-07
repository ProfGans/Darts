import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/career/career_engine.dart';
import '../../domain/career/career_models.dart';
import '../../domain/career/career_statistics.dart';
import '../../domain/career/career_template.dart';
import '../../domain/rankings/ranking_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import '../models/player_profile.dart';
import '../storage/app_storage.dart';
import 'computer_repository.dart';
import 'player_repository.dart';

class CareerRepository extends ChangeNotifier {
  CareerRepository._();

  static final CareerRepository instance = CareerRepository._();

  static const _storageKey = 'careers';

  final CareerEngine _engine = const CareerEngine();
  final CareerStatisticsEngine _statisticsEngine =
      const CareerStatisticsEngine();
  final RankingEngine _rankingEngine = const RankingEngine();
  final List<CareerDefinition> _careers = <CareerDefinition>[];
  String? _activeCareerId;
  Map<String, String>? _cachedParticipantMap;
  CareerStatisticsSummary? _cachedStatisticsSummary;
  final Map<String, List<RankingStanding>> _cachedStandingsByRankingId =
      <String, List<RankingStanding>>{};
  final Map<String, CareerPlayerHistorySummary?> _cachedPlayerHistory =
      <String, CareerPlayerHistorySummary?>{};

  List<CareerDefinition> get careers => List<CareerDefinition>.unmodifiable(_careers);

  CareerDefinition? get activeCareer {
    if (_activeCareerId == null) {
      return null;
    }
    for (final career in _careers) {
      if (career.id == _activeCareerId) {
        return career;
      }
    }
    return null;
  }

  CareerCalendarItem? nextOpenCalendarItem() {
    final career = activeCareer;
    if (career == null) {
      return null;
    }
    for (final item in career.currentSeason.calendar) {
      if (!career.currentSeason.completedItemIds.contains(item.id) &&
          shouldTournamentTakePlace(item, career: career)) {
        return item;
      }
    }
    return null;
  }

  int remainingTournamentsInCurrentSeason() {
    final career = activeCareer;
    if (career == null) {
      return 0;
    }
    var remaining = 0;
    for (final item in career.currentSeason.calendar) {
      if (career.currentSeason.completedItemIds.contains(item.id)) {
        continue;
      }
      if (!shouldTournamentTakePlace(item, career: career)) {
        continue;
      }
      remaining += 1;
    }
    return remaining;
  }

  bool canFinishCurrentSeason() {
    final career = activeCareer;
    if (career == null || career.currentSeason.calendar.isEmpty) {
      return false;
    }
    for (final item in career.currentSeason.calendar) {
      if (career.currentSeason.completedItemIds.contains(item.id)) {
        continue;
      }
      if (!shouldTournamentTakePlace(item, career: career)) {
        continue;
      }
      return false;
    }
    return true;
  }

  bool shouldTournamentTakePlace(
    CareerCalendarItem item, {
    CareerDefinition? career,
  }) {
    final effectiveCareer = career ?? activeCareer;
    if (effectiveCareer == null) {
      return true;
    }
    final tagGate = item.tagGate;
    if (tagGate == null) {
      return true;
    }
    var matchingPlayers = 0;
    for (final player in effectiveCareer.databasePlayers) {
      if (player.careerTags.any((entry) => entry.tagName == tagGate.tagName)) {
        matchingPlayers += 1;
      }
    }
    final isMet = matchingPlayers >= tagGate.minimumPlayerCount;
    return tagGate.tournamentOccursWhenMet ? isMet : !isMet;
  }

  Future<void> initialize() async {
    Map<String, dynamic>? json;
    try {
      json = await AppStorage.instance.readJsonMap(_storageKey);
    } on FormatException {
      await AppStorage.instance.delete(_storageKey);
      _careers.clear();
      _activeCareerId = null;
      _invalidateDerivedDataCaches();
      notifyListeners();
      return;
    }
    if (json == null) {
      return;
    }
    final loadedCareers =
        (json['careers'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => CareerDefinition.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ),
            )
            .map(_normalizeLoadedCareer)
            .toList();
    _careers
      ..clear()
      ..addAll(loadedCareers);
    _activeCareerId = json['activeCareerId'] as String?;
    _invalidateDerivedDataCaches();
    await _persist();
    notifyListeners();
  }

  void createCareer({
    required String name,
    required CareerParticipantMode participantMode,
    String? playerProfileId,
    bool replaceWeakestPlayerWithHuman = false,
  }) {
    final career = _engine.initializeCareer(
      name: name.trim().isEmpty ? 'Neue Karriere' : name.trim(),
      participantMode: participantMode,
      playerProfileId: playerProfileId,
      replaceWeakestPlayerWithHuman: replaceWeakestPlayerWithHuman,
    );
    _careers.add(career);
    _activeCareerId = career.id;
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  void createCareerFromTemplate({
    required String name,
    required CareerTemplate template,
    required List<CareerDatabasePlayer> databasePlayers,
    required CareerParticipantMode participantMode,
    String? playerProfileId,
    bool replaceWeakestPlayerWithHuman = false,
  }) {
    final trimmed = name.trim();
    final preparedDatabasePlayers = _templateDatabasePlayersWithHuman(
      databasePlayers: databasePlayers,
      careerTagDefinitions: template.careerTagDefinitions,
      participantMode: participantMode,
      playerProfileId: playerProfileId,
      replaceWeakestPlayerWithHuman: replaceWeakestPlayerWithHuman,
    );
    final career = CareerDefinition(
      id: 'career-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed.isEmpty ? template.name : trimmed,
      participantMode: participantMode,
      playerProfileId: playerProfileId,
      replaceWeakestPlayerWithHuman: replaceWeakestPlayerWithHuman,
      databasePlayers: preparedDatabasePlayers,
      careerTagDefinitions:
          List<CareerTagDefinition>.from(template.careerTagDefinitions),
      seasonTagRules: List<CareerSeasonTagRule>.from(template.seasonTagRules),
      rankings: List<CareerRankingDefinition>.from(template.rankings),
      currentSeason: CareerSeason(
        seasonNumber: 1,
        calendar: List<CareerCalendarItem>.from(template.calendar),
      ),
      isStarted: false,
    );
    _careers.add(_normalizeLoadedCareer(career));
    _activeCareerId = career.id;
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  List<CareerDatabasePlayer> _templateDatabasePlayersWithHuman({
    required List<CareerDatabasePlayer> databasePlayers,
    required List<CareerTagDefinition> careerTagDefinitions,
    required CareerParticipantMode participantMode,
    required String? playerProfileId,
    required bool replaceWeakestPlayerWithHuman,
  }) {
    final normalizedPlayers = databasePlayers
        .map(_normalizeCareerDatabasePlayer)
        .toList();
    if (participantMode != CareerParticipantMode.withHuman) {
      return normalizedPlayers;
    }

    final PlayerProfile? human = playerProfileId == null
        ? PlayerRepository.instance.activePlayer
        : PlayerRepository.instance.playerById(playerProfileId);
    if (human == null) {
      return normalizedPlayers;
    }

    CareerDatabasePlayer? weakestPlayer;
    for (final player in normalizedPlayers) {
      if (weakestPlayer == null || player.average < weakestPlayer.average) {
        weakestPlayer = player;
      }
    }

    final inheritedTags = replaceWeakestPlayerWithHuman
        ? (weakestPlayer?.careerTags ?? const <CareerPlayerTag>[])
        : (careerTagDefinitions.any((definition) => definition.name == 'Non-Tour')
            ? const <CareerPlayerTag>[CareerPlayerTag(tagName: 'Non-Tour')]
            : const <CareerPlayerTag>[]);
    final nationalityTags = _careerTagsForNationality(
      human.nationality,
      careerTagDefinitions,
    );

    if (replaceWeakestPlayerWithHuman && weakestPlayer != null) {
      normalizedPlayers.removeWhere(
        (player) => player.databasePlayerId == weakestPlayer!.databasePlayerId,
      );
    }

    final resolution = ComputerRepository.instance
        .resolveSkillsForTheoreticalAverageQuick(human.average);
    normalizedPlayers.removeWhere(
      (player) => player.databasePlayerId == human.id,
    );
    normalizedPlayers.add(
      CareerDatabasePlayer(
          databasePlayerId: human.id,
          name: human.name,
          average: human.average,
          skill: resolution.skill,
          finishingSkill: resolution.finishingSkill,
          nationality: human.nationality,
          careerTags: <CareerPlayerTag>[
            ...List<CareerPlayerTag>.from(inheritedTags),
          ...nationalityTags
              .where(
                (tag) => !inheritedTags.any(
                  (existing) => existing.tagName == tag.tagName,
                ),
              )
        ],
      ),
    );
    return normalizedPlayers;
  }

  List<CareerPlayerTag> _careerTagsForNationality(
    String? nationality,
    List<CareerTagDefinition> definitions,
  ) {
    final normalized = nationality?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const <CareerPlayerTag>[];
    }

    final tags = <String>{
      ..._hostNationTagsForNationality(normalized, definitions),
      if (_matchesNationality(normalized, const <String>{
        'Denmark',
        'Estonia',
        'Finland',
        'Iceland',
        'Latvia',
        'Lithuania',
        'Norway',
        'Sweden',
      }))
        'Nordic/Baltic',
      if (_matchesNationality(normalized, const <String>{
        'Bulgaria',
        'Croatia',
        'Czech Republic',
        'Hungary',
        'Poland',
        'Romania',
        'Serbia',
        'Slovakia',
        'Slovenia',
      }))
        'East Europe',
      if (_matchesNationality(normalized, const <String>{
        'Bahrain',
        'China',
        'Chinese Taipei',
        'Hong Kong',
        'India',
        'Indonesia',
        'Japan',
        'Malaysia',
        'Mongolia',
        'Philippines',
        'Singapore',
        'South Korea',
        'Thailand',
        'United Arab Emirates',
        'Vietnam',
      }))
        'Asia',
      if (_matchesNationality(normalized, const <String>{
        'Canada',
        'Mexico',
        'United States',
        'USA',
      }))
        'North America',
      if (_matchesNationality(normalized, const <String>{
        'Australia',
        'New Zealand',
      }))
        'Oceania',
      if (_matchesNationality(normalized, const <String>{'China'})) 'China',
    };

    return tags
        .where(
          (tag) => definitions.any(
            (definition) => definition.name.toLowerCase() == tag.toLowerCase(),
          ),
        )
        .map((tag) => CareerPlayerTag(tagName: tag))
        .toList();
  }

  List<String> _hostNationTagsForNationality(
    String nationality,
    List<CareerTagDefinition> definitions,
  ) {
    final hostNationTags = <String>[];
    for (final definition in definitions) {
      if (!definition.name.startsWith('Host Nation ')) {
        continue;
      }
      final country = definition.name.substring('Host Nation '.length);
      if (_matchesNationality(nationality, <String>{country})) {
        hostNationTags.add(definition.name);
      }
    }
    return hostNationTags;
  }

  bool _matchesNationality(String nationality, Set<String> values) {
    return values.any(
      (value) => value.toLowerCase() == nationality.toLowerCase(),
    );
  }

  Future<void> importCareers(
    List<CareerDefinition> importedCareers, {
    bool replaceExisting = false,
  }) async {
    if (importedCareers.isEmpty) {
      return;
    }

    final nextCareers = replaceExisting
        ? <CareerDefinition>[]
        : List<CareerDefinition>.from(_careers);

    for (final imported in importedCareers) {
      final index = nextCareers.indexWhere((entry) => entry.id == imported.id);
      if (index >= 0) {
        nextCareers[index] = imported;
        continue;
      }

      final nameIndex = nextCareers.indexWhere(
        (entry) => entry.name.toLowerCase() == imported.name.toLowerCase(),
      );
      if (nameIndex >= 0) {
        nextCareers[nameIndex] = imported;
        continue;
      }
      nextCareers.add(imported);
    }

    _careers
      ..clear()
      ..addAll(nextCareers);
    _activeCareerId ??= _careers.first.id;
    _invalidateDerivedDataCaches();
    notifyListeners();
    await _persist();
  }

  void setActiveCareer(String careerId) {
    _activeCareerId = careerId;
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  void clearActiveCareer() {
    _activeCareerId = null;
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  void updateCareerBasics({
    required String name,
    required CareerParticipantMode participantMode,
    String? playerProfileId,
    bool replaceWeakestPlayerWithHuman = false,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      career.copyWith(
        name: name.trim().isEmpty ? career.name : name.trim(),
        participantMode: participantMode,
        playerProfileId: participantMode == CareerParticipantMode.withHuman
            ? playerProfileId
            : null,
        clearPlayerProfileId: participantMode != CareerParticipantMode.withHuman,
        replaceWeakestPlayerWithHuman:
            participantMode == CareerParticipantMode.withHuman &&
                replaceWeakestPlayerWithHuman,
      ),
    );
  }

  void deleteCareer(String careerId) {
    _careers.removeWhere((career) => career.id == careerId);
    if (_activeCareerId == careerId) {
      _activeCareerId = _careers.isEmpty ? null : _careers.first.id;
    }
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  void addRanking({
    required String name,
    required int validSeasons,
    bool resetAtSeasonEnd = false,
  }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }
    _replaceCareer(
      _engine.addRanking(
        career: career,
        name: name.trim(),
        validSeasons: validSeasons,
        resetAtSeasonEnd: resetAtSeasonEnd,
      ),
    );
  }

  void updateRanking({
    required String rankingId,
    required String name,
    required int validSeasons,
    bool resetAtSeasonEnd = false,
  }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }
    _replaceCareer(
      _engine.updateRanking(
        career: career,
        rankingId: rankingId,
        name: name.trim(),
        validSeasons: validSeasons,
        resetAtSeasonEnd: resetAtSeasonEnd,
      ),
    );
  }

  void removeRanking(String rankingId) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.removeRanking(
        career: career,
        rankingId: rankingId,
      ),
    );
  }

  void addDatabasePlayer({
    required CareerDatabasePlayer player,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.addDatabasePlayer(
        career: career,
        player: _applyCareerTagDefinitions(
          career: career,
          player: _normalizeCareerDatabasePlayer(player),
        ),
      ),
    );
  }

  void updateDatabasePlayer({
    required CareerDatabasePlayer player,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.updateDatabasePlayer(
        career: career,
        player: _applyCareerTagDefinitions(
          career: career,
          player: _normalizeCareerDatabasePlayer(player),
        ),
      ),
    );
  }

  void updateDatabasePlayers({
    required List<CareerDatabasePlayer> players,
  }) {
    final career = activeCareer;
    if (career == null || players.isEmpty) {
      return;
    }
    final updatesById = <String, CareerDatabasePlayer>{};
    for (final player in players) {
      final normalized = _applyCareerTagDefinitions(
        career: career,
        player: _normalizeCareerDatabasePlayer(player),
      );
      updatesById[normalized.databasePlayerId] = normalized;
    }
    if (updatesById.isEmpty) {
      return;
    }
    _replaceCareer(
      career.copyWith(
        databasePlayers: career.databasePlayers
            .map(
              (entry) =>
                  updatesById[entry.databasePlayerId] ?? entry,
            )
            .toList(),
      ),
    );
  }

  void removeDatabasePlayer(String databasePlayerId) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.removeDatabasePlayer(
        career: career,
        databasePlayerId: databasePlayerId,
      ),
    );
  }

  void addCareerTagDefinition({
    required String name,
    List<CareerTagAttribute> attributes = const <CareerTagAttribute>[],
    int? playerLimit,
    int? initialValiditySeasons,
    int? extensionValiditySeasons,
    List<String> tagsToAddOnExpiry = const <String>[],
    List<String> tagsToRemoveOnInitialAssignment = const <String>[],
    List<String> tagsToRemoveOnExtension = const <String>[],
    int? fillUpToPlayerCount,
    String? fillUpByRankingId,
    List<String> fillUpRequiredCareerTags = const <String>[],
    List<String> fillUpExcludedCareerTags = const <String>[],
  }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }
    _replaceCareer(
      _engine.addCareerTagDefinition(
        career: career,
        tagDefinition: CareerTagDefinition(
          id: 'career-tag-${DateTime.now().microsecondsSinceEpoch}',
          name: name.trim(),
          attributes: attributes,
          playerLimit: playerLimit,
          initialValiditySeasons: initialValiditySeasons,
          extensionValiditySeasons: extensionValiditySeasons,
          tagsToAddOnExpiry: tagsToAddOnExpiry,
          tagsToRemoveOnInitialAssignment: tagsToRemoveOnInitialAssignment,
          tagsToRemoveOnExtension: tagsToRemoveOnExtension,
          fillUpToPlayerCount: fillUpToPlayerCount,
          fillUpByRankingId: fillUpByRankingId,
          fillUpRequiredCareerTags: fillUpRequiredCareerTags,
          fillUpExcludedCareerTags: fillUpExcludedCareerTags,
        ),
      ),
    );
  }

  void updateCareerTagDefinition({
    required String tagDefinitionId,
    required String name,
    List<CareerTagAttribute> attributes = const <CareerTagAttribute>[],
    int? playerLimit,
    int? initialValiditySeasons,
    int? extensionValiditySeasons,
    List<String> tagsToAddOnExpiry = const <String>[],
    List<String> tagsToRemoveOnInitialAssignment = const <String>[],
    List<String> tagsToRemoveOnExtension = const <String>[],
    int? fillUpToPlayerCount,
    String? fillUpByRankingId,
    List<String> fillUpRequiredCareerTags = const <String>[],
    List<String> fillUpExcludedCareerTags = const <String>[],
  }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }
    final updatedCareer = _engine.updateCareerTagDefinition(
      career: career,
      tagDefinition: CareerTagDefinition(
        id: tagDefinitionId,
        name: name.trim(),
        attributes: attributes,
        playerLimit: playerLimit,
        initialValiditySeasons: initialValiditySeasons,
        extensionValiditySeasons: extensionValiditySeasons,
        tagsToAddOnExpiry: tagsToAddOnExpiry,
        tagsToRemoveOnInitialAssignment: tagsToRemoveOnInitialAssignment,
        tagsToRemoveOnExtension: tagsToRemoveOnExtension,
        fillUpToPlayerCount: fillUpToPlayerCount,
        fillUpByRankingId: fillUpByRankingId,
        fillUpRequiredCareerTags: fillUpRequiredCareerTags,
        fillUpExcludedCareerTags: fillUpExcludedCareerTags,
      ),
    );
    _replaceCareer(_reapplyCareerTagDefinitions(updatedCareer));
  }

  void removeCareerTagDefinition(String tagDefinitionId) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.removeCareerTagDefinition(
        career: career,
        tagDefinitionId: tagDefinitionId,
      ),
    );
  }

  void addSeasonTagRule({
    required String tagName,
    required String rankingId,
    required int fromRank,
    required int toRank,
    required CareerSeasonTagRuleAction action,
    CareerSeasonTagRuleRankMode rankMode = CareerSeasonTagRuleRankMode.range,
    int? referenceRank,
    CareerSeasonTagRuleCheckMode checkMode =
        CareerSeasonTagRuleCheckMode.none,
    String? checkTagName,
    int? checkRemainingSeasons,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.addSeasonTagRule(
        career: career,
        rule: CareerSeasonTagRule(
          id: 'season-tag-rule-${DateTime.now().microsecondsSinceEpoch}',
          tagName: tagName,
          rankingId: rankingId,
          fromRank: fromRank,
          toRank: toRank,
          action: action,
          rankMode: rankMode,
          referenceRank: referenceRank,
          checkMode: checkMode,
          checkTagName: checkTagName,
          checkRemainingSeasons: checkRemainingSeasons,
        ),
      ),
    );
  }

  void updateSeasonTagRule({
    required String ruleId,
    required String tagName,
    required String rankingId,
    required int fromRank,
    required int toRank,
    required CareerSeasonTagRuleAction action,
    CareerSeasonTagRuleRankMode rankMode = CareerSeasonTagRuleRankMode.range,
    int? referenceRank,
    CareerSeasonTagRuleCheckMode checkMode =
        CareerSeasonTagRuleCheckMode.none,
    String? checkTagName,
    int? checkRemainingSeasons,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.updateSeasonTagRule(
        career: career,
        rule: CareerSeasonTagRule(
          id: ruleId,
          tagName: tagName,
          rankingId: rankingId,
          fromRank: fromRank,
          toRank: toRank,
          action: action,
          rankMode: rankMode,
          referenceRank: referenceRank,
          checkMode: checkMode,
          checkTagName: checkTagName,
          checkRemainingSeasons: checkRemainingSeasons,
        ),
      ),
    );
  }

  void removeSeasonTagRule(String ruleId) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.removeSeasonTagRule(
        career: career,
        ruleId: ruleId,
      ),
    );
  }

  void addCalendarItem({
      String? itemId,
      required String name,
      int tier = 1,
      TournamentGame game = TournamentGame.x01,
    TournamentFormat format = TournamentFormat.knockout,
    required int fieldSize,
    MatchMode matchMode = MatchMode.legs,
    required int legsToWin,
    required int startScore,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    required int prizePool,
    List<int> knockoutPrizeValues = const <int>[],
    List<int> leaguePositionPrizeValues = const <int>[],
    int setsToWin = 1,
    int legsPerSet = 1,
    List<int> roundDistanceValues = const <int>[],
    int pointsForWin = 2,
    int pointsForDraw = 1,
    int roundRobinRepeats = 1,
    int playoffQualifierCount = 4,
    required List<String> countsForRankingIds,
    String? seedingRankingId,
    int seedCount = 0,
    List<CareerQualificationCondition> qualificationConditions =
        const <CareerQualificationCondition>[],
    List<CareerTournamentSlotRule> slotRules =
        const <CareerTournamentSlotRule>[],
    List<String> fillRequiredCareerTags = const <String>[],
    List<String> fillExcludedCareerTags = const <String>[],
    String? fillRankingId,
    int fillTopByRankingCount = 0,
    int fillTopByAverageCount = 0,
      List<CareerTournamentFillRule> fillRules =
          const <CareerTournamentFillRule>[],
      CareerTournamentTagGate? tagGate,
      String? seriesGroupId,
      int? seriesIndex,
      int? seriesLength,
      CareerLeagueSeriesStage? seriesStage,
      CareerLeagueSeriesQualificationMode leagueSeriesQualificationMode =
          CareerLeagueSeriesQualificationMode.fixedAtStart,
    }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }

    final item = CareerCalendarItem(
        id: itemId ?? 'calendar-${DateTime.now().microsecondsSinceEpoch}',
        name: name.trim(),
        tier: tier,
        game: game,
      format: format,
      fieldSize: fieldSize,
      matchMode: matchMode,
      legsToWin: legsToWin,
      startScore: startScore,
      checkoutRequirement: checkoutRequirement,
      prizePool: prizePool,
      knockoutPrizeValues: knockoutPrizeValues,
      leaguePositionPrizeValues: leaguePositionPrizeValues,
      setsToWin: setsToWin,
      legsPerSet: legsPerSet,
      roundDistanceValues: roundDistanceValues,
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      roundRobinRepeats: roundRobinRepeats,
      playoffQualifierCount: playoffQualifierCount,
      countsForRankingIds: countsForRankingIds,
      seedingRankingId: seedingRankingId,
      seedCount: seedCount,
      qualificationConditions: qualificationConditions,
      slotRules: slotRules,
      fillRequiredCareerTags: fillRequiredCareerTags,
      fillExcludedCareerTags: fillExcludedCareerTags,
      fillRankingId: fillRankingId,
      fillTopByRankingCount: fillTopByRankingCount,
        fillTopByAverageCount: fillTopByAverageCount,
        fillRules: fillRules,
        tagGate: tagGate,
        seriesGroupId: seriesGroupId,
        seriesIndex: seriesIndex,
        seriesLength: seriesLength,
        seriesStage: seriesStage,
        leagueSeriesQualificationMode: leagueSeriesQualificationMode,
      );

    _replaceCareer(
      _engine.addCalendarItem(
        career: career,
        item: item,
      ),
    );
  }

  void updateCalendarItem({
      required String itemId,
      required String name,
      int tier = 1,
      TournamentGame game = TournamentGame.x01,
    TournamentFormat format = TournamentFormat.knockout,
    required int fieldSize,
    MatchMode matchMode = MatchMode.legs,
    required int legsToWin,
    required int startScore,
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    required int prizePool,
    List<int> knockoutPrizeValues = const <int>[],
    List<int> leaguePositionPrizeValues = const <int>[],
    int setsToWin = 1,
    int legsPerSet = 1,
    List<int> roundDistanceValues = const <int>[],
    int pointsForWin = 2,
    int pointsForDraw = 1,
    int roundRobinRepeats = 1,
    int playoffQualifierCount = 4,
    required List<String> countsForRankingIds,
    String? seedingRankingId,
    int seedCount = 0,
    List<CareerQualificationCondition> qualificationConditions =
        const <CareerQualificationCondition>[],
    List<CareerTournamentSlotRule> slotRules =
        const <CareerTournamentSlotRule>[],
    List<String> fillRequiredCareerTags = const <String>[],
    List<String> fillExcludedCareerTags = const <String>[],
    String? fillRankingId,
    int fillTopByRankingCount = 0,
    int fillTopByAverageCount = 0,
      List<CareerTournamentFillRule> fillRules =
          const <CareerTournamentFillRule>[],
      CareerTournamentTagGate? tagGate,
      String? seriesGroupId,
      int? seriesIndex,
      int? seriesLength,
      CareerLeagueSeriesStage? seriesStage,
      CareerLeagueSeriesQualificationMode leagueSeriesQualificationMode =
          CareerLeagueSeriesQualificationMode.fixedAtStart,
    }) {
    final career = activeCareer;
    if (career == null || name.trim().isEmpty) {
      return;
    }

    final item = CareerCalendarItem(
        id: itemId,
        name: name.trim(),
        tier: tier,
        game: game,
      format: format,
      fieldSize: fieldSize,
      matchMode: matchMode,
      legsToWin: legsToWin,
      startScore: startScore,
      checkoutRequirement: checkoutRequirement,
      prizePool: prizePool,
      knockoutPrizeValues: knockoutPrizeValues,
      leaguePositionPrizeValues: leaguePositionPrizeValues,
      setsToWin: setsToWin,
      legsPerSet: legsPerSet,
      roundDistanceValues: roundDistanceValues,
      pointsForWin: pointsForWin,
      pointsForDraw: pointsForDraw,
      roundRobinRepeats: roundRobinRepeats,
      playoffQualifierCount: playoffQualifierCount,
      countsForRankingIds: countsForRankingIds,
      seedingRankingId: seedingRankingId,
      seedCount: seedCount,
      qualificationConditions: qualificationConditions,
      slotRules: slotRules,
      fillRequiredCareerTags: fillRequiredCareerTags,
      fillExcludedCareerTags: fillExcludedCareerTags,
      fillRankingId: fillRankingId,
      fillTopByRankingCount: fillTopByRankingCount,
        fillTopByAverageCount: fillTopByAverageCount,
        fillRules: fillRules,
        tagGate: tagGate,
        seriesGroupId: seriesGroupId,
        seriesIndex: seriesIndex,
        seriesLength: seriesLength,
        seriesStage: seriesStage,
        leagueSeriesQualificationMode: leagueSeriesQualificationMode,
      );

    _replaceCareer(
      _engine.updateCalendarItem(
        career: career,
        item: item,
      ),
    );
  }

  void removeCalendarItem(String itemId) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.removeCalendarItem(
        career: career,
        itemId: itemId,
      ),
    );
  }

  void reorderCalendar(int oldIndex, int newIndex) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.reorderCalendar(
        career: career,
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
    );
  }

  void startCareer() {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(_engine.startCareer(career));
  }

  void finishCurrentSeason() {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    final standingsByRanking = <String, List<RankingStanding>>{};
    for (final ranking in career.rankings) {
      standingsByRanking[ranking.id] = _rankingEngine.buildCareerStandings(
        ranking: ranking,
        currentSeasonNumber: career.currentSeason.seasonNumber,
        completedTournaments: career.completedTournaments,
        participants: _participantMap(career),
      );
    }
    final updatedCareer = _applySeasonTagRules(
      career: career,
      standingsByRanking: standingsByRanking,
    );
      _replaceCareer(
        _engine.finishCurrentSeason(updatedCareer).copyWith(
          leagueSeriesStates: const <CareerLeagueSeriesState>[],
        ),
      );
    }

  void completeCurrentTournament({
    required CareerCalendarItem item,
    required TournamentBracket bracket,
  }) {
    final career = activeCareer;
    final champion = bracket.champion;
    final runnerUp = bracket.runnerUp;
    final semiFinalists = bracket.rounds.length >= 2
        ? bracket
            .losersForRound(bracket.rounds[bracket.rounds.length - 2].roundNumber)
            .map((entry) => entry.id)
            .toList()
        : const <String>[];
    final quarterFinalists = bracket.rounds.length >= 3
        ? bracket
            .losersForRound(bracket.rounds[bracket.rounds.length - 3].roundNumber)
            .map((entry) => entry.id)
            .toList()
        : const <String>[];
    if (career == null || champion == null) {
      return;
    }
    final payoutData = _payoutDataForTournament(
      item: item,
      bracket: bracket,
      champion: champion,
      runnerUp: runnerUp,
    );
    final playerX01Stats = _aggregateX01StatsForBracket(bracket);
    final matchHistoryEvents = _extractMatchHistoryEventsForBracket(
      seasonNumber: career.currentSeason.seasonNumber,
      tournamentName: item.name,
      bracket: bracket,
    );
    final nineDarterEvents = _extractNineDarterEventsForBracket(
      seasonNumber: career.currentSeason.seasonNumber,
      tournamentName: item.name,
      bracket: bracket,
    );
    final careerWithTournamentTagRules = _applyTournamentTagRules(
      career: career,
      item: item,
      winnerId: champion.id,
      runnerUpId: runnerUp?.id,
      semiFinalistIds: semiFinalists,
      quarterFinalistIds: quarterFinalists,
    );

    _replaceCareer(
      _engine.completeTournament(
        career: careerWithTournamentTagRules,
        item: item,
        winnerId: champion.id,
        winnerName: champion.name,
        runnerUpId: runnerUp?.id,
        runnerUpName: runnerUp?.name,
        semiFinalistIds: semiFinalists,
        quarterFinalistIds: quarterFinalists,
        playerPayouts: payoutData.payouts,
        playerResultLabels: payoutData.resultLabels,
        playerX01Stats: playerX01Stats,
        nineDarterEvents: nineDarterEvents,
        matchHistoryEvents: matchHistoryEvents,
      ),
    );
  }

  void completeLeagueSeriesRound({
    required CareerCalendarItem item,
    required TournamentBracket roundBracket,
    required String seriesName,
  }) {
    final career = activeCareer;
    if (career == null || item.seriesGroupId == null) {
      return;
    }
    final roundState = CareerLeagueSeriesRoundState(
      calendarItemId: item.id,
      bracket: roundBracket,
    );
    final nextSeriesStates = career.leagueSeriesStates
        .where((entry) => entry.id != item.seriesGroupId)
        .toList();
    final currentState = _leagueSeriesState(career, item.seriesGroupId!);
    final mergedRounds = <CareerLeagueSeriesRoundState>[
      ...?currentState?.completedRounds.where(
        (entry) => entry.calendarItemId != item.id,
      ),
      roundState,
    ]..sort((left, right) {
        final leftRound = left.bracket.rounds.isEmpty
            ? 1 << 20
            : left.bracket.rounds.first.roundNumber;
        final rightRound = right.bracket.rounds.isEmpty
            ? 1 << 20
            : right.bracket.rounds.first.roundNumber;
        return leftRound.compareTo(rightRound);
      });
    nextSeriesStates.add(
      CareerLeagueSeriesState(
        id: item.seriesGroupId!,
        baseName: seriesName,
        format: item.format,
        qualificationMode: item.leagueSeriesQualificationMode,
        fixedParticipantIds: currentState?.fixedParticipantIds ?? const <String>[],
        completedRounds: mergedRounds,
      ),
    );

    final completedItemIds = <String>[
      ...career.currentSeason.completedItemIds,
      if (!career.currentSeason.completedItemIds.contains(item.id)) item.id,
    ];
    var updatedCareer = career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        completedItemIds: completedItemIds,
      ),
      leagueSeriesStates: nextSeriesStates,
    );

    final isFinalSeriesItem = item.seriesLength != null &&
        item.seriesIndex != null &&
        item.seriesIndex! >= item.seriesLength!;
    if (!isFinalSeriesItem) {
      _replaceCareer(updatedCareer);
      return;
    }

    final fullBracket = _mergeLeagueSeriesBrackets(
      rounds: mergedRounds,
      fallbackBracket: roundBracket,
    );
    final champion = fullBracket.champion;
    if (champion == null) {
      _replaceCareer(updatedCareer);
      return;
    }
    final runnerUp = fullBracket.runnerUp;
    final semiFinalists = fullBracket.rounds.length >= 2
        ? fullBracket
            .losersForRound(fullBracket.rounds[fullBracket.rounds.length - 2].roundNumber)
            .map((entry) => entry.id)
            .toList()
        : const <String>[];
    final quarterFinalists = fullBracket.rounds.length >= 3
        ? fullBracket
            .losersForRound(fullBracket.rounds[fullBracket.rounds.length - 3].roundNumber)
            .map((entry) => entry.id)
            .toList()
        : const <String>[];
    final payoutData = _payoutDataForTournament(
      item: item.copyWith(name: seriesName),
      bracket: fullBracket,
      champion: champion,
      runnerUp: runnerUp,
    );
    final playerX01Stats = _aggregateX01StatsForBracket(fullBracket);
    final matchHistoryEvents = _extractMatchHistoryEventsForBracket(
      seasonNumber: career.currentSeason.seasonNumber,
      tournamentName: seriesName,
      bracket: fullBracket,
    );
    final nineDarterEvents = _extractNineDarterEventsForBracket(
      seasonNumber: career.currentSeason.seasonNumber,
      tournamentName: seriesName,
      bracket: fullBracket,
    );
    final careerWithTagRules = _applyTournamentTagRules(
      career: updatedCareer,
      item: item.copyWith(name: seriesName),
      winnerId: champion.id,
      runnerUpId: runnerUp?.id,
      semiFinalistIds: semiFinalists,
      quarterFinalistIds: quarterFinalists,
    );
    final completedTournament = CareerCompletedTournament(
      seasonNumber: career.currentSeason.seasonNumber,
      calendarItemId: item.seriesGroupId!,
      calendarIndex: career.currentSeason.calendar.indexWhere(
        (entry) => entry.id == item.id,
      ),
      name: seriesName,
      fieldSize: item.fieldSize,
      winnerId: champion.id,
      winnerName: champion.name,
      runnerUpId: runnerUp?.id,
      runnerUpName: runnerUp?.name,
      semiFinalistIds: semiFinalists,
      quarterFinalistIds: quarterFinalists,
      prizePool: item.prizePool,
      playerPayouts: payoutData.payouts,
      playerResultLabels: payoutData.resultLabels,
      playerX01Stats: playerX01Stats,
      nineDarterEvents: nineDarterEvents,
      matchHistoryEvents: matchHistoryEvents,
      countsForRankingIds: item.countsForRankingIds,
    );
    _replaceCareer(
      careerWithTagRules.copyWith(
        leagueSeriesStates: careerWithTagRules.leagueSeriesStates
            .where((entry) => entry.id != item.seriesGroupId)
            .toList(),
        completedTournaments: <CareerCompletedTournament>[
          ...careerWithTagRules.completedTournaments,
          completedTournament,
        ],
      ),
    );
  }

  Map<String, CareerX01PlayerStats> _aggregateX01StatsForBracket(
    TournamentBracket bracket,
  ) {
    final aggregated = <String, CareerX01PlayerStats>{};
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        final participantStats = match.result?.participantStats ?? const <TournamentPlayerMatchStats>[];
        for (final stats in participantStats) {
          final next = CareerX01PlayerStats(
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
          aggregated.update(
            stats.participantId,
            (current) => current.add(next),
            ifAbsent: () => next,
          );
        }
      }
    }
    return aggregated;
  }

  List<CareerNineDarterEvent> _extractNineDarterEventsForBracket({
    required int seasonNumber,
    required String tournamentName,
    required TournamentBracket bracket,
  }) {
    final events = <CareerNineDarterEvent>[];
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        final result = match.result;
        if (result == null) {
          continue;
        }
        for (final stats in result.participantStats) {
          final count = stats.won9Darters > 0
              ? stats.won9Darters
              : (stats.bestLegDarts == 9 ? 1 : 0);
          if (count <= 0) {
            continue;
          }
          final opponent = match.playerA?.id == stats.participantId
              ? match.playerB
              : match.playerA;
          for (var index = 0; index < count; index += 1) {
            events.add(
              CareerNineDarterEvent(
                playerId: stats.participantId,
                playerName: stats.participantName,
                seasonNumber: seasonNumber,
                tournamentName: tournamentName,
                roundLabel: round.title,
                opponentId: opponent?.id ?? '',
                opponentName: opponent?.name ?? 'Unbekannter Gegner',
                scoreText: result.scoreText,
              ),
            );
          }
        }
      }
    }
    return events;
  }

  List<CareerMatchHistoryEvent> _extractMatchHistoryEventsForBracket({
    required int seasonNumber,
    required String tournamentName,
    required TournamentBracket bracket,
  }) {
    final events = <CareerMatchHistoryEvent>[];
    for (final round in bracket.rounds) {
      for (final match in round.matches) {
        final result = match.result;
        if (result == null) {
          continue;
        }
        final participantStats = result.participantStats;
        if (participantStats.isEmpty) {
          continue;
        }
        for (final stats in participantStats) {
          final opponent = match.playerA?.id == stats.participantId
              ? match.playerB
              : match.playerA;
          final average = stats.dartsThrown > 0
              ? (stats.pointsScored * 3) / stats.dartsThrown
              : 0.0;
          final didWin = result.winnerId == stats.participantId;
          events.add(
            CareerMatchHistoryEvent(
              playerId: stats.participantId,
              playerName: stats.participantName,
              opponentId: opponent?.id ?? '',
              opponentName: opponent?.name ?? 'Unbekannter Gegner',
              opponentTheoAverage: opponent?.average,
              seasonNumber: seasonNumber,
              tournamentName: tournamentName,
              roundLabel: round.title,
              scoreText: result.scoreText,
              resultLabel: didWin
                  ? 'Sieg'
                  : (result.isDraw ? 'Unentschieden' : 'Niederlage'),
              average: average,
            ),
          );
        }
      }
    }
    return events;
  }

  void skipCurrentTournament({
    required CareerCalendarItem item,
  }) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    _replaceCareer(
      _engine.skipTournament(
        career: career,
        item: item,
      ),
    );
  }

  void setLeagueSeriesState(CareerLeagueSeriesState state) {
    final career = activeCareer;
    if (career == null) {
      return;
    }
    final nextStates = career.leagueSeriesStates
        .where((entry) => entry.id != state.id)
        .toList()
      ..add(state);
    _replaceCareer(career.copyWith(leagueSeriesStates: nextStates));
  }

  List<RankingStanding> standingsForRanking(String rankingId) {
    final career = activeCareer;
    if (career == null) {
      return const <RankingStanding>[];
    }

    final cached = _cachedStandingsByRankingId[rankingId];
    if (cached != null) {
      return cached;
    }

    CareerRankingDefinition? ranking;
    for (final entry in career.rankings) {
      if (entry.id == rankingId) {
        ranking = entry;
        break;
      }
    }
    if (ranking == null) {
      return const <RankingStanding>[];
    }

    final standings = _rankingEngine.buildCareerStandings(
      ranking: ranking,
      currentSeasonNumber: career.currentSeason.seasonNumber,
      completedTournaments: career.completedTournaments,
      participants: _participantMap(career),
    );
    _cachedStandingsByRankingId[rankingId] = standings;
    return standings;
  }

  CareerStatisticsSummary? statisticsSummary() {
    final career = activeCareer;
    if (career == null) {
      return null;
    }

    final cached = _cachedStatisticsSummary;
    if (cached != null) {
      return cached;
    }

    final summary = _statisticsEngine.buildSummary(
      currentSeasonNumber: career.currentSeason.seasonNumber,
      completedTournaments: career.completedTournaments,
      participants: _participantMap(career),
    );
    _cachedStatisticsSummary = summary;
    return summary;
  }

  CareerPlayerHistorySummary? playerHistory(String playerId) {
    return playerHistoryWithFilter(playerId);
  }

  CareerPlayerHistorySummary? playerHistoryWithFilter(
    String playerId, {
    CareerHistoryFilterMode filterMode = CareerHistoryFilterMode.career,
    int? seasonNumber,
  }) {
    final career = activeCareer;
    if (career == null) {
      return null;
    }
    final cacheKey =
        '$playerId|${filterMode.name}|${seasonNumber ?? 'all'}';
    if (_cachedPlayerHistory.containsKey(cacheKey)) {
      return _cachedPlayerHistory[cacheKey];
    }

    final participants = _participantMap(career);
    final playerName = participants[playerId];
    if (playerName == null) {
      return null;
    }
    final history = _statisticsEngine.buildPlayerHistory(
      playerId: playerId,
      playerName: playerName,
      currentSeasonNumber: career.currentSeason.seasonNumber,
      completedTournaments: career.completedTournaments,
      filterMode: filterMode,
      seasonNumber: seasonNumber,
    );
    _cachedPlayerHistory[cacheKey] = history;
    return history;
  }

  Map<String, String> _participantMap(CareerDefinition career) {
    final cached = _cachedParticipantMap;
    if (cached != null) {
      return cached;
    }

    final entries = <String, String>{};
    if (career.participantMode == CareerParticipantMode.withHuman) {
      final playerId = career.playerProfileId;
      final PlayerProfile? human = playerId == null
          ? PlayerRepository.instance.activePlayer
          : PlayerRepository.instance.playerById(playerId);
      if (human != null) {
        entries[human.id] = human.name;
      }
    }

    for (final player in career.databasePlayers) {
      entries[player.databasePlayerId] = player.name;
    }

    _cachedParticipantMap = entries;
    return entries;
  }

  void _replaceCareer(CareerDefinition updatedCareer) {
    final index = _careers.indexWhere((career) => career.id == updatedCareer.id);
    if (index < 0) {
      return;
    }
    _careers[index] = _normalizeLoadedCareer(updatedCareer);
    _invalidateDerivedDataCaches();
    notifyListeners();
    unawaited(_persist());
  }

  void _invalidateDerivedDataCaches() {
    _cachedParticipantMap = null;
    _cachedStatisticsSummary = null;
    _cachedStandingsByRankingId.clear();
    _cachedPlayerHistory.clear();
  }

  CareerDefinition _normalizeLoadedCareer(CareerDefinition career) {
    return career.copyWith(
      databasePlayers: career.databasePlayers
          .map(_normalizeCareerDatabasePlayer)
          .toList(),
    );
  }

  CareerDatabasePlayer _normalizeCareerDatabasePlayer(
    CareerDatabasePlayer player,
  ) {
    final average = player.average;
    if (average.isNaN || average.isInfinite) {
      return player.copyWith(average: 0);
    }
    return player;
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

  TournamentBracket _mergeLeagueSeriesBrackets({
    required List<CareerLeagueSeriesRoundState> rounds,
    required TournamentBracket fallbackBracket,
  }) {
    if (rounds.isEmpty) {
      return fallbackBracket;
    }
    final participantsById = <String, TournamentParticipant>{};
    final mergedRounds = <TournamentRound>[];
    for (final roundState in rounds) {
      for (final participant in roundState.bracket.participants) {
        participantsById[participant.id] = participant;
      }
      mergedRounds.addAll(roundState.bracket.rounds);
    }
    mergedRounds.sort((left, right) => left.roundNumber.compareTo(right.roundNumber));
    return TournamentBracket(
      definition: fallbackBracket.definition,
      participants: participantsById.values.toList(),
      rounds: mergedRounds,
    );
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, dynamic>{
        'activeCareerId': _activeCareerId,
        'careers': _careers.map((entry) => entry.toJson()).toList(),
      },
    );
  }

  CareerDatabasePlayer _applyCareerTagDefinitions({
    required CareerDefinition career,
    required CareerDatabasePlayer player,
  }) {
    final normalizedTags = <CareerPlayerTag>[];
    final seen = <String>{};
    for (final rawTag in player.careerTags) {
      final tag = rawTag.tagName.trim();
      if (tag.isEmpty || !seen.add(tag)) {
        continue;
      }
      CareerTagDefinition? definition;
      for (final entry in career.careerTagDefinitions) {
        if (entry.name == tag) {
          definition = entry;
          break;
        }
      }
      if (definition == null) {
        normalizedTags.add(rawTag.copyWith(tagName: tag));
        continue;
      }
      if (definition.playerLimit != null && definition.playerLimit! > 0) {
        var existingCount = 0;
        for (final existingPlayer in career.databasePlayers) {
          if (existingPlayer.databasePlayerId == player.databasePlayerId) {
            continue;
          }
          if (existingPlayer.careerTags.any((entry) => entry.tagName == tag)) {
            existingCount += 1;
          }
        }
        if (existingCount >= definition.playerLimit!) {
          continue;
        }
      }
      final remainingSeasons =
          rawTag.remainingSeasons ?? definition.initialValiditySeasons;
      normalizedTags.add(
        rawTag.copyWith(
          tagName: tag,
          remainingSeasons: remainingSeasons,
          clearRemainingSeasons: remainingSeasons == null,
        ),
      );
    }
    return player.copyWith(careerTags: normalizedTags);
  }

  CareerDefinition _reapplyCareerTagDefinitions(CareerDefinition career) {
    return career.copyWith(
      databasePlayers: career.databasePlayers
          .map(
            (player) => _applyCareerTagDefinitions(
              career: career,
              player: player,
            ),
          )
          .toList(),
    );
  }

  CareerDefinition _applySeasonTagRules({
    required CareerDefinition career,
    required Map<String, List<RankingStanding>> standingsByRanking,
  }) {
    final decrementedCareer = _decrementCareerTagDurations(career);
    if (career.seasonTagRules.isEmpty || decrementedCareer.databasePlayers.isEmpty) {
      return decrementedCareer;
    }
    final nextPlayers = decrementedCareer.databasePlayers.map((player) {
      final nextTags = List<CareerPlayerTag>.from(player.careerTags);
      for (final rule in career.seasonTagRules) {
        final standings = standingsByRanking[rule.rankingId];
        if (standings == null) {
          continue;
        }
        var isMatched = false;
        for (final standing in standings) {
          if (standing.id != player.databasePlayerId) {
            continue;
          }
          if (_matchesSeasonRuleRank(rule, standing.rank) &&
              _matchesSeasonRuleCheck(player: player, rule: rule)) {
            isMatched = true;
          }
          break;
        }
        if (!isMatched) {
          continue;
        }
        if (rule.action == CareerSeasonTagRuleAction.add) {
          _assignOrExtendTag(
            tagAssignments: nextTags,
            tagDefinition: _tagDefinitionByName(decrementedCareer, rule.tagName),
            tagName: rule.tagName,
          );
        } else {
          nextTags.removeWhere((entry) => entry.tagName == rule.tagName);
        }
      }
      return player.copyWith(careerTags: nextTags);
    }).toList();
    final updatedCareer = decrementedCareer.copyWith(databasePlayers: nextPlayers);
    final filledCareer = _applyTagFillUps(
      career: updatedCareer,
      standingsByRanking: standingsByRanking,
    );
    return _reapplyCareerTagDefinitions(filledCareer);
  }

  CareerDefinition _applyTournamentTagRules({
    required CareerDefinition career,
    required CareerCalendarItem item,
    required String winnerId,
    required String? runnerUpId,
    required List<String> semiFinalistIds,
    required List<String> quarterFinalistIds,
  }) {
    if (item.tournamentTagRules.isEmpty || career.databasePlayers.isEmpty) {
      return career;
    }
    final nextPlayers = career.databasePlayers.map((player) {
      final nextTags = List<CareerPlayerTag>.from(player.careerTags);
      for (final rule in item.tournamentTagRules) {
        if (!_matchesTournamentTagRuleTarget(
          rule: rule,
          playerId: player.databasePlayerId,
          winnerId: winnerId,
          runnerUpId: runnerUpId,
          semiFinalistIds: semiFinalistIds,
          quarterFinalistIds: quarterFinalistIds,
        )) {
          continue;
        }
        if (rule.action == CareerTournamentTagRuleAction.add) {
          _assignOrExtendTag(
            tagAssignments: nextTags,
            tagDefinition: _tagDefinitionByName(career, rule.tagName),
            tagName: rule.tagName,
          );
        } else {
          nextTags.removeWhere((entry) => entry.tagName == rule.tagName);
        }
      }
      return player.copyWith(careerTags: nextTags);
    }).toList();
    return _reapplyCareerTagDefinitions(
      career.copyWith(databasePlayers: nextPlayers),
    );
  }

  CareerDefinition _decrementCareerTagDurations(CareerDefinition career) {
    return career.copyWith(
      databasePlayers: career.databasePlayers.map((player) {
        final nextTags = <CareerPlayerTag>[];
        final tagsToAddOnExpiry = <String>[];
        for (final tag in player.careerTags) {
          final remainingSeasons = tag.remainingSeasons;
          if (remainingSeasons == null) {
            nextTags.add(tag);
            continue;
          }
          final nextRemaining = remainingSeasons - 1;
          if (nextRemaining <= 0) {
            final definition = _tagDefinitionByName(career, tag.tagName);
            if (definition != null) {
              tagsToAddOnExpiry.addAll(definition.tagsToAddOnExpiry);
            }
            continue;
          }
          nextTags.add(tag.copyWith(remainingSeasons: nextRemaining));
        }
        final deduplicatedExpiryTags = <String>{};
        for (final tagName in tagsToAddOnExpiry) {
          final trimmedTagName = tagName.trim();
          if (trimmedTagName.isEmpty || !deduplicatedExpiryTags.add(trimmedTagName)) {
            continue;
          }
          _assignOrExtendTag(
            tagAssignments: nextTags,
            tagDefinition: _tagDefinitionByName(career, trimmedTagName),
            tagName: trimmedTagName,
          );
        }
        return player.copyWith(careerTags: nextTags);
      }).toList(),
    );
  }

  CareerDefinition _applyTagFillUps({
    required CareerDefinition career,
    required Map<String, List<RankingStanding>> standingsByRanking,
  }) {
    final nextPlayers = List<CareerDatabasePlayer>.from(career.databasePlayers);
    for (final definition in career.careerTagDefinitions) {
      final targetPlayerCount = definition.fillUpToPlayerCount;
      final rankingId = definition.fillUpByRankingId;
      if (targetPlayerCount == null ||
          targetPlayerCount <= 0 ||
          rankingId == null ||
          rankingId.trim().isEmpty) {
        continue;
      }
      final standings = standingsByRanking[rankingId];
      if (standings == null || standings.isEmpty) {
        continue;
      }
      var currentCount = nextPlayers
          .where(
            (player) =>
                player.careerTags.any((tag) => tag.tagName == definition.name),
          )
          .length;
      if (currentCount >= targetPlayerCount) {
        continue;
      }
      for (final standing in standings) {
        if (currentCount >= targetPlayerCount) {
          break;
        }
        final playerIndex = nextPlayers.indexWhere(
          (player) => player.databasePlayerId == standing.id,
        );
        if (playerIndex < 0) {
          continue;
        }
        final player = nextPlayers[playerIndex];
        if (player.careerTags.any((tag) => tag.tagName == definition.name) ||
            !_matchesCareerTagFilters(
              player: player,
              requiredTags: definition.fillUpRequiredCareerTags,
              excludedTags: definition.fillUpExcludedCareerTags,
            )) {
          continue;
        }
        final nextTags = List<CareerPlayerTag>.from(player.careerTags);
        _assignOrExtendTag(
          tagAssignments: nextTags,
          tagDefinition: definition,
          tagName: definition.name,
        );
        nextPlayers[playerIndex] = player.copyWith(careerTags: nextTags);
        currentCount += 1;
      }
    }
    return career.copyWith(databasePlayers: nextPlayers);
  }

  bool _matchesSeasonRuleRank(CareerSeasonTagRule rule, int rank) {
    if (rule.rankMode == CareerSeasonTagRuleRankMode.greaterThanRank) {
      return rank > (rule.referenceRank ?? rule.fromRank);
    }
    final start = rule.fromRank <= rule.toRank ? rule.fromRank : rule.toRank;
    final end = rule.fromRank <= rule.toRank ? rule.toRank : rule.fromRank;
    return rank >= start && rank <= end;
  }

  bool _matchesSeasonRuleCheck({
    required CareerDatabasePlayer player,
    required CareerSeasonTagRule rule,
  }) {
    if (rule.checkMode == CareerSeasonTagRuleCheckMode.none) {
      return true;
    }
    final checkTagName = rule.checkTagName;
    final checkRemainingSeasons = rule.checkRemainingSeasons;
    if (checkTagName == null || checkRemainingSeasons == null) {
      return true;
    }
    CareerPlayerTag? matchedTag;
    for (final tag in player.careerTags) {
      if (tag.tagName == checkTagName) {
        matchedTag = tag;
        break;
      }
    }
    if (matchedTag == null || matchedTag.remainingSeasons == null) {
      return false;
    }
    if (rule.checkMode == CareerSeasonTagRuleCheckMode.tagValidityAtMost) {
      return matchedTag.remainingSeasons! <= checkRemainingSeasons;
    }
    return matchedTag.remainingSeasons! >= checkRemainingSeasons;
  }

  CareerTagDefinition? _tagDefinitionByName(
    CareerDefinition career,
    String tagName,
  ) {
    for (final definition in career.careerTagDefinitions) {
      if (definition.name == tagName) {
        return definition;
      }
    }
    return null;
  }

  void _assignOrExtendTag({
    required List<CareerPlayerTag> tagAssignments,
    required CareerTagDefinition? tagDefinition,
    required String tagName,
  }) {
    final index = tagAssignments.indexWhere((entry) => entry.tagName == tagName);
    final tagsToRemove = index < 0
        ? (tagDefinition?.tagsToRemoveOnInitialAssignment ?? const <String>[])
        : (tagDefinition?.tagsToRemoveOnExtension ?? const <String>[]);
    if (tagsToRemove.isNotEmpty) {
      tagAssignments.removeWhere(
        (entry) => entry.tagName != tagName && tagsToRemove.contains(entry.tagName),
      );
    }
    if (index < 0) {
      tagAssignments.add(
        CareerPlayerTag(
          tagName: tagName,
          remainingSeasons: tagDefinition?.initialValiditySeasons,
        ),
      );
      return;
    }
    final extensionValiditySeasons =
        tagDefinition?.extensionValiditySeasons ??
            tagDefinition?.initialValiditySeasons;
    if (extensionValiditySeasons == null) {
      tagAssignments[index] = tagAssignments[index].copyWith(
        clearRemainingSeasons: true,
      );
      return;
    }
    tagAssignments[index] = tagAssignments[index].copyWith(
      remainingSeasons: extensionValiditySeasons,
    );
  }

  bool _matchesCareerTagFilters({
    required CareerDatabasePlayer player,
    required List<String> requiredTags,
    required List<String> excludedTags,
  }) {
    final playerTags = player.careerTags.map((entry) => entry.tagName).toSet();
    for (final tag in requiredTags) {
      if (!playerTags.contains(tag)) {
        return false;
      }
    }
    for (final tag in excludedTags) {
      if (playerTags.contains(tag)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesTournamentTagRuleTarget({
    required CareerTournamentTagRule rule,
    required String playerId,
    required String winnerId,
    required String? runnerUpId,
    required List<String> semiFinalistIds,
    required List<String> quarterFinalistIds,
  }) {
    switch (rule.target) {
      case CareerTournamentTagRuleTarget.winner:
        return playerId == winnerId;
      case CareerTournamentTagRuleTarget.runnerUp:
        return playerId == runnerUpId;
      case CareerTournamentTagRuleTarget.semiFinalists:
        return semiFinalistIds.contains(playerId);
      case CareerTournamentTagRuleTarget.quarterFinalists:
        return quarterFinalistIds.contains(playerId);
    }
  }

  _TournamentPayoutData _payoutDataForTournament({
    required CareerCalendarItem item,
    required TournamentBracket bracket,
    required TournamentParticipant champion,
    required TournamentParticipant? runnerUp,
  }) {
    final payouts = <String, int>{};
    final labels = <String, String>{};
    var usedConfiguredPayouts = false;

    if (item.format == TournamentFormat.league ||
        item.format == TournamentFormat.leaguePlayoff) {
      for (var index = 0; index < bracket.standings.length; index += 1) {
        final standing = bracket.standings[index];
        final payout = index < item.leaguePositionPrizeValues.length
            ? item.leaguePositionPrizeValues[index]
            : 0;
        if (payout > 0) {
          payouts[standing.participant.id] =
              (payouts[standing.participant.id] ?? 0) + payout;
          usedConfiguredPayouts = true;
        }
        labels.putIfAbsent(
          standing.participant.id,
          () => 'Liga Platz ${index + 1}',
        );
      }
    }

    if (item.format == TournamentFormat.knockout ||
        item.format == TournamentFormat.leaguePlayoff) {
      final relevantRounds = item.format == TournamentFormat.leaguePlayoff
          ? bracket.playoffRounds
          : bracket.rounds;
      if (item.knockoutPrizeValues.isNotEmpty) {
        for (var index = 0; index < relevantRounds.length; index += 1) {
          final round = relevantRounds[index];
          final payout = index < item.knockoutPrizeValues.length
              ? item.knockoutPrizeValues[index]
              : 0;
          final resultLabel = _resultLabelForRound(index, relevantRounds.length);
          for (final loser in bracket.losersForRound(round.roundNumber)) {
            payouts[loser.id] = (payouts[loser.id] ?? 0) + payout;
            labels[loser.id] = resultLabel;
          }
        }

        payouts[champion.id] =
            (payouts[champion.id] ?? 0) + item.knockoutPrizeValues.last;
        labels[champion.id] = 'Sieger';
        if (runnerUp != null) {
          labels.putIfAbsent(runnerUp.id, () => 'Finalist');
        }
        usedConfiguredPayouts = true;
      }
    }

    if (!usedConfiguredPayouts) {
      return _TournamentPayoutData(
        payouts: <String, int>{champion.id: item.prizePool},
        resultLabels: <String, String>{champion.id: 'Sieger'},
      );
    }

    return _TournamentPayoutData(
      payouts: payouts,
      resultLabels: labels,
    );
  }

  String _resultLabelForRound(int roundIndex, int roundCount) {
    if (roundIndex == roundCount - 1) {
      return 'Finalist';
    }
    if (roundIndex == roundCount - 2) {
      return 'Halbfinale';
    }
    if (roundIndex == roundCount - 3) {
      return 'Viertelfinale';
    }
    return 'Runde ${roundIndex + 1}';
  }
}

class _TournamentPayoutData {
  const _TournamentPayoutData({
    required this.payouts,
    required this.resultLabels,
  });

  final Map<String, int> payouts;
  final Map<String, String> resultLabels;
}

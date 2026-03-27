import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/career/career_models.dart';
import '../../domain/career/career_template.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import '../models/computer_player.dart';
import 'computer_repository.dart';
import '../storage/app_storage.dart';

class CareerTemplateRepository extends ChangeNotifier {
  CareerTemplateRepository._();

  static final CareerTemplateRepository instance =
      CareerTemplateRepository._();

  static const _storageKey = 'career_templates';
  static const builtInPdcBasicTemplateId = 'template-pdc-basic';
  static const _builtInTemplateAssetPath = 'assets/templates/basic_pdc_template.json';
  final List<CareerTemplate> _templates = <CareerTemplate>[];
  CareerTemplate? _builtInTemplate;

  List<CareerTemplate> get templates => List<CareerTemplate>.unmodifiable(
        <CareerTemplate>[
          if (_builtInTemplate != null) _builtInTemplate!,
          ..._templates,
        ],
      );

  bool isBuiltInTemplate(String templateId) =>
      templateId == builtInPdcBasicTemplateId;

  Future<void> initialize() async {
    final json = await AppStorage.instance.readJsonMap(_storageKey);
    final loadedTemplates = (json?['templates'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (entry) => CareerTemplate.fromJson(
            (entry as Map).cast<String, dynamic>(),
          ),
        )
        .where(
          (template) =>
              !isBuiltInTemplate(template.id) &&
              template.id != 'template-pdc-system' &&
              !template.name.toLowerCase().startsWith('pdc-system') &&
              template.name.toLowerCase() != 'pdc basic' &&
              template.name.toLowerCase() != 'basic pdc',
        )
        .toList();
    _templates
      ..clear()
      ..addAll(loadedTemplates);
    _builtInTemplate = await _loadBuiltInTemplate();
    notifyListeners();
  }

  Future<void> importTemplates(
    List<CareerTemplate> importedTemplates, {
    bool replaceExisting = false,
  }) async {
    if (importedTemplates.isEmpty) {
      return;
    }

    final nextTemplates = replaceExisting
        ? <CareerTemplate>[]
        : List<CareerTemplate>.from(_templates);

    for (final imported in importedTemplates) {
      final index = nextTemplates.indexWhere((entry) => entry.id == imported.id);
      if (index >= 0) {
        nextTemplates[index] = imported;
        continue;
      }
      final nameIndex = nextTemplates.indexWhere(
        (entry) => entry.name.toLowerCase() == imported.name.toLowerCase(),
      );
      if (nameIndex >= 0) {
        nextTemplates[nameIndex] = imported;
        continue;
      }
      nextTemplates.add(imported);
    }

    _templates
      ..clear()
      ..addAll(nextTemplates);
    notifyListeners();
    await _persist();
  }

  void saveTemplate({
    required String name,
    List<CareerDatabasePlayer> databasePlayers =
        const <CareerDatabasePlayer>[],
    List<CareerTagDefinition> careerTagDefinitions =
        const <CareerTagDefinition>[],
    List<CareerSeasonTagRule> seasonTagRules =
        const <CareerSeasonTagRule>[],
    required List<CareerRankingDefinition> rankings,
    required List<CareerCalendarItem> calendar,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final template = CareerTemplate(
      id: 'template-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      databasePlayers: databasePlayers,
      careerTagDefinitions: careerTagDefinitions,
      seasonTagRules: seasonTagRules,
      rankings: rankings,
      calendar: calendar,
    );
    _templates.insert(0, template);
    notifyListeners();
    unawaited(_persist());
  }

  void deleteTemplate(String templateId) {
    if (isBuiltInTemplate(templateId)) {
      return;
    }
    _templates.removeWhere((entry) => entry.id == templateId);
    notifyListeners();
    unawaited(_persist());
  }

  Future<CareerTemplate> _loadBuiltInTemplate() async {
    try {
      final raw = await rootBundle.loadString(_builtInTemplateAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final template = CareerTemplate.fromJson(decoded);
        return CareerTemplate(
          id: builtInPdcBasicTemplateId,
          name: template.name,
          databasePlayers: template.databasePlayers,
          careerTagDefinitions: template.careerTagDefinitions,
          seasonTagRules: template.seasonTagRules,
          rankings: template.rankings,
          calendar: template.calendar,
        );
      }
    } catch (_) {
      // Fall back to the code-defined template if the bundled asset is unavailable.
    }
    return _buildPdcTemplate(ComputerRepository.instance.players);
  }

  CareerTemplate _buildPdcTemplate(List<ComputerPlayer> computerPlayers) {
    const pdcRankingId = 'pdc-order-of-merit';
    const proTourRankingId = 'pdc-protour-order-of-merit';
    const playersChampionshipRankingId =
        'pdc-players-championship-order-of-merit';
    const europeanTourRankingId = 'pdc-european-tour-order-of-merit';
    const challengeTourRankingId = 'pdc-challenge-tour-order-of-merit';
    const developmentTourRankingId = 'pdc-development-tour-order-of-merit';
    const qSchoolRankingId = 'pdc-q-school-order-of-merit';
    const worldSeriesRankingId = 'pdc-world-series-order-of-merit';

    const realPlayerTag = 'Echter Spieler';
    const bulkTag = 'Bulk';
    const tourCardTag = 'Tour Card Holder';
    const associateTag = 'Associate Member';
    const nonTourTag = 'Non-Tour';
    const developmentEligibleTag = 'Development Tour Eligible';
    const nordicBalticTag = 'Nordic/Baltic';
    const eastEuropeTag = 'East Europe';
    const asiaTag = 'Asia';
    const northAmericaTag = 'North America';
    const oceaniaTag = 'Oceania';
    const chinaTag = 'China';
    const ukOpenAmateurQualifierTag = 'UK Open Amateur Qualifier';
    const premierLeagueInviteTag = 'Premier League Invite';
    const worldSeriesInviteTag = 'World Series Invite';
    const worldChampAsiaQualifierTag = 'World Championship Asia Qualifier';
    const worldChampAsianTourQualifierTag =
        'World Championship Asian Tour Qualifier';
    const worldChampNorthAmericaQualifierTag =
        'World Championship North America Qualifier';
    const worldChampOceaniaQualifierTag =
        'World Championship Oceania Qualifier';
    const worldChampChinaQualifierTag = 'World Championship China Qualifier';

    const hostNations = <String>[
      'Belgium',
      'Germany',
      'Austria',
      'Netherlands',
      'Hungary',
      'Czech Republic',
      'Switzerland',
      'Poland',
      'Slovakia',
    ];
    final hostNationTags = <String, String>{
      for (final country in hostNations) country: 'Host Nation $country',
    };

    final realPlayers = computerPlayers
        .where((player) => _hasSourceTag(player, realPlayerTag))
        .toList()
      ..sort(
        (left, right) =>
            right.theoreticalAverage.compareTo(left.theoreticalAverage),
      );
    final fallbackTourPlayers = computerPlayers
        .where((player) => !_hasSourceTag(player, bulkTag))
        .toList()
      ..sort(
        (left, right) =>
            right.theoreticalAverage.compareTo(left.theoreticalAverage),
      );
    final seededTourPlayers =
        (realPlayers.length >= 128 ? realPlayers : fallbackTourPlayers)
            .take(128)
            .toList();
    final tourCardIds =
        seededTourPlayers.map((player) => player.id).toSet();
    final invitationalIds = seededTourPlayers.take(8).map((player) => player.id).toSet();

    final databasePlayers = computerPlayers.map((player) {
      final tagNames = <String>{
        if (tourCardIds.contains(player.id)) tourCardTag,
        if (invitationalIds.contains(player.id)) ...<String>[
          premierLeagueInviteTag,
          worldSeriesInviteTag,
        ],
        if (_hasSourceTag(player, bulkTag)) nonTourTag,
        if (_isDevelopmentEligible(player)) developmentEligibleTag,
        if (_isNordicBaltic(player)) nordicBalticTag,
        if (_isEastEurope(player)) eastEuropeTag,
        if (_isAsian(player)) asiaTag,
        if (_isNorthAmerican(player)) northAmericaTag,
        if (_isOceanian(player)) oceaniaTag,
        if (_isChinese(player)) chinaTag,
        ..._hostNationCareerTags(
          player: player,
          hostNationTags: hostNationTags,
        ),
      };
      return CareerDatabasePlayer(
        databasePlayerId: player.id,
        name: player.name,
        average: player.theoreticalAverage,
        skill: player.skill,
        finishingSkill: player.finishingSkill,
        careerTags: tagNames.map((tagName) {
          if (tagName == tourCardTag) {
            return const CareerPlayerTag(
              tagName: tourCardTag,
              remainingSeasons: 2,
            );
          }
          return CareerPlayerTag(tagName: tagName);
        }).toList(),
      );
    }).toList();

    final rankings = <CareerRankingDefinition>[
      const CareerRankingDefinition(
        id: pdcRankingId,
        name: 'PDC Order of Merit',
        validSeasons: 2,
      ),
      const CareerRankingDefinition(
        id: proTourRankingId,
        name: 'ProTour Order of Merit',
        validSeasons: 1,
      ),
      const CareerRankingDefinition(
        id: playersChampionshipRankingId,
        name: 'Players Championship Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      const CareerRankingDefinition(
        id: europeanTourRankingId,
        name: 'European Tour Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      const CareerRankingDefinition(
        id: challengeTourRankingId,
        name: 'Challenge Tour Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      const CareerRankingDefinition(
        id: developmentTourRankingId,
        name: 'Development Tour Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      const CareerRankingDefinition(
        id: qSchoolRankingId,
        name: 'Q School Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      const CareerRankingDefinition(
        id: worldSeriesRankingId,
        name: 'World Series Order of Merit',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
    ];

    final europeanTourStops = <_PdcEuropeanTourStop>[
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-01',
        name: 'Belgian Darts Open',
        hostNation: 'Belgium',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-02',
        name: 'European Darts Trophy',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-03',
        name: 'International Darts Open',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-04',
        name: 'German Darts Grand Prix',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-05',
        name: 'Austrian Darts Open',
        hostNation: 'Austria',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-06',
        name: 'Dutch Darts Championship',
        hostNation: 'Netherlands',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-07',
        name: 'European Darts Open',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-08',
        name: 'Baltic Sea Darts Open',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-09',
        name: 'Hungarian Darts Trophy',
        hostNation: 'Hungary',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-10',
        name: 'Flanders Darts Trophy',
        hostNation: 'Belgium',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-11',
        name: 'Czech Darts Open',
        hostNation: 'Czech Republic',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-12',
        name: 'German Darts Championship',
        hostNation: 'Germany',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-13',
        name: 'Swiss Darts Trophy',
        hostNation: 'Switzerland',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-14',
        name: 'Polish Darts Open',
        hostNation: 'Poland',
      ),
      const _PdcEuropeanTourStop(
        id: 'pdc-european-tour-15',
        name: 'Slovak Darts Open',
        hostNation: 'Slovakia',
      ),
    ];

    final tagDefinitions = <CareerTagDefinition>[
      const CareerTagDefinition(
        id: 'pdc-tag-tour-card-holder',
        name: tourCardTag,
        initialValiditySeasons: 2,
        extensionValiditySeasons: 2,
        tagsToAddOnExpiry: <String>[associateTag, nonTourTag],
        tagsToRemoveOnInitialAssignment: <String>[associateTag, nonTourTag],
        tagsToRemoveOnExtension: <String>[associateTag, nonTourTag],
        fillUpToPlayerCount: 128,
        fillUpByRankingId: qSchoolRankingId,
        fillUpExcludedCareerTags: <String>[tourCardTag],
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-associate-member',
        name: associateTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-non-tour',
        name: nonTourTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-development-eligible',
        name: developmentEligibleTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-nordic-baltic',
        name: nordicBalticTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-east-europe',
        name: eastEuropeTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-asia',
        name: asiaTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-north-america',
        name: northAmericaTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-oceania',
        name: oceaniaTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-china',
        name: chinaTag,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-uk-open-amateur-qualifier',
        name: ukOpenAmateurQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-premier-league-invite',
        name: premierLeagueInviteTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-series-invite',
        name: worldSeriesInviteTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-champ-asia-qualifier',
        name: worldChampAsiaQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-champ-asian-tour-qualifier',
        name: worldChampAsianTourQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-champ-north-america-qualifier',
        name: worldChampNorthAmericaQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-champ-oceania-qualifier',
        name: worldChampOceaniaQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      const CareerTagDefinition(
        id: 'pdc-tag-world-champ-china-qualifier',
        name: worldChampChinaQualifierTag,
        initialValiditySeasons: 1,
        extensionValiditySeasons: 1,
      ),
      ...hostNationTags.entries.map(
        (entry) => CareerTagDefinition(
          id:
              'pdc-tag-${entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
          name: entry.value,
        ),
      ),
      ...europeanTourStops.expand(
        (stop) => <CareerTagDefinition>[
          CareerTagDefinition(
            id: '${stop.id}-tour-card-qualifier-tag',
            name: '${stop.name} Tour Card Qualifier',
            initialValiditySeasons: 1,
            extensionValiditySeasons: 1,
          ),
          CareerTagDefinition(
            id: '${stop.id}-host-qualifier-tag',
            name: '${stop.name} Host Nation Qualifier',
            initialValiditySeasons: 1,
            extensionValiditySeasons: 1,
          ),
          CareerTagDefinition(
            id: '${stop.id}-nordic-qualifier-tag',
            name: '${stop.name} Nordic/Baltic Qualifier',
            initialValiditySeasons: 1,
            extensionValiditySeasons: 1,
          ),
          CareerTagDefinition(
            id: '${stop.id}-east-europe-qualifier-tag',
            name: '${stop.name} East Europe Qualifier',
            initialValiditySeasons: 1,
            extensionValiditySeasons: 1,
          ),
        ],
      ),
    ];

    final calendar = <CareerCalendarItem>[
      ..._buildSeries(
        idPrefix: 'pdc-q-school',
        namePrefix: 'Q School Day',
        count: 4,
        startIndex: 1,
        fieldSize: 128,
        prizePool: 25000,
        countsForRankingIds: const <String>[qSchoolRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: tourCardTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      const CareerCalendarItem(
        id: 'pdc-premier-league',
        name: 'Premier League',
        game: TournamentGame.x01,
        format: TournamentFormat.leaguePlayoff,
        fieldSize: 8,
        matchMode: MatchMode.legs,
        legsToWin: 6,
        startScore: 501,
        checkoutRequirement: CheckoutRequirement.doubleOut,
        prizePool: 1000000,
        leaguePositionPrizeValues: <int>[275000, 125000, 75000, 75000],
        knockoutPrizeValues: <int>[0, 0, 0, 0],
        pointsForWin: 2,
        pointsForDraw: 0,
        roundRobinRepeats: 2,
        playoffQualifierCount: 4,
        countsForRankingIds: <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[premierLeagueInviteTag],
            slotCount: 8,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-challenge-tour-a',
        namePrefix: 'Challenge Tour',
        count: 6,
        startIndex: 1,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[challengeTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-development-tour-a',
        namePrefix: 'Development Tour',
        count: 6,
        startIndex: 1,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[developmentTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag, developmentEligibleTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-players-championship-a',
        namePrefix: 'Players Championship',
        count: 8,
        startIndex: 1,
        fieldSize: 128,
        prizePool: 75000,
        countsForRankingIds: const <String>[
          pdcRankingId,
          proTourRankingId,
          playersChampionshipRankingId,
        ],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
        fillRankingId: qSchoolRankingId,
        fillTopByRankingCount: 128,
        fillRequiredCareerTags: const <String>[nonTourTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
      ),
      _knockoutEvent(
        id: 'pdc-world-series-bahrain',
        name: 'Bahrain Darts Masters',
        fieldSize: 16,
        prizePool: 100000,
        countsForRankingIds: const <String>[worldSeriesRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldSeriesInviteTag],
            slotCount: 8,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[asiaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 8,
          ),
        ],
      ),
      ...europeanTourStops.sublist(0, 4).expand(
        (stop) => _buildEuropeanTourWeekend(
          stop: stop,
          pdcRankingId: pdcRankingId,
          proTourRankingId: proTourRankingId,
          europeanTourRankingId: europeanTourRankingId,
          tourCardTag: tourCardTag,
          hostNationTag: hostNationTags[stop.hostNation]!,
          associateTag: associateTag,
          nordicBalticTag: nordicBalticTag,
          eastEuropeTag: eastEuropeTag,
        ),
      ),
      ..._buildSeries(
        idPrefix: 'pdc-uk-open-amateur-qualifier',
        namePrefix: 'UK Open Amateur Qualifier',
        count: 16,
        startIndex: 1,
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 32,
          ),
        ],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: ukOpenAmateurQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-uk-open',
        name: 'UK Open',
        fieldSize: 160,
        prizePool: 600000,
        countsForRankingIds: const <String>[pdcRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
          CareerQualificationCondition(
            rankingId: challengeTourRankingId,
            fromRank: 1,
            toRank: 8,
            slotCount: 8,
          ),
          CareerQualificationCondition(
            rankingId: developmentTourRankingId,
            fromRank: 1,
            toRank: 8,
            slotCount: 8,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[ukOpenAmateurQualifierTag],
            slotCount: 16,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-series-nordic',
        name: 'Nordic Darts Masters',
        fieldSize: 16,
        prizePool: 100000,
        countsForRankingIds: const <String>[worldSeriesRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldSeriesInviteTag],
            slotCount: 8,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nordicBalticTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 8,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-players-championship-b',
        namePrefix: 'Players Championship',
        count: 8,
        startIndex: 9,
        fieldSize: 128,
        prizePool: 75000,
        countsForRankingIds: const <String>[
          pdcRankingId,
          proTourRankingId,
          playersChampionshipRankingId,
        ],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
        fillRankingId: qSchoolRankingId,
        fillTopByRankingCount: 128,
        fillRequiredCareerTags: const <String>[nonTourTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-challenge-tour-b',
        namePrefix: 'Challenge Tour',
        count: 6,
        startIndex: 7,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[challengeTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-development-tour-b',
        namePrefix: 'Development Tour',
        count: 6,
        startIndex: 7,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[developmentTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag, developmentEligibleTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ...europeanTourStops.sublist(4, 8).expand(
        (stop) => _buildEuropeanTourWeekend(
          stop: stop,
          pdcRankingId: pdcRankingId,
          proTourRankingId: proTourRankingId,
          europeanTourRankingId: europeanTourRankingId,
          tourCardTag: tourCardTag,
          hostNationTag: hostNationTags[stop.hostNation]!,
          associateTag: associateTag,
          nordicBalticTag: nordicBalticTag,
          eastEuropeTag: eastEuropeTag,
        ),
      ),
      _knockoutEvent(
        id: 'pdc-world-matchplay',
        name: 'World Matchplay',
        fieldSize: 32,
        prizePool: 800000,
        countsForRankingIds: const <String>[pdcRankingId],
        seedingRankingId: pdcRankingId,
        seedCount: 16,
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: pdcRankingId,
            fromRank: 1,
            toRank: 16,
            slotCount: 16,
          ),
          CareerQualificationCondition(
            rankingId: proTourRankingId,
            fromRank: 1,
            toRank: 16,
            slotCount: 16,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-series-us',
        name: 'US Darts Masters',
        fieldSize: 16,
        prizePool: 100000,
        countsForRankingIds: const <String>[worldSeriesRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldSeriesInviteTag],
            slotCount: 8,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[northAmericaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 8,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-players-championship-c',
        namePrefix: 'Players Championship',
        count: 10,
        startIndex: 17,
        fieldSize: 128,
        prizePool: 75000,
        countsForRankingIds: const <String>[
          pdcRankingId,
          proTourRankingId,
          playersChampionshipRankingId,
        ],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
        fillRankingId: qSchoolRankingId,
        fillTopByRankingCount: 128,
        fillRequiredCareerTags: const <String>[nonTourTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-challenge-tour-c',
        namePrefix: 'Challenge Tour',
        count: 6,
        startIndex: 13,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[challengeTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-development-tour-c',
        namePrefix: 'Development Tour',
        count: 6,
        startIndex: 13,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[developmentTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag, developmentEligibleTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ...europeanTourStops.sublist(8, 12).expand(
        (stop) => _buildEuropeanTourWeekend(
          stop: stop,
          pdcRankingId: pdcRankingId,
          proTourRankingId: proTourRankingId,
          europeanTourRankingId: europeanTourRankingId,
          tourCardTag: tourCardTag,
          hostNationTag: hostNationTags[stop.hostNation]!,
          associateTag: associateTag,
          nordicBalticTag: nordicBalticTag,
          eastEuropeTag: eastEuropeTag,
        ),
      ),
      _knockoutEvent(
        id: 'pdc-world-grand-prix',
        name: 'World Grand Prix',
        fieldSize: 32,
        prizePool: 600000,
        countsForRankingIds: const <String>[pdcRankingId],
        seedingRankingId: pdcRankingId,
        seedCount: 16,
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: pdcRankingId,
            fromRank: 1,
            toRank: 16,
            slotCount: 16,
          ),
          CareerQualificationCondition(
            rankingId: proTourRankingId,
            fromRank: 1,
            toRank: 16,
            slotCount: 16,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-series-poland',
        name: 'Poland Darts Masters',
        fieldSize: 16,
        prizePool: 100000,
        countsForRankingIds: const <String>[worldSeriesRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldSeriesInviteTag],
            slotCount: 8,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[eastEuropeTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 8,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-players-championship-d',
        namePrefix: 'Players Championship',
        count: 8,
        startIndex: 27,
        fieldSize: 128,
        prizePool: 75000,
        countsForRankingIds: const <String>[
          pdcRankingId,
          proTourRankingId,
          playersChampionshipRankingId,
        ],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
        fillRankingId: qSchoolRankingId,
        fillTopByRankingCount: 128,
        fillRequiredCareerTags: const <String>[nonTourTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-challenge-tour-d',
        namePrefix: 'Challenge Tour',
        count: 6,
        startIndex: 19,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[challengeTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ..._buildSeries(
        idPrefix: 'pdc-development-tour-d',
        namePrefix: 'Development Tour',
        count: 6,
        startIndex: 19,
        fieldSize: 128,
        prizePool: 15000,
        countsForRankingIds: const <String>[developmentTourRankingId],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nonTourTag, developmentEligibleTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 128,
          ),
        ],
      ),
      ...europeanTourStops.sublist(12).expand(
        (stop) => _buildEuropeanTourWeekend(
          stop: stop,
          pdcRankingId: pdcRankingId,
          proTourRankingId: proTourRankingId,
          europeanTourRankingId: europeanTourRankingId,
          tourCardTag: tourCardTag,
          hostNationTag: hostNationTags[stop.hostNation]!,
          associateTag: associateTag,
          nordicBalticTag: nordicBalticTag,
          eastEuropeTag: eastEuropeTag,
        ),
      ),
      _knockoutEvent(
        id: 'pdc-players-championship-finals',
        name: 'Players Championship Finals',
        fieldSize: 64,
        prizePool: 600000,
        countsForRankingIds: const <String>[pdcRankingId],
        seedingRankingId: playersChampionshipRankingId,
        seedCount: 32,
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: playersChampionshipRankingId,
            fromRank: 1,
            toRank: 64,
            slotCount: 64,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-european-championship',
        name: 'European Championship',
        fieldSize: 32,
        prizePool: 600000,
        countsForRankingIds: const <String>[pdcRankingId],
        seedingRankingId: europeanTourRankingId,
        seedCount: 16,
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: europeanTourRankingId,
            fromRank: 1,
            toRank: 32,
            slotCount: 32,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-series-finals',
        name: 'World Series Finals',
        fieldSize: 32,
        prizePool: 300000,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: worldSeriesRankingId,
            fromRank: 1,
            toRank: 24,
            slotCount: 24,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldSeriesInviteTag],
            slotCount: 8,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship-asia-championship-qualifier',
        name: 'World Championship Asia Qualifier',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 6,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[asiaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: const <String>[asiaTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: worldChampAsiaQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship-asian-tour-qualifier',
        name: 'World Championship Asian Tour Qualifier',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 6,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[asiaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: const <String>[asiaTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: worldChampAsianTourQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship-north-america-qualifier',
        name: 'World Championship North America Qualifier',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 6,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[northAmericaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: const <String>[northAmericaTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: worldChampNorthAmericaQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship-oceania-qualifier',
        name: 'World Championship Oceania Qualifier',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 6,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[oceaniaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: const <String>[oceaniaTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: worldChampOceaniaQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship-china-qualifier',
        name: 'World Championship China Qualifier',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 6,
        countsForRankingIds: const <String>[],
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[chinaTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: const <String>[chinaTag],
        fillExcludedCareerTags: const <String>[tourCardTag],
        tournamentTagRules: const <CareerTournamentTagRule>[
          CareerTournamentTagRule(
            tagName: worldChampChinaQualifierTag,
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ),
        ],
      ),
      _knockoutEvent(
        id: 'pdc-world-championship',
        name: 'World Championship',
        fieldSize: 128,
        prizePool: 5000000,
        matchMode: MatchMode.sets,
        legsToWin: 3,
        setsToWin: 3,
        legsPerSet: 5,
        roundDistanceValues: const <int>[3, 3, 4, 4, 5, 6, 7],
        countsForRankingIds: const <String>[pdcRankingId],
        seedingRankingId: pdcRankingId,
        seedCount: 32,
        qualificationConditions: const <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: pdcRankingId,
            fromRank: 1,
            toRank: 64,
            slotCount: 64,
          ),
          CareerQualificationCondition(
            rankingId: challengeTourRankingId,
            fromRank: 1,
            toRank: 2,
            slotCount: 2,
          ),
          CareerQualificationCondition(
            rankingId: developmentTourRankingId,
            fromRank: 1,
            toRank: 2,
            slotCount: 2,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldChampAsiaQualifierTag],
            slotCount: 1,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldChampAsianTourQualifierTag],
            slotCount: 1,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldChampNorthAmericaQualifierTag],
            slotCount: 1,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldChampOceaniaQualifierTag],
            slotCount: 1,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[worldChampChinaQualifierTag],
            slotCount: 1,
          ),
        ],
        fillRankingId: proTourRankingId,
        fillTopByRankingCount: 55,
        fillRequiredCareerTags: const <String>[tourCardTag],
      ),
    ];

    return CareerTemplate(
      id: builtInPdcBasicTemplateId,
      name: 'PDC Basic',
      participantMode: CareerParticipantMode.cpuOnly,
      databasePlayers: databasePlayers,
      careerTagDefinitions: tagDefinitions,
      seasonTagRules: const <CareerSeasonTagRule>[
        CareerSeasonTagRule(
          id: 'pdc-season-associate-q-school-top-32',
          tagName: associateTag,
          rankingId: qSchoolRankingId,
          fromRank: 1,
          toRank: 32,
          action: CareerSeasonTagRuleAction.add,
        ),
        CareerSeasonTagRule(
          id: 'pdc-season-tour-card-top-64',
          tagName: tourCardTag,
          rankingId: pdcRankingId,
          fromRank: 1,
          toRank: 64,
          action: CareerSeasonTagRuleAction.add,
        ),
        CareerSeasonTagRule(
          id: 'pdc-season-tour-card-challenge-top-2',
          tagName: tourCardTag,
          rankingId: challengeTourRankingId,
          fromRank: 1,
          toRank: 2,
          action: CareerSeasonTagRuleAction.add,
        ),
        CareerSeasonTagRule(
          id: 'pdc-season-tour-card-development-top-2',
          tagName: tourCardTag,
          rankingId: developmentTourRankingId,
          fromRank: 1,
          toRank: 2,
          action: CareerSeasonTagRuleAction.add,
        ),
        CareerSeasonTagRule(
          id: 'pdc-season-premier-league-invite-top-8',
          tagName: premierLeagueInviteTag,
          rankingId: pdcRankingId,
          fromRank: 1,
          toRank: 8,
          action: CareerSeasonTagRuleAction.add,
        ),
        CareerSeasonTagRule(
          id: 'pdc-season-world-series-invite-top-8',
          tagName: worldSeriesInviteTag,
          rankingId: pdcRankingId,
          fromRank: 1,
          toRank: 8,
          action: CareerSeasonTagRuleAction.add,
        ),
      ],
      rankings: rankings,
      calendar: calendar,
    );
  }

  List<CareerCalendarItem> _buildEuropeanTourWeekend({
    required _PdcEuropeanTourStop stop,
    required String pdcRankingId,
    required String proTourRankingId,
    required String europeanTourRankingId,
    required String tourCardTag,
    required String hostNationTag,
    required String associateTag,
    required String nordicBalticTag,
    required String eastEuropeTag,
  }) {
    final tourCardQualifierTag = '${stop.name} Tour Card Qualifier';
    final hostQualifierTag = '${stop.name} Host Nation Qualifier';
    final nordicQualifierTag = '${stop.name} Nordic/Baltic Qualifier';
    final eastEuropeQualifierTag = '${stop.name} East Europe Qualifier';
    return <CareerCalendarItem>[
      _knockoutEvent(
        id: '${stop.id}-tour-card-qualifier-a',
        name: '${stop.name} Tour Card Holder Qualifier A',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            excludedCareerTags: <String>[tourCardQualifierTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[tourCardQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: tourCardQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: tourCardQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-tour-card-qualifier-b',
        name: '${stop.name} Tour Card Holder Qualifier B',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            excludedCareerTags: <String>[tourCardQualifierTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[tourCardQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: tourCardQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: tourCardQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-tour-card-qualifier-c',
        name: '${stop.name} Tour Card Holder Qualifier C',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            excludedCareerTags: <String>[tourCardQualifierTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[tourCardQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: tourCardQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: tourCardQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-tour-card-qualifier-d',
        name: '${stop.name} Tour Card Holder Qualifier D',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            excludedCareerTags: <String>[tourCardQualifierTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[tourCardQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: tourCardQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: tourCardQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-tour-card-qualifier-e',
        name: '${stop.name} Tour Card Holder Qualifier E',
        fieldSize: 32,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardTag],
            excludedCareerTags: <String>[tourCardQualifierTag],
            slotCount: 32,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[tourCardQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: tourCardQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: tourCardQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-host-nation-qualifier-a',
        name: '${stop.name} Host Nation Qualifier A',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[hostNationTag],
            excludedCareerTags: <String>[tourCardTag, hostQualifierTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: <String>[hostNationTag],
        fillExcludedCareerTags: <String>[tourCardTag, hostQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: hostQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: hostQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-host-nation-qualifier-b',
        name: '${stop.name} Host Nation Qualifier B',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[hostNationTag],
            excludedCareerTags: <String>[tourCardTag, hostQualifierTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: <String>[hostNationTag],
        fillExcludedCareerTags: <String>[tourCardTag, hostQualifierTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: hostQualifierTag),
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.runnerUp,
          ).copyWith(tagName: hostQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-nordic-baltic-qualifier',
        name: '${stop.name} Nordic/Baltic Qualifier',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nordicBalticTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: <String>[nordicBalticTag],
        fillExcludedCareerTags: <String>[tourCardTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: nordicQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: '${stop.id}-east-europe-qualifier',
        name: '${stop.name} East Europe Qualifier',
        fieldSize: 16,
        prizePool: 0,
        legsToWin: 5,
        countsForRankingIds: const <String>[],
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[eastEuropeTag],
            excludedCareerTags: <String>[tourCardTag],
            slotCount: 16,
          ),
        ],
        fillRequiredCareerTags: <String>[eastEuropeTag],
        fillExcludedCareerTags: <String>[tourCardTag],
        tournamentTagRules: <CareerTournamentTagRule>[
          const CareerTournamentTagRule(
            tagName: '',
            action: CareerTournamentTagRuleAction.add,
            target: CareerTournamentTagRuleTarget.winner,
          ).copyWith(tagName: eastEuropeQualifierTag),
        ],
      ),
      _knockoutEvent(
        id: stop.id,
        name: stop.name,
        fieldSize: 48,
        prizePool: 175000,
        countsForRankingIds: <String>[
          pdcRankingId,
          proTourRankingId,
          europeanTourRankingId,
        ],
        seedingRankingId: pdcRankingId,
        seedCount: 16,
        qualificationConditions: <CareerQualificationCondition>[
          CareerQualificationCondition(
            rankingId: pdcRankingId,
            fromRank: 1,
            toRank: 16,
            entryRound: 2,
            slotCount: 16,
          ),
          CareerQualificationCondition(
            rankingId: proTourRankingId,
            fromRank: 1,
            toRank: 16,
            slotCount: 16,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[tourCardQualifierTag],
            slotCount: 10,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[hostQualifierTag],
            slotCount: 4,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[nordicQualifierTag],
            slotCount: 1,
          ),
          CareerQualificationCondition(
            type: CareerQualificationConditionType.careerTagOnly,
            requiredCareerTags: <String>[eastEuropeQualifierTag],
            slotCount: 1,
          ),
        ],
        fillRequiredCareerTags: <String>[tourCardTag],
        fillExcludedCareerTags: <String>[associateTag],
        fillRankingId: proTourRankingId,
        fillTopByRankingCount: 10,
      ),
    ];
  }

  bool _hasSourceTag(ComputerPlayer player, String tagName) {
    return player.tags.any(
      (entry) => entry.toLowerCase() == tagName.toLowerCase(),
    );
  }

  bool _isDevelopmentEligible(ComputerPlayer player) {
    final age = player.age;
    return age != null && age >= 16 && age <= 24;
  }

  bool _isNordicBaltic(ComputerPlayer player) {
    const nationalities = <String>{
      'Denmark',
      'Estonia',
      'Finland',
      'Iceland',
      'Latvia',
      'Lithuania',
      'Norway',
      'Sweden',
    };
    return _matchesNationality(player, nationalities);
  }

  bool _isEastEurope(ComputerPlayer player) {
    const nationalities = <String>{
      'Bulgaria',
      'Croatia',
      'Czech Republic',
      'Hungary',
      'Poland',
      'Romania',
      'Serbia',
      'Slovakia',
      'Slovenia',
    };
    return _matchesNationality(player, nationalities);
  }

  bool _isAsian(ComputerPlayer player) {
    const nationalities = <String>{
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
    };
    return _matchesNationality(player, nationalities);
  }

  bool _isNorthAmerican(ComputerPlayer player) {
    const nationalities = <String>{
      'Canada',
      'Mexico',
      'United States',
      'USA',
    };
    return _matchesNationality(player, nationalities);
  }

  bool _isOceanian(ComputerPlayer player) {
    const nationalities = <String>{
      'Australia',
      'New Zealand',
    };
    return _matchesNationality(player, nationalities);
  }

  bool _isChinese(ComputerPlayer player) {
    const nationalities = <String>{
      'China',
    };
    return _matchesNationality(player, nationalities);
  }

  bool _matchesNationality(ComputerPlayer player, Set<String> nationalities) {
    final nationality = player.nationality?.trim();
    if (nationality == null || nationality.isEmpty) {
      return false;
    }
    return nationalities.any(
      (entry) => entry.toLowerCase() == nationality.toLowerCase(),
    );
  }

  List<String> _hostNationCareerTags({
    required ComputerPlayer player,
    required Map<String, String> hostNationTags,
  }) {
    final nationality = player.nationality?.trim();
    if (nationality == null || nationality.isEmpty) {
      return const <String>[];
    }
    for (final entry in hostNationTags.entries) {
      if (entry.key.toLowerCase() == nationality.toLowerCase()) {
        return <String>[entry.value];
      }
    }
    return const <String>[];
  }

  List<CareerCalendarItem> _buildSeries({
    required String idPrefix,
    required String namePrefix,
    required int count,
    required int startIndex,
    required int fieldSize,
    required int prizePool,
    required List<String> countsForRankingIds,
    String? seedingRankingId,
    int seedCount = 0,
    MatchMode matchMode = MatchMode.legs,
    int legsToWin = 6,
    int setsToWin = 1,
    int legsPerSet = 1,
    List<int> roundDistanceValues = const <int>[],
    List<CareerQualificationCondition> qualificationConditions =
        const <CareerQualificationCondition>[],
    List<CareerTournamentTagRule> tournamentTagRules =
        const <CareerTournamentTagRule>[],
    List<String> fillRequiredCareerTags = const <String>[],
    List<String> fillExcludedCareerTags = const <String>[],
    String? fillRankingId,
    int fillTopByRankingCount = 0,
    int fillTopByAverageCount = 0,
  }) {
    return List<CareerCalendarItem>.generate(
      count,
      (index) {
        final number = startIndex + index;
        return _knockoutEvent(
          id: '$idPrefix-$number',
          name: '$namePrefix $number',
          fieldSize: fieldSize,
          prizePool: prizePool,
          matchMode: matchMode,
          legsToWin: legsToWin,
          setsToWin: setsToWin,
          legsPerSet: legsPerSet,
          roundDistanceValues: roundDistanceValues,
          countsForRankingIds: countsForRankingIds,
          seedingRankingId: seedingRankingId,
          seedCount: seedCount,
          qualificationConditions: qualificationConditions,
          tournamentTagRules: tournamentTagRules,
          fillRequiredCareerTags: fillRequiredCareerTags,
          fillExcludedCareerTags: fillExcludedCareerTags,
          fillRankingId: fillRankingId,
          fillTopByRankingCount: fillTopByRankingCount,
          fillTopByAverageCount: fillTopByAverageCount,
        );
      },
    );
  }

  CareerCalendarItem _knockoutEvent({
    required String id,
    required String name,
    required int fieldSize,
    required int prizePool,
    required List<String> countsForRankingIds,
    String? seedingRankingId,
    int seedCount = 0,
    MatchMode matchMode = MatchMode.legs,
    int legsToWin = 6,
    int setsToWin = 1,
    int legsPerSet = 1,
    List<int> roundDistanceValues = const <int>[],
    List<CareerQualificationCondition> qualificationConditions =
        const <CareerQualificationCondition>[],
    List<CareerTournamentTagRule> tournamentTagRules =
        const <CareerTournamentTagRule>[],
    List<String> fillRequiredCareerTags = const <String>[],
    List<String> fillExcludedCareerTags = const <String>[],
    String? fillRankingId,
    int fillTopByRankingCount = 0,
    int fillTopByAverageCount = 0,
  }) {
    final roundCount = _roundCountForFieldSize(fieldSize);
    return CareerCalendarItem(
      id: id,
      name: name,
      game: TournamentGame.x01,
      format: TournamentFormat.knockout,
      fieldSize: fieldSize,
      matchMode: matchMode,
      legsToWin: legsToWin,
      startScore: 501,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      prizePool: prizePool,
      knockoutPrizeValues: List<int>.filled(roundCount + 1, 0),
      setsToWin: setsToWin,
      legsPerSet: legsPerSet,
      roundDistanceValues: roundDistanceValues.isEmpty
          ? List<int>.generate(
              roundCount,
              (index) => index == roundCount - 1
                  ? 10
                  : index == roundCount - 2
                      ? 8
                      : 6,
            )
          : roundDistanceValues,
      countsForRankingIds: countsForRankingIds,
      seedingRankingId: seedingRankingId,
      seedCount: seedCount,
      qualificationConditions: qualificationConditions,
      tournamentTagRules: tournamentTagRules,
      fillRequiredCareerTags: fillRequiredCareerTags,
      fillExcludedCareerTags: fillExcludedCareerTags,
      fillRankingId: fillRankingId,
      fillTopByRankingCount: fillTopByRankingCount,
      fillTopByAverageCount: fillTopByAverageCount,
    );
  }

  int _roundCountForFieldSize(int fieldSize) {
    var rounds = 0;
    var size = 1;
    while (size < fieldSize) {
      size *= 2;
      rounds += 1;
    }
    return rounds;
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, dynamic>{
        'templates': _templates.map((entry) => entry.toJson()).toList(),
      },
    );
  }
}

class _PdcEuropeanTourStop {
  const _PdcEuropeanTourStop({
    required this.id,
    required this.name,
    required this.hostNation,
  });

  final String id;
  final String name;
  final String hostNation;
}

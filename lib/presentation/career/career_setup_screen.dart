import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models/computer_player.dart';
import '../../data/models/generated_name_catalog.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/career_repository.dart';
import '../../data/repositories/career_template_repository.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/career/career_models.dart';
import '../../domain/career/career_template.dart';
import '../../domain/rankings/ranking_engine.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import 'widgets/career_editor_section_card.dart';
import 'widgets/career_rankings_editor.dart';
import 'widgets/career_roster_editor.dart';
import 'widgets/career_roster_add_players_section.dart';
import 'widgets/career_roster_list_section.dart';
import 'widgets/career_season_rules_editor.dart';
import 'widgets/career_tag_definition_editor.dart';
import 'widgets/career_tag_definitions_list.dart';
import 'widgets/career_tournament_editor.dart';
import 'widgets/career_tournament_prize_editor.dart';
import 'widgets/career_validation_panel.dart';
import '../tournament/tournament_basics_form.dart';
import '../tournament/tournament_form_models.dart';

class CareerSetupScreen extends StatefulWidget {
  const CareerSetupScreen({
    super.key,
    this.creationMode = CareerCreationMode.expert,
  });

  final CareerCreationMode creationMode;

  @override
  State<CareerSetupScreen> createState() => _CareerSetupScreenState();
}

enum CareerCreationMode {
  simple,
  expert,
}

class _CareerRosterViewData {
  const _CareerRosterViewData({
    required this.availableTags,
    required this.addablePlayers,
  });

  final List<String> availableTags;
  final List<ComputerPlayer> addablePlayers;
}

class _SimpleQuickTourBlueprint {
  const _SimpleQuickTourBlueprint({
    required this.id,
    required this.baseName,
    required this.categoryName,
    required this.format,
    required this.tier,
    required this.fieldSize,
    required this.legsToWin,
    required this.prizePool,
    required this.seedCount,
    this.isSeries = false,
    this.roundRobinRepeats = 1,
    this.playoffQualifierCount = 4,
    this.countsForMajorRace = false,
  });

  final String id;
  final String baseName;
  final String categoryName;
  final TournamentFormat format;
  final int tier;
  final int fieldSize;
  final int legsToWin;
  final int prizePool;
  final int seedCount;
  final bool isSeries;
  final int roundRobinRepeats;
  final int playoffQualifierCount;
  final bool countsForMajorRace;
}

class _SimpleQuickTourTypeConfig {
  const _SimpleQuickTourTypeConfig({
    required this.count,
    this.customName,
    this.prizeSplitPreset = CareerTournamentPrizeSplitPreset.proTour,
    this.fieldSizeOverride,
    this.prizePoolOverride,
    this.knockoutPrizeValues = const <int>[],
    this.leaguePositionPrizeValues = const <int>[],
  });

  final int count;
  final String? customName;
  final CareerTournamentPrizeSplitPreset prizeSplitPreset;
  final int? fieldSizeOverride;
  final int? prizePoolOverride;
  final List<int> knockoutPrizeValues;
  final List<int> leaguePositionPrizeValues;

  _SimpleQuickTourTypeConfig copyWith({
    int? count,
    String? customName,
    CareerTournamentPrizeSplitPreset? prizeSplitPreset,
    int? fieldSizeOverride,
    int? prizePoolOverride,
    List<int>? knockoutPrizeValues,
    List<int>? leaguePositionPrizeValues,
    bool clearCustomName = false,
    bool clearFieldSizeOverride = false,
    bool clearPrizePoolOverride = false,
  }) {
    return _SimpleQuickTourTypeConfig(
      count: count ?? this.count,
      customName: clearCustomName ? null : (customName ?? this.customName),
      prizeSplitPreset: prizeSplitPreset ?? this.prizeSplitPreset,
      fieldSizeOverride: clearFieldSizeOverride
          ? null
          : (fieldSizeOverride ?? this.fieldSizeOverride),
      prizePoolOverride: clearPrizePoolOverride
          ? null
          : (prizePoolOverride ?? this.prizePoolOverride),
      knockoutPrizeValues: knockoutPrizeValues ?? this.knockoutPrizeValues,
      leaguePositionPrizeValues:
          leaguePositionPrizeValues ?? this.leaguePositionPrizeValues,
    );
  }
}

class _SimpleQuickTournamentDraft {
  const _SimpleQuickTournamentDraft({
    required this.blueprintId,
    required this.config,
  });

  final String blueprintId;
  final _SimpleQuickTourTypeConfig config;
}

class _SimpleQuickTournamentAddPage extends StatefulWidget {
  const _SimpleQuickTournamentAddPage({
    required this.addableBlueprints,
    required this.host,
    required this.rosterSize,
  });

  final List<_SimpleQuickTourBlueprint> addableBlueprints;
  final _CareerSetupScreenState host;
  final int rosterSize;

  @override
  State<_SimpleQuickTournamentAddPage> createState() =>
      _SimpleQuickTournamentAddPageState();
}

class _SimpleQuickTournamentAddPageState
    extends State<_SimpleQuickTournamentAddPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _countController;
  late final TextEditingController _fieldSizeController;
  late final TextEditingController _prizePoolController;
  late String _selectedBlueprintId;
  late CareerTournamentPrizeSplitPreset _selectedPreset;
  List<int> _knockoutPrizeValues = <int>[];
  List<int> _leaguePrizeValues = <int>[];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _countController = TextEditingController();
    _fieldSizeController = TextEditingController();
    _prizePoolController = TextEditingController();
    _selectedBlueprintId = widget.addableBlueprints.first.id;
    _selectedPreset = CareerTournamentPrizeSplitPreset.proTour;
    _syncDraftWithBlueprint(resetName: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _countController.dispose();
    _fieldSizeController.dispose();
    _prizePoolController.dispose();
    super.dispose();
  }

  _SimpleQuickTourBlueprint get _selectedBlueprint => widget.addableBlueprints
      .firstWhere((blueprint) => blueprint.id == _selectedBlueprintId);

  int get _fieldSize => int.tryParse(_fieldSizeController.text.trim()) ?? 0;
  int get _prizePool => int.tryParse(_prizePoolController.text.trim()) ?? 0;

  int get _playoffQualifierCount =>
      _selectedBlueprint.format == TournamentFormat.leaguePlayoff
          ? widget.host._quickPlayoffQualifierCountForFieldSize(
              fieldSize: _fieldSize,
              requestedQualifierCount: _selectedBlueprint.playoffQualifierCount,
            )
          : _selectedBlueprint.playoffQualifierCount;

  void _syncDraftWithBlueprint({required bool resetName}) {
    final blueprint = _selectedBlueprint;
    final fieldSize = widget.host._quickFieldSizeForBlueprint(
      blueprint: blueprint,
      rosterSize: widget.rosterSize,
    );
    final prizePool = widget.host._quickPrizePoolForFieldSize(
      blueprint: blueprint,
      fieldSize: fieldSize,
    );
    final playoffQualifierCount = blueprint.format == TournamentFormat.leaguePlayoff
        ? widget.host._quickPlayoffQualifierCountForFieldSize(
            fieldSize: fieldSize,
            requestedQualifierCount: blueprint.playoffQualifierCount,
          )
        : blueprint.playoffQualifierCount;
    _countController.text =
        '${widget.host._defaultSimpleQuickCountForBlueprint(blueprint.id)}';
    _fieldSizeController.text = '$fieldSize';
    _prizePoolController.text = '$prizePool';
    _selectedPreset = CareerTournamentPrizeSplitPreset.proTour;
    _knockoutPrizeValues = widget.host._defaultQuickKnockoutPrizeValues(
      preset: _selectedPreset,
      prizePool: prizePool,
      stageCount: widget.host._quickKnockoutStageCount(
        blueprint: blueprint,
        fieldSize: fieldSize,
        playoffQualifierCount: playoffQualifierCount,
      ),
      format: blueprint.format,
    );
    _leaguePrizeValues = widget.host._defaultQuickLeaguePrizeValues(
      preset: _selectedPreset,
      prizePool: prizePool,
      placeCount: widget.host._quickLeaguePrizePlaceCount(
        blueprint: blueprint,
        fieldSize: fieldSize,
      ),
      format: blueprint.format,
    );
    if (resetName) {
      _nameController.clear();
    }
  }

  void _applyPreset() {
    final blueprint = _selectedBlueprint;
    final prizePool = _prizePool;
    final fieldSize = _fieldSize;
    final playoffQualifierCount = _playoffQualifierCount;
    setState(() {
      _knockoutPrizeValues = widget.host._defaultQuickKnockoutPrizeValues(
        preset: _selectedPreset,
        prizePool: prizePool,
        stageCount: widget.host._quickKnockoutStageCount(
          blueprint: blueprint,
          fieldSize: fieldSize,
          playoffQualifierCount: playoffQualifierCount,
        ),
        format: blueprint.format,
      );
      _leaguePrizeValues = widget.host._defaultQuickLeaguePrizeValues(
        preset: _selectedPreset,
        prizePool: prizePool,
        placeCount: widget.host._quickLeaguePrizePlaceCount(
          blueprint: blueprint,
          fieldSize: fieldSize,
        ),
        format: blueprint.format,
      );
    });
  }

  _SimpleQuickTourTypeConfig _buildConfig() {
    return _SimpleQuickTourTypeConfig(
      count: max(0, int.tryParse(_countController.text.trim()) ?? 0),
      customName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      prizeSplitPreset: _selectedPreset,
      fieldSizeOverride: _fieldSize > 0 ? _fieldSize : null,
      prizePoolOverride: _prizePool > 0 ? _prizePool : null,
      knockoutPrizeValues: List<int>.from(_knockoutPrizeValues),
      leaguePositionPrizeValues: List<int>.from(_leaguePrizeValues),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blueprint = _selectedBlueprint;
    final stageCount = widget.host._quickKnockoutStageCount(
      blueprint: blueprint,
      fieldSize: _fieldSize,
      playoffQualifierCount: _playoffQualifierCount,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick-Turnier'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DropdownButtonFormField<String>(
              value: _selectedBlueprintId,
              decoration: const InputDecoration(
                labelText: 'Turnierart',
              ),
              items: widget.addableBlueprints
                  .map(
                    (blueprint) => DropdownMenuItem<String>(
                      value: blueprint.id,
                      child: Text(blueprint.categoryName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedBlueprintId = value;
                  _syncDraftWithBlueprint(resetName: false);
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Optionaler Anzeigename',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Anzahl',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _fieldSizeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Teilnehmerfeld',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prizePoolController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Preisgeld',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CareerTournamentPrizeSplitPreset>(
              value: _selectedPreset,
              decoration: const InputDecoration(
                labelText: 'Preisgeld-Share',
              ),
              items: CareerTournamentPrizeSplitPreset.values
                  .map(
                    (preset) => DropdownMenuItem<
                        CareerTournamentPrizeSplitPreset>(
                      value: preset,
                      child: Text(preset.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _selectedPreset = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: _applyPreset,
                child: const Text('Preset anwenden'),
              ),
            ),
            if (_knockoutPrizeValues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'KO-Auszahlungen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List<Widget>.generate(_knockoutPrizeValues.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: ValueKey<String>(
                            'add-quick-ko-value-${blueprint.id}-$index-${_knockoutPrizeValues[index]}',
                          ),
                          controller: TextEditingController(
                            text: '${_knockoutPrizeValues[index]}',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsed = int.tryParse(value.trim()) ?? 0;
                            setState(() {
                              _knockoutPrizeValues[index] = parsed < 0 ? 0 : parsed;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: widget.host._quickKnockoutPrizeLabel(
                              index,
                              stageCount,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: ValueKey<String>(
                            'add-quick-ko-share-${blueprint.id}-$index-${_knockoutPrizeValues[index]}',
                          ),
                          controller: TextEditingController(
                            text: widget.host
                                ._quickKnockoutSharePercent(
                                  values: _knockoutPrizeValues,
                                  index: index,
                                  format: blueprint.format,
                                )
                                .toStringAsFixed(1),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            final parsed =
                                double.tryParse(value.trim().replaceAll(',', '.'));
                            if (parsed == null) {
                              return;
                            }
                            setState(() {
                              _knockoutPrizeValues = widget.host
                                  ._quickKnockoutValuesWithSharePercent(
                                values: _knockoutPrizeValues,
                                index: index,
                                sharePercent: parsed,
                                prizePool: _prizePool,
                                format: blueprint.format,
                              );
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Share %',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (_leaguePrizeValues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Liga-Auszahlungen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...List<Widget>.generate(_leaguePrizeValues.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: ValueKey<String>(
                            'add-quick-league-value-${blueprint.id}-$index-${_leaguePrizeValues[index]}',
                          ),
                          controller: TextEditingController(
                            text: '${_leaguePrizeValues[index]}',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            final parsed = int.tryParse(value.trim()) ?? 0;
                            setState(() {
                              _leaguePrizeValues[index] = parsed < 0 ? 0 : parsed;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: '${index + 1}. Platz',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: ValueKey<String>(
                            'add-quick-league-share-${blueprint.id}-$index-${_leaguePrizeValues[index]}',
                          ),
                          controller: TextEditingController(
                            text: widget.host
                                ._quickLeagueSharePercent(
                                  values: _leaguePrizeValues,
                                  index: index,
                                )
                                .toStringAsFixed(1),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (value) {
                            final parsed =
                                double.tryParse(value.trim().replaceAll(',', '.'));
                            if (parsed == null) {
                              return;
                            }
                            setState(() {
                              _leaguePrizeValues =
                                  widget.host._quickLeagueValuesWithSharePercent(
                                values: _leaguePrizeValues,
                                index: index,
                                sharePercent: parsed,
                                prizePool: _prizePool,
                                format: blueprint.format,
                              );
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Share %',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _SimpleQuickTournamentDraft(
                    blueprintId: _selectedBlueprintId,
                    config: _buildConfig(),
                  ),
                );
              },
              child: const Text('Hinzufuegen'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TemplateCareerPoolMode {
  empty,
  allDatabasePlayers,
  selectedDatabasePlayers,
}

enum _CareerSetupStep {
  grundlagen,
  kader,
  ranglisten,
  tagsRegeln,
  turniere,
  kalender,
  pruefen,
}

enum _CareerRosterSubstep {
  pool,
  training,
  spieler,
}

enum _CareerTournamentSubstep {
  basics,
  quali,
  preisgeld,
  serie,
}

enum _CareerStructurePreset {
  custom,
  pdcLike,
  developmentFocus,
}

enum _CareerTournamentAccessPreset {
  custom,
  open,
  top64OrderOfMerit,
  tourCardOnly,
  challengeTourOnly,
  developmentTourOnly,
  womensSeriesOnly,
  hostNationOnly,
}

class _CareerSetupScreenState extends State<CareerSetupScreen> {
  final CareerRepository _repository = CareerRepository.instance;
  final CareerTemplateRepository _templateRepository =
      CareerTemplateRepository.instance;
  final PlayerRepository _playerRepository = PlayerRepository.instance;
  final ComputerRepository _computerRepository = ComputerRepository.instance;

  final TextEditingController _careerNameController = TextEditingController();
  final TextEditingController _templateNameController = TextEditingController();
  final TextEditingController _rankingNameController = TextEditingController();
  final TextEditingController _rankingValidSeasonsController =
      TextEditingController(text: '1');
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _prizePoolController =
      TextEditingController(text: '12500');
  final TextEditingController _seriesCountController =
      TextEditingController(text: '1');
  final TextEditingController _qualificationFromController =
      TextEditingController(text: '1');
  final TextEditingController _qualificationToController =
      TextEditingController(text: '16');
  final TextEditingController _qualificationEntryRoundController =
      TextEditingController(text: '1');
  final TextEditingController _qualificationSlotCountController =
      TextEditingController();
  final TextEditingController _fillTopByRankingController =
      TextEditingController();
  final TextEditingController _fillTopByAverageController =
      TextEditingController();
  final TextEditingController _databasePlayerTagsController =
      TextEditingController();
  final TextEditingController _careerRosterTagsController =
      TextEditingController();
  final TextEditingController _trainingMinAverageController =
      TextEditingController();
  final TextEditingController _trainingMaxAverageController =
      TextEditingController();
  final TextEditingController _simpleTargetRosterSizeController =
      TextEditingController(text: '32');
  final TextEditingController _careerTagNameController = TextEditingController();
  final TextEditingController _careerTagAttributesController =
      TextEditingController();
  final TextEditingController _careerTagLimitController =
      TextEditingController();
  final TextEditingController _careerTagInitialValidityController =
      TextEditingController();
  final TextEditingController _careerTagExtensionValidityController =
      TextEditingController();
  final TextEditingController _careerTagAddOnExpiryController =
      TextEditingController();
  final TextEditingController _careerTagRemoveOnInitialController =
      TextEditingController();
  final TextEditingController _careerTagRemoveOnExtensionController =
      TextEditingController();
  final TextEditingController _seasonTagRuleFromController =
      TextEditingController(text: '1');
  final TextEditingController _seasonTagRuleToController =
      TextEditingController(text: '1');
  final TextEditingController _seasonTagRuleReferenceRankController =
      TextEditingController();
  final TextEditingController _seasonTagRuleCheckRemainingController =
      TextEditingController();
  final TextEditingController _tournamentTagGateMinimumController =
      TextEditingController();

  CareerParticipantMode _participantMode = CareerParticipantMode.withHuman;
  String? _selectedPlayerProfileId;
  bool _replaceWeakestPlayerWithHuman = true;
  int _rankingValidSeasons = 1;
  bool _rankingResetAtSeasonEnd = false;
  String? _editingRankingId;
  CareerSeasonTagRuleAction _seasonTagRuleAction =
      CareerSeasonTagRuleAction.add;
  CareerQualificationConditionType _qualificationConditionType =
      CareerQualificationConditionType.rankingRange;
  CareerSeasonTagRuleRankMode _seasonTagRuleRankMode =
      CareerSeasonTagRuleRankMode.range;
  CareerSeasonTagRuleCheckMode _seasonTagRuleCheckMode =
      CareerSeasonTagRuleCheckMode.none;
  TournamentFormData _tournamentFormData = const TournamentFormData();
  int _seedCount = 0;
  String? _selectedTemplateId;
  String? _seedingRankingId;
  String? _qualificationRankingId;
  String? _fillRankingId;
  String? _selectedDatabasePlayerId;
  String? _editingCareerTagId;
  String? _editingSeasonTagRuleId;
  String? _selectedTrainingPoolTagName;
  bool _isTrainingModeExpanded = false;
  String? _selectedSeasonTagRuleTagName;
  String? _selectedSeasonTagRuleRankingId;
  String? _selectedSeasonTagRuleCheckTagName;
  String? _selectedTournamentTagGateTagName;
  bool _tournamentOccursWhenTagGateMet = true;
  bool _showAdvancedTournamentRules = false;
  bool _showAdvancedTournamentSeries = false;
  bool _showAdvancedTagRules = false;
  bool _showExistingTagDefinitions = false;
  bool _showAdvancedCalendarDetails = false;
  CareerTournamentPrizeSplitPreset _selectedPrizeSplitPreset =
      CareerTournamentPrizeSplitPreset.proTour;
  String? _lastCareerId;
  String? _editingCalendarItemId;
  final Set<String> _selectedRankingIds = <String>{};
  final Set<String> _selectedDatabasePlayerIds = <String>{};
  final Set<String> _selectedCareerRosterPlayerIds = <String>{};
  final Set<String> _selectedDatabaseTagFilters = <String>{};
  final Set<String> _selectedTemplateDatabasePlayerIds = <String>{};
  final Set<String> _selectedTemplateDatabaseTagFilters = <String>{};
  final Map<String, CareerDatabasePlayer> _simpleTemplateTrainingOverrides =
      <String, CareerDatabasePlayer>{};
  final Map<String, _SimpleQuickTourTypeConfig> _simpleQuickTourConfigs =
      <String, _SimpleQuickTourTypeConfig>{};
  final Set<String> _simpleQuickSelectedBlueprintIds = <String>{};
  bool _simpleQuickTournamentGenerationEnabled = true;
  final Set<TournamentFormat> _simpleQuickFormats = <TournamentFormat>{
    TournamentFormat.knockout,
    TournamentFormat.league,
    TournamentFormat.leaguePlayoff,
  };
  bool _simpleQuickIncludeSeries = true;
  bool _simpleQuickIncludeStandalone = true;
  bool _showAdvancedCreation = false;
  bool _creationModeApplied = false;
  bool _isBusy = false;
  String _busyMessage = '';
  double? _busyProgress;
  final Set<String> _selectedQualificationTagNames = <String>{};
  final Set<String> _selectedQualificationExcludedTagNames = <String>{};
  final Set<String> _selectedQualificationNationalities = <String>{};
  final Set<String> _selectedQualificationExcludedNationalities = <String>{};
  final Set<String> _selectedFillTagNames = <String>{};
  final Set<String> _selectedFillExcludedTagNames = <String>{};
  final Set<String> _selectedFillNationalities = <String>{};
  final Set<String> _selectedFillExcludedNationalities = <String>{};
  bool _fillAutoGeneratePlayers = false;
  final List<CareerGeneratedAgeDistribution> _generatedFillAgeDistributions =
      <CareerGeneratedAgeDistribution>[];
  final List<CareerGeneratedNationalityDistribution>
      _generatedFillNationalityDistributions =
      <CareerGeneratedNationalityDistribution>[];
  final List<CareerQualificationCondition> _qualificationConditions =
      <CareerQualificationCondition>[];
  bool _createAsSeries = false;
  bool _expandLeagueIntoMatchdays = false;
  _TemplateCareerPoolMode _templateCareerPoolMode =
      _TemplateCareerPoolMode.allDatabasePlayers;
  _CareerSetupStep _setupStep = _CareerSetupStep.grundlagen;
  _CareerRosterSubstep _rosterSubstep = _CareerRosterSubstep.pool;
  _CareerTournamentSubstep _tournamentSubstep = _CareerTournamentSubstep.basics;
  _CareerStructurePreset _selectedCareerStructurePreset =
      _CareerStructurePreset.custom;
  _CareerTournamentAccessPreset _selectedTournamentAccessPreset =
      _CareerTournamentAccessPreset.custom;
  CareerLeagueSeriesQualificationMode _leagueSeriesQualificationMode =
      CareerLeagueSeriesQualificationMode.fixedAtStart;
  String? _editingSeriesGroupId;
  int? _editingSeriesIndex;
  int? _editingSeriesLength;
  CareerLeagueSeriesStage? _editingSeriesStage;
  List<int> _knockoutPrizeValues = <int>[];
  List<int> _leaguePositionPrizeValues = <int>[];

  @override
  void dispose() {
    _careerNameController.dispose();
    _templateNameController.dispose();
    _rankingNameController.dispose();
    _rankingValidSeasonsController.dispose();
    _itemNameController.dispose();
    _prizePoolController.dispose();
    _seriesCountController.dispose();
    _qualificationFromController.dispose();
    _qualificationToController.dispose();
    _qualificationEntryRoundController.dispose();
    _qualificationSlotCountController.dispose();
    _fillTopByRankingController.dispose();
    _fillTopByAverageController.dispose();
    _databasePlayerTagsController.dispose();
    _careerRosterTagsController.dispose();
    _trainingMinAverageController.dispose();
    _trainingMaxAverageController.dispose();
    _simpleTargetRosterSizeController.dispose();
    _careerTagNameController.dispose();
    _careerTagAttributesController.dispose();
    _careerTagLimitController.dispose();
    _careerTagInitialValidityController.dispose();
    _careerTagExtensionValidityController.dispose();
    _careerTagAddOnExpiryController.dispose();
    _careerTagRemoveOnInitialController.dispose();
    _careerTagRemoveOnExtensionController.dispose();
    _seasonTagRuleFromController.dispose();
    _seasonTagRuleToController.dispose();
    _seasonTagRuleReferenceRankController.dispose();
    _seasonTagRuleCheckRemainingController.dispose();
    _tournamentTagGateMinimumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _repository,
        _templateRepository,
        _playerRepository,
        _computerRepository,
      ]),
      builder: (context, _) {
        final careers = _repository.careers;
        final activeCareer = _repository.activeCareer;
        final templates = _templateRepository.templates;
        final players = _playerRepository.players;
        final databasePlayers = _computerRepository.players;

        if (_selectedPlayerProfileId == null && players.isNotEmpty) {
          _selectedPlayerProfileId = _playerRepository.activePlayer?.id ?? players.first.id;
        } else if (_selectedPlayerProfileId != null &&
            players.every((player) => player.id != _selectedPlayerProfileId)) {
          _selectedPlayerProfileId =
              players.isEmpty ? null : (_playerRepository.activePlayer?.id ?? players.first.id);
        }

        _syncCareerContext(activeCareer);
        if (_selectedTemplateId != null &&
            templates.every((template) => template.id != _selectedTemplateId)) {
          _selectedTemplateId = null;
        }
        if (_selectedDatabasePlayerId == null && databasePlayers.isNotEmpty) {
          _selectedDatabasePlayerId = databasePlayers.first.id;
        } else if (_selectedDatabasePlayerId != null &&
            databasePlayers.every(
              (player) => player.id != _selectedDatabasePlayerId,
            )) {
          _selectedDatabasePlayerId =
              databasePlayers.isEmpty ? null : databasePlayers.first.id;
        }
        if (!_creationModeApplied) {
          _creationModeApplied = true;
          _showAdvancedCreation =
              widget.creationMode == CareerCreationMode.expert;
        }

        return Stack(
          children: <Widget>[
            Scaffold(
              appBar: AppBar(
                title: const Text('Karriere planen'),
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: <Widget>[
                if (activeCareer == null)
                  ...<Widget>[
                    _buildUnifiedCreationCard(
                      context,
                      careers: careers,
                      activeCareer: activeCareer,
                      templates: templates,
                      players: players,
                    ),
                  ]
                else ...<Widget>[
                  _buildSetupStepper(context),
                  const SizedBox(height: 16),
                  _buildStepIntroCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildCurrentStepContent(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildStepNavigation(context, activeCareer),
                ],
                  ],
                ),
              ),
            ),
            if (_isBusy) ...<Widget>[
              const ModalBarrier(
                dismissible: false,
                color: Colors.black38,
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              value: _busyProgress,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _busyMessage,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_busyProgress != null) ...<Widget>[
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: _busyProgress,
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCareerCard(
    BuildContext context, {
    required List<CareerDefinition> careers,
    required CareerDefinition? activeCareer,
    required List<CareerTemplate> templates,
    required List<PlayerProfile> players,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Karrieren', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _careerNameController,
              decoration: const InputDecoration(labelText: 'Karrierename'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CareerParticipantMode>(
              key: ValueKey<CareerParticipantMode>(_participantMode),
              initialValue: _participantMode,
              decoration: const InputDecoration(labelText: 'Teilnehmermodus'),
              items: const <DropdownMenuItem<CareerParticipantMode>>[
                DropdownMenuItem(
                  value: CareerParticipantMode.withHuman,
                  child: Text('Mit mir'),
                ),
                DropdownMenuItem(
                  value: CareerParticipantMode.cpuOnly,
                  child: Text('Nur Computer'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _participantMode = value);
                }
              },
            ),
            if (_participantMode == CareerParticipantMode.withHuman) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedPlayerProfileId ?? 'no-player'),
                initialValue: _selectedPlayerProfileId,
                decoration: const InputDecoration(labelText: 'Spielerprofil'),
                items: players
                    .map(
                      (player) => DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(player.name),
                      ),
                    )
                    .toList(),
                onChanged: players.isEmpty
                    ? null
                    : (value) {
                        setState(() => _selectedPlayerProfileId = value);
                      },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _replaceWeakestPlayerWithHuman,
                onChanged: (value) {
                  setState(() => _replaceWeakestPlayerWithHuman = value);
                },
                title: const Text('Schwaechsten Spieler ersetzen'),
                subtitle: const Text(
                  'Dein Karriere-Spieler ersetzt im allgemeinen Teilnehmerpool den Computer-Spieler mit dem niedrigsten Average. Qualifikation und Setzlisten gelten danach weiterhin ganz normal.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _createOrCreateFromTemplate,
              icon: const Icon(Icons.add),
              label: const Text('Karriere erstellen'),
            ),
            if (templates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>(_selectedTemplateId),
                initialValue: _selectedTemplateId,
                decoration: const InputDecoration(labelText: 'Vorlage'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Keine Vorlage'),
                  ),
                  ...templates.map(
                    (template) => DropdownMenuItem<String?>(
                      value: template.id,
                      child: Text(template.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTemplateId = value;
                    _simpleTemplateTrainingOverrides.clear();
                    _selectedTrainingPoolTagName = null;
                    _trainingMinAverageController.clear();
                    _trainingMaxAverageController.clear();
                  });
                },
              ),
              if (_selectedTemplateId != null) ...<Widget>[
                const SizedBox(height: 12),
                _buildTemplatePoolSelector(context),
              ],
            ],
            const SizedBox(height: 16),
            if (careers.isEmpty)
              const Text('Noch keine Karriere vorhanden.')
            else
              ...careers.map((career) {
                final isActive = activeCareer?.id == career.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: ListTile(
                      title: Text(career.name),
                      subtitle: Text(
                        'Saison ${career.currentSeason.seasonNumber} | ${career.rankings.length} Ranglisten${career.playerProfileId != null ? ' | ${_playerName(career.playerProfileId!)}' : ''}${career.replaceWeakestPlayerWithHuman ? ' | mit Spielerprofil' : ''}',
                      ),
                      onTap: () {
                        _repository.setActiveCareer(career.id);
                        setState(() {});
                      },
                      trailing: IconButton(
                        onPressed: () {
                          _repository.deleteCareer(career.id);
                          setState(() {});
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStepper(BuildContext context) {
    final steps = _setupSteps;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Karriere-Editor',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Arbeite Schritt fuer Schritt. Auf Mobile bleibt so immer nur ein Hauptbereich offen, auf Desktop bleibt der Flow trotzdem klar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(steps.length, (index) {
                final step = steps[index];
                final selected = _setupStep == step;
                final completed = index < steps.indexOf(_setupStep);
                return ChoiceChip(
                  label: Text('${index + 1}. ${_stepLabel(step)}'),
                  selected: selected,
                  avatar: completed
                      ? const Icon(Icons.check_rounded, size: 16)
                      : null,
                  onSelected: (_) {
                    setState(() => _setSetupStep(step));
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIntroCard(BuildContext context, CareerDefinition career) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _stepLabel(_setupStep),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _stepDescription(_setupStep, career),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent(BuildContext context, CareerDefinition career) {
    switch (_setupStep) {
        case _CareerSetupStep.grundlagen:
            return Column(
              children: <Widget>[
                _buildCareerBasicsEditor(context, career),
                const SizedBox(height: 16),
                _buildCareerStructurePresetCard(context, career),
                const SizedBox(height: 16),
                _buildWizardSectionCard(
                  context,
                  title: 'Trainingsmodus',
                  subtitle:
                      'Passe den Karriere-Pool schon am Anfang an, bevor du tiefer in Ranglisten und Turniere gehst.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _isTrainingModeExpanded,
                        onChanged: (value) {
                          setState(() => _isTrainingModeExpanded = value);
                        },
                        title: const Text('Trainingsmodus aktivieren'),
                        subtitle: const Text(
                          'Blendet die Average-Spanne und die Pool-Auswahl fuer den fruehen Trainingsmodus ein.',
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _buildTrainingModeSection(career),
                        ),
                        crossFadeState: _isTrainingModeExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTemplateSelectionCard(context),
              ],
            );
      case _CareerSetupStep.kader:
        return _buildRosterStep(context, career);
      case _CareerSetupStep.ranglisten:
        return _buildRankingsCard(context, career);
      case _CareerSetupStep.tagsRegeln:
        return _buildCareerTagsCard(context, career);
      case _CareerSetupStep.turniere:
        return _buildTournamentStep(context, career);
      case _CareerSetupStep.kalender:
        return _buildCalendarCard(context, career);
        case _CareerSetupStep.pruefen:
          return Column(
            children: <Widget>[
              _buildValidationCard(context, career),
              const SizedBox(height: 16),
              _buildTemplatesCard(context, career),
              const SizedBox(height: 16),
              Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Abschluss',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pruefe noch einmal die Validierung und starte die Karriere danach direkt in die erste Saison.',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: career.currentSeason.calendar.isEmpty
                          ? null
                          : () {
                              _repository.startCareer();
                              Navigator.of(context).pushNamed(AppRoutes.careerDetail);
                            },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Karriere starten'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _buildStepNavigation(BuildContext context, CareerDefinition career) {
    final steps = _setupSteps;
    final currentIndex = steps.indexOf(_setupStep);
    final isFirst = currentIndex == 0;
    final isLast = currentIndex == steps.length - 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          spacing: 8,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: isFirst
                  ? null
                  : () {
                      setState(() {
                        _setSetupStep(steps[currentIndex - 1]);
                      });
                    },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Zurueck'),
            ),
            FilledButton.icon(
              onPressed: isLast
                  ? (career.currentSeason.calendar.isEmpty
                      ? null
                      : () {
                          _repository.startCareer();
                          Navigator.of(context).pushNamed(AppRoutes.careerDetail);
                        })
                  : () {
                      setState(() {
                        _setSetupStep(steps[currentIndex + 1]);
                      });
                    },
              icon: Icon(isLast ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded),
              label: Text(isLast ? 'Karriere starten' : 'Weiter'),
            ),
          ],
        ),
      ),
    );
  }

  List<_CareerSetupStep> get _setupSteps => <_CareerSetupStep>[
        _CareerSetupStep.grundlagen,
        _CareerSetupStep.ranglisten,
        _CareerSetupStep.tagsRegeln,
        _CareerSetupStep.turniere,
        _CareerSetupStep.kalender,
        _CareerSetupStep.kader,
        _CareerSetupStep.pruefen,
      ];

  String _stepLabel(_CareerSetupStep step) {
    switch (step) {
      case _CareerSetupStep.grundlagen:
        return 'Grundlagen';
      case _CareerSetupStep.kader:
        return 'Kader';
      case _CareerSetupStep.ranglisten:
        return 'Ranglisten';
      case _CareerSetupStep.tagsRegeln:
        return 'Tags & Regeln';
      case _CareerSetupStep.turniere:
        return 'Turniere';
      case _CareerSetupStep.kalender:
        return 'Kalender';
      case _CareerSetupStep.pruefen:
        return 'Pruefen';
    }
  }

  String _stepDescription(_CareerSetupStep step, CareerDefinition career) {
      switch (step) {
        case _CareerSetupStep.grundlagen:
          return 'Pruefe die Grunddaten von ${career.name} und arbeite mit Vorlagen, ohne gleich in alle Detailbereiche springen zu muessen.';
        case _CareerSetupStep.ranglisten:
          return 'Lege zuerst fest, welche Rankings die Karriere tragen und wie lange Geld- oder Punktergebnisse gueltig bleiben.';
        case _CareerSetupStep.tagsRegeln:
          return 'Hier definierst du die Rahmenbedingungen der Karriere: Tags, Auf- und Abstiege, Ablaufregeln und saisonale Automatik.';
        case _CareerSetupStep.turniere:
          return 'Baue danach die Turnierstruktur mit Formaten, Quali-Wege, Preisgeld und Serieneinstellungen auf.';
        case _CareerSetupStep.kalender:
          return 'Ordne die Saison im Kalender, pruefe die Reihenfolge und strukturiere den gesamten Ablauf der Karriere.';
        case _CareerSetupStep.kader:
          return 'Wenn die Karriere-Struktur steht, stellst du den Karriere-Pool zusammen, passt Training an und verwaltest die Spieler getrennt von der Hauptdatenbank.';
        case _CareerSetupStep.pruefen:
          return 'Zum Schluss bekommst du Validierung, Vorschau und den Start in die eigentliche Karriere.';
      }
  }

  String _rosterSubstepLabel(_CareerRosterSubstep step) {
    switch (step) {
      case _CareerRosterSubstep.pool:
        return 'Spieler waehlen';
      case _CareerRosterSubstep.training:
        return 'Training';
      case _CareerRosterSubstep.spieler:
        return 'Kader';
    }
  }

  String _rosterSubstepDescription(
    _CareerRosterSubstep step,
    CareerDefinition career,
  ) {
    switch (step) {
      case _CareerRosterSubstep.pool:
        return 'Waehle zuerst aus, welche Spieler ueberhaupt in diesem Karriere-Pool landen sollen.';
      case _CareerRosterSubstep.training:
        return 'Passe hier die Average-Spanne fuer den gewaehlten Pool gesammelt an und klappe den Bereich bei Bedarf direkt ein oder aus.';
      case _CareerRosterSubstep.spieler:
        return 'Zum Schluss verwaltest du nur noch die bereits hinzugefuegten Karriere-Spieler.';
    }
  }

  String _tournamentSubstepLabel(_CareerTournamentSubstep step) {
    switch (step) {
      case _CareerTournamentSubstep.basics:
        return 'Basics';
      case _CareerTournamentSubstep.quali:
        return 'Quali';
      case _CareerTournamentSubstep.preisgeld:
        return 'Wertung & Preisgeld';
      case _CareerTournamentSubstep.serie:
        return 'Erstellung beenden';
    }
  }

  String _tournamentSubstepDescription(
    _CareerTournamentSubstep step,
    CareerDefinition career,
  ) {
    switch (step) {
      case _CareerTournamentSubstep.basics:
        return 'Lege hier nur Format, Feldgroesse, Tier und Matchlogik des Turniers fest.';
      case _CareerTournamentSubstep.quali:
        return 'Danach bestimmst du, wer teilnimmt, wie gesetzt wird und fuer welche Ranglisten das Event zaehlt.';
      case _CareerTournamentSubstep.preisgeld:
        return 'Jetzt folgt die sportliche Wertung ueber Ranglisten und die Verteilung des Preisgelds.';
      case _CareerTournamentSubstep.serie:
        return 'Zum Schluss entscheidest du, wie das Turnier im Kalender landet: einzeln, als Serie oder als Spieltage.';
    }
  }

  String _tournamentFormatLabel(TournamentFormat format) {
    switch (format) {
      case TournamentFormat.knockout:
        return 'KO';
      case TournamentFormat.league:
        return 'Liga';
      case TournamentFormat.leaguePlayoff:
        return 'Liga + Playoff';
    }
  }

  int _requiredCareerPoolSize(CareerDefinition career) {
    var required = 0;
    for (final item in career.currentSeason.calendar) {
      if (item.fieldSize > required) {
        required = item.fieldSize;
      }
    }
    return required;
  }

  String _careerPoolRequirementLabel(CareerDefinition career) {
    final required = _requiredCareerPoolSize(career);
    final current = career.databasePlayers.length;
    if (required <= 0) {
      return '$current Spieler im Karriere-Pool | Noch keine Turniere geplant';
    }
    final fits = current >= required;
    return '$current Spieler im Karriere-Pool | Fuer die geplanten Turniere werden mindestens $required Spieler benoetigt${fits ? ' | Pool reicht aus' : ' | Es fehlen ${required - current}'}';
  }

  Widget _buildSubstepStatusCard<T>({
    required BuildContext context,
    required String title,
    required int currentIndex,
    required int totalCount,
    required String description,
    required String summary,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$title ${currentIndex + 1}/$totalCount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF21415E),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubstepNavigation<T>({
    required List<T> values,
    required T current,
    required String Function(T value) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    final currentIndex = values.indexOf(current);
    final isFirst = currentIndex <= 0;
    final isLast = currentIndex >= values.length - 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isFirst
                    ? null
                    : () => onSelected(values[currentIndex - 1]),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Zurueck'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: isLast
                    ? null
                    : () => onSelected(values[currentIndex + 1]),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  isLast ? 'Fertig' : labelBuilder(values[currentIndex + 1]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool expanded,
    required ValueChanged<bool> onChanged,
    required Widget child,
  }) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          maintainState: true,
          onExpansionChanged: onChanged,
          title: Text(title),
          subtitle: Text(subtitle),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubstepSwitcher<T>({
    required List<T> values,
    required T current,
    required String Function(T value) labelBuilder,
    required ValueChanged<T> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          label: Text(labelBuilder(value)),
          selected: value == current,
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }

  Widget _buildWizardSectionCard(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D7285),
                    ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentSeriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_tournamentFormData.format == TournamentFormat.league ||
            _tournamentFormData.format == TournamentFormat.leaguePlayoff)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _expandLeagueIntoMatchdays && _editingCalendarItemId == null,
            onChanged: _editingCalendarItemId != null
                ? null
                : (value) {
                    setState(() => _expandLeagueIntoMatchdays = value);
                  },
            title: const Text('Als Spieltage im Saisonkalender ausgeben'),
            subtitle: const Text(
              'Legt jeden Spieltag und bei Liga+Playoff auch die Playoff-Runden als eigene Kalendereintraege an.',
            ),
          ),
        if (_expandLeagueIntoMatchdays &&
            _editingCalendarItemId == null &&
            (_tournamentFormData.format == TournamentFormat.league ||
                _tournamentFormData.format == TournamentFormat.leaguePlayoff)) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<CareerLeagueSeriesQualificationMode>(
            initialValue: _leagueSeriesQualificationMode,
            decoration: const InputDecoration(
              labelText: 'Qualifikation fuer Spieltage',
            ),
            items: const <DropdownMenuItem<CareerLeagueSeriesQualificationMode>>[
              DropdownMenuItem(
                value: CareerLeagueSeriesQualificationMode.fixedAtStart,
                child: Text('Teilnehmer einmalig zu Ligastart festziehen'),
              ),
              DropdownMenuItem(
                value: CareerLeagueSeriesQualificationMode.recheckEachMatchday,
                child: Text('Vor jedem Spieltag neu qualifizieren'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _leagueSeriesQualificationMode = value);
              }
            },
          ),
        ],
        if (!_expandLeagueIntoMatchdays ||
            (_tournamentFormData.format != TournamentFormat.league &&
                _tournamentFormData.format != TournamentFormat.leaguePlayoff))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _createAsSeries && _editingCalendarItemId == null,
            onChanged: _editingCalendarItemId != null
                ? null
                : (value) {
                    setState(() => _createAsSeries = value);
                  },
            title: const Text('Als Turnierserie anlegen'),
            subtitle: Text(
              _editingCalendarItemId != null
                  ? 'Beim Bearbeiten wird immer nur dieses eine Turnier aktualisiert.'
                  : 'Erstellt dasselbe Turnier mehrfach und nummeriert es automatisch durch.',
            ),
          ),
        if (_createAsSeries &&
            !_expandLeagueIntoMatchdays &&
            _editingCalendarItemId == null) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: _seriesCountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Anzahl Turniere in der Serie',
              helperText: 'Zum Beispiel 5 fuer Name 1 bis Name 5.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTournamentActionsSection(CareerDefinition career) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton(
          onPressed: _submitCalendarItem,
          child: Text(
            _editingCalendarItemId == null
                ? 'Turnier hinzufuegen'
                : 'Turnier aktualisieren',
          ),
        ),
        if (_editingCalendarItemId != null)
          OutlinedButton(
            onPressed: () => _resetCalendarForm(career),
            child: const Text('Bearbeitung abbrechen'),
          ),
      ],
    );
  }

  Widget _buildTournamentSlotRuleSection(CareerDefinition career) {
    final availableNationalities = _availableCareerNationalities(career);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Slot-Regeln',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        const Text(
          'Definiert feste Startplaetze und spaete Einstiege ins Turnier, zum Beispiel: 48er Feld, Plaetze 17-48 ab Runde 1 und Top 16 ab Runde 2.',
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<CareerQualificationConditionType>(
          initialValue: _qualificationConditionType,
          decoration: const InputDecoration(labelText: 'Quali-Typ'),
          items: const <DropdownMenuItem<CareerQualificationConditionType>>[
            DropdownMenuItem(
              value: CareerQualificationConditionType.rankingRange,
              child: Text('Ranglistenbereich'),
            ),
            DropdownMenuItem(
              value: CareerQualificationConditionType.careerTagOnly,
              child: Text('Nur Karriere-Tag'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _qualificationConditionType = value);
            }
          },
        ),
        if (_qualificationConditionType ==
            CareerQualificationConditionType.rankingRange) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_qualificationRankingId ?? 'qualification-empty'),
            initialValue: _qualificationRankingId,
            decoration: const InputDecoration(labelText: 'Rangliste'),
            items: career.rankings
                .map(
                  (ranking) => DropdownMenuItem<String>(
                    value: ranking.id,
                    child: Text(ranking.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _qualificationRankingId = value);
              }
            },
          ),
        ],
        if (career.careerTagDefinitions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _qualificationConditionType ==
                    CareerQualificationConditionType.careerTagOnly
                ? 'Karriere-Tag fuer diese Qualifikation'
                : 'Zusaetzliche Karriere-Tags fuer diese Qualifikation',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: career.careerTagDefinitions.map((definition) {
              return FilterChip(
                label: Text(definition.name),
                selected: _selectedQualificationTagNames.contains(definition.name),
                onSelected: (selected) {
                  setState(() {
                    if (_qualificationConditionType ==
                        CareerQualificationConditionType.careerTagOnly) {
                      _selectedQualificationTagNames.clear();
                      if (selected) {
                        _selectedQualificationTagNames.add(definition.name);
                      }
                    } else {
                      if (selected) {
                        _selectedQualificationTagNames.add(definition.name);
                      } else {
                        _selectedQualificationTagNames.remove(definition.name);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Karriere-Tags als Ausschluss',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: career.careerTagDefinitions.map((definition) {
              return FilterChip(
                label: Text(definition.name),
                selected: _selectedQualificationExcludedTagNames.contains(definition.name),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedQualificationExcludedTagNames.add(definition.name);
                    } else {
                      _selectedQualificationExcludedTagNames.remove(definition.name);
                    }
                  });
                },
              );
              }).toList(),
            ),
          ],
          if (availableNationalities.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _qualificationConditionType ==
                      CareerQualificationConditionType.careerTagOnly
                  ? 'Nationalitaet fuer diese Qualifikation'
                  : 'Zusaetzliche Nationalitaeten fuer diese Qualifikation',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableNationalities.map((nationality) {
                return FilterChip(
                  label: Text(nationality),
                  selected:
                      _selectedQualificationNationalities.contains(nationality),
                  onSelected: (selected) {
                    setState(() {
                      if (_qualificationConditionType ==
                          CareerQualificationConditionType.careerTagOnly) {
                        _selectedQualificationNationalities.clear();
                        if (selected) {
                          _selectedQualificationNationalities.add(nationality);
                        }
                      } else {
                        if (selected) {
                          _selectedQualificationNationalities.add(nationality);
                        } else {
                          _selectedQualificationNationalities
                              .remove(nationality);
                        }
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'Nationalitaeten als Ausschluss',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableNationalities.map((nationality) {
                return FilterChip(
                  label: Text(nationality),
                  selected: _selectedQualificationExcludedNationalities
                      .contains(nationality),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedQualificationExcludedNationalities
                            .add(nationality);
                      } else {
                        _selectedQualificationExcludedNationalities
                            .remove(nationality);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
          if (_qualificationConditionType ==
              CareerQualificationConditionType.rankingRange) ...<Widget>[
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _qualificationFromController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Von Rang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _qualificationToController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bis Rang'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: _qualificationSlotCountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximale Slots',
            helperText: 'Leer = alle passenden Spieler aus dieser Bedingung uebernehmen.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _qualificationEntryRoundController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Greift ab Runde',
            helperText:
                '1 = direkt zu Turnierbeginn, 2 = Einstieg in Runde 2 usw. Beispiel: Top 16 ab Runde 2.',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _addQualificationCondition(career),
          icon: const Icon(Icons.playlist_add),
          label: const Text('Bedingung hinzufuegen'),
        ),
        const SizedBox(height: 8),
        if (_qualificationConditions.isEmpty)
          const Text('Noch keine Bedingungen angelegt.')
        else
          ..._qualificationConditions.asMap().entries.map((entry) {
            var rankingName = entry.value.rankingId ?? 'Karriere-Tag';
            if (entry.value.rankingId != null) {
              for (final ranking in career.rankings) {
                if (ranking.id == entry.value.rankingId) {
                  rankingName = ranking.name;
                  break;
                }
              }
            }
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_qualificationConditionLabel(entry.value, rankingName)),
              trailing: IconButton(
                onPressed: () {
                  setState(() {
                    _qualificationConditions.removeAt(entry.key);
                  });
                },
                icon: const Icon(Icons.delete_outline),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTournamentFillRuleSection(CareerDefinition career) {
    final availableNationalities = _availableCareerNationalities(career);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Fill-Regeln ueber Rangliste',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>(_fillRankingId ?? 'fill-ranking-empty'),
          initialValue: _fillRankingId,
          decoration: const InputDecoration(
            labelText: 'Auffuell-Rangliste',
          ),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Keine Rangliste'),
            ),
            ...career.rankings.map(
              (ranking) => DropdownMenuItem<String?>(
                value: ranking.id,
                child: Text(ranking.name),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() => _fillRankingId = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fillTopByRankingController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Top X aus Rangliste',
            helperText:
                '0 oder leer = unbegrenzt aus der gewaehlten Rangliste auffuellen.',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Fill-Regeln nach Average',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (career.careerTagDefinitions.isNotEmpty) ...<Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
            children: career.careerTagDefinitions.map((definition) {
              return FilterChip(
                label: Text(definition.name),
                selected: _selectedFillTagNames.contains(definition.name),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFillTagNames.add(definition.name);
                    } else {
                      _selectedFillTagNames.remove(definition.name);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            'Ausschluss-Tags fuer Auffuellung',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: career.careerTagDefinitions.map((definition) {
              return FilterChip(
                label: Text(definition.name),
                selected: _selectedFillExcludedTagNames.contains(definition.name),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedFillExcludedTagNames.add(definition.name);
                    } else {
                      _selectedFillExcludedTagNames.remove(definition.name);
                    }
                  });
                },
              );
              }).toList(),
            ),
            const SizedBox(height: 12),
            if (availableNationalities.isNotEmpty) ...<Widget>[
              Text(
                'Nationalitaeten fuer Auffuellung',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableNationalities.map((nationality) {
                  return FilterChip(
                    label: Text(nationality),
                    selected: _selectedFillNationalities.contains(nationality),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFillNationalities.add(nationality);
                        } else {
                          _selectedFillNationalities.remove(nationality);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                'Ausschluss-Nationalitaeten fuer Auffuellung',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableNationalities.map((nationality) {
                  return FilterChip(
                    label: Text(nationality),
                    selected:
                        _selectedFillExcludedNationalities.contains(nationality),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFillExcludedNationalities.add(nationality);
                        } else {
                          _selectedFillExcludedNationalities.remove(nationality);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ],
        TextField(
          controller: _fillTopByAverageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Top X nach Average',
            helperText:
                '0 oder leer = unbegrenzt aus dem gefilterten Average-Pool auffuellen.',
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _fillAutoGeneratePlayers,
          onChanged: (value) {
            setState(() {
              _fillAutoGeneratePlayers = value;
              if (value) {
                _ensureGeneratedFillDefaults();
              }
            });
          },
          title: const Text('Fehlende Auffuellspieler automatisch generieren'),
          subtitle: const Text(
            'Fehlende Restslots werden mit generierten CPU-Spielern gefuellt. Diese Generierung greift auch waehrend der kompletten Karriere-Simulation.',
          ),
        ),
        if (_fillAutoGeneratePlayers) ...<Widget>[
          const SizedBox(height: 12),
          _buildGeneratedFillConfiguration(career),
        ],
      ],
    );
  }

  Widget _buildTournamentTagGateSection(CareerDefinition career) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Turnier findet statt bei Karriere-Tag-Regel',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (career.careerTagDefinitions.isEmpty)
          const Text(
            'Lege zuerst Karriere-Tags an, um das Stattfinden eines Turniers darueber zu steuern.',
          )
        else ...<Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              _selectedTournamentTagGateTagName ?? 'tournament-tag-gate-empty',
            ),
            initialValue: _selectedTournamentTagGateTagName,
            decoration: const InputDecoration(
              labelText: 'Karriere-Tag',
            ),
            items: career.careerTagDefinitions
                .map(
                  (definition) => DropdownMenuItem<String>(
                    value: definition.name,
                    child: Text(definition.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() => _selectedTournamentTagGateTagName = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tournamentTagGateMinimumController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mindestens X Spieler mit Tag',
              helperText: 'Leer oder 0 = keine Tag-Regel',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<bool>(
            key: ValueKey<bool>(_tournamentOccursWhenTagGateMet),
            initialValue: _tournamentOccursWhenTagGateMet,
            decoration: const InputDecoration(
              labelText: 'Turnier findet statt',
            ),
            items: const <DropdownMenuItem<bool>>[
              DropdownMenuItem<bool>(
                value: true,
                child: Text('Ja, wenn Bedingung erfuellt ist'),
              ),
              DropdownMenuItem<bool>(
                value: false,
                child: Text('Nein, wenn Bedingung erfuellt ist'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _tournamentOccursWhenTagGateMet = value);
              }
            },
          ),
        ],
      ],
    );
  }

  void _ensureGeneratedFillDefaults() {
    if (_generatedFillAgeDistributions.isEmpty) {
      _generatedFillAgeDistributions.addAll(
        const <CareerGeneratedAgeDistribution>[
          CareerGeneratedAgeDistribution(minAge: 16, maxAge: 23, percent: 35),
          CareerGeneratedAgeDistribution(minAge: 24, maxAge: 31, percent: 35),
          CareerGeneratedAgeDistribution(minAge: 32, maxAge: 39, percent: 20),
          CareerGeneratedAgeDistribution(minAge: 40, maxAge: 55, percent: 10),
        ],
      );
    }
  }

  Widget _buildGeneratedFillConfiguration(CareerDefinition career) {
    final availableNationalities = <String>{
      ...ComputerRepository.officialNationalities,
      ..._availableCareerNationalities(career),
    }.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Generierung fuer Auffuellspieler',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Generierte Spieler werden eher am unteren Ende der erlaubten Average-Spanne erzeugt. Hier kannst du zusaetzlich Alter und Nationalitaet prozentual gewichten.',
        ),
        const SizedBox(height: 16),
        Text(
          'Altersverteilung in Prozent',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(_generatedFillAgeDistributions.length, (index) {
          final distribution = _generatedFillAgeDistributions[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    initialValue: distribution.minAge.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min Alter'),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        _generatedFillAgeDistributions[index] =
                            _generatedFillAgeDistributions[index]
                            .copyWith(minAge: parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: distribution.maxAge.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max Alter'),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed > 0) {
                        _generatedFillAgeDistributions[index] =
                            _generatedFillAgeDistributions[index]
                            .copyWith(maxAge: parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: distribution.percent.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Prozent'),
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null && parsed >= 0) {
                        _generatedFillAgeDistributions[index] =
                            _generatedFillAgeDistributions[index]
                            .copyWith(percent: parsed);
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: _generatedFillAgeDistributions.length <= 1
                      ? null
                      : () {
                          setState(() {
                            _generatedFillAgeDistributions.removeAt(index);
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _generatedFillAgeDistributions.add(
                  const CareerGeneratedAgeDistribution(
                    minAge: 24,
                    maxAge: 32,
                    percent: 0,
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Altersbereich hinzufuegen'),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Nationalitaetsverteilung in Prozent',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(
          _generatedFillNationalityDistributions.length,
          (index) {
            final distribution =
                _generatedFillNationalityDistributions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: distribution.nationality.isEmpty
                          ? null
                          : distribution.nationality,
                      decoration: const InputDecoration(
                        labelText: 'Nationalitaet',
                      ),
                      items: availableNationalities
                          .map(
                            (entry) => DropdownMenuItem<String>(
                              value: entry,
                              child: Text(entry),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return;
                        }
                        setState(() {
                          _generatedFillNationalityDistributions[index] =
                              _generatedFillNationalityDistributions[index]
                                  .copyWith(nationality: value.trim());
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: distribution.percent.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prozent'),
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        if (parsed != null && parsed >= 0) {
                          _generatedFillNationalityDistributions[index] =
                              _generatedFillNationalityDistributions[index]
                                  .copyWith(percent: parsed);
                        }
                      },
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _generatedFillNationalityDistributions.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: availableNationalities.isEmpty
                ? null
                : () {
                    setState(() {
                      final used = _generatedFillNationalityDistributions
                          .map((entry) => entry.nationality)
                          .where((entry) => entry.isNotEmpty)
                          .toSet();
                      final firstAvailable = availableNationalities.firstWhere(
                        (entry) => !used.contains(entry),
                        orElse: () => availableNationalities.first,
                      );
                      _generatedFillNationalityDistributions.add(
                        CareerGeneratedNationalityDistribution(
                          nationality: firstAvailable,
                          percent: 0,
                        ),
                      );
                    });
                  },
            icon: const Icon(Icons.add),
            label: const Text('Nationalitaet hinzufuegen'),
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentRankingsSection(CareerDefinition career) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Zaehlt fuer Ranglisten',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (career.rankings.isEmpty)
          const Text('Noch keine Ranglisten vorhanden.')
        else
          ...career.rankings.map(
            (ranking) => CheckboxListTile(
              value: _selectedRankingIds.contains(ranking.id),
              onChanged: (value) {
                setState(() {
                  if (value ?? false) {
                    _selectedRankingIds.add(ranking.id);
                  } else {
                    _selectedRankingIds.remove(ranking.id);
                  }
                });
              },
              title: Text(ranking.name),
              subtitle: Text(
                ranking.resetAtSeasonEnd
                    ? 'Setzt sich am Saisonende zurueck'
                    : 'Gueltig ueber ${ranking.validSeasons} Saison(en)',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }

  Widget _buildRosterStep(BuildContext context, CareerDefinition career) {
    final rosterViewData = _buildRosterViewData(career);
    final assignedTagNames = _parseCareerTags(
      _databasePlayerTagsController.text,
    ).map((entry) => entry.tagName).toSet();
    final rosterSteps = _CareerRosterSubstep.values;
    final rosterIndex = rosterSteps.indexOf(_rosterSubstep);
    final rosterSummary = switch (_rosterSubstep) {
        _CareerRosterSubstep.pool =>
          '${rosterViewData.addablePlayers.length} Spieler verfuegbar | ${_selectedDatabasePlayerIds.length} markiert',
      _CareerRosterSubstep.training =>
        '${career.databasePlayers.length} Spieler im Karriere-Pool | Trainingsbereich ${_isTrainingModeExpanded ? 'geoeffnet' : 'geschlossen'}',
      _CareerRosterSubstep.spieler =>
        '${career.databasePlayers.length} Karriere-Spieler | ${_selectedCareerRosterPlayerIds.length} markiert',
    };

    Widget content;
      switch (_rosterSubstep) {
      case _CareerRosterSubstep.pool:
        content = _buildWizardSectionCard(
          context,
          title: 'Spieler waehlen',
          subtitle: 'Filtere Datenbankspieler, markiere sie und uebernimm sie gesammelt in den Karriere-Pool.',
          child: CareerRosterAddPlayersSection(
            career: career,
            availableTags: rosterViewData.availableTags,
            addablePlayers: rosterViewData.addablePlayers,
            selectedDatabaseTagFilters: _selectedDatabaseTagFilters,
            selectedDatabasePlayerIds: _selectedDatabasePlayerIds,
            databasePlayerTagsController: _databasePlayerTagsController,
            assignedTagNames: assignedTagNames,
            tagUsageLabelBuilder: (tagName) =>
                _careerTagUsageFilterLabel(career, tagName),
            onToggleAssignmentCareerTag: _toggleAssignmentCareerTag,
            onClearFilters: () {
              setState(() {
                _selectedDatabaseTagFilters.clear();
              });
            },
            onToggleDatabaseTagFilter: (tag) {
              setState(() {
                if (_selectedDatabaseTagFilters.contains(tag)) {
                  _selectedDatabaseTagFilters.remove(tag);
                } else {
                  _selectedDatabaseTagFilters.add(tag);
                }
              });
            },
            onToggleSelectAll: () {
              setState(() {
                if (_selectedDatabasePlayerIds.length ==
                    rosterViewData.addablePlayers.length) {
                  _selectedDatabasePlayerIds.clear();
                } else {
                  _selectedDatabasePlayerIds
                    ..clear()
                    ..addAll(
                      rosterViewData.addablePlayers.map((player) => player.id),
                    );
                }
              });
            },
            onTogglePlayerSelection: (playerId) {
              setState(() {
                if (_selectedDatabasePlayerIds.contains(playerId)) {
                  _selectedDatabasePlayerIds.remove(playerId);
                } else {
                  _selectedDatabasePlayerIds.add(playerId);
                }
              });
            },
            onAddSelectedPlayers: _addSelectedDatabasePlayersToCareer,
          ),
        );
        break;
      case _CareerRosterSubstep.training:
        content = const SizedBox.shrink();
        break;
      case _CareerRosterSubstep.spieler:
        content = _buildWizardSectionCard(
          context,
          title: 'Kader verwalten',
          subtitle: 'Bearbeite vorhandene Karriere-Spieler, Tags und Sammelaktionen nur noch auf dem finalen Pool.',
          child: CareerRosterListSection(
            players: career.databasePlayers,
            selectedPlayerIds: _selectedCareerRosterPlayerIds,
            careerRosterTagsController: _careerRosterTagsController,
            tagLabelBuilder: _careerTagAssignmentLabel,
            onToggleSelectAll: () {
              setState(() {
                if (_selectedCareerRosterPlayerIds.length ==
                    career.databasePlayers.length) {
                  _selectedCareerRosterPlayerIds.clear();
                } else {
                  _selectedCareerRosterPlayerIds
                    ..clear()
                    ..addAll(
                      career.databasePlayers.map(
                        (player) => player.databasePlayerId,
                      ),
                    );
                }
              });
            },
            onTogglePlayerSelection: (playerId) {
              setState(() {
                if (_selectedCareerRosterPlayerIds.contains(playerId)) {
                  _selectedCareerRosterPlayerIds.remove(playerId);
                } else {
                  _selectedCareerRosterPlayerIds.add(playerId);
                }
              });
            },
            onApplyTags: _applyTagsToSelectedCareerPlayers,
            onRemoveTags: _removeTagsFromSelectedCareerPlayers,
            onClearTags: _clearAllTagsFromSelectedCareerPlayers,
            onRemovePlayers: _removeSelectedCareerPlayers,
            onEditPlayer: _editCareerDatabasePlayer,
            onDeletePlayer: _repository.removeDatabasePlayer,
            onRemoveSingleTag: (player, tagName) {
              _removeCareerTagFromPlayer(player: player, tagName: tagName);
            },
          ),
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSubstepStatusCard<_CareerRosterSubstep>(
          context: context,
          title: 'Kader',
          currentIndex: rosterIndex,
          totalCount: rosterSteps.length,
          description: _rosterSubstepDescription(_rosterSubstep, career),
          summary: rosterSummary,
        ),
        const SizedBox(height: 16),
          _buildWizardSectionCard(
            context,
            title: 'Bereich waehlen',
            subtitle: _careerPoolRequirementLabel(career),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildSubstepSwitcher<_CareerRosterSubstep>(
                  values: _CareerRosterSubstep.values,
                  current: _rosterSubstep,
                  labelBuilder: _rosterSubstepLabel,
                  onSelected: (value) {
                    setState(() {
                      _rosterSubstep = value;
                      if (value == _CareerRosterSubstep.training) {
                        _isTrainingModeExpanded = true;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isTrainingModeExpanded,
                  onChanged: (value) {
                    setState(() {
                      _isTrainingModeExpanded = value;
                      if (value) {
                        _rosterSubstep = _CareerRosterSubstep.training;
                      } else if (_rosterSubstep == _CareerRosterSubstep.training) {
                        _rosterSubstep = _CareerRosterSubstep.pool;
                      }
                    });
                  },
                  title: const Text('Trainingsmodus einblenden'),
                  subtitle: const Text(
                    'Blendet den Bereich fuer Average-Spannen direkt in diesem Schritt ein oder aus.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildWizardSectionCard(
              context,
              title: 'Trainingsmodus',
              subtitle: 'Average-Spanne fuer Karriere-Gegner anpassen',
              child: _buildTrainingModeSection(career),
            ),
            crossFadeState: _isTrainingModeExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
          if (_isTrainingModeExpanded) const SizedBox(height: 16),
          if (_rosterSubstep != _CareerRosterSubstep.training) content,
          const SizedBox(height: 16),
          _buildSubstepNavigation<_CareerRosterSubstep>(
            values: rosterSteps,
            current: _rosterSubstep,
            labelBuilder: _rosterSubstepLabel,
          onSelected: (value) {
            setState(() => _rosterSubstep = value);
          },
        ),
      ],
    );
  }

  void _setSetupStep(_CareerSetupStep step) {
    _setupStep = step;
    if (step == _CareerSetupStep.kader) {
      _rosterSubstep = _CareerRosterSubstep.pool;
    } else if (step == _CareerSetupStep.turniere) {
      _tournamentSubstep = _CareerTournamentSubstep.basics;
    }
  }

  Widget _buildTournamentStep(BuildContext context, CareerDefinition career) {
    final tournamentSteps = _CareerTournamentSubstep.values;
    final tournamentIndex = tournamentSteps.indexOf(_tournamentSubstep);
    final rankingCount = _selectedRankingIds.length;
    final tournamentSummary = switch (_tournamentSubstep) {
      _CareerTournamentSubstep.basics =>
        '${_tournamentFormatLabel(_tournamentFormData.format)} | Tier ${_tournamentFormData.parsedTier ?? '-'} | Feld ${_tournamentFormData.parsedFieldSize ?? '-'}',
      _CareerTournamentSubstep.quali =>
        '${_simpleQualificationSummary(career)} | Setzliste ${_seedingRankingId == null ? 'aus' : 'an'} | ${_qualificationConditions.length} Gesamtregeln',
      _CareerTournamentSubstep.preisgeld =>
        'Preisgeld ${_calculatedPrizePool()} | ${rankingCount == 0 ? 'ohne Wertung' : '$rankingCount Wertungen aktiv'}',
      _CareerTournamentSubstep.serie =>
          _expandLeagueIntoMatchdays
              ? 'Ausgabe als Spieltage aktiviert'
            : (_createAsSeries ? 'Turnierserie aktiviert' : 'Einzelturnier im Kalender'),
    };
    final basicsSection = _buildWizardSectionCard(
        context,
        title: _editingCalendarItemId == null ? 'Turnierbasis' : 'Turnier bearbeiten',
      subtitle: 'Format, Feldgroesse, Distanz und Grundlogik',
      child: TournamentBasicsForm(
        nameController: _itemNameController,
        formData: _tournamentFormData,
        onChanged: (value) {
          setState(() {
            _tournamentFormData = value;
            _syncKnockoutPrizeValues();
            _syncLeaguePositionPrizeValues();
          });
        },
      ),
    );

    final prizeSection = _buildWizardSectionCard(
      context,
      title: 'Wertung & Preisgeld',
      subtitle: 'Lege fest, fuer welche Ranglisten das Turnier zaehlt und wie das Preisgeld verteilt wird.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildWizardSectionCard(
            context,
            title: 'Pflicht: Ranglisten-Wertung',
            subtitle: 'Lege fest, fuer welche Ranglisten das Turnier zaehlt.',
            child: _buildTournamentRankingsSection(career),
          ),
          const SizedBox(height: 16),
          CareerTournamentPrizeEditor(
            usesKnockoutPrizeSetup: _usesKnockoutPrizeSetup,
            usesLeaguePositionPrizeSetup: _usesLeaguePositionPrizeSetup,
            knockoutPrizeValues: _knockoutPrizeValues,
            knockoutPrizeLabel: _knockoutPrizeLabel,
            onKnockoutPrizeChanged: (index, value) {
              final parsed = int.tryParse(value.trim()) ?? 0;
              setState(() {
                _knockoutPrizeValues[index] = parsed;
              });
            },
            calculatedKnockoutPrizePool: _calculatedKnockoutPrizePool(),
            leaguePositionPrizeValues: _leaguePositionPrizeValues,
            onLeaguePositionPrizeChanged: (index, value) {
              final parsed = int.tryParse(value.trim()) ?? 0;
              setState(() {
                _leaguePositionPrizeValues[index] = parsed;
              });
            },
          calculatedLeaguePrizePool: _calculatedLeaguePrizePool(),
          prizePoolController: _prizePoolController,
          calculatedPrizePool: _calculatedPrizePool(),
          selectedSplitPreset: _selectedPrizeSplitPreset,
          onSplitPresetChanged: (value) {
            setState(() => _selectedPrizeSplitPreset = value);
          },
          onApplyKnockoutSplit: () {
            setState(_applyKnockoutPrizeSplitPreset);
          },
          totalPrizeHelperText: _prizePoolHelperText(),
          ),
        ],
      ),
      );

    final seriesSection = _buildWizardSectionCard(
        context,
        title: 'Serie & Kalenderausgabe',
        subtitle: 'Pflicht: Turnier uebernehmen. Serien und Spieltage nur bei Bedarf aufklappen.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAdvancedSection(
              context,
              title: 'Erweiterte Serienoptionen',
              subtitle: 'Turnierserien und Spieltags-Ausgabe fuer Ligen nur aktivieren, wenn du sie wirklich brauchst.',
              expanded: _showAdvancedTournamentSeries,
              onChanged: (value) {
                setState(() => _showAdvancedTournamentSeries = value);
              },
              child: _buildTournamentSeriesSection(),
            ),
            const SizedBox(height: 16),
            _buildTournamentActionsSection(career),
          ],
      ),
    );

    Widget activeSection;
    switch (_tournamentSubstep) {
      case _CareerTournamentSubstep.basics:
        activeSection = basicsSection;
        break;
      case _CareerTournamentSubstep.quali:
        activeSection = _buildTournamentQualiStep(context, career);
        break;
      case _CareerTournamentSubstep.preisgeld:
        activeSection = prizeSection;
        break;
      case _CareerTournamentSubstep.serie:
        activeSection = seriesSection;
        break;
    }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSubstepStatusCard<_CareerTournamentSubstep>(
            context: context,
            title: 'Turniere',
            currentIndex: tournamentIndex,
            totalCount: tournamentSteps.length,
            description:
                _tournamentSubstepDescription(_tournamentSubstep, career),
            summary: tournamentSummary,
          ),
          const SizedBox(height: 16),
          _buildWizardSectionCard(
            context,
            title: 'Turniere',
          subtitle: _editingCalendarItemId == null
              ? 'Neue Turniere fuer die Saison planen'
              : 'Bestehenden Kalendereintrag bearbeiten',
          child: _buildSubstepSwitcher<_CareerTournamentSubstep>(
            values: _CareerTournamentSubstep.values,
            current: _tournamentSubstep,
            labelBuilder: _tournamentSubstepLabel,
            onSelected: (value) {
              setState(() => _tournamentSubstep = value);
            },
          ),
          ),
          const SizedBox(height: 16),
          activeSection,
          const SizedBox(height: 16),
          _buildSubstepNavigation<_CareerTournamentSubstep>(
            values: tournamentSteps,
            current: _tournamentSubstep,
            labelBuilder: _tournamentSubstepLabel,
            onSelected: (value) {
              setState(() => _tournamentSubstep = value);
            },
          ),
        ],
      );
    }

  Widget _buildTournamentQualiStep(BuildContext context, CareerDefinition career) {
    return _buildWizardSectionCard(
      context,
      title: 'Qualifikation',
      subtitle: 'Pflicht zuerst: normaler Ranglistenbereich und Setzliste. Komplexere Quali-Regeln nur bei Bedarf.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildTournamentAccessPresetCard(context, career),
          const SizedBox(height: 16),
          _buildWizardSectionCard(
            context,
            title: 'Pflicht: Normale Qualifikation',
            subtitle: 'Lege fest, welche Ranglistenplaetze sich direkt fuer dieses Turnier qualifizieren.',
            child: _buildSimpleQualificationSection(career),
          ),
          const SizedBox(height: 16),
          _buildWizardSectionCard(
            context,
            title: 'Pflicht: Setzliste',
            subtitle: 'Einfache Setzliste ueber Rangliste und Anzahl gesetzter Plaetze.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<String?>(
                  key: ValueKey<String?>(_seedingRankingId ?? 'no-seeding'),
                  initialValue: _seedingRankingId,
                  decoration: const InputDecoration(
                    labelText: 'Setzlisten-Rangliste',
                  ),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Keine Setzliste'),
                    ),
                    ...career.rankings.map(
                      (ranking) => DropdownMenuItem<String?>(
                        value: ranking.id,
                        child: Text(ranking.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _seedingRankingId = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$_seedCount',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gesetzte Plaetze',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null && parsed >= 0) {
                      setState(() => _seedCount = parsed);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildAdvancedSection(
            context,
            title: 'Erweiterte Turnierregeln',
            subtitle: 'Slot-Regeln, Auffuellen und Tag-Gates nur oeffnen, wenn du wirklich fein steuern willst.',
            expanded: _showAdvancedTournamentRules,
            onChanged: (value) {
              setState(() => _showAdvancedTournamentRules = value);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _buildWizardSectionCard(
                  context,
                  title: 'Quali- und Slot-Regeln',
                  child: _buildTournamentSlotRuleSection(career),
                ),
                const SizedBox(height: 16),
                _buildWizardSectionCard(
                  context,
                  title: 'Auffuellen & Tag-Gates',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildTournamentFillRuleSection(career),
                      const SizedBox(height: 16),
                      _buildTournamentTagGateSection(career),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTournamentActionsSection(career),
        ],
      ),
    );
  }

  Widget _buildSimpleQualificationSection(CareerDefinition career) {
    final simpleCondition = _simpleQualificationCondition;
    final selectedRankingId =
        _qualificationRankingId ?? simpleCondition?.rankingId;
    final fromValue = _qualificationFromController.text.trim().isEmpty
        ? '${simpleCondition?.fromRank ?? 1}'
        : _qualificationFromController.text;
    final toValue = _qualificationToController.text.trim().isEmpty
        ? '${simpleCondition?.toRank ?? 16}'
        : _qualificationToController.text;

    if (_qualificationFromController.text != fromValue) {
      _qualificationFromController.value = TextEditingValue(
        text: fromValue,
        selection: TextSelection.collapsed(offset: fromValue.length),
      );
    }
    if (_qualificationToController.text != toValue) {
      _qualificationToController.value = TextEditingValue(
        text: toValue,
        selection: TextSelection.collapsed(offset: toValue.length),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (career.rankings.isEmpty)
          const Text(
            'Lege zuerst mindestens eine Rangliste an, damit du eine normale Qualifikation ueber Ranglistenplaetze bauen kannst.',
          )
        else ...<Widget>[
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>(selectedRankingId ?? 'simple-qualification-empty'),
            initialValue: selectedRankingId,
            decoration: const InputDecoration(
              labelText: 'Qualifikations-Rangliste',
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Keine normale Qualifikation'),
              ),
              ...career.rankings.map(
                (ranking) => DropdownMenuItem<String?>(
                  value: ranking.id,
                  child: Text(ranking.name),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _qualificationRankingId = value;
                if (value == null) {
                  _removeSimpleQualificationCondition();
                } else {
                  _upsertSimpleQualificationCondition(career);
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _qualificationFromController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Von Rang'),
                  onChanged: (_) {
                    if (_qualificationRankingId != null) {
                      setState(() => _upsertSimpleQualificationCondition(career));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _qualificationToController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bis Rang'),
                  onChanged: (_) {
                    if (_qualificationRankingId != null) {
                      setState(() => _upsertSimpleQualificationCondition(career));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _qualificationRankingId == null
                ? 'Aktuell ist keine einfache Ranglisten-Qualifikation gesetzt.'
                : _simpleQualificationSummary(career),
            style: const TextStyle(color: Color(0xFF556372)),
          ),
        ],
      ],
    );
  }

  CareerQualificationCondition? get _simpleQualificationCondition {
    for (final condition in _qualificationConditions) {
      if (condition.type == CareerQualificationConditionType.rankingRange &&
          condition.entryRound == 1 &&
          condition.slotCount == null &&
          condition.requiredCareerTags.isEmpty &&
          condition.excludedCareerTags.isEmpty &&
          condition.requiredNationalities.isEmpty &&
          condition.excludedNationalities.isEmpty) {
        return condition;
      }
    }
    return null;
  }

  int _simpleQualificationConditionIndex() {
    for (var index = 0; index < _qualificationConditions.length; index += 1) {
      final condition = _qualificationConditions[index];
      if (condition.type == CareerQualificationConditionType.rankingRange &&
          condition.entryRound == 1 &&
          condition.slotCount == null &&
          condition.requiredCareerTags.isEmpty &&
          condition.excludedCareerTags.isEmpty &&
          condition.requiredNationalities.isEmpty &&
          condition.excludedNationalities.isEmpty) {
        return index;
      }
    }
    return -1;
  }

  void _removeSimpleQualificationCondition() {
    final index = _simpleQualificationConditionIndex();
    if (index >= 0) {
      _qualificationConditions.removeAt(index);
    }
  }

  void _upsertSimpleQualificationCondition(CareerDefinition career) {
    final rankingId =
        _qualificationRankingId ?? (career.rankings.isEmpty ? null : career.rankings.first.id);
    if (rankingId == null) {
      _removeSimpleQualificationCondition();
      return;
    }
    final parsedFrom = int.tryParse(_qualificationFromController.text.trim()) ?? 1;
    final parsedTo = int.tryParse(_qualificationToController.text.trim()) ?? parsedFrom;
    final fromRank = parsedFrom <= parsedTo ? parsedFrom : parsedTo;
    final toRank = parsedFrom <= parsedTo ? parsedTo : parsedFrom;
    final condition = CareerQualificationCondition(
      type: CareerQualificationConditionType.rankingRange,
      rankingId: rankingId,
      fromRank: fromRank,
      toRank: toRank,
      entryRound: 1,
      slotCount: null,
      requiredCareerTags: const <String>[],
      excludedCareerTags: const <String>[],
      requiredNationalities: const <String>[],
      excludedNationalities: const <String>[],
    );
    final index = _simpleQualificationConditionIndex();
    if (index >= 0) {
      _qualificationConditions[index] = condition;
    } else {
      _qualificationConditions.insert(0, condition);
    }
  }

  String _simpleQualificationSummary(CareerDefinition career) {
    final condition = _simpleQualificationCondition;
    if (condition == null || condition.rankingId == null) {
      return 'Keine normale Qualifikation';
    }
    var rankingName = condition.rankingId ?? 'Unbekannte Rangliste';
    for (final ranking in career.rankings) {
      if (ranking.id == condition.rankingId) {
        rankingName = ranking.name;
        break;
      }
    }
    return '$rankingName: Rang ${condition.fromRank}-${condition.toRank}';
  }

  Widget _buildCareerBasicsEditor(
    BuildContext context,
    CareerDefinition career,
  ) {
    final players = _playerRepository.players;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Karrieregrundlagen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Lege zuerst Name, Teilnehmermodus und dein Spielerprofil fest. Damit steht die Basis, bevor du Rankings, Regeln und Turniere aufbaust.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _careerNameController,
              decoration: const InputDecoration(labelText: 'Karrierename'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CareerParticipantMode>(
              key: ValueKey<CareerParticipantMode>(
                _participantMode,
              ),
              initialValue: _participantMode,
              decoration: const InputDecoration(labelText: 'Teilnehmermodus'),
              items: const <DropdownMenuItem<CareerParticipantMode>>[
                DropdownMenuItem(
                  value: CareerParticipantMode.withHuman,
                  child: Text('Mit mir'),
                ),
                DropdownMenuItem(
                  value: CareerParticipantMode.cpuOnly,
                  child: Text('Nur Computer'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _participantMode = value);
                }
              },
            ),
            if (_participantMode == CareerParticipantMode.withHuman) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedPlayerProfileId ?? 'no-player'),
                initialValue: _selectedPlayerProfileId,
                decoration: const InputDecoration(labelText: 'Spielerprofil'),
                items: players
                    .map(
                      (player) => DropdownMenuItem<String>(
                        value: player.id,
                        child: Text(player.name),
                      ),
                    )
                    .toList(),
                onChanged: players.isEmpty
                    ? null
                    : (value) {
                        setState(() => _selectedPlayerProfileId = value);
                      },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _replaceWeakestPlayerWithHuman,
                onChanged: (value) {
                  setState(() => _replaceWeakestPlayerWithHuman = value);
                },
                title: const Text('Schwaechsten Spieler ersetzen'),
                subtitle: const Text(
                  'Dein Karriere-Spieler ersetzt im allgemeinen Teilnehmerpool den Computer-Spieler mit dem niedrigsten Average.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                _repository.updateCareerBasics(
                  name: _careerNameController.text,
                  participantMode: _participantMode,
                  playerProfileId: _participantMode == CareerParticipantMode.withHuman
                      ? _selectedPlayerProfileId
                      : null,
                  replaceWeakestPlayerWithHuman:
                      _replaceWeakestPlayerWithHuman,
                );
                setState(() {});
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Grundlagen speichern'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerStructurePresetCard(
    BuildContext context,
    CareerDefinition career,
  ) {
    return _buildWizardSectionCard(
      context,
      title: 'Karriere-System',
      subtitle:
          'Lege fest, ob direkt typische Status-Tags, Ranglisten und Saisonende-Regeln angelegt werden sollen.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<_CareerStructurePreset>(
            initialValue: _selectedCareerStructurePreset,
            decoration: const InputDecoration(
              labelText: 'Struktur-Preset',
            ),
            items: _CareerStructurePreset.values
                .map(
                  (preset) => DropdownMenuItem<_CareerStructurePreset>(
                    value: preset,
                    child: Text(_careerStructurePresetLabel(preset)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCareerStructurePreset = value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            _careerStructurePresetDescription(_selectedCareerStructurePreset),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          if (_selectedCareerStructurePreset != _CareerStructurePreset.custom)
            ...<Widget>[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => _applyCareerStructurePreset(career),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Statussystem anwenden'),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildCareerStatusPresetCard(
    BuildContext context,
    CareerDefinition career,
  ) {
    return _buildWizardSectionCard(
      context,
      title: 'Status-Presets',
      subtitle:
          'Lege mit einem Schritt typische Tour-Status-Tags und Saisonende-Regeln an.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Aktuell: ${career.careerTagDefinitions.length} Tags | ${career.seasonTagRules.length} Saisonregeln',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF21415E),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_CareerStructurePreset>(
            initialValue: _selectedCareerStructurePreset,
            decoration: const InputDecoration(
              labelText: 'Status-Preset',
            ),
            items: _CareerStructurePreset.values
                .map(
                  (preset) => DropdownMenuItem<_CareerStructurePreset>(
                    value: preset,
                    child: Text(_careerStructurePresetLabel(preset)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCareerStructurePreset = value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            _careerStructurePresetDescription(_selectedCareerStructurePreset),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          if (_selectedCareerStructurePreset != _CareerStructurePreset.custom)
            ...<Widget>[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _applyCareerStructurePreset(career),
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Tags und Saisonregeln anlegen'),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildTournamentAccessPresetCard(
    BuildContext context,
    CareerDefinition career,
  ) {
    return _buildWizardSectionCard(
      context,
      title: 'Turnierzugang-Preset',
      subtitle:
          'Setzt einen typischen Zugangsweg fuer dieses Turnier und fuellt die Quali-Regeln passend vor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<_CareerTournamentAccessPreset>(
            initialValue: _selectedTournamentAccessPreset,
            decoration: const InputDecoration(
              labelText: 'Zugang',
            ),
            items: _CareerTournamentAccessPreset.values
                .map(
                  (preset) =>
                      DropdownMenuItem<_CareerTournamentAccessPreset>(
                    value: preset,
                    child: Text(_tournamentAccessPresetLabel(preset)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedTournamentAccessPreset = value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            _tournamentAccessPresetDescription(
              _selectedTournamentAccessPreset,
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          if (_selectedTournamentAccessPreset !=
              _CareerTournamentAccessPreset.custom) ...<Widget>[
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() => _applyTournamentAccessPreset(career));
              },
              icon: const Icon(Icons.how_to_reg_outlined),
              label: const Text('Zugangs-Preset anwenden'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRankingCutoffPreviewCard(
    BuildContext context,
    CareerDefinition career,
  ) {
    return _buildWizardSectionCard(
      context,
      title: 'Ranglisten-Cutoffs',
      subtitle:
          'Zeigt dir direkt, wer aktuell an wichtigen Grenzbereichen wie Top 16, Top 32 oder Top 64 liegt.',
      child: career.rankings.isEmpty
          ? const Text(
              'Lege zuerst Ranglisten an. Danach siehst du hier die aktuellen Cutoffs und Bubble-Bereiche.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: career.rankings
                  .take(4)
                  .map(
                    (ranking) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildSingleRankingCutoffPreview(
                        context,
                        career,
                        ranking,
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSingleRankingCutoffPreview(
    BuildContext context,
    CareerDefinition career,
    CareerRankingDefinition ranking,
  ) {
    final standings = _repository.standingsForRanking(ranking.id);
    final cutoffs = <int>[16, 32, 64]
        .where((cutoff) => standings.length >= cutoff)
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF4F8FB),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ranking.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            standings.isEmpty
                ? 'Noch keine Ergebnisse'
                : '${standings.length} Spieler mit Wertung',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          if (standings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            if (cutoffs.isEmpty)
              Text(
                'Aktueller Leader: ${standings.first.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cutoffs
                    .map(
                      (cutoff) => _buildCutoffChip(
                        context,
                        label: 'Top $cutoff',
                        standing: standings[cutoff - 1],
                      ),
                    )
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCutoffChip(
    BuildContext context, {
    required String label,
    required RankingStanding standing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD5E4EE)),
      ),
      child: Text(
        '$label: #${standing.rank} ${standing.name}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildTemplateSelectionCard(BuildContext context) {
    final templates = _templateRepository.templates;
    final selectedTemplate = _selectedTemplate();
    final subtitle = selectedTemplate == null
        ? (_simpleQuickTournamentGenerationEnabled
            ? 'Quick-Erstellung ist aktiv. Eine Vorlage ist aktuell nicht ausgewaehlt.'
            : 'Waehle eine Vorlage aus oder aktiviere stattdessen die Quick-Erstellung.')
        : '${selectedTemplate.calendar.length} Turniere | ${selectedTemplate.rankings.length} Ranglisten';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Vorlage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            ),
            if (templates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: ValueKey<String?>('grundlagen-template-$_selectedTemplateId'),
                initialValue: _selectedTemplateId,
                decoration: const InputDecoration(labelText: 'Aktive Vorlage'),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Keine Vorlage'),
                  ),
                  ...templates.map(
                    (template) => DropdownMenuItem<String?>(
                      value: template.id,
                      child: Text(template.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTemplateId = value;
                    if (value != null) {
                      _simpleQuickTournamentGenerationEnabled = false;
                    }
                    _simpleTemplateTrainingOverrides.clear();
                    _selectedTrainingPoolTagName = null;
                    _trainingMinAverageController.clear();
                    _trainingMaxAverageController.clear();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleQuickTournamentCard(
    BuildContext context,
    CareerTemplate? template,
  ) {
    final selectedFormats = _effectiveSimpleQuickFormats();
    final selectedPoolCount = _templateCreationPoolPlayers(template).length;
    final rosterSize = _effectiveSimpleTargetRosterSize(selectedPoolCount);
    final availableBlueprints = _availableSimpleQuickTourBlueprints();
    final selectedBlueprints = availableBlueprints
        .where((entry) => _simpleQuickSelectedBlueprintIds.contains(entry.id))
        .toList();
    final addableBlueprints = availableBlueprints
        .where((entry) => !_simpleQuickSelectedBlueprintIds.contains(entry.id))
        .toList();

    return _buildWizardSectionCard(
      context,
      title: 'Quick-Turniererstellung',
      subtitle:
          'Lege im einfachen Modus fest, wie die Quick-Tour aufgebaut wird: Anzahl, Teilnehmerfelder und Preisgelder je Tour-Baustein.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _simpleQuickTournamentGenerationEnabled,
            onChanged: (value) {
              if (!value && _selectedTemplateId == null) {
                return;
              }
              setState(() {
                _simpleQuickTournamentGenerationEnabled = value;
                if (value) {
                  _selectedTemplateId = null;
                }
                _simpleTemplateTrainingOverrides.clear();
                _selectedTrainingPoolTagName = null;
                _trainingMinAverageController.clear();
                _trainingMaxAverageController.clear();
              });
            },
            title: const Text('Quick-Turniermix aktivieren'),
            subtitle: const Text(
              'Erzeugt fuer die einfache Karriere ein eigenstaendiges Tour-Geruest statt Turniere aus einer Vorlage zu remixen.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _simpleQuickTournamentGenerationEnabled
                ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quick-Erstellung ist aktiv. Die Detailkonfiguration der Tour-Bausteine wird gerade schrittweise wieder eingeblendet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aktueller Ziel-Kader: $rosterSize Spieler',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Formate',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TournamentFormat.values.map((format) {
                      final selected = selectedFormats.contains(format);
                      return FilterChip(
                        label: Text(_tournamentFormatLabel(format)),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            if (selected) {
                              if (_simpleQuickFormats.length > 1) {
                                _simpleQuickFormats.remove(format);
                              }
                            } else {
                              _simpleQuickFormats.add(format);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Modi',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilterChip(
                        label: const Text('Turnierserien'),
                        selected: _simpleQuickIncludeSeries,
                        onSelected: (value) {
                          if (!value && !_simpleQuickIncludeStandalone) {
                            return;
                          }
                          setState(() => _simpleQuickIncludeSeries = value);
                        },
                      ),
                      FilterChip(
                        label: const Text('Einzelturniere'),
                        selected: _simpleQuickIncludeStandalone,
                        onSelected: (value) {
                          if (!value && !_simpleQuickIncludeSeries) {
                            return;
                          }
                          setState(() => _simpleQuickIncludeStandalone = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bausteine hinzufuegen',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Material(
                        color: addableBlueprints.isEmpty
                            ? Theme.of(context).colorScheme.surfaceContainerHighest
                            : Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: addableBlueprints.isEmpty
                              ? null
                              : () => _openSimpleQuickTournamentComposer(
                                    addableBlueprints,
                                    rosterSize: rosterSize,
                                  ),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.add_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            addableBlueprints.isEmpty
                                ? 'Mit den aktuellen Filtern sind keine weiteren Turnierarten verfuegbar.'
                                : 'Fuege ueber das Plus selbst Bausteine mit Name und Turnierart hinzu.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF556372),
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ausgewaehlte Tour-Bausteine',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (selectedBlueprints.isEmpty)
                    const Text(
                      'Fuege zuerst selbst Tour-Bausteine hinzu. Erst diese Auswahl bildet deine Quick-Tour.',
                    )
                  else
                    Column(
                      children: selectedBlueprints.map((blueprint) {
                        final config =
                            _simpleQuickTourConfigs[blueprint.id] ??
                            _SimpleQuickTourTypeConfig(
                              count: _defaultSimpleQuickCountForBlueprint(
                                blueprint.id,
                              ),
                            );
                        final customDisplayName = config.customName?.trim();
                        final displayName =
                            customDisplayName != null &&
                                    customDisplayName.isNotEmpty
                                ? customDisplayName
                                : blueprint.categoryName;
                        final effectiveFieldSize =
                            config.fieldSizeOverride ??
                            _quickFieldSizeForBlueprint(
                              blueprint: blueprint,
                              rosterSize: rosterSize,
                            );
                        final effectivePrizePool =
                            config.prizePoolOverride ??
                            _quickPrizePoolForFieldSize(
                              blueprint: blueprint,
                              fieldSize: effectiveFieldSize,
                            );
                        final effectivePlayoffQualifierCount =
                            blueprint.format == TournamentFormat.leaguePlayoff
                                ? _quickPlayoffQualifierCountForFieldSize(
                                    fieldSize: effectiveFieldSize,
                                    requestedQualifierCount:
                                        blueprint.playoffQualifierCount,
                                  )
                                : blueprint.playoffQualifierCount;
                        final effectiveKnockoutPrizeValues =
                            _effectiveQuickKnockoutPrizeValues(
                          blueprint: blueprint,
                          config: config,
                          fieldSize: effectiveFieldSize,
                          prizePool: effectivePrizePool,
                          playoffQualifierCount: effectivePlayoffQualifierCount,
                        );
                        final effectiveLeaguePrizeValues =
                            _effectiveQuickLeaguePrizeValues(
                          blueprint: blueprint,
                          config: config,
                          fieldSize: effectiveFieldSize,
                          prizePool: effectivePrizePool,
                        );
                          return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Icon(
                                    blueprint.isSeries
                                        ? Icons.view_week_outlined
                                        : Icons.emoji_events_outlined,
                                    size: 18,
                                    color: const Color(0xFF556372),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(displayName),
                                  ),
                                  IconButton(
                                    tooltip: 'Baustein entfernen',
                                    onPressed: () {
                                      setState(() {
                                        _simpleQuickSelectedBlueprintIds.remove(
                                          blueprint.id,
                                        );
                                      });
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                        'quick-count-lite-${blueprint.id}',
                                      ),
                                      keyboardType: TextInputType.number,
                                      initialValue: '${config.count}',
                                      onChanged: (value) {
                                        final parsed =
                                            int.tryParse(value.trim()) ?? 0;
                                        setState(() {
                                          _simpleQuickTourConfigs[blueprint.id] =
                                              config.copyWith(
                                            count: parsed < 0 ? 0 : parsed,
                                          );
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Anzahl',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                        'quick-field-lite-${blueprint.id}',
                                      ),
                                      keyboardType: TextInputType.number,
                                      initialValue: '$effectiveFieldSize',
                                      onChanged: (value) {
                                        final parsed = int.tryParse(value.trim());
                                        setState(() {
                                          _simpleQuickTourConfigs[blueprint.id] =
                                              parsed == null
                                                  ? config.copyWith(
                                                      clearFieldSizeOverride: true,
                                                    )
                                                  : config.copyWith(
                                                      fieldSizeOverride: parsed,
                                                    );
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Teilnehmerfeld',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: TextFormField(
                                        key: ValueKey<String>(
                                        'quick-prize-lite-${blueprint.id}',
                                      ),
                                      keyboardType: TextInputType.number,
                                      initialValue: '$effectivePrizePool',
                                      onChanged: (value) {
                                        final parsed = int.tryParse(value.trim());
                                        setState(() {
                                          _simpleQuickTourConfigs[blueprint.id] =
                                              parsed == null
                                                  ? config.copyWith(
                                                      clearPrizePoolOverride: true,
                                                    )
                                                  : config.copyWith(
                                                      prizePoolOverride: parsed,
                                                    );
                                        });
                                      },
                                      decoration: const InputDecoration(
                                        labelText: 'Preisgeld',
                                      ),
                                    ),
                              ),
                            ],
                          ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<CareerTournamentPrizeSplitPreset>(
                                key: ValueKey<String>(
                                  'quick-prize-preset-lite-${blueprint.id}',
                                ),
                                initialValue: config.prizeSplitPreset,
                                decoration: const InputDecoration(
                                  labelText: 'Preisgeld-Share',
                                ),
                                items: CareerTournamentPrizeSplitPreset.values
                                    .map(
                                      (preset) => DropdownMenuItem<
                                          CareerTournamentPrizeSplitPreset>(
                                        value: preset,
                                        child: Text(preset.label),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _simpleQuickTourConfigs[blueprint.id] =
                                        config.copyWith(
                                      prizeSplitPreset: value,
                                    );
                                  });
                                },
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton(
                                  onPressed: () {
                                    final refreshedConfig =
                                        _simpleQuickTourConfigs[blueprint.id] ??
                                        config;
                                    final refreshedFieldSize =
                                        refreshedConfig.fieldSizeOverride ??
                                        _quickFieldSizeForBlueprint(
                                          blueprint: blueprint,
                                          rosterSize: rosterSize,
                                        );
                                    final refreshedPrizePool =
                                        refreshedConfig.prizePoolOverride ??
                                        _quickPrizePoolForFieldSize(
                                          blueprint: blueprint,
                                          fieldSize: refreshedFieldSize,
                                        );
                                    final refreshedPlayoffQualifierCount =
                                        blueprint.format ==
                                                TournamentFormat.leaguePlayoff
                                            ? _quickPlayoffQualifierCountForFieldSize(
                                                fieldSize: refreshedFieldSize,
                                                requestedQualifierCount:
                                                    blueprint.playoffQualifierCount,
                                              )
                                            : blueprint.playoffQualifierCount;
                                    setState(() {
                                      _simpleQuickTourConfigs[blueprint.id] =
                                          refreshedConfig.copyWith(
                                        knockoutPrizeValues:
                                            _defaultQuickKnockoutPrizeValues(
                                          preset: refreshedConfig.prizeSplitPreset,
                                          prizePool: refreshedPrizePool,
                                          stageCount: _quickKnockoutStageCount(
                                            blueprint: blueprint,
                                            fieldSize: refreshedFieldSize,
                                            playoffQualifierCount:
                                                refreshedPlayoffQualifierCount,
                                          ),
                                          format: blueprint.format,
                                        ),
                                        leaguePositionPrizeValues:
                                            _defaultQuickLeaguePrizeValues(
                                          preset: refreshedConfig.prizeSplitPreset,
                                          prizePool: refreshedPrizePool,
                                          placeCount:
                                              _quickLeaguePrizePlaceCount(
                                            blueprint: blueprint,
                                            fieldSize: refreshedFieldSize,
                                          ),
                                          format: blueprint.format,
                                        ),
                                      );
                                    });
                                  },
                                  child: const Text('Preset anwenden'),
                                ),
                              ),
                              if (effectiveKnockoutPrizeValues.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  'KO-Auszahlungen',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: List<Widget>.generate(
                                    effectiveKnockoutPrizeValues.length,
                                    (index) => SizedBox(
                                      width: 210,
                                      child: Column(
                                        children: <Widget>[
                                          TextFormField(
                                            key: ValueKey<String>(
                                              'quick-knockout-lite-${blueprint.id}-$index',
                                            ),
                                            keyboardType: TextInputType.number,
                                            initialValue:
                                                '${effectiveKnockoutPrizeValues[index]}',
                                            onChanged: (value) {
                                              final parsed =
                                                  int.tryParse(value.trim()) ?? 0;
                                              final nextValues = List<int>.from(
                                                effectiveKnockoutPrizeValues,
                                              );
                                              nextValues[index] =
                                                  parsed < 0 ? 0 : parsed;
                                              setState(() {
                                                _simpleQuickTourConfigs[
                                                        blueprint.id] =
                                                    config.copyWith(
                                                  knockoutPrizeValues: nextValues,
                                                );
                                              });
                                            },
                                            decoration: InputDecoration(
                                              labelText: _quickKnockoutPrizeLabel(
                                                index,
                                                effectiveKnockoutPrizeValues.length,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            key: ValueKey<String>(
                                              'quick-knockout-share-${blueprint.id}-$index',
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            initialValue:
                                                _quickKnockoutSharePercent(
                                              values: effectiveKnockoutPrizeValues,
                                              index: index,
                                              format: blueprint.format,
                                            ).toStringAsFixed(1),
                                            onChanged: (value) {
                                              final parsed = double.tryParse(
                                                value.trim().replaceAll(',', '.'),
                                              );
                                              if (parsed == null) {
                                                return;
                                              }
                                              final nextValues =
                                                  _quickKnockoutValuesWithSharePercent(
                                                values: effectiveKnockoutPrizeValues,
                                                index: index,
                                                sharePercent: parsed,
                                                prizePool: effectivePrizePool,
                                                format: blueprint.format,
                                              );
                                              setState(() {
                                                _simpleQuickTourConfigs[
                                                        blueprint.id] =
                                                    config.copyWith(
                                                  knockoutPrizeValues: nextValues,
                                                );
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              labelText: 'Share %',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (effectiveLeaguePrizeValues.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 8),
                                Text(
                                  'Liga-Auszahlungen',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: List<Widget>.generate(
                                    effectiveLeaguePrizeValues.length,
                                    (index) => SizedBox(
                                      width: 180,
                                      child: Column(
                                        children: <Widget>[
                                          TextFormField(
                                            key: ValueKey<String>(
                                              'quick-league-lite-${blueprint.id}-$index',
                                            ),
                                            keyboardType: TextInputType.number,
                                            initialValue:
                                                '${effectiveLeaguePrizeValues[index]}',
                                            onChanged: (value) {
                                              final parsed =
                                                  int.tryParse(value.trim()) ?? 0;
                                              final nextValues = List<int>.from(
                                                effectiveLeaguePrizeValues,
                                              );
                                              nextValues[index] =
                                                  parsed < 0 ? 0 : parsed;
                                              setState(() {
                                                _simpleQuickTourConfigs[
                                                        blueprint.id] =
                                                    config.copyWith(
                                                  leaguePositionPrizeValues:
                                                      nextValues,
                                                );
                                              });
                                            },
                                            decoration: InputDecoration(
                                              labelText: '${index + 1}. Platz',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            key: ValueKey<String>(
                                              'quick-league-share-${blueprint.id}-$index',
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                            initialValue: _quickLeagueSharePercent(
                                              values: effectiveLeaguePrizeValues,
                                              index: index,
                                            ).toStringAsFixed(1),
                                            onChanged: (value) {
                                              final parsed = double.tryParse(
                                                value.trim().replaceAll(',', '.'),
                                              );
                                              if (parsed == null) {
                                                return;
                                              }
                                              final nextValues =
                                                  _quickLeagueValuesWithSharePercent(
                                                values: effectiveLeaguePrizeValues,
                                                index: index,
                                                sharePercent: parsed,
                                                prizePool: effectivePrizePool,
                                                format: blueprint.format,
                                              );
                                              setState(() {
                                                _simpleQuickTourConfigs[
                                                        blueprint.id] =
                                                    config.copyWith(
                                                  leaguePositionPrizeValues:
                                                      nextValues,
                                                );
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              labelText: 'Share %',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          );
                        }).toList(),
                      ),
                  const SizedBox(height: 6),
                  Text(
                    template == null
                        ? 'Ohne Vorlage wird eine eigenstaendige Quick-Tour aufgebaut.'
                        : 'Mit Vorlage bleibt Quick deaktiviert, bis du die Vorlage abwaehlst.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
                ],
              )
                : Text(
                    template == null
                        ? 'Quick-Erstellung ist aus. Waehle eine Vorlage oder aktiviere die Quick-Erstellung fuer eine eigenstaendige Tour.'
                        : 'Es ist eine Vorlage aktiv. Fuer die Quick-Erstellung wird die Vorlage automatisch abgewaehlt.',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCreationCard(BuildContext context) {
    final selectedTemplate = _selectedTemplate();
    final effectiveTemplate = _effectiveSimpleCreationTemplate();
    final selectedPoolCount = _templateCreationPoolPlayers(selectedTemplate).length;
    final targetRosterSize = _effectiveSimpleTargetRosterSize(
      selectedPoolCount,
    );
    final generatedCount = max(0, targetRosterSize - selectedPoolCount);
    final canCreate = effectiveTemplate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Einfache Karriere',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Im einfachen Modus nutzt du entweder eine Vorlage oder die Quick-Erstellung. Beides gleichzeitig ist nicht aktiv.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTemplateSelectionCard(context),
        const SizedBox(height: 16),
        _buildSimpleQuickTournamentCard(context, selectedTemplate),
        const SizedBox(height: 16),
        _buildTemplatePoolSelector(
          context,
          labelText: 'Karriere-Kader',
        ),
        const SizedBox(height: 16),
        _buildWizardSectionCard(
          context,
          title: 'Trainingsmodus',
          subtitle:
              'Passe die Average-Spanne direkt vor dem Karrierestart fuer den aktuellen Start-Kader an.',
          child: _buildSimpleTrainingModeSection(selectedTemplate),
        ),
        const SizedBox(height: 16),
        _buildWizardSectionCard(
          context,
          title: 'Kadergroesse',
          subtitle:
              'Lege fest, wie gross der Karriere-Kader insgesamt sein soll. Fehlende Plaetze werden mit schwaecheren Spielern aufgefuellt.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _simpleTargetRosterSizeController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Ziel-Kadergroesse',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                generatedCount <= 0
                    ? 'Der aktuelle Kader ist bereits gross genug. Es werden keine Zusatzspieler erzeugt.'
                    : '$generatedCount Zusatzspieler werden automatisch erzeugt und bewusst schwaecher als dein ausgewaehlter Kern gehalten.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildWizardSectionCard(
          context,
          title: 'Start',
          subtitle:
              'Quick-Tour ist wieder sichtbar. Weitere Bloecke werden schrittweise wieder eingeblendet.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                selectedTemplate == null
                    ? (_simpleQuickTournamentGenerationEnabled
                        ? '$selectedPoolCount ausgewaehlte Spieler. ${generatedCount <= 0 ? 'Der aktuelle Kader ist bereits gross genug.' : '$generatedCount moegliche Zusatzspieler und bis zu $targetRosterSize Kaderplaetze sind vorbereitet.'} ${effectiveTemplate == null ? '' : '${effectiveTemplate.calendar.length} Quick-Tour-Eintraege sind vorbereitet.'}'
                        : 'Waehle zuerst eine Vorlage oder aktiviere die Quick-Erstellung.')
                    : '$selectedPoolCount ausgewaehlte Spieler. ${generatedCount <= 0 ? 'Der aktuelle Kader ist bereits gross genug.' : '$generatedCount moegliche Zusatzspieler und bis zu $targetRosterSize Kaderplaetze sind vorbereitet.'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: canCreate ? _createSimpleCareerFromTemplate : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Einfache Karriere erstellen'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedCreationCard(
    BuildContext context, {
    required List<CareerDefinition> careers,
    required CareerDefinition? activeCareer,
    required List<CareerTemplate> templates,
    required List<PlayerProfile> players,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSimpleCreationCard(context),
        const SizedBox(height: 16),
        _buildWizardSectionCard(
          context,
          title: 'Komplexe Erstellung',
          subtitle:
              'Wenn Vorlage oder Quick nicht reichen, kannst du hier in den vollstaendigen Karriere-Editor wechseln.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _showAdvancedCreation,
                onChanged: (value) {
                  setState(() => _showAdvancedCreation = value);
                },
                title: const Text('Komplexe Erstellung einblenden'),
                subtitle: const Text(
                  'Zeigt die komplette manuelle Karriere-Erstellung mit Kader, Ranglisten, Regeln und Kalender.',
                ),
              ),
              const SizedBox(height: 8),
              if (!_showAdvancedCreation)
                const Text(
                  'Starte oben mit Vorlage oder Quick-Tour. Nur fuer Spezialfaelle brauchst du den vollstaendigen Editor direkt am Anfang.',
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: <Widget>[
                      _buildCareerCard(
                        context,
                        careers: careers,
                        activeCareer: activeCareer,
                        templates: templates,
                        players: players,
                      ),
                      const SizedBox(height: 16),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'Die komplexe Erstellung bleibt verfuegbar, ist aber jetzt bewusst der zweite Schritt nach Vorlage oder Quick.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleQuickTourTypeCard(
    BuildContext context, {
    required _SimpleQuickTourBlueprint blueprint,
    required _SimpleQuickTourTypeConfig config,
    required int effectiveFieldSize,
    required int effectivePrizePool,
  }) {
    final effectivePlayoffQualifierCount =
        blueprint.format == TournamentFormat.leaguePlayoff
            ? _quickPlayoffQualifierCountForFieldSize(
                fieldSize: effectiveFieldSize,
                requestedQualifierCount: blueprint.playoffQualifierCount,
              )
            : blueprint.playoffQualifierCount;
    final effectiveKnockoutPrizeValues = _effectiveQuickKnockoutPrizeValues(
      blueprint: blueprint,
      config: config,
      fieldSize: effectiveFieldSize,
      prizePool: effectivePrizePool,
      playoffQualifierCount: effectivePlayoffQualifierCount,
    );
    final effectiveLeaguePrizeValues = _effectiveQuickLeaguePrizeValues(
      blueprint: blueprint,
      config: config,
      fieldSize: effectiveFieldSize,
      prizePool: effectivePrizePool,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    blueprint.categoryName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F4F3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_tournamentFormatLabel(blueprint.format)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              blueprint.isSeries
                  ? 'Serienformat mit mehreren Kalendereintraegen pro Event.'
                  : 'Einzelturnier der Tour.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>('quick-count-${blueprint.id}-${config.count}'),
                    keyboardType: TextInputType.number,
                    initialValue: '${config.count}',
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim()) ?? 0;
                      setState(() {
                        _simpleQuickTourConfigs[blueprint.id] = config.copyWith(
                          count: parsed < 0 ? 0 : parsed,
                        );
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Anzahl',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>(
                      'quick-field-${blueprint.id}-${config.fieldSizeOverride ?? effectiveFieldSize}',
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: '$effectiveFieldSize',
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      setState(() {
                        _simpleQuickTourConfigs[blueprint.id] = parsed == null
                            ? config.copyWith(clearFieldSizeOverride: true)
                            : config.copyWith(fieldSizeOverride: parsed);
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Teilnehmerfeld',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey<String>(
                      'quick-prize-${blueprint.id}-${config.prizePoolOverride ?? effectivePrizePool}',
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: '$effectivePrizePool',
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      setState(() {
                        _simpleQuickTourConfigs[blueprint.id] = parsed == null
                            ? config.copyWith(clearPrizePoolOverride: true)
                            : config.copyWith(prizePoolOverride: parsed);
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Preisgeld',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<CareerTournamentPrizeSplitPreset>(
                    key: ValueKey<String>(
                      'quick-prize-preset-${blueprint.id}-${config.prizeSplitPreset.name}',
                    ),
                    initialValue: config.prizeSplitPreset,
                    decoration: const InputDecoration(
                      labelText: 'Preisgeld-Share',
                    ),
                    items: CareerTournamentPrizeSplitPreset.values
                        .map(
                          (preset) =>
                              DropdownMenuItem<CareerTournamentPrizeSplitPreset>(
                            value: preset,
                            child: Text(preset.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _simpleQuickTourConfigs[blueprint.id] = config.copyWith(
                          prizeSplitPreset: value,
                          knockoutPrizeValues: _defaultQuickKnockoutPrizeValues(
                            preset: value,
                            prizePool: effectivePrizePool,
                            stageCount: _quickKnockoutStageCount(
                              blueprint: blueprint,
                              fieldSize: effectiveFieldSize,
                              playoffQualifierCount:
                                  effectivePlayoffQualifierCount,
                            ),
                            format: blueprint.format,
                          ),
                          leaguePositionPrizeValues:
                              _defaultQuickLeaguePrizeValues(
                            preset: value,
                            prizePool: effectivePrizePool,
                            placeCount: _quickLeaguePrizePlaceCount(
                              blueprint: blueprint,
                              fieldSize: effectiveFieldSize,
                            ),
                            format: blueprint.format,
                          ),
                        );
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _simpleQuickTourConfigs[blueprint.id] = config.copyWith(
                        knockoutPrizeValues: _defaultQuickKnockoutPrizeValues(
                          preset: config.prizeSplitPreset,
                          prizePool: effectivePrizePool,
                          stageCount: _quickKnockoutStageCount(
                            blueprint: blueprint,
                            fieldSize: effectiveFieldSize,
                            playoffQualifierCount:
                                effectivePlayoffQualifierCount,
                          ),
                          format: blueprint.format,
                        ),
                        leaguePositionPrizeValues:
                            _defaultQuickLeaguePrizeValues(
                          preset: config.prizeSplitPreset,
                          prizePool: effectivePrizePool,
                          placeCount: _quickLeaguePrizePlaceCount(
                            blueprint: blueprint,
                            fieldSize: effectiveFieldSize,
                          ),
                          format: blueprint.format,
                        ),
                      );
                    });
                  },
                  child: const Text('Preset anwenden'),
                ),
              ],
            ),
            if (effectiveKnockoutPrizeValues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'KO-Auszahlungen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(
                  effectiveKnockoutPrizeValues.length,
                  (index) => SizedBox(
                    width: 210,
                    child: TextFormField(
                      key: ValueKey<String>(
                        'quick-knockout-${blueprint.id}-$index-${effectiveKnockoutPrizeValues[index]}',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '${effectiveKnockoutPrizeValues[index]}',
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim()) ?? 0;
                        final nextValues =
                            List<int>.from(effectiveKnockoutPrizeValues);
                        nextValues[index] = parsed < 0 ? 0 : parsed;
                        setState(() {
                          _simpleQuickTourConfigs[blueprint.id] = config.copyWith(
                            knockoutPrizeValues: nextValues,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        labelText: _quickKnockoutPrizeLabel(
                          index,
                          effectiveKnockoutPrizeValues.length,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (effectiveLeaguePrizeValues.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Liga-Auszahlungen',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List<Widget>.generate(
                  effectiveLeaguePrizeValues.length,
                  (index) => SizedBox(
                    width: 180,
                    child: TextFormField(
                      key: ValueKey<String>(
                        'quick-league-${blueprint.id}-$index-${effectiveLeaguePrizeValues[index]}',
                      ),
                      keyboardType: TextInputType.number,
                      initialValue: '${effectiveLeaguePrizeValues[index]}',
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim()) ?? 0;
                        final nextValues =
                            List<int>.from(effectiveLeaguePrizeValues);
                        nextValues[index] = parsed < 0 ? 0 : parsed;
                        setState(() {
                          _simpleQuickTourConfigs[blueprint.id] = config.copyWith(
                            leaguePositionPrizeValues: nextValues,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        labelText: '${index + 1}. Platz',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCard(BuildContext context, CareerDefinition career) {
    final issues = _collectValidationIssues(career);
    final previews = career.currentSeason.calendar
        .take(6)
        .map((item) => _buildTournamentPreview(career, item))
        .toList();
    return Column(
      children: <Widget>[
        _buildRankingCutoffPreviewCard(context, career),
        const SizedBox(height: 16),
        CareerValidationPanel(
          issues: issues,
          previews: previews,
        ),
      ],
    );
  }

  List<CareerEditorIssue> _collectValidationIssues(CareerDefinition career) {
    final issues = <CareerEditorIssue>[];
    final rankingIds = career.rankings.map((ranking) => ranking.id).toSet();

    if (career.rankings.isEmpty) {
      issues.add(
        const CareerEditorIssue(
          severity: CareerEditorIssueSeverity.warning,
          title: 'Keine Ranglisten angelegt',
          message:
              'Turniere koennen zwar existieren, aber Rankings, Setzlisten und viele Quali-Wege bleiben damit leer.',
        ),
      );
    }
    if (career.currentSeason.calendar.isEmpty) {
      issues.add(
        const CareerEditorIssue(
          severity: CareerEditorIssueSeverity.warning,
          title: 'Kein Saisonkalender vorhanden',
          message:
              'Lege mindestens ein Turnier oder eine Turnierserie an, damit die Karriere spielbar wird.',
        ),
      );
    }
    if (career.databasePlayers.isEmpty) {
      issues.add(
        const CareerEditorIssue(
          severity: CareerEditorIssueSeverity.error,
          title: 'Kein Spielerpool vorhanden',
          message:
              'Die Karriere hat aktuell keine Datenbankspieler und kann deshalb keine Turnierfelder fuellen.',
        ),
      );
    }

    final rankingUsage = <String, int>{
      for (final ranking in career.rankings) ranking.id: 0,
    };

      for (final item in career.currentSeason.calendar) {
        final previewParticipants = TournamentRepository.instance
            .previewCareerParticipants(career: career, item: item);
        final seededParticipants = previewParticipants
            .where((participant) => participant.seedNumber != null)
            .toList()
          ..sort((left, right) {
            final seedCompare =
                (left.seedNumber ?? 1 << 20).compareTo(right.seedNumber ?? 1 << 20);
            if (seedCompare != 0) {
              return seedCompare;
            }
            return left.name.compareTo(right.name);
          });
        for (final rankingId in item.countsForRankingIds) {
          rankingUsage.update(rankingId, (count) => count + 1, ifAbsent: () => 1);
        }

      final fixedSlotCount = item.effectiveSlotRules.fold<int>(
        0,
        (sum, rule) => sum + rule.slotCount,
      );
      final estimatedEligiblePlayers = _estimatedEligiblePlayers(career, item);

      if (item.countsForRankingIds.isEmpty) {
        issues.add(
          CareerEditorIssue(
            severity: CareerEditorIssueSeverity.info,
            title: '${item.name}: zaehlt fuer keine Rangliste',
            message:
                'Das Turnier speist aktuell keine Rangliste und wirkt damit nur auf Historie, Geld und Tags.',
          ),
        );
      }
        if (item.seedingRankingId != null && !rankingIds.contains(item.seedingRankingId)) {
          issues.add(
            CareerEditorIssue(
              severity: CareerEditorIssueSeverity.error,
            title: '${item.name}: Setzlisten-Rangliste fehlt',
            message:
                'Die ausgewaehlte Setzlisten-Rangliste existiert nicht mehr und sollte neu gesetzt werden.',
            ),
          );
        }
        if (item.seedingRankingId != null &&
            item.seedCount > 0 &&
            seededParticipants.length < item.seedCount) {
          issues.add(
            CareerEditorIssue(
              severity: CareerEditorIssueSeverity.warning,
              title: '${item.name}: weniger gesetzte Spieler als eingestellt',
              message:
                  'Aktuell koennen nur ${seededParticipants.length} von ${item.seedCount} geplanten Setzplaetzen vergeben werden.',
            ),
          );
        }
        for (final rule in item.effectiveSlotRules) {
        if (rule.sourceType == CareerTournamentSlotSourceType.rankingRange &&
            (rule.rankingId == null || !rankingIds.contains(rule.rankingId))) {
          issues.add(
            CareerEditorIssue(
              severity: CareerEditorIssueSeverity.error,
              title: '${item.name}: Slot-Regel ohne gueltige Rangliste',
              message:
                  'Mindestens eine Slot-Regel verweist auf eine nicht mehr vorhandene Rangliste.',
            ),
          );
        }
      }
      if (item.format == TournamentFormat.knockout) {
        final roundSlotCounts = <int, int>{};
        for (final rule in item.effectiveSlotRules) {
          roundSlotCounts.update(
            rule.entryRound,
            (count) => count + rule.slotCount,
            ifAbsent: () => rule.slotCount,
          );
        }
        for (final entry in roundSlotCounts.entries) {
          final capacity = _knockoutRoundEntryCapacity(
            fieldSize: item.fieldSize,
            entryRound: entry.key,
          );
          if (entry.value > capacity) {
            issues.add(
              CareerEditorIssue(
                severity: CareerEditorIssueSeverity.error,
                title: '${item.name}: zu viele Einsteiger fuer Runde ${entry.key}',
                message:
                    '${entry.value} Spieler sollen erst in Runde ${entry.key} einsteigen, aber in diesem ${item.fieldSize}er Feld gibt es dort nur $capacity freie Startplaetze.',
              ),
            );
          }
        }
      }
      for (final rule in item.effectiveFillRules) {
        if (rule.sourceType == CareerTournamentFillSourceType.ranking &&
            (rule.rankingId == null || !rankingIds.contains(rule.rankingId))) {
          issues.add(
            CareerEditorIssue(
              severity: CareerEditorIssueSeverity.error,
              title: '${item.name}: Fill-Regel ohne gueltige Rangliste',
              message:
                  'Mindestens eine Fill-Regel ueber Rangliste verweist auf eine nicht mehr vorhandene Rangliste.',
            ),
          );
        }
      }
      if (fixedSlotCount > item.fieldSize) {
        issues.add(
          CareerEditorIssue(
            severity: CareerEditorIssueSeverity.warning,
            title: '${item.name}: mehr feste Slots als Feldgroesse',
            message:
                '$fixedSlotCount feste Slots treffen auf ein ${item.fieldSize}er Feld. Das erzeugt Ueberbuchung oder verdraengte Teilnehmer.',
          ),
        );
      }
      if (estimatedEligiblePlayers < item.fieldSize) {
        issues.add(
          CareerEditorIssue(
            severity: CareerEditorIssueSeverity.warning,
            title: '${item.name}: zu kleiner Spielerpool',
            message:
                'Aktuell sind nur etwa $estimatedEligiblePlayers von ${item.fieldSize} benoetigten Spielern ueber Slot- und Fill-Regeln erreichbar.',
          ),
        );
      }
      if (item.tagGate != null) {
        final gateMatches = career.databasePlayers
            .where((player) => player.activeTagNames.contains(item.tagGate!.tagName))
            .length;
        final gateMet = gateMatches >= item.tagGate!.minimumPlayerCount;
        final tournamentOccurs = item.tagGate!.tournamentOccursWhenMet
            ? gateMet
            : !gateMet;
        if (!tournamentOccurs) {
          issues.add(
            CareerEditorIssue(
              severity: CareerEditorIssueSeverity.info,
              title: '${item.name}: Turnier-Regel greift aktuell nicht',
              message:
                  'Die Tag-Pruefung fuer `${item.tagGate!.tagName}` ist im aktuellen Kader nicht erfuellt, das Turnier wuerde also ausfallen.',
            ),
          );
        }
      }
    }

    for (final ranking in career.rankings) {
      if ((rankingUsage[ranking.id] ?? 0) == 0) {
        issues.add(
          CareerEditorIssue(
            severity: CareerEditorIssueSeverity.info,
            title: '${ranking.name}: ohne Einspeiser',
            message:
                'Diese Rangliste wird aktuell von keinem Turnier gespeist.',
          ),
        );
      }
    }

    final humanPreview = _buildHumanCareerPreview(career);
    if (humanPreview != null) {
      issues.add(humanPreview);
    }

    return issues;
  }

  CareerTournamentPreview _buildTournamentPreview(
    CareerDefinition career,
    CareerCalendarItem item,
  ) {
    final estimatedEligiblePlayers = _estimatedEligiblePlayers(career, item);
    final fixedSlotCount = item.effectiveSlotRules.fold<int>(
      0,
      (sum, rule) => sum + rule.slotCount,
    );
    final previewParticipants = TournamentRepository.instance
        .previewCareerParticipants(career: career, item: item);
    final seededParticipants = previewParticipants
        .where((participant) => participant.seedNumber != null)
        .toList()
      ..sort((left, right) {
        final seedCompare =
            (left.seedNumber ?? 1 << 20).compareTo(right.seedNumber ?? 1 << 20);
        if (seedCompare != 0) {
          return seedCompare;
        }
        return left.name.compareTo(right.name);
      });
    final gateActive = _isTournamentCurrentlyActive(career, item);
    final enoughPlayers = estimatedEligiblePlayers >= item.fieldSize;
    return CareerTournamentPreview(
      name: item.name,
      fieldSize: item.fieldSize,
      estimatedEligiblePlayers: estimatedEligiblePlayers,
      fixedSlotCount: fixedSlotCount,
      fillRuleCount: item.effectiveFillRules.length,
      statusLabel: !gateActive
          ? 'Faellt aktuell aus'
          : enoughPlayers
          ? 'Spielbar'
          : 'Unterbesetzt',
      statusColor: !gateActive
          ? Colors.blue.shade100
          : enoughPlayers
          ? Colors.green.shade100
          : Colors.orange.shade100,
      humanStatus: _humanTournamentStatus(career, item),
      seedTarget: item.seedCount,
      seededCount: seededParticipants.length,
      seededPlayers: seededParticipants
          .take(8)
          .map((participant) => 'S${participant.seedNumber} ${participant.name}')
          .toList(),
    );
  }

  CareerEditorIssue? _buildHumanCareerPreview(CareerDefinition career) {
    if (career.participantMode != CareerParticipantMode.withHuman ||
        career.playerProfileId == null) {
      return null;
    }
    final humanPlayer = career.databasePlayers
        .where((player) => player.databasePlayerId == career.playerProfileId)
        .toList();
    if (humanPlayer.isEmpty) {
      return const CareerEditorIssue(
        severity: CareerEditorIssueSeverity.warning,
        title: 'Mein Spieler ist nicht im Karriere-Kader',
        message:
            'Das Spielerprofil ist nicht sauber im Karriere-Pool vorhanden und kann so in keinem Turnier auftauchen.',
      );
    }
    final playableTournaments = career.currentSeason.calendar
        .where((item) => _isPlayerEligibleForTournament(humanPlayer.first, item, career))
        .length;
    if (playableTournaments == 0) {
      return const CareerEditorIssue(
        severity: CareerEditorIssueSeverity.warning,
        title: 'Mein Spieler hat aktuell keinen Startpfad',
        message:
            'Im aktuellen Saisonkalender passt dein Spieler zu keiner Turnierregel. Pruefe Slot-Regeln, Fill-Regeln und Karriere-Tags.',
      );
    }
    return CareerEditorIssue(
      severity: CareerEditorIssueSeverity.info,
      title: 'Mein Spieler ist eingeplant',
      message:
          'Dein Spieler passt aktuell zu $playableTournaments Turnieren im Kalender.',
    );
  }

  int _estimatedEligiblePlayers(
    CareerDefinition career,
    CareerCalendarItem item,
  ) {
    return career.databasePlayers
        .where((player) => _isPlayerEligibleForTournament(player, item, career))
        .length;
  }

  bool _isPlayerEligibleForTournament(
    CareerDatabasePlayer player,
    CareerCalendarItem item,
    CareerDefinition career,
  ) {
    if (!_isTournamentCurrentlyActive(career, item)) {
      return false;
    }
    final slotRules = item.effectiveSlotRules;
    final fillRules = item.effectiveFillRules;
    if (slotRules.isEmpty && fillRules.isEmpty) {
      return true;
    }
    return slotRules.any((rule) => _matchesSlotRule(player, rule)) ||
        fillRules.any((rule) => _matchesFillRule(player, rule));
  }

  bool _isTournamentCurrentlyActive(
    CareerDefinition career,
    CareerCalendarItem item,
  ) {
    final tagGate = item.tagGate;
    if (tagGate == null) {
      return true;
    }
    final gateMatches = career.databasePlayers
        .where((player) => player.activeTagNames.contains(tagGate.tagName))
        .length;
    final gateMet = gateMatches >= tagGate.minimumPlayerCount;
    return tagGate.tournamentOccursWhenMet ? gateMet : !gateMet;
  }

  bool _matchesSlotRule(
    CareerDatabasePlayer player,
    CareerTournamentSlotRule rule,
  ) {
    final tagsMatch = _matchesTagFilters(
      player,
      requiredTags: rule.requiredCareerTags,
      excludedTags: rule.excludedCareerTags,
      requiredNationalities: rule.requiredNationalities,
      excludedNationalities: rule.excludedNationalities,
    );
    if (!tagsMatch) {
      return false;
    }
    switch (rule.sourceType) {
      case CareerTournamentSlotSourceType.careerTag:
        return rule.requiredCareerTags.isEmpty ||
            rule.requiredCareerTags.every(player.activeTagNames.contains);
      case CareerTournamentSlotSourceType.rankingRange:
        return true;
    }
  }

  bool _matchesFillRule(
    CareerDatabasePlayer player,
    CareerTournamentFillRule rule,
  ) {
    return _matchesTagFilters(
      player,
      requiredTags: rule.requiredCareerTags,
      excludedTags: rule.excludedCareerTags,
      requiredNationalities: rule.requiredNationalities,
      excludedNationalities: rule.excludedNationalities,
    );
  }

  bool _matchesTagFilters(
    CareerDatabasePlayer player, {
    required List<String> requiredTags,
    required List<String> excludedTags,
    List<String> requiredNationalities = const <String>[],
    List<String> excludedNationalities = const <String>[],
  }) {
      final tagNames = player.activeTagNames.toSet();
      for (final tag in requiredTags) {
        if (!tagNames.contains(tag)) {
          return false;
      }
    }
      for (final tag in excludedTags) {
        if (tagNames.contains(tag)) {
          return false;
        }
      }
      final nationality = (player.nationality ?? '').trim();
      if (requiredNationalities.isNotEmpty &&
          !requiredNationalities.contains(nationality)) {
        return false;
      }
      if (nationality.isNotEmpty &&
          excludedNationalities.contains(nationality)) {
        return false;
      }
      return true;
    }

  List<String> _availableCareerNationalities(CareerDefinition career) {
    final result = <String>{};
    for (final player in career.databasePlayers) {
      final nationality = (player.nationality ?? '').trim();
      if (nationality.isNotEmpty) {
        result.add(nationality);
      }
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  String _humanTournamentStatus(CareerDefinition career, CareerCalendarItem item) {
    if (career.participantMode != CareerParticipantMode.withHuman ||
        career.playerProfileId == null) {
      return 'CPU-Karriere ohne eigenes Profil.';
    }
    final players = career.databasePlayers
        .where((player) => player.databasePlayerId == career.playerProfileId)
        .toList();
    if (players.isEmpty) {
      return 'Mein Spieler ist aktuell nicht im Karriere-Kader.';
    }
    return _isPlayerEligibleForTournament(players.first, item, career)
        ? 'Mein Spieler passt aktuell zu mindestens einer Turnierregel.'
        : 'Mein Spieler passt aktuell zu keiner Turnierregel.';
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required String title,
    String? subtitle,
    bool initiallyExpanded = false,
    required List<Widget> children,
  }) {
    return CareerEditorSectionCard(
      title: title,
      subtitle: subtitle,
      initiallyExpanded: initiallyExpanded,
      children: children,
    );
  }

  Widget _buildCalendarCard(BuildContext context, CareerDefinition career) {
    final calendar = career.currentSeason.calendar;
    final largestFieldSize = calendar.isEmpty
        ? 0
        : calendar
            .map((item) => item.fieldSize)
            .reduce((left, right) => left > right ? left : right);
    final firstTournamentName = calendar.isEmpty ? null : calendar.first.name;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildWizardSectionCard(
          context,
          title: 'Kalender pruefen',
          subtitle:
              'Pflicht: Reihenfolge kontrollieren und sicherstellen, dass die Saisonstruktur stimmt.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${calendar.length} Turniere geplant'
                '${largestFieldSize > 0 ? ' | Groesstes Feld $largestFieldSize Spieler' : ''}'
                '${firstTournamentName == null ? '' : ' | Start mit $firstTournamentName'}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _showAdvancedCalendarDetails,
                onChanged: (value) {
                  setState(() => _showAdvancedCalendarDetails = value);
                },
                title: const Text('Erweiterte Turnierdetails einblenden'),
                subtitle: const Text(
                  'Zeigt Ranglisten, Setzlisten, Preisgeld und Sonderregeln direkt in der Kalenderliste.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          context: context,
          title: 'Saisonkalender',
          subtitle: calendar.isEmpty
              ? 'Noch keine Turniere geplant'
              : '${calendar.length} Turniere in Saison-Reihenfolge',
          initiallyExpanded: true,
          children: <Widget>[
            if (calendar.isEmpty)
              const Text(
                'Noch keine Turniere angelegt. Weiter unten kannst du das erste Turnier hinzufuegen.',
              )
            else ...<Widget>[
              Text(
                'Ziehe die Turniere in die richtige Reihenfolge. Bearbeiten und Loeschen bleibt direkt pro Eintrag erreichbar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
              const SizedBox(height: 12),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: calendar.length,
                onReorder: (oldIndex, newIndex) {
                  var target = newIndex;
                  if (target > oldIndex) {
                    target -= 1;
                  }
                  _repository.reorderCalendar(oldIndex, target);
                },
                itemBuilder: (context, index) {
                  final item = calendar[index];
                  return Card(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        _showAdvancedCalendarDetails
                            ? _calendarItemAdvancedSubtitle(career, item)
                            : _calendarItemCompactSubtitle(item),
                      ),
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      trailing: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          IconButton(
                            onPressed: () => _beginEdit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () {
                              _repository.removeCalendarItem(item.id);
                              if (_editingCalendarItemId == item.id) {
                                _resetCalendarForm(career);
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _calendarItemCompactSubtitle(CareerCalendarItem item) {
    final tierLabel = item.tier == null ? '' : 'Tier ${item.tier} | ';
    final formatLabel = _tournamentFormatLabel(item.format);
    return '$tierLabel$formatLabel | ${item.fieldSize} Spieler | ${item.startScore}';
  }

  String _calendarItemAdvancedSubtitle(
    CareerDefinition career,
    CareerCalendarItem item,
  ) {
    final rankingsLabel = item.countsForRankingIds.isEmpty
        ? 'Keine Rangliste'
        : career.rankings
            .where((ranking) => item.countsForRankingIds.contains(ranking.id))
            .map((entry) => entry.name)
            .join(', ');
    var seedingLabel = 'Keine Setzliste';
    if (item.seedingRankingId != null) {
      for (final ranking in career.rankings) {
        if (ranking.id == item.seedingRankingId) {
          seedingLabel = ranking.name;
          break;
        }
      }
    }
    final baseLabel = item.format == TournamentFormat.league
        ? '${item.tier == null ? '' : 'Tier ${item.tier} | '}'
            '${item.fieldSize} Spieler | Liga ${item.roundRobinRepeats}x | '
            '${item.pointsForWin}/${item.pointsForDraw} Punkte | '
            '${item.startScore} | Preisgeld ${item.prizePool} | '
            '$rankingsLabel'
        : item.format == TournamentFormat.leaguePlayoff
            ? '${item.tier == null ? '' : 'Tier ${item.tier} | '}'
                '${item.fieldSize} Spieler | Liga ${item.roundRobinRepeats}x + Top ${item.playoffQualifierCount} Playoffs | '
                '${item.pointsForWin}/${item.pointsForDraw} Punkte | '
                '${item.startScore} | Preisgeld ${item.prizePool} | '
                '$rankingsLabel'
            : '${item.tier == null ? '' : 'Tier ${item.tier} | '}'
                '${item.fieldSize} Spieler | First to ${item.legsToWin} | '
                '${item.matchMode == MatchMode.legs ? 'Legs' : 'Sets ${item.setsToWin} / Legs ${item.legsPerSet}'} | '
                '${item.startScore} | Preisgeld ${item.prizePool} | '
                '$rankingsLabel | $seedingLabel Top ${item.seedCount}';
    final tagGateLabel = item.tagGate == null
        ? ''
        : ' | Tag-Regel ${item.tagGate!.tagName} ${item.tagGate!.minimumPlayerCount}+';
    return '$baseLabel$tagGateLabel';
  }

  Widget _buildTemplatesCard(BuildContext context, CareerDefinition career) {
    return _buildExpandableSection(
      context: context,
      title: 'Vorlagen',
      subtitle: '${_templateRepository.templates.length} gespeichert',
      children: <Widget>[
        TextField(
          controller: _templateNameController,
          decoration: const InputDecoration(labelText: 'Vorlagenname'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => _saveCurrentCareerAsTemplate(career),
          icon: const Icon(Icons.bookmark_add),
          label: const Text('Aktuelle Planung als Vorlage speichern'),
        ),
        if (_templateRepository.templates.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ..._templateRepository.templates.map(
            (template) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(template.name),
              subtitle: Text(
                '${template.calendar.length} Turniere | ${template.rankings.length} Ranglisten | Pool wird beim Erstellen gewaehlt',
              ),
              trailing: _templateRepository.isBuiltInTemplate(template.id)
                  ? const Chip(label: Text('App'))
                  : IconButton(
                      onPressed: () {
                        _templateRepository.deleteTemplate(template.id);
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRankingsCard(BuildContext context, CareerDefinition career) {
    return Column(
      children: <Widget>[
        CareerRankingsEditor(
          rankings: career.rankings,
          rankingNameController: _rankingNameController,
          rankingValidSeasonsController: _rankingValidSeasonsController,
          rankingResetAtSeasonEnd: _rankingResetAtSeasonEnd,
          editingRankingId: _editingRankingId,
          onValidSeasonsChanged: (value) {
            setState(() => _rankingValidSeasons = value);
          },
          onResetAtSeasonEndChanged: (value) {
            setState(() => _rankingResetAtSeasonEnd = value);
          },
          onSave: _addRanking,
          onCancelEdit: _resetRankingForm,
          onEditRanking: _beginEditRanking,
          onDeleteRanking: _removeRanking,
        ),
        const SizedBox(height: 16),
        _buildRankingCutoffPreviewCard(context, career),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildTournamentCard(BuildContext context, CareerDefinition career) {
    return CareerTournamentEditor(
      isEditing: _editingCalendarItemId != null,
      nameController: _itemNameController,
      formData: _tournamentFormData,
      onFormChanged: (value) {
        setState(() {
          _tournamentFormData = value;
          _syncKnockoutPrizeValues();
          _syncLeaguePositionPrizeValues();
        });
      },
      prizeSection: CareerTournamentPrizeEditor(
        usesKnockoutPrizeSetup: _usesKnockoutPrizeSetup,
        usesLeaguePositionPrizeSetup: _usesLeaguePositionPrizeSetup,
        knockoutPrizeValues: _knockoutPrizeValues,
        knockoutPrizeLabel: _knockoutPrizeLabel,
        onKnockoutPrizeChanged: (index, value) {
          final parsed = int.tryParse(value.trim()) ?? 0;
          setState(() {
            _knockoutPrizeValues[index] = parsed;
          });
        },
        calculatedKnockoutPrizePool: _calculatedKnockoutPrizePool(),
        leaguePositionPrizeValues: _leaguePositionPrizeValues,
        onLeaguePositionPrizeChanged: (index, value) {
          final parsed = int.tryParse(value.trim()) ?? 0;
          setState(() {
            _leaguePositionPrizeValues[index] = parsed;
          });
        },
        calculatedLeaguePrizePool: _calculatedLeaguePrizePool(),
        prizePoolController: _prizePoolController,
        calculatedPrizePool: _calculatedPrizePool(),
        selectedSplitPreset: _selectedPrizeSplitPreset,
        onSplitPresetChanged: (value) {
          setState(() => _selectedPrizeSplitPreset = value);
        },
        onApplyKnockoutSplit: () {
          setState(_applyKnockoutPrizeSplitPreset);
        },
        totalPrizeHelperText: _prizePoolHelperText(),
      ),
      seriesSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_tournamentFormData.format == TournamentFormat.league ||
              _tournamentFormData.format == TournamentFormat.leaguePlayoff)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _expandLeagueIntoMatchdays && _editingCalendarItemId == null,
              onChanged: _editingCalendarItemId != null
                  ? null
                  : (value) {
                      setState(() => _expandLeagueIntoMatchdays = value);
                    },
              title: const Text('Als Spieltage im Saisonkalender ausgeben'),
              subtitle: const Text(
                'Legt jeden Spieltag und bei Liga+Playoff auch die Playoff-Runden als eigene Kalendereintraege an.',
              ),
            ),
          if (_expandLeagueIntoMatchdays &&
              _editingCalendarItemId == null &&
              (_tournamentFormData.format == TournamentFormat.league ||
                  _tournamentFormData.format ==
                      TournamentFormat.leaguePlayoff)) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<CareerLeagueSeriesQualificationMode>(
              initialValue: _leagueSeriesQualificationMode,
              decoration: const InputDecoration(
                labelText: 'Qualifikation fuer Spieltage',
              ),
              items: const <DropdownMenuItem<CareerLeagueSeriesQualificationMode>>[
                DropdownMenuItem(
                  value: CareerLeagueSeriesQualificationMode.fixedAtStart,
                  child: Text('Teilnehmer einmalig zu Ligastart festziehen'),
                ),
                DropdownMenuItem(
                  value:
                      CareerLeagueSeriesQualificationMode.recheckEachMatchday,
                  child: Text('Vor jedem Spieltag neu qualifizieren'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _leagueSeriesQualificationMode = value);
                }
              },
            ),
          ],
          if (!_expandLeagueIntoMatchdays ||
              (_tournamentFormData.format != TournamentFormat.league &&
                  _tournamentFormData.format !=
                      TournamentFormat.leaguePlayoff))
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _createAsSeries && _editingCalendarItemId == null,
                onChanged: _editingCalendarItemId != null
                    ? null
                    : (value) {
                        setState(() => _createAsSeries = value);
                      },
                title: const Text('Als Turnierserie anlegen'),
                subtitle: Text(
                  _editingCalendarItemId != null
                      ? 'Beim Bearbeiten wird immer nur dieses eine Turnier aktualisiert.'
                      : 'Erstellt dasselbe Turnier mehrfach und nummeriert es automatisch durch.',
                ),
            ),
          if (_createAsSeries &&
              !_expandLeagueIntoMatchdays &&
              _editingCalendarItemId == null) ...<Widget>[
            const SizedBox(height: 12),
            TextField(
              controller: _seriesCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Anzahl Turniere in der Serie',
                helperText: 'Zum Beispiel 5 fuer Name 1 bis Name 5.',
              ),
            ),
          ],
        ],
      ),
      seedingSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DropdownButtonFormField<String?>(
            key: ValueKey<String?>(_seedingRankingId ?? 'no-seeding'),
            initialValue: _seedingRankingId,
            decoration: const InputDecoration(
              labelText: 'Setzlisten-Rangliste',
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Keine Setzliste'),
              ),
              ...career.rankings.map(
                (ranking) => DropdownMenuItem<String?>(
                  value: ranking.id,
                  child: Text(ranking.name),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _seedingRankingId = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '$_seedCount',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Gesetzte Plaetze',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                setState(() => _seedCount = parsed);
              }
            },
          ),
        ],
      ),
      slotRuleSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              'Slot-Regeln',
              style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Definiert feste Startplaetze und spaete Einstiege ins Turnier, zum Beispiel: 48er Feld, Plaetze 17-48 ab Runde 1 und Top 16 ab Runde 2.',
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<CareerQualificationConditionType>(
              initialValue: _qualificationConditionType,
              decoration: const InputDecoration(labelText: 'Quali-Typ'),
              items: const <DropdownMenuItem<CareerQualificationConditionType>>[
                DropdownMenuItem(
                  value: CareerQualificationConditionType.rankingRange,
                  child: Text('Ranglistenbereich'),
                ),
                DropdownMenuItem(
                  value: CareerQualificationConditionType.careerTagOnly,
                  child: Text('Nur Karriere-Tag'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _qualificationConditionType = value);
                }
              },
          ),
          if (_qualificationConditionType ==
                CareerQualificationConditionType.rankingRange) ...<Widget>[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  _qualificationRankingId ?? 'qualification-empty',
                ),
                initialValue: _qualificationRankingId,
                decoration: const InputDecoration(labelText: 'Rangliste'),
                items: career.rankings
                    .map(
                      (ranking) => DropdownMenuItem<String>(
                        value: ranking.id,
                        child: Text(ranking.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _qualificationRankingId = value);
                  }
                },
            ),
          ],
          if (career.careerTagDefinitions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
                _qualificationConditionType ==
                        CareerQualificationConditionType.careerTagOnly
                    ? 'Karriere-Tag fuer diese Qualifikation'
                    : 'Zusaetzliche Karriere-Tags fuer diese Qualifikation',
                style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: career.careerTagDefinitions.map((definition) {
                  return FilterChip(
                    label: Text(definition.name),
                    selected:
                        _selectedQualificationTagNames.contains(definition.name),
                    onSelected: (selected) {
                      setState(() {
                        if (_qualificationConditionType ==
                            CareerQualificationConditionType.careerTagOnly) {
                          _selectedQualificationTagNames.clear();
                          if (selected) {
                            _selectedQualificationTagNames.add(definition.name);
                          }
                        } else {
                          if (selected) {
                            _selectedQualificationTagNames.add(definition.name);
                          } else {
                            _selectedQualificationTagNames
                                .remove(definition.name);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
                'Karriere-Tags als Ausschluss',
                style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: career.careerTagDefinitions.map((definition) {
                  return FilterChip(
                    label: Text(definition.name),
                    selected: _selectedQualificationExcludedTagNames
                        .contains(definition.name),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedQualificationExcludedTagNames
                              .add(definition.name);
                        } else {
                          _selectedQualificationExcludedTagNames
                              .remove(definition.name);
                        }
                      });
                    },
                  );
                }).toList(),
            ),
          ],
          if (_qualificationConditionType ==
                CareerQualificationConditionType.rankingRange) ...<Widget>[
            const SizedBox(height: 12),
            Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _qualificationFromController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Von Rang'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _qualificationToController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bis Rang'),
                    ),
                  ),
                ],
            ),
          ],
          const SizedBox(height: 12),
          TextField(
              controller: _qualificationSlotCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximale Slots',
                helperText:
                    'Leer = alle passenden Spieler aus dieser Bedingung uebernehmen.',
              ),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _qualificationEntryRoundController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Greift ab Runde',
                helperText:
                    '1 = direkt zu Turnierbeginn, 2 = Einstieg in Runde 2 usw. Beispiel: Top 16 ab Runde 2.',
              ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => _addQualificationCondition(career),
              icon: const Icon(Icons.playlist_add),
              label: const Text('Bedingung hinzufuegen'),
          ),
          const SizedBox(height: 8),
          if (_qualificationConditions.isEmpty)
            const Text('Noch keine Bedingungen angelegt.')
          else
            ..._qualificationConditions.asMap().entries.map((entry) {
                var rankingName = entry.value.rankingId ?? 'Karriere-Tag';
                if (entry.value.rankingId != null) {
                  for (final ranking in career.rankings) {
                    if (ranking.id == entry.value.rankingId) {
                      rankingName = ranking.name;
                      break;
                    }
                  }
                }
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_qualificationConditionLabel(entry.value, rankingName)),
              trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _qualificationConditions.removeAt(entry.key);
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              }),
        ],
      ),
      fillRuleSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              'Fill-Regeln ueber Rangliste',
              style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
              key: ValueKey<String?>(_fillRankingId ?? 'fill-ranking-empty'),
              initialValue: _fillRankingId,
              decoration: const InputDecoration(
                labelText: 'Auffuell-Rangliste',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Keine Rangliste'),
                ),
                ...career.rankings.map(
                  (ranking) => DropdownMenuItem<String?>(
                    value: ranking.id,
                    child: Text(ranking.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _fillRankingId = value);
              },
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _fillTopByRankingController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Top X aus Rangliste',
                helperText:
                    '0 oder leer = unbegrenzt aus der gewaehlten Rangliste auffuellen.',
              ),
          ),
          const SizedBox(height: 16),
          Text(
              'Fill-Regeln nach Average',
              style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (career.careerTagDefinitions.isNotEmpty) ...<Widget>[
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: career.careerTagDefinitions.map((definition) {
                  return FilterChip(
                    label: Text(definition.name),
                    selected: _selectedFillTagNames.contains(definition.name),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFillTagNames.add(definition.name);
                        } else {
                          _selectedFillTagNames.remove(definition.name);
                        }
                      });
                    },
                  );
                }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
                'Ausschluss-Tags fuer Auffuellung',
                style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: career.careerTagDefinitions.map((definition) {
                  return FilterChip(
                    label: Text(definition.name),
                    selected: _selectedFillExcludedTagNames
                        .contains(definition.name),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFillExcludedTagNames.add(definition.name);
                        } else {
                          _selectedFillExcludedTagNames.remove(definition.name);
                        }
                      });
                    },
                  );
                }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
              controller: _fillTopByAverageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Top X nach Average',
                helperText:
                    '0 oder leer = unbegrenzt aus dem gefilterten Average-Pool auffuellen.',
              ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fillAutoGeneratePlayers,
            onChanged: (value) {
              setState(() => _fillAutoGeneratePlayers = value);
            },
            title: const Text('Fehlende Auffuellspieler automatisch generieren'),
            subtitle: const Text(
              'Wenn nach den normalen Fill-Regeln noch Plaetze fehlen, werden passende CPU-Spieler fuer die Restslots erzeugt.',
            ),
          ),
        ],
      ),
      tagGateSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              'Turnier findet statt bei Karriere-Tag-Regel',
              style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (career.careerTagDefinitions.isEmpty)
            const Text(
                'Lege zuerst Karriere-Tags an, um das Stattfinden eines Turniers darueber zu steuern.',
            )
          else ...<Widget>[
            DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  _selectedTournamentTagGateTagName ?? 'tournament-tag-gate-empty',
                ),
                initialValue: _selectedTournamentTagGateTagName,
                decoration: const InputDecoration(
                  labelText: 'Karriere-Tag',
                ),
                items: career.careerTagDefinitions
                    .map(
                      (definition) => DropdownMenuItem<String>(
                        value: definition.name,
                        child: Text(definition.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                    setState(() => _selectedTournamentTagGateTagName = value);
                  },
            ),
            const SizedBox(height: 12),
            TextField(
                controller: _tournamentTagGateMinimumController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mindestens X Spieler mit Tag',
                  helperText: 'Leer oder 0 = keine Tag-Regel',
                ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool>(
                key: ValueKey<bool>(_tournamentOccursWhenTagGateMet),
                initialValue: _tournamentOccursWhenTagGateMet,
                decoration: const InputDecoration(
                  labelText: 'Turnier findet statt',
                ),
                items: const <DropdownMenuItem<bool>>[
                  DropdownMenuItem<bool>(
                    value: true,
                    child: Text('Ja, wenn Bedingung erfuellt ist'),
                  ),
                  DropdownMenuItem<bool>(
                    value: false,
                    child: Text('Nein, wenn Bedingung erfuellt ist'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _tournamentOccursWhenTagGateMet = value);
                  }
                },
            ),
          ],
        ],
      ),
      rankingsSection: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              'Zaehlt fuer Ranglisten',
              style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          if (career.rankings.isEmpty)
            const Text('Noch keine Ranglisten vorhanden.')
          else
            ...career.rankings.map(
                (ranking) => CheckboxListTile(
                  value: _selectedRankingIds.contains(ranking.id),
                  onChanged: (value) {
                    setState(() {
                      if (value ?? false) {
                        _selectedRankingIds.add(ranking.id);
                      } else {
                        _selectedRankingIds.remove(ranking.id);
                      }
                    });
                  },
                  title: Text(ranking.name),
                  subtitle: Text(
                    ranking.resetAtSeasonEnd
                        ? 'Setzt sich am Saisonende zurueck'
                        : 'Gueltig ueber ${ranking.validSeasons} Saison(en)',
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
        ],
      ),
      actionsSection: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton(
                  onPressed: _submitCalendarItem,
                  child: Text(
                    _editingCalendarItemId == null
                        ? 'Turnier hinzufuegen'
                        : 'Turnier aktualisieren',
                  ),
                ),
                if (_editingCalendarItemId != null)
                  OutlinedButton(
                    onPressed: () => _resetCalendarForm(career),
                    child: const Text('Bearbeitung abbrechen'),
                  ),
              ],
            ),
    );
  }

  Widget _buildCareerTagsCard(BuildContext context, CareerDefinition career) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildWizardSectionCard(
          context,
          title: 'Status',
          subtitle: 'Zwei Aufgaben: erst Tags definieren, dann die Regeln darauf aufbauen.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${career.careerTagDefinitions.length} Karriere-Tags | ${career.seasonTagRules.length} Saisonregeln',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF21415E),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Empfohlene Reihenfolge: 1. Tags anlegen  2. Bestehende Tags pruefen  3. Regeln fuer Saisonwechsel bauen.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildCareerStatusPresetCard(context, career),
        const SizedBox(height: 16),
        _buildWizardSectionCard(
          context,
          title: '1. Tags definieren',
          subtitle: 'Hier entstehen Karriere-Tags, Limits, Laufzeiten und optionale Auto-Fill-Regeln.',
          child: _buildCareerTagDefinitionSection(career),
        ),
        const SizedBox(height: 16),
        _buildAdvancedSection(
          context,
          title: 'Bestehende Tags ansehen',
          subtitle: 'Oeffne diesen Bereich, wenn du vorhandene Karriere-Tags pruefen, bearbeiten oder loeschen willst.',
          expanded: _showExistingTagDefinitions,
          onChanged: (value) {
            setState(() => _showExistingTagDefinitions = value);
          },
          child: _buildExistingCareerTagsSection(career),
        ),
        const SizedBox(height: 16),
        _buildAdvancedSection(
          context,
          title: '2. Saisonregeln bauen',
          subtitle: 'Regeln fuer Vergabe, Verlaengerung und Entfernen von Tags nur oeffnen, wenn die Tag-Basis steht.',
          expanded: _showAdvancedTagRules,
          onChanged: (value) {
            setState(() => _showAdvancedTagRules = value);
          },
          child: _buildSeasonRulesSection(career),
        ),
      ],
    );
  }

  Widget _buildCareerTagDefinitionSection(CareerDefinition career) {
    return CareerTagDefinitionEditor(
      isEditing: _editingCareerTagId != null,
      nameController: _careerTagNameController,
      attributesController: _careerTagAttributesController,
      limitController: _careerTagLimitController,
      initialValidityController: _careerTagInitialValidityController,
      extensionValidityController: _careerTagExtensionValidityController,
      addOnExpiryController: _careerTagAddOnExpiryController,
      removeOnInitialController: _careerTagRemoveOnInitialController,
      removeOnExtensionController: _careerTagRemoveOnExtensionController,
      onSave: _submitCareerTagDefinition,
      onCancel: _resetCareerTagForm,
    );
  }

  Widget _buildSeasonRulesSection(CareerDefinition career) {
    return CareerSeasonRulesEditor(
      career: career,
      isEditing: _editingSeasonTagRuleId != null,
      selectedTagName: _selectedSeasonTagRuleTagName,
      selectedRankingId: _selectedSeasonTagRuleRankingId,
      action: _seasonTagRuleAction,
      rankMode: _seasonTagRuleRankMode,
      fromController: _seasonTagRuleFromController,
      toController: _seasonTagRuleToController,
      referenceRankController: _seasonTagRuleReferenceRankController,
      checkMode: _seasonTagRuleCheckMode,
      selectedCheckTagName: _selectedSeasonTagRuleCheckTagName,
      checkRemainingController: _seasonTagRuleCheckRemainingController,
      onTagChanged: (value) {
        setState(() => _selectedSeasonTagRuleTagName = value);
      },
      onRankingChanged: (value) {
        setState(() => _selectedSeasonTagRuleRankingId = value);
      },
      onActionChanged: (value) {
        setState(() => _seasonTagRuleAction = value);
      },
      onRankModeChanged: (value) {
        setState(() => _seasonTagRuleRankMode = value);
      },
      onCheckModeChanged: (value) {
        setState(() => _seasonTagRuleCheckMode = value);
      },
      onCheckTagChanged: (value) {
        setState(() => _selectedSeasonTagRuleCheckTagName = value);
      },
      onSave: () => _submitSeasonTagRule(career),
      onCancel: () => _resetSeasonTagRuleForm(career),
      onEdit: _beginEditSeasonTagRule,
      onDelete: _repository.removeSeasonTagRule,
      describeRule: _seasonRuleLabel,
    );
  }

  Widget _buildExistingCareerTagsSection(CareerDefinition career) {
    return CareerTagDefinitionsList(
      definitions: career.careerTagDefinitions,
      describeDefinition: (definition) =>
          _careerTagDefinitionSummary(career, definition),
      onEdit: _beginEditCareerTagDefinition,
      onDelete: _repository.removeCareerTagDefinition,
    );
  }

  // ignore: unused_element
  Widget _buildDatabasePlayersCard(
    BuildContext context,
    CareerDefinition career,
  ) {
    final rosterViewData = _buildRosterViewData(career);
    final assignedTagNames = _parseCareerTags(
      _databasePlayerTagsController.text,
    ).map((entry) => entry.tagName).toSet();

    return CareerRosterEditor(
      rosterCount: career.databasePlayers.length,
      summarySection: const Text(
        'Diese Spieler bilden den eigenen Karriere-Kader. Karriere-Tags gelten nur in dieser Karriere.',
      ),
      trainingSection: _buildTrainingModeSection(career),
      addPlayersSection: CareerRosterAddPlayersSection(
        career: career,
        availableTags: rosterViewData.availableTags,
        addablePlayers: rosterViewData.addablePlayers,
        selectedDatabaseTagFilters: _selectedDatabaseTagFilters,
        selectedDatabasePlayerIds: _selectedDatabasePlayerIds,
        databasePlayerTagsController: _databasePlayerTagsController,
        assignedTagNames: assignedTagNames,
        tagUsageLabelBuilder: (tagName) =>
            _careerTagUsageFilterLabel(career, tagName),
        onToggleAssignmentCareerTag: _toggleAssignmentCareerTag,
        onClearFilters: () {
          setState(() {
            _selectedDatabaseTagFilters.clear();
          });
        },
        onToggleDatabaseTagFilter: (tag) {
          setState(() {
            if (_selectedDatabaseTagFilters.contains(tag)) {
              _selectedDatabaseTagFilters.remove(tag);
            } else {
              _selectedDatabaseTagFilters.add(tag);
            }
          });
        },
        onToggleSelectAll: () {
          setState(() {
            if (_selectedDatabasePlayerIds.length ==
                rosterViewData.addablePlayers.length) {
              _selectedDatabasePlayerIds.clear();
            } else {
              _selectedDatabasePlayerIds
                ..clear()
                ..addAll(
                  rosterViewData.addablePlayers.map((player) => player.id),
                );
            }
          });
        },
        onTogglePlayerSelection: (playerId) {
          setState(() {
            if (_selectedDatabasePlayerIds.contains(playerId)) {
              _selectedDatabasePlayerIds.remove(playerId);
            } else {
              _selectedDatabasePlayerIds.add(playerId);
            }
          });
        },
        onAddSelectedPlayers: _addSelectedDatabasePlayersToCareer,
      ),
      rosterSection: CareerRosterListSection(
        players: career.databasePlayers,
        selectedPlayerIds: _selectedCareerRosterPlayerIds,
        careerRosterTagsController: _careerRosterTagsController,
        tagLabelBuilder: _careerTagAssignmentLabel,
        onToggleSelectAll: () {
          setState(() {
            if (_selectedCareerRosterPlayerIds.length ==
                career.databasePlayers.length) {
              _selectedCareerRosterPlayerIds.clear();
            } else {
              _selectedCareerRosterPlayerIds
                ..clear()
                ..addAll(
                  career.databasePlayers.map(
                    (player) => player.databasePlayerId,
                  ),
                );
            }
          });
        },
        onTogglePlayerSelection: (playerId) {
          setState(() {
            if (_selectedCareerRosterPlayerIds.contains(playerId)) {
              _selectedCareerRosterPlayerIds.remove(playerId);
            } else {
              _selectedCareerRosterPlayerIds.add(playerId);
            }
          });
        },
        onApplyTags: _applyTagsToSelectedCareerPlayers,
        onRemoveTags: _removeTagsFromSelectedCareerPlayers,
        onClearTags: _clearAllTagsFromSelectedCareerPlayers,
        onRemovePlayers: _removeSelectedCareerPlayers,
        onEditPlayer: _editCareerDatabasePlayer,
        onDeletePlayer: _repository.removeDatabasePlayer,
        onRemoveSingleTag: (player, tagName) {
          _removeCareerTagFromPlayer(player: player, tagName: tagName);
        },
      ),
    );
  }

  Widget _buildTrainingModeSection(CareerDefinition career) {
    final poolPlayers = _trainingPoolPlayers(career);
    return _buildTrainingModeContent(
      poolPlayers: poolPlayers,
      availablePoolTags: career.careerTagDefinitions.map((entry) => entry.name).toList(),
      poolLabel: 'Gesamter Karriere-Kader',
      emptyLabel: 'Im aktuell gewaehlten Pool sind keine Karriere-Spieler vorhanden.',
      applyLabel: 'Auf Karriere-Pool anwenden',
      onApply: () => _applyTrainingModeToPool(career),
    );
  }

  Widget _buildSimpleTrainingModeSection(CareerTemplate? template) {
    final poolPlayers = _templateTrainingPoolPlayers(template);
    final hasTemplate = template != null;
    return _buildTrainingModeContent(
      poolPlayers: poolPlayers,
      availablePoolTags: hasTemplate
          ? template.careerTagDefinitions.map((entry) => entry.name).toList()
          : const <String>[],
      poolLabel: hasTemplate
          ? 'Gesamter Vorlagen-Kader'
          : 'Gesamter aktueller Start-Kader',
      emptyLabel: hasTemplate
          ? 'Im aktuell gewaehlten Vorlagen-Kader sind keine Spieler fuer den Trainingsmodus vorhanden.'
          : 'Im aktuell gewaehlten Start-Kader sind keine Spieler fuer den Trainingsmodus vorhanden.',
      applyLabel: hasTemplate
          ? 'Auf Vorlagen-Kader anwenden'
          : 'Auf Start-Kader anwenden',
      onApply: () => _applyTrainingModeToTemplatePool(template),
    );
  }

  Widget _buildTrainingModeContent({
    required List<CareerDatabasePlayer> poolPlayers,
    required List<String> availablePoolTags,
    required String poolLabel,
    required String emptyLabel,
    required VoidCallback onApply,
    required String applyLabel,
  }) {
    final hasPool = poolPlayers.isNotEmpty;
    final currentMin = hasPool
        ? poolPlayers
            .map((player) => player.average)
            .reduce((left, right) => left < right ? left : right)
        : 0.0;
    final currentMax = hasPool
        ? poolPlayers
            .map((player) => player.average)
            .reduce((left, right) => left > right ? left : right)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Passe die Average-Spanne eines Karriere-Pools an. Die Werte werden nur in dieser Karriere bzw. diesem Start-Setup geaendert, nie in der Hauptdatenbank.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>(
            _selectedTrainingPoolTagName ?? 'training-pool-all',
          ),
          initialValue: _selectedTrainingPoolTagName,
          decoration: const InputDecoration(labelText: 'Pool'),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
              value: null,
              child: Text(poolLabel),
            ),
            ...availablePoolTags.map(
              (tag) => DropdownMenuItem<String?>(
                value: tag,
                child: Text('Karriere-Tag: $tag'),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedTrainingPoolTagName = value;
            });
          },
        ),
        const SizedBox(height: 12),
        Text(
          hasPool
              ? 'Aktuelle Average-Spanne: ${currentMin.toStringAsFixed(1)} bis ${currentMax.toStringAsFixed(1)} (${poolPlayers.length} Spieler)'
              : emptyLabel,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _trainingMinAverageController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Wunsch-Minimum',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _trainingMaxAverageController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Wunsch-Maximum',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: hasPool
                  ? () {
                      setState(() {
                        _trainingMinAverageController.text =
                            currentMin.toStringAsFixed(1);
                        _trainingMaxAverageController.text =
                            currentMax.toStringAsFixed(1);
                      });
                    }
                  : null,
              child: const Text('Aktuelle Spanne uebernehmen'),
            ),
            FilledButton.tonalIcon(
              onPressed: hasPool ? onApply : null,
              icon: const Icon(Icons.fitness_center),
              label: Text(applyLabel),
            ),
          ],
        ),
      ],
    );
  }

  _CareerRosterViewData _buildRosterViewData(CareerDefinition career) {
    final availablePlayers = _computerRepository.players;
    final selectedIds = career.databasePlayers
        .map((entry) => entry.databasePlayerId)
        .toSet();
    final availableTags = availablePlayers
        .expand((player) => player.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _selectedDatabaseTagFilters.removeWhere(
      (tag) => !availableTags.contains(tag),
    );
    final addablePlayers = availablePlayers
        .where((player) => !selectedIds.contains(player.id))
        .where((player) {
          if (_selectedDatabaseTagFilters.isEmpty) {
            return true;
          }
          for (final tag in player.tags) {
            if (_selectedDatabaseTagFilters.contains(tag)) {
              return true;
            }
          }
          return false;
        })
        .toList()
      ..sort(
        (left, right) =>
            right.theoreticalAverage.compareTo(left.theoreticalAverage),
      );
    _selectedDatabasePlayerIds.removeWhere(
      (playerId) => addablePlayers.every((player) => player.id != playerId),
    );
    return _CareerRosterViewData(
      availableTags: availableTags,
      addablePlayers: addablePlayers,
    );
  }

  List<CareerDatabasePlayer> _trainingPoolPlayers(CareerDefinition career) {
    final humanPlayerProfileId = career.playerProfileId;
    final selectedTrainingTag = _selectedTrainingPoolTagName?.trim();
    final poolPlayers = (selectedTrainingTag == null || selectedTrainingTag.isEmpty)
        ? career.databasePlayers
        : career.databasePlayers
            .where(
              (player) =>
                  player.activeTagNames.contains(selectedTrainingTag),
            )
            .toList();
    if (humanPlayerProfileId == null) {
      return poolPlayers;
    }
    return poolPlayers
        .where((player) => player.databasePlayerId != humanPlayerProfileId)
        .toList();
  }

  List<CareerDatabasePlayer> _templateTrainingPoolPlayers(
    CareerTemplate? template,
  ) {
    final poolPlayers = _templateCreationPoolPlayers(template);
    final selectedTrainingTag = _selectedTrainingPoolTagName?.trim();
    if (selectedTrainingTag == null || selectedTrainingTag.isEmpty) {
      return poolPlayers;
    }
    return poolPlayers
        .where(
          (player) =>
              player.activeTagNames.contains(selectedTrainingTag),
        )
        .toList();
  }

  String _careerTagUsageFilterLabel(CareerDefinition career, String tagName) {
    CareerTagDefinition? definition;
    for (final entry in career.careerTagDefinitions) {
      if (entry.name == tagName) {
        definition = entry;
        break;
      }
    }
    if (definition == null) {
      return tagName;
    }
    final usageCount = _careerTagUsageCount(career, tagName);
    final limitSuffix = definition.playerLimit == null
        ? ''
        : ' $usageCount/${definition.playerLimit}';
    return '$tagName$limitSuffix';
  }

  String _seasonRuleLabel(CareerSeasonTagRule rule) {
    var rankingName = rule.rankingId;
    for (final ranking in _repository.activeCareer?.rankings ?? const <CareerRankingDefinition>[]) {
      if (ranking.id == rule.rankingId) {
        rankingName = ranking.name;
        break;
      }
    }
    final rankLabel = rule.rankMode == CareerSeasonTagRuleRankMode.greaterThanRank
        ? '$rankingName > Platz ${rule.referenceRank ?? rule.fromRank}'
        : '$rankingName ${rule.fromRank}-${rule.toRank}';
    final checkLabel = rule.checkMode == CareerSeasonTagRuleCheckMode.none
        ? ''
        : ' | ${rule.checkTagName} ${rule.checkMode == CareerSeasonTagRuleCheckMode.tagValidityAtMost ? '<=' : '>='} ${rule.checkRemainingSeasons} Saisons';
    return '$rankLabel$checkLabel nach Saisonende';
  }

  String _careerTagDefinitionSummary(
    CareerDefinition career,
    CareerTagDefinition definition,
  ) {
    final usageCount = _careerTagUsageCount(career, definition.name);
    final attributesLabel = definition.attributes.isEmpty
        ? 'Keine Attribute'
        : definition.attributes
            .map((entry) => '${entry.key}=${entry.value}')
            .join(', ');
    final limitLabel = definition.playerLimit == null
        ? 'kein Limit'
        : '$usageCount/${definition.playerLimit} Spieler';
    final validityLabel =
        'Erstvergabe: ${definition.initialValiditySeasons == null ? 'dauerhaft' : '${definition.initialValiditySeasons} Saisons'}'
        ' | Verlaengerung: ${definition.extensionValiditySeasons == null ? 'dauerhaft' : '${definition.extensionValiditySeasons} Saisons'}';
    final expiryLabel = definition.tagsToAddOnExpiry.isEmpty
        ? 'Ablauf: nichts'
        : 'Ablauf: +${definition.tagsToAddOnExpiry.join(', ')}';
    final initialRemovalLabel =
        definition.tagsToRemoveOnInitialAssignment.isEmpty
            ? 'Erstvergabe entfernt nichts'
            : 'Erstvergabe entfernt ${definition.tagsToRemoveOnInitialAssignment.join(', ')}';
    final extensionRemovalLabel = definition.tagsToRemoveOnExtension.isEmpty
        ? 'Verlaengerung entfernt nichts'
        : 'Verlaengerung entfernt ${definition.tagsToRemoveOnExtension.join(', ')}';
    return '$attributesLabel | Limit: $limitLabel | $validityLabel | $expiryLabel | $initialRemovalLabel | $extensionRemovalLabel';
  }

  Future<List<CareerDatabasePlayer>> _resolveTrainingModePlayersLocally(
    List<CareerDatabasePlayer> poolPlayers, {
    required double targetMin,
    required double targetMax,
    String? progressPrefix,
  }) async {
    final sortedPlayers = List<CareerDatabasePlayer>.from(poolPlayers)
      ..sort((left, right) => left.average.compareTo(right.average));
    final currentMin = sortedPlayers.first.average;
    final currentMax = sortedPlayers.last.average;
    final updatedPlayers = <CareerDatabasePlayer>[];

    for (var index = 0; index < sortedPlayers.length; index += 1) {
      final player = sortedPlayers[index];
      final double progress;
      if (sortedPlayers.length == 1) {
        progress = 0.5;
      } else if ((currentMax - currentMin).abs() < 0.0001) {
        progress = index / (sortedPlayers.length - 1);
      } else {
        progress = (player.average - currentMin) / (currentMax - currentMin);
      }
      final targetAverage = (targetMin + ((targetMax - targetMin) * progress))
          .clamp(0, 180)
          .toDouble();
      final resolution = _computerRepository
          .resolveSkillsForTheoreticalAverageQuick(targetAverage);
      updatedPlayers.add(
        player.copyWith(
          average: resolution.theoreticalAverage,
          skill: resolution.skill,
          finishingSkill: resolution.finishingSkill,
        ),
      );

      final processedCount = index + 1;
      if (mounted &&
          (processedCount == sortedPlayers.length || processedCount % 8 == 0)) {
        setState(() {
          final prefix =
              progressPrefix ?? 'Trainingsmodus wird angewendet...';
          _busyMessage =
              '$prefix ($processedCount/${sortedPlayers.length} Spieler)';
          _busyProgress = processedCount / sortedPlayers.length;
        });
        await Future<void>.delayed(Duration.zero);
      }
    }

    return updatedPlayers;
  }

  Future<void> _applyTrainingModeToPool(CareerDefinition career) async {
    final poolPlayers = _trainingPoolPlayers(career);
    if (poolPlayers.isEmpty) {
      return;
    }
    final parsedMin = double.tryParse(
      _trainingMinAverageController.text.trim().replaceAll(',', '.'),
    );
    final parsedMax = double.tryParse(
      _trainingMaxAverageController.text.trim().replaceAll(',', '.'),
    );
    if (parsedMin == null || parsedMax == null) {
      return;
    }
    final targetMin = parsedMin <= parsedMax ? parsedMin : parsedMax;
    final targetMax = parsedMin <= parsedMax ? parsedMax : parsedMin;
    final busyMessage = _trainingModeBusyMessage(
      targetMin: targetMin,
      targetMax: targetMax,
    );
    await _runBusyAction(
      message: '$busyMessage (0/${poolPlayers.length} Spieler)',
      action: () async {
        final updatedPlayers = await _resolveTrainingModePlayersLocally(
          poolPlayers,
          targetMin: targetMin,
          targetMax: targetMax,
          progressPrefix: busyMessage,
        );
        _repository.updateDatabasePlayers(players: updatedPlayers);
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyTrainingModeToTemplatePool(CareerTemplate? template) async {
    final poolPlayers = _templateTrainingPoolPlayers(template);
    if (poolPlayers.isEmpty) {
      return;
    }
    final parsedMin = double.tryParse(
      _trainingMinAverageController.text.trim().replaceAll(',', '.'),
    );
    final parsedMax = double.tryParse(
      _trainingMaxAverageController.text.trim().replaceAll(',', '.'),
    );
    if (parsedMin == null || parsedMax == null) {
      return;
    }
    final targetMin = parsedMin <= parsedMax ? parsedMin : parsedMax;
    final targetMax = parsedMin <= parsedMax ? parsedMax : parsedMin;
    final busyMessage = _trainingModeBusyMessage(
      targetMin: targetMin,
      targetMax: targetMax,
    );
    await _runBusyAction(
      message: '$busyMessage (0/${poolPlayers.length} Spieler)',
      action: () async {
        final updatedPlayers = await _resolveTrainingModePlayersLocally(
          poolPlayers,
          targetMin: targetMin,
          targetMax: targetMax,
          progressPrefix: busyMessage,
        );
        for (final player in updatedPlayers) {
          _simpleTemplateTrainingOverrides[player.databasePlayerId] = player;
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  String _trainingModeBusyMessage({
    required double targetMin,
    required double targetMax,
  }) {
    final computerPlayers = _computerRepository.players;
    if (computerPlayers.isEmpty) {
      return 'Trainingsmodus wird angewendet...';
    }
    final theoreticalAverages = computerPlayers
        .map((player) => player.theoreticalAverage)
        .toList();
    final databaseMin = theoreticalAverages.reduce(min);
    final databaseMax = theoreticalAverages.reduce(max);
    final needsWarmup = targetMin < databaseMin || targetMax > databaseMax;
    if (!needsWarmup) {
      return 'Trainingsmodus wird angewendet...';
    }
    return 'Trainingsmodus wird angewendet. Neue Theo-Werte ausserhalb des aktuellen Datenbankbereichs werden vorbereitet...';
  }

  Future<void> _createOrCreateFromTemplate() async {
    if (_selectedTemplateId != null) {
      await _createCareerFromTemplate();
      return;
    }
    _createCareer();
  }

  Future<void> _createSimpleCareerFromTemplate() async {
    final effectiveTemplate = _effectiveSimpleCreationTemplate();
    if (effectiveTemplate == null) {
      return;
    }
    final templateDatabasePlayers = _buildSimpleCreationRoster(
      _selectedTemplate(),
    );
    final shouldContinue = await _confirmTemplateCreation(
      effectiveTemplate,
      templateDatabasePlayers.length,
    );
    if (!shouldContinue || !mounted) {
      return;
    }

    final hasHumanProfile = _playerRepository.players.isNotEmpty;
    await _runBusyAction(
      message: 'Einfache Karriere wird erstellt...',
      action: () async {
        await Future<void>.delayed(Duration.zero);
        _repository.createCareerFromTemplate(
          name: '',
          template: effectiveTemplate,
          databasePlayers: templateDatabasePlayers,
          participantMode: hasHumanProfile
              ? CareerParticipantMode.withHuman
              : CareerParticipantMode.cpuOnly,
          playerProfileId:
              hasHumanProfile ? _selectedPlayerProfileId ?? _playerRepository.activePlayer?.id : null,
          replaceWeakestPlayerWithHuman: hasHumanProfile,
        );
        _applySelectedCareerStructurePresetIfNeeded();
        _repository.startCareer();
      },
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.careerDetail);
  }

  CareerTemplate? _effectiveSimpleCreationTemplate() {
    final selectedTemplate = _selectedTemplate();
    if (selectedTemplate != null) {
      return selectedTemplate;
    }
    if (!_simpleQuickTournamentGenerationEnabled) {
      return null;
    }
    return _templateForSimpleCreation(_buildNeutralSimpleTemplate());
  }

  CareerTemplate _buildNeutralSimpleTemplate() {
    return const CareerTemplate(
      id: 'simple-neutral-base',
      name: 'Quick Tour Basis',
      careerTagDefinitions: <CareerTagDefinition>[],
      seasonTagRules: <CareerSeasonTagRule>[],
      rankings: <CareerRankingDefinition>[],
      calendar: <CareerCalendarItem>[],
    );
  }

  int _effectiveSimpleTargetRosterSize(int selectedCount) {
    final parsed = int.tryParse(_simpleTargetRosterSizeController.text.trim());
    final fallback = selectedCount <= 0 ? 32 : selectedCount;
    final normalized = parsed == null || parsed <= 0 ? fallback : parsed;
    if (normalized < selectedCount) {
      return selectedCount;
    }
    return normalized;
  }

  List<CareerDatabasePlayer> _buildSimpleCreationRoster(CareerTemplate? template) {
    final selectedPlayers = _templateCreationPoolPlayers(template);
    final targetSize = _effectiveSimpleTargetRosterSize(selectedPlayers.length);
    final missingCount = targetSize - selectedPlayers.length;
    if (missingCount <= 0) {
      return selectedPlayers;
    }

    final generatedPlayers = _generateWeakerRosterPlayers(
      existingPlayers: selectedPlayers,
      count: missingCount,
    );
    return <CareerDatabasePlayer>[
      ...selectedPlayers,
      ...generatedPlayers,
    ];
  }

  List<CareerDatabasePlayer> _generateWeakerRosterPlayers({
    required List<CareerDatabasePlayer> existingPlayers,
    required int count,
  }) {
    if (count <= 0) {
      return const <CareerDatabasePlayer>[];
    }
    final random = Random();
    final nowToken = DateTime.now().microsecondsSinceEpoch;
    final selectedAverages = existingPlayers
        .map((player) => player.average)
        .where((value) => value > 0)
        .toList()
      ..sort();
    final selectedMin = selectedAverages.isEmpty ? 52.0 : selectedAverages.first;
    final selectedAverage = selectedAverages.isEmpty
        ? 58.0
        : selectedAverages.fold<double>(0, (sum, value) => sum + value) /
            selectedAverages.length;
    final generatedMax = min(
      selectedMin - 1.5,
      selectedAverage - 4.0,
    ).clamp(34.0, 85.0).toDouble();
    final generatedMin = max(28.0, generatedMax - 12.0);
    final usedNamesLowercase = <String>{
      ..._computerRepository.players
          .map((player) => player.name.trim().toLowerCase())
          .where((name) => name.isNotEmpty),
      ...existingPlayers
          .map((player) => player.name.trim().toLowerCase())
          .where((name) => name.isNotEmpty),
    };
    final nationalities = _computerRepository.nationalityDefinitions.isEmpty
        ? ComputerRepository.officialNationalities
        : _computerRepository.nationalityDefinitions;

    return List<CareerDatabasePlayer>.generate(count, (index) {
      final progress = count == 1 ? 0.5 : index / (count - 1);
      final targetAverage =
          generatedMin + ((generatedMax - generatedMin) * progress);
      final resolution = _computerRepository.resolveSkillsForTheoreticalAverageQuick(
        targetAverage,
      );
      final nationality = nationalities.isEmpty
          ? null
          : nationalities[index % nationalities.length];
      final name = GeneratedNameCatalog.generateUniquePlayerName(
        random: random,
        usedNamesLowercase: usedNamesLowercase,
        nationality: nationality,
        fallbackPrefix: 'Tour',
      );
      usedNamesLowercase.add(name.trim().toLowerCase());
      return CareerDatabasePlayer(
        databasePlayerId: 'generated-career-$nowToken-$index',
        name: name,
        average: resolution.theoreticalAverage,
        skill: resolution.skill,
        finishingSkill: resolution.finishingSkill,
        nationality: nationality,
      );
    });
  }

  void _createCareer() {
    _repository.createCareer(
      name: _careerNameController.text,
      participantMode: _participantMode,
      playerProfileId:
          _participantMode == CareerParticipantMode.withHuman ? _selectedPlayerProfileId : null,
      replaceWeakestPlayerWithHuman:
          _participantMode == CareerParticipantMode.withHuman &&
              _replaceWeakestPlayerWithHuman,
    );
    _applySelectedCareerStructurePresetIfNeeded();
    _careerNameController.clear();
    final activeCareer = _repository.activeCareer;
    if (activeCareer != null) {
      _applyCareerDefaults(activeCareer);
      }
      setState(() {
        _setSetupStep(_CareerSetupStep.ranglisten);
      });
  }

  Future<void> _createCareerFromTemplate() async {
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      return;
    }
    final resolvedTemplate = _selectedTemplate();
    if (resolvedTemplate == null || resolvedTemplate.id != templateId) {
      return;
    }

    final templateDatabasePlayers =
        _templateCreationPoolPlayers(resolvedTemplate);

    final shouldContinue = await _confirmTemplateCreation(
      resolvedTemplate,
      templateDatabasePlayers.length,
    );
    if (!shouldContinue || !mounted) {
      return;
    }

    await _runBusyAction(
      message: 'Karriere wird aus Vorlage erstellt...',
      action: () async {
        await Future<void>.delayed(Duration.zero);
        _repository.createCareerFromTemplate(
          name: _careerNameController.text,
          template: resolvedTemplate,
          databasePlayers: templateDatabasePlayers,
          participantMode: _participantMode,
          playerProfileId: _participantMode == CareerParticipantMode.withHuman
              ? _selectedPlayerProfileId
              : null,
          replaceWeakestPlayerWithHuman:
              _participantMode == CareerParticipantMode.withHuman &&
                  _replaceWeakestPlayerWithHuman,
        );
        _applySelectedCareerStructurePresetIfNeeded();
        _careerNameController.clear();
        final activeCareer = _repository.activeCareer;
        if (activeCareer != null) {
          _applyCareerDefaults(activeCareer);
        }
        if (mounted) {
          setState(() {
            _setSetupStep(_CareerSetupStep.ranglisten);
          });
        }
      },
    );
  }

  Future<bool> _confirmTemplateCreation(
    CareerTemplate template,
    int selectedPoolCount,
  ) async {
    final isQuickTourTemplate = template.id.startsWith('quick-tour-');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isQuickTourTemplate ? 'Quick-Tour erstellen?' : 'Vorlage erstellen?',
          ),
          content: Text(
            isQuickTourTemplate
                ? 'Es wird ein neues Quick-Tour-Geruest als Karriere angelegt.\n\n'
                    '$selectedPoolCount Spieler aus dem aktuell gewaehlten Karriere-Pool, ${template.calendar.length} Turniere und ${template.rankings.length} Ranglisten werden automatisch aufgebaut.\n\n'
                    'Die Saison ist nicht aus einer Vorlagen-Saison kopiert, sondern als eigenstaendige Tour zusammengestellt.'
                : 'Die Vorlage "${template.name}" wird als neue Karriere angelegt.\n\n'
                    '$selectedPoolCount Spieler aus dem aktuell gewaehlten Karriere-Pool, ${template.calendar.length} Turniere und ${template.rankings.length} Ranglisten werden uebernommen.\n\n'
                    'Je nach Vorlagengroesse kann das kurz dauern.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Widget _buildTemplatePoolSelector(
    BuildContext context, {
    String labelText = 'Karriere-Pool fuer Vorlage',
  }) {
    final template = _selectedTemplate();
    final poolViewData = _buildTemplatePoolViewData();
    final selectedCount = _templateCreationPoolPlayers(template).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
          DropdownButtonFormField<_TemplateCareerPoolMode>(
            key: ValueKey<_TemplateCareerPoolMode>(_templateCareerPoolMode),
            initialValue: _templateCareerPoolMode,
            decoration: InputDecoration(
              labelText: labelText,
            ),
          items: const <DropdownMenuItem<_TemplateCareerPoolMode>>[
            DropdownMenuItem(
              value: _TemplateCareerPoolMode.empty,
              child: Text('Leer starten'),
            ),
            DropdownMenuItem(
              value: _TemplateCareerPoolMode.allDatabasePlayers,
              child: Text('Alle Datenbankspieler'),
            ),
            DropdownMenuItem(
              value: _TemplateCareerPoolMode.selectedDatabasePlayers,
              child: Text('Auswahl aus Datenbank'),
            ),
          ],
            onChanged: (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _templateCareerPoolMode = value;
                _simpleTemplateTrainingOverrides.clear();
                _selectedTrainingPoolTagName = null;
              });
            },
          ),
        const SizedBox(height: 8),
        Text(
          _templateCareerPoolMode == _TemplateCareerPoolMode.empty
              ? 'Die Karriere startet ohne vorbereiteten Karriere-Pool.'
              : '$selectedCount Spieler werden beim Erstellen in den Karriere-Pool uebernommen.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_templateCareerPoolMode ==
            _TemplateCareerPoolMode.selectedDatabasePlayers) ...<Widget>[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Pool-Auswahl aus Datenbank'),
            subtitle: Text(
              poolViewData.addablePlayers.isEmpty
                  ? 'Keine Spieler verfuegbar'
                  : '${_selectedTemplateDatabasePlayerIds.length} von ${poolViewData.addablePlayers.length} Spielern ausgewaehlt',
            ),
            children: <Widget>[
              if (poolViewData.availableTags.isNotEmpty) ...<Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: poolViewData.availableTags
                      .map(
                        (tag) => FilterChip(
                          label: Text(tag),
                          selected:
                              _selectedTemplateDatabaseTagFilters.contains(tag),
                          onSelected: (_) {
                            setState(() {
                              if (_selectedTemplateDatabaseTagFilters
                                  .contains(tag)) {
                                _selectedTemplateDatabaseTagFilters.remove(tag);
                              } else {
                                _selectedTemplateDatabaseTagFilters.add(tag);
                              }
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _selectedTemplateDatabaseTagFilters.isEmpty
                            ? 'Kein Datenbank-Tag-Filter aktiv'
                            : 'Filter: ${_selectedTemplateDatabaseTagFilters.join(', ')}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (_selectedTemplateDatabaseTagFilters.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(
                            _selectedTemplateDatabaseTagFilters.clear,
                          );
                        },
                        child: const Text('Filter loeschen'),
                      ),
                  ],
                ),
              ],
              if (poolViewData.addablePlayers.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Kein Datenbankspieler passt zur aktuellen Auswahl.'),
                  ),
                )
              else ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_selectedTemplateDatabasePlayerIds.length} Spieler ausgewaehlt',
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedTemplateDatabasePlayerIds.length ==
                              poolViewData.addablePlayers.length) {
                            _selectedTemplateDatabasePlayerIds.clear();
                          } else {
                            _selectedTemplateDatabasePlayerIds
                              ..clear()
                              ..addAll(
                                poolViewData.addablePlayers
                                    .map((player) => player.id),
                              );
                          }
                        });
                      },
                      child: Text(
                        _selectedTemplateDatabasePlayerIds.length ==
                                poolViewData.addablePlayers.length
                            ? 'Auswahl leeren'
                            : 'Alle waehlen',
                      ),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: SingleChildScrollView(
                    child: Column(
                      children: poolViewData.addablePlayers
                          .map(
                            (player) => CheckboxListTile(
                              value: _selectedTemplateDatabasePlayerIds
                                  .contains(player.id),
                              onChanged: (_) {
                                setState(() {
                                  if (_selectedTemplateDatabasePlayerIds
                                      .contains(player.id)) {
                                    _selectedTemplateDatabasePlayerIds
                                        .remove(player.id);
                                  } else {
                                    _selectedTemplateDatabasePlayerIds
                                        .add(player.id);
                                  }
                                });
                              },
                              title: Text(player.name),
                              subtitle: Text(
                                '${player.theoreticalAverage.toStringAsFixed(1)} Theo Avg'
                                '${player.tags.isEmpty ? '' : ' | ${player.tags.join(', ')}'}',
                              ),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  CareerTemplate? _selectedTemplate() {
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      return null;
    }
    for (final template in _templateRepository.templates) {
      if (template.id == templateId) {
        return template;
      }
    }
    return null;
  }

  Set<TournamentFormat> _effectiveSimpleQuickFormats() {
    if (_simpleQuickFormats.isEmpty) {
      return TournamentFormat.values.toSet();
    }
    return _simpleQuickFormats;
  }

  void _ensureSimpleQuickTourConfigs() {
    for (final blueprint in _allSimpleQuickTourBlueprints()) {
      _simpleQuickTourConfigs.putIfAbsent(
        blueprint.id,
        () => _SimpleQuickTourTypeConfig(
          count: _defaultSimpleQuickCountForBlueprint(blueprint.id),
        ),
      );
    }
  }

  int _defaultSimpleQuickCountForBlueprint(String blueprintId) {
    return switch (blueprintId) {
      'open' => 8,
      'championship' => 4,
      'players-championship' => 8,
      'masters' => 2,
      'major' => 1,
      'league-finals' => 1,
      _ => 0,
    };
  }

  int _configuredSimpleQuickEventCount({
    required List<_SimpleQuickTourBlueprint> blueprints,
  }) {
    return blueprints.fold<int>(
      0,
      (sum, blueprint) =>
          sum + (_simpleQuickTourConfigs[blueprint.id]?.count ?? 0),
    );
  }

  CareerTemplate _templateForSimpleCreation(CareerTemplate template) {
    if (!_simpleQuickTournamentGenerationEnabled) {
      return template;
    }
    _ensureSimpleQuickTourConfigs();
    final rosterSize = _buildSimpleCreationRoster(
      _selectedTemplate() ?? template,
    ).length;
    final rankings = _buildSimpleQuickTourRankings();
    final generatedCalendar = _buildSimpleQuickTourCalendar(
      rankings: rankings,
      rosterSize: rosterSize,
    );
    return CareerTemplate(
      id: 'quick-tour-${generatedCalendar.length}-$rosterSize',
      name: 'Quick Tour',
      participantMode: template.participantMode,
      playerProfileId: template.playerProfileId,
      replaceWeakestPlayerWithHuman: template.replaceWeakestPlayerWithHuman,
      careerTagDefinitions: template.careerTagDefinitions,
      seasonTagRules: template.seasonTagRules,
      rankings: rankings,
      calendar: generatedCalendar,
    );
  }

  List<CareerRankingDefinition> _buildSimpleQuickTourRankings() {
    return const <CareerRankingDefinition>[
      CareerRankingDefinition(
        id: 'quick-tour-order-of-merit',
        name: 'Tour Order of Merit',
        validSeasons: 2,
      ),
      CareerRankingDefinition(
        id: 'quick-season-race',
        name: 'Season Race',
        validSeasons: 1,
        resetAtSeasonEnd: true,
      ),
      CareerRankingDefinition(
        id: 'quick-major-race',
        name: 'Major Race',
        validSeasons: 1,
        resetAtSeasonEnd: true,
        countedCategories: <String>['Masters', 'Major'],
      ),
    ];
  }

  List<_SimpleQuickTourBlueprint> _allSimpleQuickTourBlueprints() {
    return const <_SimpleQuickTourBlueprint>[
      _SimpleQuickTourBlueprint(
        id: 'open',
        baseName: 'Tour Open',
        categoryName: 'Open',
        format: TournamentFormat.knockout,
        tier: 1,
        fieldSize: 64,
        legsToWin: 4,
        prizePool: 18000,
        seedCount: 16,
      ),
      _SimpleQuickTourBlueprint(
        id: 'championship',
        baseName: 'Championship',
        categoryName: 'Championship',
        format: TournamentFormat.knockout,
        tier: 2,
        fieldSize: 64,
        legsToWin: 5,
        prizePool: 26000,
        seedCount: 16,
      ),
      _SimpleQuickTourBlueprint(
        id: 'players-championship',
        baseName: 'Players Championship',
        categoryName: 'Players Championship',
        format: TournamentFormat.knockout,
        tier: 2,
        fieldSize: 32,
        legsToWin: 5,
        prizePool: 14000,
        seedCount: 8,
      ),
      _SimpleQuickTourBlueprint(
        id: 'masters',
        baseName: 'Tour Masters',
        categoryName: 'Masters',
        format: TournamentFormat.knockout,
        tier: 3,
        fieldSize: 32,
        legsToWin: 6,
        prizePool: 32000,
        seedCount: 8,
        countsForMajorRace: true,
      ),
      _SimpleQuickTourBlueprint(
        id: 'major',
        baseName: 'Tour Major',
        categoryName: 'Major',
        format: TournamentFormat.knockout,
        tier: 4,
        fieldSize: 32,
        legsToWin: 7,
        prizePool: 60000,
        seedCount: 8,
        countsForMajorRace: true,
      ),
      _SimpleQuickTourBlueprint(
        id: 'league-finals',
        baseName: 'Championship League',
        categoryName: 'League Finals',
        format: TournamentFormat.leaguePlayoff,
        tier: 4,
        fieldSize: 4,
        legsToWin: 6,
        prizePool: 24000,
        seedCount: 0,
        isSeries: true,
        roundRobinRepeats: 1,
        playoffQualifierCount: 4,
        countsForMajorRace: true,
      ),
    ];
  }

  List<_SimpleQuickTourBlueprint> _availableSimpleQuickTourBlueprints() {
    final allowedFormats = _effectiveSimpleQuickFormats();
    return _allSimpleQuickTourBlueprints().where((entry) {
      if (!allowedFormats.contains(entry.format)) {
        return false;
      }
      if (entry.isSeries && !_simpleQuickIncludeSeries) {
        return false;
      }
      if (!entry.isSeries && !_simpleQuickIncludeStandalone) {
        return false;
      }
      return true;
    }).toList();
  }

  List<_SimpleQuickTourBlueprint> _selectedSimpleQuickTourBlueprints() {
    final selectedIds = _simpleQuickSelectedBlueprintIds;
    return _availableSimpleQuickTourBlueprints()
        .where((entry) => selectedIds.contains(entry.id))
        .toList();
  }

  Future<void> _openSimpleQuickTournamentComposer(
    List<_SimpleQuickTourBlueprint> addableBlueprints,
    {required int rosterSize}
  ) async {
    if (addableBlueprints.isEmpty) {
      return;
    }
    final result = await Navigator.of(context).push<_SimpleQuickTournamentDraft>(
      MaterialPageRoute<_SimpleQuickTournamentDraft>(
        builder: (_) => _SimpleQuickTournamentAddPage(
          addableBlueprints: addableBlueprints,
          host: this,
          rosterSize: rosterSize,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    _ensureSimpleQuickTourConfigs();
    final selectedBlueprintId = result.blueprintId;
    if (!mounted) {
      return;
    }
    setState(() {
      _simpleQuickSelectedBlueprintIds.add(selectedBlueprintId);
      _simpleQuickTourConfigs[selectedBlueprintId] = result.config;
    });
  }

  List<CareerCalendarItem> _buildSimpleQuickTourCalendar({
    required List<CareerRankingDefinition> rankings,
    required int rosterSize,
  }) {
    _ensureSimpleQuickTourConfigs();
    final blueprints = _selectedSimpleQuickTourBlueprints()
        .where((entry) => (_simpleQuickTourConfigs[entry.id]?.count ?? 0) > 0)
        .toList();
    if (blueprints.isEmpty) {
      return const <CareerCalendarItem>[];
    }

    final mainRankingId = rankings[0].id;
    final seasonRankingId = rankings[1].id;
    final majorRankingId = rankings[2].id;
    final result = <CareerCalendarItem>[];
    for (final blueprint in blueprints) {
      final configuredCount = _simpleQuickTourConfigs[blueprint.id]?.count ?? 0;
      for (var cycle = 0; cycle < configuredCount; cycle += 1) {
        result.addAll(
          _buildSimpleQuickTourItemsForBlueprint(
            blueprint: blueprint,
            cycle: cycle,
            rosterSize: rosterSize,
            mainRankingId: mainRankingId,
            seasonRankingId: seasonRankingId,
            majorRankingId: majorRankingId,
          ),
        );
      }
    }

    return result;
  }

  List<CareerCalendarItem> _buildSimpleQuickTourItemsForBlueprint({
    required _SimpleQuickTourBlueprint blueprint,
    required int cycle,
    required int rosterSize,
    required String mainRankingId,
    required String seasonRankingId,
    required String majorRankingId,
  }) {
    final countsForRankingIds = <String>[
      mainRankingId,
      seasonRankingId,
      if (blueprint.countsForMajorRace) majorRankingId,
    ];
    final config = _simpleQuickTourConfigs[blueprint.id];
    final configuredCustomName = config?.customName?.trim();
    final configuredBaseName =
        configuredCustomName != null && configuredCustomName.isNotEmpty
            ? configuredCustomName
            : blueprint.baseName;
    final baseId = '${blueprint.id}-${cycle + 1}';
    final baseName = '${configuredBaseName} ${cycle + 1}';
    final effectiveFieldSize = config?.fieldSizeOverride ??
        _quickFieldSizeForBlueprint(
      blueprint: blueprint,
      rosterSize: rosterSize,
    );
    final effectiveSeedCount = _quickSeedCountForFieldSize(
      fieldSize: effectiveFieldSize,
      requestedSeedCount: blueprint.seedCount,
    );
    final effectivePrizePool = config?.prizePoolOverride ??
        _quickPrizePoolForFieldSize(
      blueprint: blueprint,
      fieldSize: effectiveFieldSize,
    );
    final effectivePlayoffQualifierCount = blueprint.format ==
            TournamentFormat.leaguePlayoff
        ? _quickPlayoffQualifierCountForFieldSize(
            fieldSize: effectiveFieldSize,
            requestedQualifierCount: blueprint.playoffQualifierCount,
          )
        : blueprint.playoffQualifierCount;
    final effectiveKnockoutPrizeValues = _effectiveQuickKnockoutPrizeValues(
      blueprint: blueprint,
      config: config,
      fieldSize: effectiveFieldSize,
      prizePool: effectivePrizePool,
      playoffQualifierCount: effectivePlayoffQualifierCount,
    );
    final effectiveLeaguePrizeValues = _effectiveQuickLeaguePrizeValues(
      blueprint: blueprint,
      config: config,
      fieldSize: effectiveFieldSize,
      prizePool: effectivePrizePool,
    );
    if (!blueprint.isSeries) {
      return <CareerCalendarItem>[
        CareerCalendarItem(
          id: 'quick-$baseId',
          name: baseName,
          categoryName: blueprint.categoryName,
          tier: blueprint.tier,
          format: blueprint.format,
          fieldSize: effectiveFieldSize,
          legsToWin: blueprint.legsToWin,
          startScore: 501,
          prizePool: effectivePrizePool,
          knockoutPrizeValues: effectiveKnockoutPrizeValues,
          leaguePositionPrizeValues: effectiveLeaguePrizeValues,
          countsForRankingIds: countsForRankingIds,
          seedingRankingId: mainRankingId,
          seedCount: effectiveSeedCount,
        ),
      ];
    }

    final leagueMatchdayCount = _leagueMatchdayCount(
      fieldSize: effectiveFieldSize,
      repeats: blueprint.roundRobinRepeats,
    );
    final playoffRoundCount = blueprint.format == TournamentFormat.leaguePlayoff
        ? _playoffRoundCount(effectivePlayoffQualifierCount)
        : 0;
    final totalSeriesLength = leagueMatchdayCount + playoffRoundCount;

    final items = <CareerCalendarItem>[];
    final seriesGroupId = 'quick-series-$baseId';
    for (var index = 0; index < leagueMatchdayCount; index += 1) {
      items.add(
        CareerCalendarItem(
          id: 'quick-$baseId-league-${index + 1}',
          name: '$baseName - Spieltag ${index + 1}',
          categoryName: blueprint.categoryName,
          tier: blueprint.tier,
          format: blueprint.format,
          fieldSize: effectiveFieldSize,
          legsToWin: blueprint.legsToWin,
          startScore: 501,
          prizePool: effectivePrizePool,
          knockoutPrizeValues: effectiveKnockoutPrizeValues,
          leaguePositionPrizeValues: effectiveLeaguePrizeValues,
          pointsForWin: 2,
          pointsForDraw: 0,
          roundRobinRepeats: blueprint.roundRobinRepeats,
          playoffQualifierCount: effectivePlayoffQualifierCount,
          countsForRankingIds: countsForRankingIds,
          seriesGroupId: seriesGroupId,
          seriesIndex: index + 1,
          seriesLength: totalSeriesLength,
          seriesStage: CareerLeagueSeriesStage.leagueMatchday,
        ),
      );
    }
    for (var index = 0; index < playoffRoundCount; index += 1) {
      final roundNumber = leagueMatchdayCount + index + 1;
      items.add(
        CareerCalendarItem(
          id: 'quick-$baseId-playoff-${index + 1}',
          name: '$baseName - Playoff ${_playoffRoundLabel(index + 1, playoffRoundCount)}',
          categoryName: blueprint.categoryName,
          tier: blueprint.tier,
          format: blueprint.format,
          fieldSize: effectiveFieldSize,
          legsToWin: blueprint.legsToWin,
          startScore: 501,
          prizePool: effectivePrizePool,
          knockoutPrizeValues: effectiveKnockoutPrizeValues,
          leaguePositionPrizeValues: effectiveLeaguePrizeValues,
          pointsForWin: 2,
          pointsForDraw: 0,
          roundRobinRepeats: blueprint.roundRobinRepeats,
          playoffQualifierCount: effectivePlayoffQualifierCount,
          countsForRankingIds: countsForRankingIds,
          seriesGroupId: seriesGroupId,
          seriesIndex: roundNumber,
          seriesLength: totalSeriesLength,
          seriesStage: CareerLeagueSeriesStage.playoffRound,
        ),
      );
    }
    return items;
  }

  int _quickFieldSizeForBlueprint({
    required _SimpleQuickTourBlueprint blueprint,
    required int rosterSize,
  }) {
    final safeRosterSize = rosterSize < 4 ? 4 : rosterSize;
    if (blueprint.isSeries) {
      if (safeRosterSize >= 48) {
        return blueprint.format == TournamentFormat.leaguePlayoff ? 8 : 8;
      }
      if (safeRosterSize >= 24) {
        return blueprint.format == TournamentFormat.leaguePlayoff ? 6 : 6;
      }
      return 4;
    }

    final target = switch (blueprint.categoryName) {
      'Open' => ((safeRosterSize * 0.9).floor()),
      'Championship' => ((safeRosterSize * 0.8).floor()),
      'Players Championship' => ((safeRosterSize * 0.6).floor()),
      'Masters' => ((safeRosterSize * 0.5).floor()),
      'Major' => ((safeRosterSize * 0.5).floor()),
      _ => ((safeRosterSize * 0.65).floor()),
    };
    return _closestSupportedFieldSize(
      target: target,
      minValue: 4,
      maxValue: safeRosterSize >= 64 ? 64 : safeRosterSize,
    );
  }

  int _closestSupportedFieldSize({
    required int target,
    required int minValue,
    required int maxValue,
  }) {
    final supported = <int>[4, 8, 16, 32, 64]
        .where((value) => value >= minValue && value <= maxValue)
        .toList();
    if (supported.isEmpty) {
      return minValue;
    }
    var best = supported.first;
    var bestDistance = (best - target).abs();
    for (final value in supported.skip(1)) {
      final distance = (value - target).abs();
      if (distance < bestDistance) {
        best = value;
        bestDistance = distance;
      }
    }
    return best;
  }

  int _quickSeedCountForFieldSize({
    required int fieldSize,
    required int requestedSeedCount,
  }) {
    if (requestedSeedCount <= 0 || fieldSize < 8) {
      return 0;
    }
    final normalized = fieldSize >= 64
        ? 16
        : fieldSize >= 32
        ? 8
        : 4;
    return normalized > requestedSeedCount ? requestedSeedCount : normalized;
  }

  int _quickPrizePoolForFieldSize({
    required _SimpleQuickTourBlueprint blueprint,
    required int fieldSize,
  }) {
    final baseFieldSize = blueprint.fieldSize <= 0 ? 1 : blueprint.fieldSize;
    final scaled = (blueprint.prizePool * fieldSize / baseFieldSize).round();
    return scaled < 4000 ? 4000 : scaled;
  }

  int _quickPlayoffQualifierCountForFieldSize({
    required int fieldSize,
    required int requestedQualifierCount,
  }) {
    if (fieldSize >= 8) {
      return requestedQualifierCount >= 8 ? 8 : requestedQualifierCount;
    }
    if (fieldSize >= 6) {
      return 4;
    }
    return 2;
  }

  List<int> _effectiveQuickKnockoutPrizeValues({
    required _SimpleQuickTourBlueprint blueprint,
    required _SimpleQuickTourTypeConfig? config,
    required int fieldSize,
    required int prizePool,
    required int playoffQualifierCount,
  }) {
    final stageCount = _quickKnockoutStageCount(
      blueprint: blueprint,
      fieldSize: fieldSize,
      playoffQualifierCount: playoffQualifierCount,
    );
    if (stageCount <= 0) {
      return const <int>[];
    }
    final configuredValues = config?.knockoutPrizeValues ?? const <int>[];
    if (configuredValues.length == stageCount) {
      return configuredValues;
    }
    return _defaultQuickKnockoutPrizeValues(
      preset: config?.prizeSplitPreset ?? CareerTournamentPrizeSplitPreset.proTour,
      prizePool: prizePool,
      stageCount: stageCount,
      format: blueprint.format,
    );
  }

  List<int> _effectiveQuickLeaguePrizeValues({
    required _SimpleQuickTourBlueprint blueprint,
    required _SimpleQuickTourTypeConfig? config,
    required int fieldSize,
    required int prizePool,
  }) {
    final placeCount = _quickLeaguePrizePlaceCount(
      blueprint: blueprint,
      fieldSize: fieldSize,
    );
    if (placeCount <= 0) {
      return const <int>[];
    }
    final configuredValues = config?.leaguePositionPrizeValues ?? const <int>[];
    if (configuredValues.length == placeCount) {
      return configuredValues;
    }
    return _defaultQuickLeaguePrizeValues(
      preset: config?.prizeSplitPreset ?? CareerTournamentPrizeSplitPreset.proTour,
      prizePool: prizePool,
      placeCount: placeCount,
      format: blueprint.format,
    );
  }

  int _quickKnockoutStageCount({
    required _SimpleQuickTourBlueprint blueprint,
    required int fieldSize,
    required int playoffQualifierCount,
  }) {
    return switch (blueprint.format) {
      TournamentFormat.knockout => _roundCountForFieldSize(fieldSize) + 1,
      TournamentFormat.leaguePlayoff =>
        _playoffRoundCount(playoffQualifierCount) + 1,
      TournamentFormat.league => 0,
    };
  }

  int _quickLeaguePrizePlaceCount({
    required _SimpleQuickTourBlueprint blueprint,
    required int fieldSize,
  }) {
    if (blueprint.format != TournamentFormat.league &&
        blueprint.format != TournamentFormat.leaguePlayoff) {
      return 0;
    }
    return fieldSize.clamp(0, 8).toInt();
  }

  List<int> _defaultQuickKnockoutPrizeValues({
    required CareerTournamentPrizeSplitPreset preset,
    required int prizePool,
    required int stageCount,
    required TournamentFormat format,
  }) {
    if (stageCount <= 0 || prizePool <= 0) {
      return List<int>.filled(stageCount < 0 ? 0 : stageCount, 0);
    }
    final targetKnockoutPool = format == TournamentFormat.leaguePlayoff
        ? (prizePool * 0.5).round()
        : prizePool;
    final loserCounts = List<int>.generate(
      stageCount - 1,
      (index) => 1 << (stageCount - index - 2),
    );
    final stageShares = _quickKnockoutStageSharesForPreset(
      preset,
      stageCount,
    );
    final nextValues = List<int>.filled(stageCount, 0);
    for (var index = 0; index < stageCount - 1; index += 1) {
      final loserCount = loserCounts[index];
      if (loserCount <= 0) {
        continue;
      }
      final stageTotal = (targetKnockoutPool * stageShares[index]).round();
      nextValues[index] = (stageTotal / loserCount).round();
    }
    nextValues[stageCount - 1] =
        (targetKnockoutPool * stageShares[stageCount - 1]).round();
    final usedTotal = nextValues[stageCount - 1] +
        List<int>.generate(
          stageCount - 1,
          (index) => nextValues[index] * loserCounts[index],
        ).fold<int>(0, (sum, value) => sum + value);
    nextValues[stageCount - 1] =
        (nextValues[stageCount - 1] + (targetKnockoutPool - usedTotal))
            .clamp(0, 1 << 30);
    return nextValues;
  }

  List<double> _quickKnockoutStageSharesForPreset(
    CareerTournamentPrizeSplitPreset preset,
    int stageCount,
  ) {
    final baseShares = switch (preset) {
      CareerTournamentPrizeSplitPreset.proTour => <double>[
          0.10,
          0.10,
          0.12,
          0.14,
          0.16,
          0.15,
          0.23,
        ],
      CareerTournamentPrizeSplitPreset.major => <double>[
          0.06,
          0.08,
          0.11,
          0.15,
          0.18,
          0.17,
          0.25,
        ],
      CareerTournamentPrizeSplitPreset.development => <double>[
          0.12,
          0.12,
          0.13,
          0.14,
          0.15,
          0.14,
          0.20,
        ],
    };
    final rawShares = stageCount <= baseShares.length
        ? List<double>.from(
            baseShares.sublist(baseShares.length - stageCount),
          )
        : (List<double>.filled(
            stageCount - baseShares.length,
            baseShares.first,
            growable: true,
          )
          ..addAll(baseShares));
    final total = rawShares.fold<double>(0, (sum, entry) => sum + entry);
    if (total <= 0) {
      return List<double>.filled(stageCount, 1 / stageCount);
    }
    return rawShares.map((entry) => entry / total).toList();
  }

  List<int> _defaultQuickLeaguePrizeValues({
    required CareerTournamentPrizeSplitPreset preset,
    required int prizePool,
    required int placeCount,
    required TournamentFormat format,
  }) {
    if (placeCount <= 0 || prizePool <= 0) {
      return List<int>.filled(placeCount < 0 ? 0 : placeCount, 0);
    }
    final targetLeaguePool = format == TournamentFormat.leaguePlayoff
        ? (prizePool - (prizePool * 0.5).round()).clamp(0, prizePool)
        : prizePool;
    final baseShares = switch (preset) {
      CareerTournamentPrizeSplitPreset.proTour => <double>[
          0.40,
          0.22,
          0.14,
          0.10,
          0.07,
          0.04,
          0.02,
          0.01,
        ],
      CareerTournamentPrizeSplitPreset.major => <double>[
          0.48,
          0.22,
          0.12,
          0.08,
          0.05,
          0.03,
          0.015,
          0.005,
        ],
      CareerTournamentPrizeSplitPreset.development => <double>[
          0.28,
          0.20,
          0.16,
          0.12,
          0.09,
          0.07,
          0.05,
          0.03,
        ],
    };
    final rawShares = List<double>.from(baseShares.take(placeCount));
    final total = rawShares.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) {
      return List<int>.filled(placeCount, 0);
    }
    final normalized = rawShares.map((value) => value / total).toList();
    final nextValues = normalized
        .map((share) => (targetLeaguePool * share).round())
        .toList();
    final difference =
        targetLeaguePool - nextValues.fold<int>(0, (sum, value) => sum + value);
    nextValues[0] = (nextValues[0] + difference).clamp(0, 1 << 30);
    return nextValues;
  }

  double _quickKnockoutSharePercent({
    required List<int> values,
    required int index,
    required TournamentFormat format,
  }) {
    if (values.isEmpty || index < 0 || index >= values.length) {
      return 0;
    }
    final loserCounts = List<int>.generate(
      values.length - 1,
      (entry) => 1 << (values.length - entry - 2),
    );
    final totalPool = format == TournamentFormat.leaguePlayoff
        ? _calculatedKnockoutPrizePoolForValues(values)
        : _calculatedKnockoutPrizePoolForValues(values);
    if (totalPool <= 0) {
      return 0;
    }
    final stageTotal = index == values.length - 1
        ? values[index]
        : values[index] * loserCounts[index];
    return (stageTotal / totalPool) * 100;
  }

  List<int> _quickKnockoutValuesWithSharePercent({
    required List<int> values,
    required int index,
    required double sharePercent,
    required int prizePool,
    required TournamentFormat format,
  }) {
    if (index < 0 || index >= values.length) {
      return values;
    }
    final targetPool = format == TournamentFormat.leaguePlayoff
        ? (prizePool * 0.5).round()
        : prizePool;
    if (targetPool <= 0) {
      return values;
    }
    final normalizedShare = sharePercent < 0 ? 0.0 : sharePercent / 100.0;
    final loserCounts = List<int>.generate(
      values.length - 1,
      (entry) => 1 << (values.length - entry - 2),
    );
    final nextValues = List<int>.from(values);
    if (index == values.length - 1) {
      nextValues[index] = (targetPool * normalizedShare).round().clamp(
            0,
            1 << 30,
          );
    } else {
      final loserCount = loserCounts[index];
      final stageTotal = (targetPool * normalizedShare).round();
      nextValues[index] =
          loserCount <= 0 ? 0 : (stageTotal / loserCount).round().clamp(0, 1 << 30);
    }
    return nextValues;
  }

  double _quickLeagueSharePercent({
    required List<int> values,
    required int index,
  }) {
    if (values.isEmpty || index < 0 || index >= values.length) {
      return 0;
    }
    final totalPool = values.fold<int>(0, (sum, entry) => sum + entry);
    if (totalPool <= 0) {
      return 0;
    }
    return (values[index] / totalPool) * 100;
  }

  List<int> _quickLeagueValuesWithSharePercent({
    required List<int> values,
    required int index,
    required double sharePercent,
    required int prizePool,
    required TournamentFormat format,
  }) {
    if (index < 0 || index >= values.length) {
      return values;
    }
    final targetPool = format == TournamentFormat.leaguePlayoff
        ? (prizePool - (prizePool * 0.5).round()).clamp(0, prizePool)
        : prizePool;
    if (targetPool <= 0) {
      return values;
    }
    final normalizedShare = sharePercent < 0 ? 0.0 : sharePercent / 100.0;
    final nextValues = List<int>.from(values);
    nextValues[index] = (targetPool * normalizedShare).round().clamp(
          0,
          1 << 30,
        );
    return nextValues;
  }

  String _quickKnockoutPrizeLabel(int index, int stageCount) {
    if (index == stageCount - 1) {
      return 'Sieger';
    }
    if (index == stageCount - 2) {
      return 'Finalverlierer';
    }
    if (index == stageCount - 3) {
      return 'Halbfinalverlierer';
    }
    if (index == stageCount - 4) {
      return 'Viertelfinalverlierer';
    }
    return 'Runde ${index + 1} Verlierer';
  }

  int _roundCountForFieldSize(int fieldSize) {
    var rounds = 0;
    var size = fieldSize;
    while (size > 1) {
      size = (size / 2).ceil();
      rounds += 1;
    }
    return rounds;
  }

  _CareerRosterViewData _buildTemplatePoolViewData() {
    final availablePlayers = _computerRepository.players.map((player) {
      final override = _simpleTemplateTrainingOverrides[player.id];
      if (override == null) {
        return player;
      }
      return player.copyWith(
        theoreticalAverage: override.average,
        skill: override.skill,
        finishingSkill: override.finishingSkill,
      );
    }).toList();
    final availableTags = availablePlayers
        .expand((player) => player.tags)
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    _selectedTemplateDatabaseTagFilters.removeWhere(
      (tag) => !availableTags.contains(tag),
    );
    final addablePlayers = availablePlayers
        .where((player) {
          if (_selectedTemplateDatabaseTagFilters.isEmpty) {
            return true;
          }
          for (final tag in player.tags) {
            if (_selectedTemplateDatabaseTagFilters.contains(tag)) {
              return true;
            }
          }
          return false;
        })
        .toList()
      ..sort(
        (left, right) =>
            right.theoreticalAverage.compareTo(left.theoreticalAverage),
      );
    _selectedTemplateDatabasePlayerIds.removeWhere(
      (playerId) => addablePlayers.every((player) => player.id != playerId),
    );
    return _CareerRosterViewData(
      availableTags: availableTags,
      addablePlayers: addablePlayers,
    );
  }

  List<CareerDatabasePlayer> _templateCreationPoolPlayers(
    CareerTemplate? template,
  ) {
    final basePlayers = switch (_templateCareerPoolMode) {
      _TemplateCareerPoolMode.empty => const <CareerDatabasePlayer>[],
      _TemplateCareerPoolMode.allDatabasePlayers => _computerRepository.players
          .map(
            (player) => _careerDatabasePlayerFromComputerPlayer(
              player: player,
              template: template,
            ),
          )
          .toList(),
      _TemplateCareerPoolMode.selectedDatabasePlayers => _computerRepository.players
          .where(
            (player) => _selectedTemplateDatabasePlayerIds.contains(player.id),
          )
          .map(
            (player) => _careerDatabasePlayerFromComputerPlayer(
              player: player,
              template: template,
            ),
          )
          .toList(),
    };
    return basePlayers.map((player) {
      return _simpleTemplateTrainingOverrides[player.databasePlayerId] ?? player;
    }).toList();
  }

  CareerDatabasePlayer _careerDatabasePlayerFromComputerPlayer({
    required ComputerPlayer player,
    required CareerTemplate? template,
  }) {
    final tagDefinitionsByLowerName = <String, CareerTagDefinition>{
      for (final definition in template?.careerTagDefinitions ??
          const <CareerTagDefinition>[])
        definition.name.toLowerCase(): definition,
    };
    final careerTags = <CareerPlayerTag>[];
    final seenTagNames = <String>{};
    for (final rawTag in player.tags) {
      final normalizedTag = rawTag.trim().toLowerCase();
      final definition = tagDefinitionsByLowerName[normalizedTag];
      if (definition == null || !seenTagNames.add(definition.name)) {
        continue;
      }
      careerTags.add(
        CareerPlayerTag(
          tagName: definition.name,
          remainingSeasons: definition.initialValiditySeasons,
        ),
      );
    }
    return CareerDatabasePlayer(
      databasePlayerId: player.id,
      name: player.name,
      average: player.theoreticalAverage,
      skill: player.skill,
      finishingSkill: player.finishingSkill,
      nationality: player.nationality,
      careerTags: careerTags,
    );
  }

  String _careerStructurePresetLabel(_CareerStructurePreset preset) {
    return switch (preset) {
      _CareerStructurePreset.custom => 'Frei / Manuell',
      _CareerStructurePreset.pdcLike => 'PDC aehnlich',
      _CareerStructurePreset.developmentFocus => 'Development-Fokus',
    };
  }

  String _careerStructurePresetDescription(_CareerStructurePreset preset) {
    return switch (preset) {
      _CareerStructurePreset.custom =>
        'Du baust Ranglisten, Karriere-Tags und Saisonende-Regeln komplett selbst.',
      _CareerStructurePreset.pdcLike =>
        'Legt typische Status-Tags wie Tour Card, Challenge Tour und mehrere passende Karriere-Ranglisten an.',
      _CareerStructurePreset.developmentFocus =>
        'Fokussiert auf Development Tour, Challenge Tour und die Frauenserie als realistischen Einstieg.',
    };
  }

  String _tournamentAccessPresetLabel(_CareerTournamentAccessPreset preset) {
    return switch (preset) {
      _CareerTournamentAccessPreset.custom => 'Frei / Manuell',
      _CareerTournamentAccessPreset.open => 'Offenes Feld',
      _CareerTournamentAccessPreset.top64OrderOfMerit =>
        'Top 64 Order of Merit',
      _CareerTournamentAccessPreset.tourCardOnly => 'Nur Tour Card',
      _CareerTournamentAccessPreset.challengeTourOnly =>
        'Nur Challenge Tour',
      _CareerTournamentAccessPreset.developmentTourOnly =>
        'Nur Development Tour',
      _CareerTournamentAccessPreset.womensSeriesOnly =>
        'Nur Womens Series',
      _CareerTournamentAccessPreset.hostNationOnly => 'Nur Host Nation',
    };
  }

  String _tournamentAccessPresetDescription(
    _CareerTournamentAccessPreset preset,
  ) {
    return switch (preset) {
      _CareerTournamentAccessPreset.custom =>
        'Du stellst normale Qualifikation, Slot-Regeln und Auffuellen komplett selbst ein.',
      _CareerTournamentAccessPreset.open =>
        'Kein spezieller Zugang. Das Feld wird ueber den normalen Fill-Pfad offen aufgebaut.',
      _CareerTournamentAccessPreset.top64OrderOfMerit =>
        'Die ersten 64 der Order of Merit qualifizieren sich direkt. Der Rest des Felds wird wie gewohnt aufgefuellt.',
      _CareerTournamentAccessPreset.tourCardOnly =>
        'Nur Spieler mit dem Karriere-Tag Tour Card koennen dieses Feld fuellen.',
      _CareerTournamentAccessPreset.challengeTourOnly =>
        'Nur Spieler mit dem Karriere-Tag Challenge Tour koennen dieses Feld fuellen.',
      _CareerTournamentAccessPreset.developmentTourOnly =>
        'Nur Spieler mit dem Karriere-Tag Development Tour koennen dieses Feld fuellen.',
      _CareerTournamentAccessPreset.womensSeriesOnly =>
        'Nur Spieler mit dem Karriere-Tag Womens Series koennen dieses Feld fuellen.',
      _CareerTournamentAccessPreset.hostNationOnly =>
        'Das Feld wird auf Spieler mit dem Karriere-Tag Host Nation Pool begrenzt.',
    };
  }

  void _applySelectedCareerStructurePresetIfNeeded() {
    final activeCareer = _repository.activeCareer;
    if (activeCareer == null ||
        _selectedCareerStructurePreset == _CareerStructurePreset.custom) {
      return;
    }
    _applyCareerStructurePresetNow(_selectedCareerStructurePreset);
  }

  Future<void> _applyCareerStructurePreset(CareerDefinition career) async {
    if (_selectedCareerStructurePreset == _CareerStructurePreset.custom) {
      return;
    }
    await _runBusyAction(
      message: 'Karriere-System wird vorbereitet...',
      action: () async {
        await Future<void>.delayed(Duration.zero);
        _applyCareerStructurePresetNow(_selectedCareerStructurePreset);
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _applyCareerStructurePresetNow(_CareerStructurePreset preset) {
    switch (preset) {
      case _CareerStructurePreset.custom:
        return;
      case _CareerStructurePreset.pdcLike:
        _applyPdcLikeStructurePreset();
        return;
      case _CareerStructurePreset.developmentFocus:
        _applyDevelopmentStructurePreset();
        return;
    }
  }

  void _applyPdcLikeStructurePreset() {
    _ensureCareerRanking(name: 'Order of Merit', validSeasons: 2);
    _ensureCareerRanking(name: 'Pro Tour Order of Merit', validSeasons: 1);
    _ensureCareerRanking(
      name: 'Players Championship Order of Merit',
      validSeasons: 1,
    );
    _ensureCareerRanking(name: 'European Tour Order of Merit', validSeasons: 1);
    _ensureCareerRanking(name: 'Challenge Tour Order of Merit', validSeasons: 1);
    _ensureCareerRanking(
      name: 'Development Tour Order of Merit',
      validSeasons: 1,
    );
    _ensureCareerRanking(name: 'Womens Series Order of Merit', validSeasons: 1);

    _ensureCareerStatusTag(name: 'Tour Card', group: 'tour', playerLimit: 128);
    _ensureCareerStatusTag(name: 'Challenge Tour', group: 'tour');
    _ensureCareerStatusTag(name: 'Development Tour', group: 'tour');
    _ensureCareerStatusTag(name: 'Womens Series', group: 'tour');
    _ensureCareerStatusTag(name: 'Host Nation Pool', group: 'qualifier');
    _ensureCareerStatusTag(
      name: 'International Qualifier',
      group: 'qualifier',
    );

    _ensureSeasonRule(
      tagName: 'Tour Card',
      rankingName: 'Order of Merit',
      fromRank: 1,
      toRank: 64,
      action: CareerSeasonTagRuleAction.add,
    );
    _ensureSeasonRule(
      tagName: 'Tour Card',
      rankingName: 'Order of Merit',
      fromRank: 65,
      toRank: 65,
      action: CareerSeasonTagRuleAction.remove,
      rankMode: CareerSeasonTagRuleRankMode.greaterThanRank,
      referenceRank: 64,
    );
    _ensureSeasonRule(
      tagName: 'Challenge Tour',
      rankingName: 'Challenge Tour Order of Merit',
      fromRank: 1,
      toRank: 32,
      action: CareerSeasonTagRuleAction.add,
    );
    _ensureSeasonRule(
      tagName: 'Development Tour',
      rankingName: 'Development Tour Order of Merit',
      fromRank: 1,
      toRank: 32,
      action: CareerSeasonTagRuleAction.add,
    );
    _ensureSeasonRule(
      tagName: 'Womens Series',
      rankingName: 'Womens Series Order of Merit',
      fromRank: 1,
      toRank: 24,
      action: CareerSeasonTagRuleAction.add,
    );
  }

  void _applyDevelopmentStructurePreset() {
    _ensureCareerRanking(
      name: 'Development Tour Order of Merit',
      validSeasons: 1,
    );
    _ensureCareerRanking(name: 'Challenge Tour Order of Merit', validSeasons: 1);
    _ensureCareerRanking(name: 'Womens Series Order of Merit', validSeasons: 1);
    _ensureCareerStatusTag(name: 'Development Tour', group: 'tour');
    _ensureCareerStatusTag(name: 'Challenge Tour', group: 'tour');
    _ensureCareerStatusTag(name: 'Womens Series', group: 'tour');
    _ensureCareerStatusTag(name: 'Host Nation Pool', group: 'qualifier');
    _ensureSeasonRule(
      tagName: 'Development Tour',
      rankingName: 'Development Tour Order of Merit',
      fromRank: 1,
      toRank: 32,
      action: CareerSeasonTagRuleAction.add,
    );
    _ensureSeasonRule(
      tagName: 'Challenge Tour',
      rankingName: 'Challenge Tour Order of Merit',
      fromRank: 1,
      toRank: 32,
      action: CareerSeasonTagRuleAction.add,
    );
    _ensureSeasonRule(
      tagName: 'Womens Series',
      rankingName: 'Womens Series Order of Merit',
      fromRank: 1,
      toRank: 24,
      action: CareerSeasonTagRuleAction.add,
    );
  }

  void _ensureCareerRanking({
    required String name,
    required int validSeasons,
    bool resetAtSeasonEnd = false,
  }) {
    final career = _repository.activeCareer;
    if (career == null || _findRankingByName(career, name) != null) {
      return;
    }
    _repository.addRanking(
      name: name,
      validSeasons: validSeasons,
      resetAtSeasonEnd: resetAtSeasonEnd,
    );
  }

  void _ensureCareerStatusTag({
    required String name,
    required String group,
    int? playerLimit,
  }) {
    final career = _repository.activeCareer;
    if (career == null || _findCareerTagDefinitionByName(career, name) != null) {
      return;
    }
    _repository.addCareerTagDefinition(
      name: name,
      playerLimit: playerLimit,
      attributes: <CareerTagAttribute>[
        const CareerTagAttribute(key: 'system', value: 'status'),
        CareerTagAttribute(key: 'group', value: group),
      ],
    );
  }

  void _ensureSeasonRule({
    required String tagName,
    required String rankingName,
    required int fromRank,
    required int toRank,
    required CareerSeasonTagRuleAction action,
    CareerSeasonTagRuleRankMode rankMode = CareerSeasonTagRuleRankMode.range,
    int? referenceRank,
  }) {
    final career = _repository.activeCareer;
    if (career == null) {
      return;
    }
    final ranking = _findRankingByName(career, rankingName);
    if (ranking == null) {
      return;
    }
    final ruleExists = career.seasonTagRules.any(
      (rule) =>
          rule.tagName == tagName &&
          rule.rankingId == ranking.id &&
          rule.fromRank == fromRank &&
          rule.toRank == toRank &&
          rule.action == action &&
          rule.rankMode == rankMode &&
          rule.referenceRank == referenceRank,
    );
    if (ruleExists) {
      return;
    }
    _repository.addSeasonTagRule(
      tagName: tagName,
      rankingId: ranking.id,
      fromRank: fromRank,
      toRank: toRank,
      action: action,
      rankMode: rankMode,
      referenceRank: referenceRank,
    );
  }

  CareerRankingDefinition? _findRankingByName(
    CareerDefinition career,
    String name,
  ) {
    for (final ranking in career.rankings) {
      if (ranking.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        return ranking;
      }
    }
    return null;
  }

  CareerTagDefinition? _findCareerTagDefinitionByName(
    CareerDefinition career,
    String name,
  ) {
    for (final tag in career.careerTagDefinitions) {
      if (tag.name.trim().toLowerCase() == name.trim().toLowerCase()) {
        return tag;
      }
    }
    return null;
  }

  void _applyTournamentAccessPreset(CareerDefinition career) {
    _qualificationConditions.clear();
    _qualificationRankingId = null;
    _selectedQualificationTagNames.clear();
    _selectedQualificationExcludedTagNames.clear();
    _selectedQualificationNationalities.clear();
    _selectedQualificationExcludedNationalities.clear();
    _fillRankingId = null;
    _fillTopByRankingController.clear();
    _fillTopByAverageController.clear();
    _selectedFillTagNames.clear();
    _selectedFillExcludedTagNames.clear();
    _selectedFillNationalities.clear();
    _selectedFillExcludedNationalities.clear();

    switch (_selectedTournamentAccessPreset) {
      case _CareerTournamentAccessPreset.custom:
        return;
      case _CareerTournamentAccessPreset.open:
        _seedingRankingId = null;
        _seedCount = 0;
        return;
      case _CareerTournamentAccessPreset.top64OrderOfMerit:
        final orderOfMerit = _findRankingByName(career, 'Order of Merit');
        _qualificationRankingId = orderOfMerit?.id;
        _qualificationFromController.text = '1';
        _qualificationToController.text = '64';
        if (orderOfMerit != null) {
          _upsertSimpleQualificationCondition(career);
          _seedingRankingId = orderOfMerit.id;
          _seedCount = 16;
        }
        return;
      case _CareerTournamentAccessPreset.tourCardOnly:
        _applyFillTagPreset(career, tagName: 'Tour Card');
        return;
      case _CareerTournamentAccessPreset.challengeTourOnly:
        _applyFillTagPreset(career, tagName: 'Challenge Tour');
        return;
      case _CareerTournamentAccessPreset.developmentTourOnly:
        _applyFillTagPreset(career, tagName: 'Development Tour');
        return;
      case _CareerTournamentAccessPreset.womensSeriesOnly:
        _applyFillTagPreset(career, tagName: 'Womens Series');
        return;
      case _CareerTournamentAccessPreset.hostNationOnly:
        _applyFillTagPreset(career, tagName: 'Host Nation Pool');
        return;
    }
  }

  void _applyFillTagPreset(
    CareerDefinition career, {
    required String tagName,
  }) {
    _selectedFillTagNames.add(tagName);
    final orderOfMerit = _findRankingByName(career, 'Order of Merit');
    if (orderOfMerit != null) {
      _seedingRankingId = orderOfMerit.id;
      _seedCount = 16;
    }
  }

  Future<void> _runBusyAction({
    required String message,
    required Future<void> Function() action,
  }) async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isBusy = true;
      _busyMessage = message;
      _busyProgress = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 16));
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _busyMessage = '';
          _busyProgress = null;
        });
      }
    }
  }

  void _addRanking() {
    final parsedValidSeasons =
        int.tryParse(_rankingValidSeasonsController.text.trim());
    final validSeasons = parsedValidSeasons != null && parsedValidSeasons > 0
        ? parsedValidSeasons
        : _rankingValidSeasons;
    _rankingValidSeasons = validSeasons;
    if (_editingRankingId == null) {
      _repository.addRanking(
        name: _rankingNameController.text,
        validSeasons: validSeasons,
        resetAtSeasonEnd: _rankingResetAtSeasonEnd,
      );
      final activeCareer = _repository.activeCareer;
      if (activeCareer != null && _selectedRankingIds.isEmpty) {
        _selectedRankingIds.add(activeCareer.rankings.last.id);
      }
    } else {
      _repository.updateRanking(
        rankingId: _editingRankingId!,
        name: _rankingNameController.text,
        validSeasons: validSeasons,
        resetAtSeasonEnd: _rankingResetAtSeasonEnd,
      );
    }
    _resetRankingForm();
    setState(() {});
  }

  void _addSelectedDatabasePlayersToCareer() {
    final career = _repository.activeCareer;
    if (career == null || _selectedDatabasePlayerIds.isEmpty) {
      return;
    }
    final tags = _parseCareerTags(_databasePlayerTagsController.text);
    for (final player in _computerRepository.players) {
      if (!_selectedDatabasePlayerIds.contains(player.id)) {
        continue;
      }
        _repository.addDatabasePlayer(
          player: CareerDatabasePlayer(
            databasePlayerId: player.id,
            name: player.name,
            average: player.theoreticalAverage,
            skill: player.skill,
            finishingSkill: player.finishingSkill,
            nationality: player.nationality,
            careerTags: tags,
          ),
        );
    }
    _databasePlayerTagsController.clear();
    _selectedDatabasePlayerIds.clear();
    final updatedCareer = _repository.activeCareer;
    final takenIds = updatedCareer?.databasePlayers
            .map((item) => item.databasePlayerId)
            .toSet() ??
        <String>{};
    String? nextDatabasePlayerId;
    for (final player in _computerRepository.players) {
      if (!takenIds.contains(player.id)) {
        nextDatabasePlayerId = player.id;
        break;
      }
    }
    _selectedDatabasePlayerId = nextDatabasePlayerId;
    setState(() {});
  }

  void _applyTagsToSelectedCareerPlayers() {
    final career = _repository.activeCareer;
    if (career == null || _selectedCareerRosterPlayerIds.isEmpty) {
      return;
    }
    final tagsToAdd = _parseCareerTags(_careerRosterTagsController.text);
    if (tagsToAdd.isEmpty) {
      return;
    }
    for (final player in career.databasePlayers) {
      if (!_selectedCareerRosterPlayerIds.contains(player.databasePlayerId)) {
        continue;
      }
      final nextTags = <CareerPlayerTag>[
        ...player.careerTags,
        ...tagsToAdd,
      ];
      _repository.updateDatabasePlayer(
        player: player.copyWith(careerTags: nextTags),
      );
    }
    setState(() {});
  }

  void _removeTagsFromSelectedCareerPlayers() {
    final career = _repository.activeCareer;
    if (career == null || _selectedCareerRosterPlayerIds.isEmpty) {
      return;
    }
    final tagNames = _parseCareerTags(_careerRosterTagsController.text)
        .map((entry) => entry.tagName)
        .toSet();
    if (tagNames.isEmpty) {
      return;
    }
    for (final player in career.databasePlayers) {
      if (!_selectedCareerRosterPlayerIds.contains(player.databasePlayerId)) {
        continue;
      }
      _repository.updateDatabasePlayer(
        player: player.copyWith(
          careerTags: player.careerTags
              .where((entry) => !tagNames.contains(entry.tagName))
              .toList(),
        ),
      );
    }
    setState(() {});
  }

  void _clearAllTagsFromSelectedCareerPlayers() {
    final career = _repository.activeCareer;
    if (career == null || _selectedCareerRosterPlayerIds.isEmpty) {
      return;
    }
    for (final player in career.databasePlayers) {
      if (!_selectedCareerRosterPlayerIds.contains(player.databasePlayerId)) {
        continue;
      }
      _repository.updateDatabasePlayer(
        player: player.copyWith(careerTags: const <CareerPlayerTag>[]),
      );
    }
    setState(() {});
  }

  void _removeSelectedCareerPlayers() {
    final career = _repository.activeCareer;
    if (career == null || _selectedCareerRosterPlayerIds.isEmpty) {
      return;
    }
    final playerIds = Set<String>.from(_selectedCareerRosterPlayerIds);
    for (final player in career.databasePlayers) {
      if (!playerIds.contains(player.databasePlayerId)) {
        continue;
      }
      _repository.removeDatabasePlayer(player.databasePlayerId);
    }
    _selectedCareerRosterPlayerIds.clear();
    setState(() {});
  }

  void _submitCareerTagDefinition() {
    final name = _careerTagNameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    final attributes = _parseCareerTagAttributes(
      _careerTagAttributesController.text,
    );
    final parsedLimit = int.tryParse(_careerTagLimitController.text.trim());
    final playerLimit = parsedLimit == null || parsedLimit <= 0
        ? null
        : parsedLimit;
    final initialValiditySeasons =
        int.tryParse(_careerTagInitialValidityController.text.trim());
    final extensionValiditySeasons =
        int.tryParse(_careerTagExtensionValidityController.text.trim());
    final tagsToAddOnExpiry =
        _parseTagNames(_careerTagAddOnExpiryController.text);
    final tagsToRemoveOnInitialAssignment =
        _parseTagNames(_careerTagRemoveOnInitialController.text);
    final tagsToRemoveOnExtension =
        _parseTagNames(_careerTagRemoveOnExtensionController.text);
    if (_editingCareerTagId == null) {
      _repository.addCareerTagDefinition(
        name: name,
        attributes: attributes,
        playerLimit: playerLimit,
        initialValiditySeasons: initialValiditySeasons == null ||
                initialValiditySeasons <= 0
            ? null
            : initialValiditySeasons,
        extensionValiditySeasons: extensionValiditySeasons == null ||
                extensionValiditySeasons <= 0
            ? null
            : extensionValiditySeasons,
        tagsToAddOnExpiry: tagsToAddOnExpiry,
        tagsToRemoveOnInitialAssignment: tagsToRemoveOnInitialAssignment,
        tagsToRemoveOnExtension: tagsToRemoveOnExtension,
      );
    } else {
      _repository.updateCareerTagDefinition(
        tagDefinitionId: _editingCareerTagId!,
        name: name,
        attributes: attributes,
        playerLimit: playerLimit,
        initialValiditySeasons: initialValiditySeasons == null ||
                initialValiditySeasons <= 0
            ? null
            : initialValiditySeasons,
        extensionValiditySeasons: extensionValiditySeasons == null ||
                extensionValiditySeasons <= 0
            ? null
            : extensionValiditySeasons,
        tagsToAddOnExpiry: tagsToAddOnExpiry,
        tagsToRemoveOnInitialAssignment: tagsToRemoveOnInitialAssignment,
        tagsToRemoveOnExtension: tagsToRemoveOnExtension,
      );
    }
    _resetCareerTagForm();
    setState(() {});
  }

  void _submitSeasonTagRule(CareerDefinition career) {
    final tagName = _selectedSeasonTagRuleTagName;
    final rankingId = _selectedSeasonTagRuleRankingId;
    final fromRank = int.tryParse(_seasonTagRuleFromController.text.trim()) ?? 1;
    final toRank = int.tryParse(_seasonTagRuleToController.text.trim()) ?? fromRank;
    final referenceRank =
        int.tryParse(_seasonTagRuleReferenceRankController.text.trim());
    final checkRemainingSeasons =
        int.tryParse(_seasonTagRuleCheckRemainingController.text.trim());
    if (tagName == null || rankingId == null) {
      return;
    }
    if (_editingSeasonTagRuleId == null) {
      _repository.addSeasonTagRule(
        tagName: tagName,
        rankingId: rankingId,
        fromRank: fromRank,
        toRank: toRank,
        action: _seasonTagRuleAction,
        rankMode: _seasonTagRuleRankMode,
        referenceRank:
            _seasonTagRuleRankMode == CareerSeasonTagRuleRankMode.greaterThanRank
                ? referenceRank
                : null,
        checkMode: _seasonTagRuleCheckMode,
        checkTagName: _seasonTagRuleCheckMode == CareerSeasonTagRuleCheckMode.none
            ? null
            : _selectedSeasonTagRuleCheckTagName,
        checkRemainingSeasons:
            _seasonTagRuleCheckMode == CareerSeasonTagRuleCheckMode.none
                ? null
                : checkRemainingSeasons,
      );
    } else {
      _repository.updateSeasonTagRule(
        ruleId: _editingSeasonTagRuleId!,
        tagName: tagName,
        rankingId: rankingId,
        fromRank: fromRank,
        toRank: toRank,
        action: _seasonTagRuleAction,
        rankMode: _seasonTagRuleRankMode,
        referenceRank:
            _seasonTagRuleRankMode == CareerSeasonTagRuleRankMode.greaterThanRank
                ? referenceRank
                : null,
        checkMode: _seasonTagRuleCheckMode,
        checkTagName: _seasonTagRuleCheckMode == CareerSeasonTagRuleCheckMode.none
            ? null
            : _selectedSeasonTagRuleCheckTagName,
        checkRemainingSeasons:
            _seasonTagRuleCheckMode == CareerSeasonTagRuleCheckMode.none
                ? null
                : checkRemainingSeasons,
      );
    }
    _resetSeasonTagRuleForm(career);
    setState(() {});
  }

  void _submitCalendarItem() {
    final fieldSize = _tournamentFormData.parsedFieldSize;
    final tier = _tournamentFormData.parsedTier;
    final startScore = _tournamentFormData.parsedStartScore;
    final prizePool = _calculatedPrizePool();
    final tournamentTagGateMinimum =
        int.tryParse(_tournamentTagGateMinimumController.text.trim());
    final tournamentTagGate =
        _selectedTournamentTagGateTagName == null ||
                tournamentTagGateMinimum == null ||
                tournamentTagGateMinimum <= 0
            ? null
            : CareerTournamentTagGate(
                tagName: _selectedTournamentTagGateTagName!,
                minimumPlayerCount: tournamentTagGateMinimum,
                tournamentOccursWhenMet: _tournamentOccursWhenTagGateMet,
              );
    final seriesCount = _editingCalendarItemId == null
        ? (_createAsSeries && !_expandLeagueIntoMatchdays
              ? (int.tryParse(_seriesCountController.text) ?? 1).clamp(1, 100)
              : 1)
        : 1;
    if (fieldSize == null ||
        fieldSize < 2 ||
        tier == null ||
        tier < 1 ||
        startScore == null ||
        startScore <= 1) {
      return;
    }
    if (_editingCalendarItemId != null) {
      _repository.updateCalendarItem(
          itemId: _editingCalendarItemId!,
          name: _itemNameController.text,
          tier: tier,
          game: _tournamentFormData.game,
        format: _tournamentFormData.format,
        fieldSize: fieldSize,
        matchMode: _tournamentFormData.matchMode,
        legsToWin: _tournamentFormData.effectiveLegsToWin,
        startScore: startScore,
        checkoutRequirement: _tournamentFormData.checkoutRequirement,
        prizePool: prizePool,
        knockoutPrizeValues: List<int>.from(_knockoutPrizeValues),
        leaguePositionPrizeValues: List<int>.from(_leaguePositionPrizeValues),
        setsToWin: _tournamentFormData.effectiveSetsToWin,
        legsPerSet: _tournamentFormData.effectiveLegsPerSet,
        roundDistanceValues: _tournamentFormData.effectiveRoundDistanceValues,
        pointsForWin: _tournamentFormData.pointsForWin,
        pointsForDraw: _tournamentFormData.pointsForDraw,
        roundRobinRepeats: _tournamentFormData.roundRobinRepeats,
        playoffQualifierCount: _tournamentFormData.playoffQualifierCount,
        countsForRankingIds: _selectedRankingIds.toList(),
        seedingRankingId: _seedingRankingId,
        seedCount: _seedCount,
        slotRules: _buildSlotRulesFromForm(),
        fillRules: _buildFillRulesFromForm(),
        qualificationConditions:
            List<CareerQualificationCondition>.from(_qualificationConditions),
        fillRequiredCareerTags: _selectedFillTagNames.toList(),
        fillExcludedCareerTags: _selectedFillExcludedTagNames.toList(),
        fillRankingId: _fillRankingId,
        fillTopByRankingCount:
            int.tryParse(_fillTopByRankingController.text.trim()) ?? 0,
          fillTopByAverageCount:
              int.tryParse(_fillTopByAverageController.text.trim()) ?? 0,
          tagGate: tournamentTagGate,
          seriesGroupId: _editingSeriesGroupId,
          seriesIndex: _editingSeriesIndex,
          seriesLength: _editingSeriesLength,
          seriesStage: _editingSeriesStage,
          leagueSeriesQualificationMode: _leagueSeriesQualificationMode,
        );
      } else {
        final baseName = _itemNameController.text.trim().isEmpty
            ? 'Turnier'
            : _itemNameController.text.trim();
        final seriesBatchId = DateTime.now().microsecondsSinceEpoch;
        if (_expandLeagueIntoMatchdays &&
            (_tournamentFormData.format == TournamentFormat.league ||
                _tournamentFormData.format ==
                    TournamentFormat.leaguePlayoff)) {
          final leagueMatchdayCount = _leagueMatchdayCount(
            fieldSize: fieldSize,
            repeats: _tournamentFormData.roundRobinRepeats,
          );
          final playoffRoundCount =
              _tournamentFormData.format == TournamentFormat.leaguePlayoff
              ? _playoffRoundCount(_tournamentFormData.playoffQualifierCount)
              : 0;
          final totalSeriesLength = leagueMatchdayCount + playoffRoundCount;
          for (var index = 0; index < leagueMatchdayCount; index += 1) {
              _repository.addCalendarItem(
                itemId: 'calendar-$seriesBatchId-league-$index',
                name: '$baseName - Spieltag ${index + 1}',
                tier: tier,
                game: _tournamentFormData.game,
              format: _tournamentFormData.format,
              fieldSize: fieldSize,
              matchMode: _tournamentFormData.matchMode,
              legsToWin: _tournamentFormData.effectiveLegsToWin,
              startScore: startScore,
              checkoutRequirement: _tournamentFormData.checkoutRequirement,
              prizePool: prizePool,
              knockoutPrizeValues: List<int>.from(_knockoutPrizeValues),
              leaguePositionPrizeValues: List<int>.from(_leaguePositionPrizeValues),
              setsToWin: _tournamentFormData.effectiveSetsToWin,
              legsPerSet: _tournamentFormData.effectiveLegsPerSet,
              roundDistanceValues:
                  _tournamentFormData.effectiveRoundDistanceValues,
              pointsForWin: _tournamentFormData.pointsForWin,
              pointsForDraw: _tournamentFormData.pointsForDraw,
              roundRobinRepeats: _tournamentFormData.roundRobinRepeats,
              playoffQualifierCount: _tournamentFormData.playoffQualifierCount,
              countsForRankingIds: _selectedRankingIds.toList(),
              seedingRankingId: _seedingRankingId,
              seedCount: _seedCount,
              slotRules: _buildSlotRulesFromForm(),
              fillRules: _buildFillRulesFromForm(),
              qualificationConditions:
                  List<CareerQualificationCondition>.from(_qualificationConditions),
              fillRequiredCareerTags: _selectedFillTagNames.toList(),
              fillExcludedCareerTags: _selectedFillExcludedTagNames.toList(),
              fillRankingId: _fillRankingId,
              fillTopByRankingCount:
                  int.tryParse(_fillTopByRankingController.text.trim()) ?? 0,
              fillTopByAverageCount:
                  int.tryParse(_fillTopByAverageController.text.trim()) ?? 0,
              tagGate: tournamentTagGate,
              seriesGroupId: 'league-series-$seriesBatchId',
              seriesIndex: index + 1,
              seriesLength: totalSeriesLength,
              seriesStage: CareerLeagueSeriesStage.leagueMatchday,
              leagueSeriesQualificationMode: _leagueSeriesQualificationMode,
            );
          }
          for (var index = 0; index < playoffRoundCount; index += 1) {
            final absoluteRound = leagueMatchdayCount + index + 1;
              _repository.addCalendarItem(
                itemId: 'calendar-$seriesBatchId-playoff-$index',
                name: '$baseName - Playoff ${_playoffRoundLabel(index + 1, playoffRoundCount)}',
                tier: tier,
                game: _tournamentFormData.game,
              format: _tournamentFormData.format,
              fieldSize: fieldSize,
              matchMode: _tournamentFormData.matchMode,
              legsToWin: _tournamentFormData.effectiveLegsToWin,
              startScore: startScore,
              checkoutRequirement: _tournamentFormData.checkoutRequirement,
              prizePool: prizePool,
              knockoutPrizeValues: List<int>.from(_knockoutPrizeValues),
              leaguePositionPrizeValues: List<int>.from(_leaguePositionPrizeValues),
              setsToWin: _tournamentFormData.effectiveSetsToWin,
              legsPerSet: _tournamentFormData.effectiveLegsPerSet,
              roundDistanceValues:
                  _tournamentFormData.effectiveRoundDistanceValues,
              pointsForWin: _tournamentFormData.pointsForWin,
              pointsForDraw: _tournamentFormData.pointsForDraw,
              roundRobinRepeats: _tournamentFormData.roundRobinRepeats,
              playoffQualifierCount: _tournamentFormData.playoffQualifierCount,
              countsForRankingIds: _selectedRankingIds.toList(),
              seedingRankingId: _seedingRankingId,
              seedCount: _seedCount,
              slotRules: _buildSlotRulesFromForm(),
              fillRules: _buildFillRulesFromForm(),
              qualificationConditions:
                  List<CareerQualificationCondition>.from(_qualificationConditions),
              fillRequiredCareerTags: _selectedFillTagNames.toList(),
              fillExcludedCareerTags: _selectedFillExcludedTagNames.toList(),
              fillRankingId: _fillRankingId,
              fillTopByRankingCount:
                  int.tryParse(_fillTopByRankingController.text.trim()) ?? 0,
              fillTopByAverageCount:
                  int.tryParse(_fillTopByAverageController.text.trim()) ?? 0,
              tagGate: tournamentTagGate,
              seriesGroupId: 'league-series-$seriesBatchId',
              seriesIndex: absoluteRound,
              seriesLength: totalSeriesLength,
              seriesStage: CareerLeagueSeriesStage.playoffRound,
              leagueSeriesQualificationMode: _leagueSeriesQualificationMode,
            );
          }
        } else {
          for (var index = 0; index < seriesCount; index += 1) {
              _repository.addCalendarItem(
                itemId: 'calendar-$seriesBatchId-$index',
                name: seriesCount == 1 ? baseName : '$baseName ${index + 1}',
                tier: tier,
                game: _tournamentFormData.game,
              format: _tournamentFormData.format,
              fieldSize: fieldSize,
              matchMode: _tournamentFormData.matchMode,
              legsToWin: _tournamentFormData.effectiveLegsToWin,
              startScore: startScore,
              checkoutRequirement: _tournamentFormData.checkoutRequirement,
              prizePool: prizePool,
              knockoutPrizeValues: List<int>.from(_knockoutPrizeValues),
              leaguePositionPrizeValues: List<int>.from(_leaguePositionPrizeValues),
              setsToWin: _tournamentFormData.effectiveSetsToWin,
              legsPerSet: _tournamentFormData.effectiveLegsPerSet,
              roundDistanceValues:
                  _tournamentFormData.effectiveRoundDistanceValues,
              pointsForWin: _tournamentFormData.pointsForWin,
              pointsForDraw: _tournamentFormData.pointsForDraw,
              roundRobinRepeats: _tournamentFormData.roundRobinRepeats,
              playoffQualifierCount: _tournamentFormData.playoffQualifierCount,
              countsForRankingIds: _selectedRankingIds.toList(),
              seedingRankingId: _seedingRankingId,
              seedCount: _seedCount,
              slotRules: _buildSlotRulesFromForm(),
              fillRules: _buildFillRulesFromForm(),
              qualificationConditions:
                  List<CareerQualificationCondition>.from(_qualificationConditions),
              fillRequiredCareerTags: _selectedFillTagNames.toList(),
              fillExcludedCareerTags: _selectedFillExcludedTagNames.toList(),
              fillRankingId: _fillRankingId,
              fillTopByRankingCount:
                  int.tryParse(_fillTopByRankingController.text.trim()) ?? 0,
              fillTopByAverageCount:
                  int.tryParse(_fillTopByAverageController.text.trim()) ?? 0,
              tagGate: tournamentTagGate,
            );
          }
        }
      }

    final activeCareer = _repository.activeCareer;
    if (activeCareer != null) {
      _resetCalendarForm(activeCareer);
    }
  }

  void _beginEdit(CareerCalendarItem item) {
    _setSetupStep(_CareerSetupStep.turniere);
    _tournamentSubstep = _CareerTournamentSubstep.basics;
    _editingCalendarItemId = item.id;
    _selectedTournamentAccessPreset = _CareerTournamentAccessPreset.custom;
    _itemNameController.text = item.name;
    _tournamentFormData = TournamentFormData.fromCareerItem(item);
    _prizePoolController.text = item.prizePool.toString();
    _knockoutPrizeValues = List<int>.from(item.knockoutPrizeValues);
    _leaguePositionPrizeValues = List<int>.from(item.leaguePositionPrizeValues);
    _syncKnockoutPrizeValues();
    _syncLeaguePositionPrizeValues();
    _seedingRankingId = item.seedingRankingId;
    _seedCount = item.seedCount;
    _selectedRankingIds
      ..clear()
      ..addAll(item.countsForRankingIds);
    _qualificationConditions
      ..clear()
      ..addAll(
        item.effectiveSlotRules.map(_slotRuleToQualificationCondition),
      );
    final simpleCondition = _simpleQualificationCondition;
    _qualificationRankingId = simpleCondition?.rankingId;
    _qualificationFromController.text = '${simpleCondition?.fromRank ?? 1}';
    _qualificationToController.text = '${simpleCondition?.toRank ?? 16}';
    _selectedQualificationTagNames.clear();
      _selectedQualificationExcludedTagNames.clear();
      _selectedQualificationNationalities.clear();
      _selectedQualificationExcludedNationalities.clear();
      for (final condition in _qualificationConditions) {
        _selectedQualificationTagNames.addAll(condition.requiredCareerTags);
        _selectedQualificationExcludedTagNames
            .addAll(condition.excludedCareerTags);
        _selectedQualificationNationalities
            .addAll(condition.requiredNationalities);
        _selectedQualificationExcludedNationalities
            .addAll(condition.excludedNationalities);
      }
      CareerTournamentFillRule? rankingFillRule;
    CareerTournamentFillRule? averageFillRule;
    for (final rule in item.effectiveFillRules) {
      if (rankingFillRule == null &&
          rule.sourceType == CareerTournamentFillSourceType.ranking) {
        rankingFillRule = rule;
      }
      if (averageFillRule == null &&
          rule.sourceType == CareerTournamentFillSourceType.average) {
        averageFillRule = rule;
      }
    }
    final fillTags = <String>{
      ...?rankingFillRule?.requiredCareerTags,
      ...?averageFillRule?.requiredCareerTags,
    };
    final fillExcludedTags = <String>{
      ...?rankingFillRule?.excludedCareerTags,
      ...?averageFillRule?.excludedCareerTags,
    };
    _selectedFillTagNames
      ..clear()
      ..addAll(fillTags);
      _selectedFillExcludedTagNames
        ..clear()
        ..addAll(fillExcludedTags);
      final fillNationalities = <String>{
        ...?rankingFillRule?.requiredNationalities,
        ...?averageFillRule?.requiredNationalities,
      };
      final fillExcludedNationalities = <String>{
        ...?rankingFillRule?.excludedNationalities,
        ...?averageFillRule?.excludedNationalities,
      };
      _selectedFillNationalities
        ..clear()
        ..addAll(fillNationalities);
      _selectedFillExcludedNationalities
        ..clear()
        ..addAll(fillExcludedNationalities);
    _fillRankingId = rankingFillRule?.rankingId;
    _fillTopByRankingController.text =
        rankingFillRule != null && rankingFillRule.maxCount > 0
        ? rankingFillRule.maxCount.toString()
        : '';
    _fillTopByAverageController.text =
        averageFillRule != null && averageFillRule.maxCount > 0
        ? averageFillRule.maxCount.toString()
        : '';
    _fillAutoGeneratePlayers = averageFillRule?.autoGeneratePlayers ?? false;
    _generatedFillAgeDistributions
      ..clear()
      ..addAll(averageFillRule?.generatedAgeDistributions ?? const <CareerGeneratedAgeDistribution>[]);
    _generatedFillNationalityDistributions
      ..clear()
      ..addAll(
        averageFillRule?.generatedNationalityDistributions ??
            const <CareerGeneratedNationalityDistribution>[],
      );
    _selectedTournamentTagGateTagName = item.tagGate?.tagName;
    _tournamentTagGateMinimumController.text =
        item.tagGate?.minimumPlayerCount.toString() ?? '';
    _tournamentOccursWhenTagGateMet =
        item.tagGate?.tournamentOccursWhenMet ?? true;
    _editingSeriesGroupId = item.seriesGroupId;
    _editingSeriesIndex = item.seriesIndex;
    _editingSeriesLength = item.seriesLength;
    _editingSeriesStage = item.seriesStage;
    _expandLeagueIntoMatchdays = item.isLeagueSeriesItem;
    _leagueSeriesQualificationMode = item.leagueSeriesQualificationMode;
    setState(() {});
  }

  void _resetCalendarForm(CareerDefinition career) {
    _editingCalendarItemId = null;
    _selectedTournamentAccessPreset = _CareerTournamentAccessPreset.custom;
    _itemNameController.clear();
    _tournamentFormData = const TournamentFormData();
    _prizePoolController.text = '12500';
    _seriesCountController.text = '1';
    _createAsSeries = false;
    _expandLeagueIntoMatchdays = false;
    _leagueSeriesQualificationMode =
        CareerLeagueSeriesQualificationMode.fixedAtStart;
    _editingSeriesGroupId = null;
    _editingSeriesIndex = null;
    _editingSeriesLength = null;
    _editingSeriesStage = null;
    _knockoutPrizeValues = <int>[];
    _leaguePositionPrizeValues = <int>[];
    _syncKnockoutPrizeValues();
    _syncLeaguePositionPrizeValues();
    _seedCount = 0;
    _seedingRankingId = null;
    _qualificationRankingId = null;
    _selectedRankingIds.clear();
    _qualificationConditions.clear();
      _selectedQualificationTagNames.clear();
      _selectedQualificationExcludedTagNames.clear();
      _selectedQualificationNationalities.clear();
      _selectedQualificationExcludedNationalities.clear();
    _qualificationEntryRoundController.text = '1';
    _qualificationFromController.text = '1';
    _qualificationToController.text = '16';
    _qualificationSlotCountController.clear();
      _selectedFillTagNames.clear();
      _selectedFillExcludedTagNames.clear();
      _selectedFillNationalities.clear();
      _selectedFillExcludedNationalities.clear();
    _fillRankingId = null;
    _fillTopByRankingController.clear();
    _fillTopByAverageController.clear();
    _selectedTournamentTagGateTagName = career.careerTagDefinitions.isEmpty
        ? null
        : career.careerTagDefinitions.first.name;
    _tournamentTagGateMinimumController.clear();
    _tournamentOccursWhenTagGateMet = true;
    setState(() {});
  }

  void _saveCurrentCareerAsTemplate(CareerDefinition career) {
    _templateRepository.saveTemplate(
      name: _templateNameController.text.isEmpty
          ? '${career.name} Vorlage'
          : _templateNameController.text,
      careerTagDefinitions:
          List<CareerTagDefinition>.from(career.careerTagDefinitions),
      seasonTagRules: List<CareerSeasonTagRule>.from(career.seasonTagRules),
      rankings: List<CareerRankingDefinition>.from(career.rankings),
      calendar: List<CareerCalendarItem>.from(career.currentSeason.calendar),
    );
    _templateNameController.clear();
    setState(() {});
  }

  void _addQualificationCondition(CareerDefinition career) {
    if (_qualificationConditionType ==
            CareerQualificationConditionType.rankingRange &&
        career.rankings.isEmpty) {
      return;
    }
    final rankingId = _qualificationConditionType ==
            CareerQualificationConditionType.rankingRange
        ? (_qualificationRankingId ?? career.rankings.first.id)
        : null;
    final fromRank = int.tryParse(_qualificationFromController.text) ?? 1;
    final toRank = int.tryParse(_qualificationToController.text) ?? fromRank;
    final entryRound = int.tryParse(_qualificationEntryRoundController.text) ?? 1;
    final slotCount =
        int.tryParse(_qualificationSlotCountController.text.trim());
    final requiredTags = _qualificationConditionType ==
            CareerQualificationConditionType.careerTagOnly
        ? _selectedQualificationTagNames.take(1).toList()
        : List<String>.from(_selectedQualificationTagNames);
    final requiredNationalities = _qualificationConditionType ==
            CareerQualificationConditionType.careerTagOnly
        ? _selectedQualificationNationalities.take(1).toList()
        : List<String>.from(_selectedQualificationNationalities);
    if (_qualificationConditionType ==
            CareerQualificationConditionType.careerTagOnly &&
        requiredTags.isEmpty &&
        requiredNationalities.isEmpty) {
      return;
    }
    setState(() {
      _qualificationConditions.add(
        CareerQualificationCondition(
          type: _qualificationConditionType,
          rankingId: rankingId,
          entryRound: entryRound < 1 ? 1 : entryRound,
          slotCount: slotCount == null || slotCount <= 0 ? null : slotCount,
          fromRank: _qualificationConditionType ==
                  CareerQualificationConditionType.rankingRange
              ? fromRank
              : 1,
          toRank: _qualificationConditionType ==
                  CareerQualificationConditionType.rankingRange
              ? toRank
              : 1,
          requiredCareerTags: requiredTags,
          requiredNationalities: requiredNationalities,
          excludedCareerTags:
              List<String>.from(_selectedQualificationExcludedTagNames),
          excludedNationalities:
              List<String>.from(_selectedQualificationExcludedNationalities),
        ),
      );
    });
  }

  List<CareerTournamentSlotRule> _buildSlotRulesFromForm() {
    return _qualificationConditions.asMap().entries.map((entry) {
      return CareerTournamentSlotRule.fromLegacyCondition(
        entry.value,
        entry.key,
      ).copyWith(id: 'editor-slot-${entry.key}');
    }).toList();
  }

  List<CareerTournamentFillRule> _buildFillRulesFromForm() {
    final rules = <CareerTournamentFillRule>[];
    final rankingCount =
        int.tryParse(_fillTopByRankingController.text.trim()) ?? 0;
    final averageCount =
        int.tryParse(_fillTopByAverageController.text.trim()) ?? 0;
    final requiredTags = _selectedFillTagNames.toList();
    final excludedTags = _selectedFillExcludedTagNames.toList();
    final requiredNationalities = _selectedFillNationalities.toList();
    final excludedNationalities =
        _selectedFillExcludedNationalities.toList();
    final generatedAgeDistributions = _generatedFillAgeDistributions
        .where(
          (entry) =>
              entry.percent > 0 &&
              entry.minAge > 0 &&
              entry.maxAge >= entry.minAge,
        )
        .toList();
    final generatedNationalityDistributions =
        _generatedFillNationalityDistributions
            .where(
              (entry) => entry.percent > 0 && entry.nationality.trim().isNotEmpty,
            )
            .toList();

    if (_fillRankingId != null) {
      rules.add(
        CareerTournamentFillRule(
          id: 'editor-fill-ranking',
          sourceType: CareerTournamentFillSourceType.ranking,
          rankingId: _fillRankingId,
          requiredCareerTags: requiredTags,
          excludedCareerTags: excludedTags,
          requiredNationalities: requiredNationalities,
          excludedNationalities: excludedNationalities,
          maxCount: rankingCount < 0 ? 0 : rankingCount,
        ),
      );
    }

    if (averageCount > 0 ||
        requiredTags.isNotEmpty ||
        excludedTags.isNotEmpty ||
        requiredNationalities.isNotEmpty ||
        excludedNationalities.isNotEmpty ||
        _fillRankingId == null) {
      rules.add(
        CareerTournamentFillRule(
          id: 'editor-fill-average',
          sourceType: CareerTournamentFillSourceType.average,
          requiredCareerTags: requiredTags,
          excludedCareerTags: excludedTags,
          requiredNationalities: requiredNationalities,
          excludedNationalities: excludedNationalities,
          maxCount: averageCount < 0 ? 0 : averageCount,
          autoGeneratePlayers: _fillAutoGeneratePlayers,
          generatedAgeDistributions: generatedAgeDistributions,
          generatedNationalityDistributions: generatedNationalityDistributions,
        ),
      );
    }

    return rules;
  }

  CareerQualificationCondition _slotRuleToQualificationCondition(
    CareerTournamentSlotRule rule,
  ) {
    return CareerQualificationCondition(
      rankingId: rule.rankingId,
      fromRank: rule.fromRank,
      toRank: rule.toRank,
      entryRound: rule.entryRound,
      slotCount: rule.slotCount,
      type: rule.sourceType == CareerTournamentSlotSourceType.careerTag
          ? CareerQualificationConditionType.careerTagOnly
          : CareerQualificationConditionType.rankingRange,
      requiredCareerTags: List<String>.from(rule.requiredCareerTags),
      excludedCareerTags: List<String>.from(rule.excludedCareerTags),
      requiredNationalities: List<String>.from(rule.requiredNationalities),
      excludedNationalities: List<String>.from(rule.excludedNationalities),
    );
  }

  Future<void> _editCareerDatabasePlayer(CareerDatabasePlayer player) async {
    final controller = TextEditingController(
      text: player.careerTags.map((entry) => entry.tagName).join(', '),
    );
    final selectedTags = player.careerTags.map((entry) => entry.tagName).toSet();
    final career = _repository.activeCareer;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(player.name),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (career != null &&
                        career.careerTagDefinitions.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: career.careerTagDefinitions.map((definition) {
                          final usageCount =
                              _careerTagUsageCount(career, definition.name);
                          final limitSuffix = definition.playerLimit == null
                              ? ''
                              : ' $usageCount/${definition.playerLimit}';
                          return FilterChip(
                            label: Text('${definition.name}$limitSuffix'),
                            selected: selectedTags.contains(definition.name),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedTags.add(definition.name);
                                } else {
                                  selectedTags.remove(definition.name);
                                }
                                controller.text = selectedTags.join(', ');
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (player.careerTags.isNotEmpty) ...<Widget>[
                      Text(
                        'Aktuelle Laufzeiten',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: player.careerTags
                            .map(
                              (tag) => InputChip(
                                label: Text(_careerTagAssignmentLabel(tag)),
                                onDeleted: () {
                                  setDialogState(() {
                                    selectedTags.remove(tag.tagName);
                                    controller.text = selectedTags.join(', ');
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Karriere-Tags',
                        helperText: 'Kommagetrennt eingeben',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    _repository.updateDatabasePlayer(
      player: player.copyWith(
        careerTags: _parseCareerTags(result),
      ),
    );
    setState(() {});
  }

  void _removeCareerTagFromPlayer({
    required CareerDatabasePlayer player,
    required String tagName,
  }) {
    _repository.updateDatabasePlayer(
      player: player.copyWith(
        careerTags: player.careerTags
            .where((entry) => entry.tagName != tagName)
            .toList(),
      ),
    );
    setState(() {});
  }

  void _syncCareerContext(CareerDefinition? activeCareer) {
    if (activeCareer == null) {
      _lastCareerId = null;
      return;
    }

    if (_lastCareerId != activeCareer.id) {
      _lastCareerId = activeCareer.id;
      _careerNameController.text = activeCareer.name;
      _participantMode = activeCareer.participantMode;
      _selectedPlayerProfileId = activeCareer.playerProfileId;
      _replaceWeakestPlayerWithHuman = activeCareer.replaceWeakestPlayerWithHuman;
      _applyCareerDefaults(activeCareer);
      return;
    }

    final validRankingIds = activeCareer.rankings.map((entry) => entry.id).toSet();
    _selectedRankingIds.removeWhere((entry) => !validRankingIds.contains(entry));
    final usedDatabasePlayerIds = activeCareer.databasePlayers
        .map((entry) => entry.databasePlayerId)
        .toSet();
    _selectedDatabasePlayerIds.removeWhere(
      (entry) => usedDatabasePlayerIds.contains(entry),
    );
    if (_seedingRankingId != null &&
        !validRankingIds.contains(_seedingRankingId)) {
      _seedingRankingId = null;
    }
    if (_qualificationRankingId == null ||
        !validRankingIds.contains(_qualificationRankingId)) {
      _qualificationRankingId = null;
    }
    if (_fillRankingId != null && !validRankingIds.contains(_fillRankingId)) {
      _fillRankingId = null;
    }
    _qualificationConditions.removeWhere(
      (condition) =>
          condition.type == CareerQualificationConditionType.rankingRange &&
          (condition.rankingId == null ||
              !validRankingIds.contains(condition.rankingId)),
    );
    final validCareerTags = activeCareer.careerTagDefinitions
        .map((entry) => entry.name)
        .toSet();
    if (_selectedTrainingPoolTagName != null &&
        !validCareerTags.contains(_selectedTrainingPoolTagName)) {
      _selectedTrainingPoolTagName = null;
    }
    for (var index = 0; index < _qualificationConditions.length; index += 1) {
      _qualificationConditions[index] = _qualificationConditions[index].copyWith(
        requiredCareerTags: _qualificationConditions[index]
            .requiredCareerTags
            .where((entry) => validCareerTags.contains(entry))
            .toList(),
        excludedCareerTags: _qualificationConditions[index]
            .excludedCareerTags
            .where((entry) => validCareerTags.contains(entry))
            .toList(),
      );
    }
      _selectedQualificationTagNames.removeWhere(
        (entry) => !validCareerTags.contains(entry),
      );
      _selectedQualificationExcludedTagNames.removeWhere(
        (entry) => !validCareerTags.contains(entry),
    );
    _selectedFillTagNames.removeWhere(
      (entry) => !validCareerTags.contains(entry),
    );
      _selectedFillExcludedTagNames.removeWhere(
        (entry) => !validCareerTags.contains(entry),
      );
      final validNationalities = _availableCareerNationalities(activeCareer).toSet();
      for (var index = 0; index < _qualificationConditions.length; index += 1) {
        _qualificationConditions[index] = _qualificationConditions[index].copyWith(
          requiredNationalities: _qualificationConditions[index]
              .requiredNationalities
              .where((entry) => validNationalities.contains(entry))
              .toList(),
          excludedNationalities: _qualificationConditions[index]
              .excludedNationalities
              .where((entry) => validNationalities.contains(entry))
              .toList(),
        );
      }
      _selectedQualificationNationalities.removeWhere(
        (entry) => !validNationalities.contains(entry),
      );
      _selectedQualificationExcludedNationalities.removeWhere(
        (entry) => !validNationalities.contains(entry),
      );
      _selectedFillNationalities.removeWhere(
        (entry) => !validNationalities.contains(entry),
      );
      _selectedFillExcludedNationalities.removeWhere(
        (entry) => !validNationalities.contains(entry),
      );
    if (_selectedSeasonTagRuleTagName != null &&
        !validCareerTags.contains(_selectedSeasonTagRuleTagName)) {
      _selectedSeasonTagRuleTagName =
          activeCareer.careerTagDefinitions.isEmpty
              ? null
              : activeCareer.careerTagDefinitions.first.name;
    }
    if (_selectedSeasonTagRuleCheckTagName != null &&
        !validCareerTags.contains(_selectedSeasonTagRuleCheckTagName)) {
      _selectedSeasonTagRuleCheckTagName =
          activeCareer.careerTagDefinitions.isEmpty
              ? null
              : activeCareer.careerTagDefinitions.first.name;
    }
    if (_selectedTournamentTagGateTagName != null &&
        !validCareerTags.contains(_selectedTournamentTagGateTagName)) {
      _selectedTournamentTagGateTagName =
          activeCareer.careerTagDefinitions.isEmpty
              ? null
              : activeCareer.careerTagDefinitions.first.name;
    }
    _syncLeaguePositionPrizeValues();
  }

  void _applyCareerDefaults(CareerDefinition career) {
    _editingCalendarItemId = null;
    _selectedCareerStructurePreset = _CareerStructurePreset.custom;
    _selectedTournamentAccessPreset = _CareerTournamentAccessPreset.custom;
    _selectedRankingIds.clear();
    _seedingRankingId = null;
    _qualificationRankingId = null;
      _qualificationConditions.clear();
      _selectedQualificationTagNames.clear();
      _selectedQualificationExcludedTagNames.clear();
      _selectedQualificationNationalities.clear();
      _selectedQualificationExcludedNationalities.clear();
        _selectedFillTagNames.clear();
        _selectedFillExcludedTagNames.clear();
        _selectedFillNationalities.clear();
        _selectedFillExcludedNationalities.clear();
        _fillTopByAverageController.clear();
        _fillAutoGeneratePlayers = false;
      _generatedFillAgeDistributions.clear();
      _generatedFillNationalityDistributions.clear();
      _selectedTrainingPoolTagName = null;
      _isTrainingModeExpanded = false;
      _trainingMinAverageController.clear();
      _trainingMaxAverageController.clear();
    _itemNameController.clear();
    _tournamentFormData = const TournamentFormData();
    _prizePoolController.text = '12500';
    _seriesCountController.text = '1';
    _createAsSeries = false;
    _knockoutPrizeValues = <int>[];
    _leaguePositionPrizeValues = <int>[];
    _syncKnockoutPrizeValues();
    _syncLeaguePositionPrizeValues();
    _seedCount = 0;
    _selectedPlayerProfileId =
        career.playerProfileId ?? _playerRepository.activePlayer?.id;
    final takenIds = career.databasePlayers
        .map((entry) => entry.databasePlayerId)
        .toSet();
    String? nextDatabasePlayerId;
    for (final player in _computerRepository.players) {
      if (!takenIds.contains(player.id)) {
        nextDatabasePlayerId = player.id;
        break;
      }
    }
    _selectedDatabasePlayerId = nextDatabasePlayerId;
    _selectedDatabasePlayerIds.clear();
    _selectedCareerRosterPlayerIds.clear();
    _selectedDatabaseTagFilters.clear();
    _databasePlayerTagsController.clear();
    _careerRosterTagsController.clear();
    _resetCareerTagForm();
    _resetRankingForm();
    _resetSeasonTagRuleForm(career);
  }

  String _playerName(String playerId) {
    return _playerRepository.playerById(playerId)?.name ?? playerId;
  }

  bool get _usesKnockoutPrizeSetup {
    return _tournamentFormData.format == TournamentFormat.knockout ||
        _tournamentFormData.format == TournamentFormat.leaguePlayoff;
  }

  bool get _usesLeaguePositionPrizeSetup {
    return _tournamentFormData.format == TournamentFormat.league ||
        _tournamentFormData.format == TournamentFormat.leaguePlayoff;
  }

  void _syncKnockoutPrizeValues() {
    if (!_usesKnockoutPrizeSetup) {
      _knockoutPrizeValues = <int>[];
      return;
    }
    final neededLength = _tournamentFormData.roundCount + 1;
    if (neededLength <= 0) {
      _knockoutPrizeValues = <int>[];
      return;
    }
    final next = List<int>.from(_knockoutPrizeValues);
    while (next.length < neededLength) {
      next.add(0);
    }
    if (next.length > neededLength) {
      next.removeRange(neededLength, next.length);
    }
    _knockoutPrizeValues = next;
  }

  void _syncLeaguePositionPrizeValues() {
    if (!_usesLeaguePositionPrizeSetup) {
      _leaguePositionPrizeValues = <int>[];
      return;
    }
    final neededLength = (_tournamentFormData.parsedFieldSize ?? 0).clamp(0, 128);
    if (neededLength <= 0) {
      _leaguePositionPrizeValues = <int>[];
      return;
    }
    final next = List<int>.from(_leaguePositionPrizeValues);
    while (next.length < neededLength) {
      next.add(0);
    }
    if (next.length > neededLength) {
      next.removeRange(neededLength, next.length);
    }
    _leaguePositionPrizeValues = next;
  }

  void _applyKnockoutPrizeSplitPreset() {
    if (!_usesKnockoutPrizeSetup || _knockoutPrizeValues.isEmpty) {
      return;
    }
    final targetTotal = int.tryParse(_prizePoolController.text.trim()) ?? 0;
    if (targetTotal <= 0) {
      return;
    }
    final targetKnockoutPool =
        (targetTotal - _calculatedLeaguePrizePool()).clamp(0, targetTotal);
    if (targetKnockoutPool <= 0) {
      return;
    }
    final stageCount = _knockoutPrizeValues.length;
    final loserCounts = _knockoutLoserCounts();
    if (stageCount == 0 || loserCounts.length != stageCount - 1) {
      return;
    }

    final stageShares = _stageSharesForPreset(
      _selectedPrizeSplitPreset,
      stageCount,
    );
    final nextValues = List<int>.filled(stageCount, 0);
    for (var index = 0; index < stageCount - 1; index += 1) {
      final loserCount = loserCounts[index];
      if (loserCount <= 0) {
        nextValues[index] = 0;
        continue;
      }
      final stageTotal = (targetKnockoutPool * stageShares[index]).round();
      nextValues[index] = (stageTotal / loserCount).round();
    }
    nextValues[stageCount - 1] =
        (targetKnockoutPool * stageShares[stageCount - 1]).round();

    final adjustedDifference =
        targetKnockoutPool - _calculatedKnockoutPrizePoolForValues(nextValues);
    nextValues[stageCount - 1] =
        (nextValues[stageCount - 1] + adjustedDifference).clamp(0, 1 << 30);
    _knockoutPrizeValues = nextValues;
  }

  List<double> _stageSharesForPreset(
    CareerTournamentPrizeSplitPreset preset,
    int stageCount,
  ) {
    final baseShares = switch (preset) {
      CareerTournamentPrizeSplitPreset.proTour => <double>[
          0.213333,
          0.213333,
          0.16,
          0.12,
          0.08,
          0.08,
          0.133334,
        ],
      CareerTournamentPrizeSplitPreset.major => <double>[
          0.20,
          0.15,
          0.15,
          0.125,
          0.125,
          0.25,
        ],
      CareerTournamentPrizeSplitPreset.development => <double>[
          0.16,
          0.16,
          0.16,
          0.12,
          0.10,
          0.10,
          0.20,
        ],
    };
    final rawShares = stageCount <= baseShares.length
        ? List<double>.from(
            baseShares.sublist(baseShares.length - stageCount),
          )
        : (List<double>.filled(
            stageCount - baseShares.length,
            baseShares.first,
            growable: true,
          )
          ..addAll(baseShares));
    final total = rawShares.fold<double>(0, (sum, entry) => sum + entry);
    if (total <= 0) {
      return List<double>.filled(stageCount, 1 / stageCount);
    }
    return rawShares.map((entry) => entry / total).toList();
  }

  int _calculatedKnockoutPrizePoolForValues(List<int> values) {
    if (values.isEmpty) {
      return 0;
    }
    final loserCounts = _knockoutLoserCounts();
    var total = values.last;
    for (var index = 0;
        index < values.length - 1 && index < loserCounts.length;
        index += 1) {
      total += loserCounts[index] * values[index];
    }
    return total;
  }

  String _knockoutPrizeLabel(int index) {
    if (index == _knockoutPrizeValues.length - 1) {
      return 'Sieger';
    }
    if (index == _knockoutPrizeValues.length - 2) {
      return 'Finalverlierer';
    }
    if (index == _knockoutPrizeValues.length - 3) {
      return 'Halbfinalverlierer';
    }
    if (index == _knockoutPrizeValues.length - 4) {
      return 'Viertelfinalverlierer';
    }
    return 'Runde ${index + 1} Verlierer';
  }

  int _calculatedKnockoutPrizePool() {
    if (_knockoutPrizeValues.isEmpty) {
      return 0;
    }
    final loserCounts = _knockoutLoserCounts();
    var total = _knockoutPrizeValues.last;
    for (var index = 0;
        index < _knockoutPrizeValues.length - 1 &&
            index < loserCounts.length;
        index += 1) {
      total += loserCounts[index] * _knockoutPrizeValues[index];
    }
    return total;
  }

  int _calculatedLeaguePrizePool() {
    var total = 0;
    for (final payout in _leaguePositionPrizeValues) {
      total += payout;
    }
    return total;
  }

  int _calculatedPrizePool() {
    if (!_usesKnockoutPrizeSetup && !_usesLeaguePositionPrizeSetup) {
      return int.tryParse(_prizePoolController.text) ?? 0;
    }
    return _calculatedKnockoutPrizePool() + _calculatedLeaguePrizePool();
  }

  String? _prizePoolHelperText() {
    if (!_usesKnockoutPrizeSetup) {
      return null;
    }
    if (_tournamentFormData.format == TournamentFormat.leaguePlayoff) {
      return 'Das Gesamtpreisgeld beruecksichtigt die Liga-Auszahlungen und die tatsaechlichen Playoff-Runden.';
    }
    final totalEntrants = _tournamentFormData.parsedFieldSize ?? 0;
    if (totalEntrants <= 0) {
      return null;
    }
    final slotRules = _buildSlotRulesFromForm();
    final laterEntryRules = slotRules.where((rule) => rule.entryRound > 1).toList();
    if (laterEntryRules.isEmpty) {
      return 'Das Gesamtpreisgeld basiert auf den tatsaechlich gespielten KO-Runden dieses Feldes.';
    }
    final laterEntrants = laterEntryRules.fold<int>(
      0,
      (sum, rule) => sum + rule.slotCount,
    );
    return 'Das Gesamtpreisgeld beruecksichtigt spaete Einstiege: $laterEntrants Spieler greifen erst ab spaeteren Runden ein.';
  }

  int _knockoutBracketSize() {
    final entrants = _tournamentFormData.format == TournamentFormat.leaguePlayoff
        ? _tournamentFormData.playoffQualifierCount
        : (_tournamentFormData.parsedFieldSize ?? 2);
    var size = 2;
    while (size < entrants) {
      size *= 2;
    }
    return size;
  }

  List<int> _knockoutLoserCounts() {
    if (!_usesKnockoutPrizeSetup) {
      return const <int>[];
    }
    final totalEntrants = _tournamentFormData.format == TournamentFormat.leaguePlayoff
        ? _tournamentFormData.playoffQualifierCount
        : (_tournamentFormData.parsedFieldSize ?? 0);
    if (totalEntrants <= 1) {
      return const <int>[];
    }

    final bracketSize = _knockoutBracketSize();
    final roundCount = _tournamentFormData.roundCount;
    final entriesByRound = List<int>.filled(roundCount, 0);

    if (_tournamentFormData.format == TournamentFormat.knockout) {
      final slotRules = _buildSlotRulesFromForm();
      var fixedEntrants = 0;
      for (final rule in slotRules) {
        final roundIndex = (rule.entryRound < 1 ? 1 : rule.entryRound) - 1;
        if (roundIndex >= entriesByRound.length) {
          continue;
        }
        entriesByRound[roundIndex] += rule.slotCount;
        fixedEntrants += rule.slotCount;
      }
      final remainingEntrants = totalEntrants - fixedEntrants;
      if (entriesByRound.isNotEmpty && remainingEntrants > 0) {
        entriesByRound[0] += remainingEntrants;
      }
    } else if (entriesByRound.isNotEmpty) {
      entriesByRound[0] = totalEntrants;
    }

    final losers = <int>[];
    var survivors = 0;
    for (var roundIndex = 0; roundIndex < roundCount; roundIndex += 1) {
      final currentParticipants = survivors + entriesByRound[roundIndex];
      final capacityAfterRound = bracketSize ~/ (1 << (roundIndex + 1));
      final roundLosers = currentParticipants > capacityAfterRound
          ? currentParticipants - capacityAfterRound
          : 0;
      losers.add(roundLosers);
      survivors = currentParticipants - roundLosers;
    }
    return losers;
  }

  int _knockoutRoundEntryCapacity({
    required int fieldSize,
    required int entryRound,
  }) {
    final normalizedRound = entryRound < 1 ? 1 : entryRound;
    var size = 2;
    while (size < fieldSize) {
      size *= 2;
    }
    return size ~/ (1 << (normalizedRound - 1));
  }

  int _leagueMatchdayCount({
    required int fieldSize,
    required int repeats,
  }) {
    final normalizedFieldSize = fieldSize < 2 ? 2 : fieldSize;
    final roundsPerCycle =
        normalizedFieldSize.isEven ? normalizedFieldSize - 1 : normalizedFieldSize;
    return roundsPerCycle * (repeats < 1 ? 1 : repeats);
  }

  int _playoffRoundCount(int qualifierCount) {
    var entrants = qualifierCount < 2 ? 2 : qualifierCount;
    var bracketSize = 2;
    while (bracketSize < entrants) {
      bracketSize *= 2;
    }
    var rounds = 0;
    while (bracketSize > 1) {
      rounds += 1;
      bracketSize ~/= 2;
    }
    return rounds;
  }

  String _playoffRoundLabel(int roundNumber, int totalRounds) {
    final remainingRounds = totalRounds - roundNumber;
    if (remainingRounds <= 0) {
      return 'Finale';
    }
    if (remainingRounds == 1) {
      return 'Halbfinale';
    }
    if (remainingRounds == 2) {
      return 'Viertelfinale';
    }
    return 'Runde $roundNumber';
  }

  String _qualificationConditionLabel(
    CareerQualificationCondition condition,
    String rankingName,
  ) {
    final baseLabel =
        condition.type == CareerQualificationConditionType.careerTagOnly
            ? 'Nur Karriere-Tag'
            : '$rankingName ${condition.fromRank}-${condition.toRank}';
    final slotLabel = condition.slotCount != null
        ? ' | Slots ${condition.slotCount}'
        : '';
    final roundLabel = ' | Einstieg Runde ${condition.entryRound}';
    final requiredLabel = condition.requiredCareerTags.isEmpty
        ? ''
        : ' | Tags ${condition.requiredCareerTags.join(', ')}';
    final excludedLabel = condition.excludedCareerTags.isEmpty
        ? ''
        : ' | Ohne ${condition.excludedCareerTags.join(', ')}';
    final requiredNationalityLabel = condition.requiredNationalities.isEmpty
        ? ''
        : ' | Nation ${condition.requiredNationalities.join(', ')}';
    final excludedNationalityLabel = condition.excludedNationalities.isEmpty
        ? ''
        : ' | Ohne Nation ${condition.excludedNationalities.join(', ')}';
      return '$baseLabel$slotLabel$roundLabel$requiredLabel$excludedLabel$requiredNationalityLabel$excludedNationalityLabel';
    }

  List<CareerPlayerTag> _parseCareerTags(String rawValue) {
    return _parseTagNames(rawValue)
        .map((entry) => CareerPlayerTag(tagName: entry))
        .toList();
  }

  List<String> _parseTagNames(String rawValue) {
    final seen = <String>{};
    return rawValue
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .where((entry) => seen.add(entry))
        .toList();
  }

  List<CareerTagAttribute> _parseCareerTagAttributes(String rawValue) {
    final result = <CareerTagAttribute>[];
    final seen = <String>{};
    for (final part in rawValue.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final separatorIndex = trimmed.indexOf('=');
      if (separatorIndex <= 0 || separatorIndex >= trimmed.length - 1) {
        continue;
      }
      final key = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (key.isEmpty || value.isEmpty || !seen.add(key)) {
        continue;
      }
      result.add(CareerTagAttribute(key: key, value: value));
    }
    return result;
  }

  int _careerTagUsageCount(CareerDefinition career, String tagName) {
    var count = 0;
    for (final player in career.databasePlayers) {
      if (player.careerTags.any((entry) => entry.tagName == tagName)) {
        count += 1;
      }
    }
    return count;
  }

  String _careerTagAssignmentLabel(CareerPlayerTag tag) {
    if (tag.remainingSeasons == null) {
      return '${tag.tagName} (dauerhaft)';
    }
    if (tag.remainingSeasons == 1) {
      return '${tag.tagName} (noch 1 Saison)';
    }
    return '${tag.tagName} (noch ${tag.remainingSeasons} Saisons)';
  }

  void _beginEditCareerTagDefinition(CareerTagDefinition definition) {
    _editingCareerTagId = definition.id;
    _careerTagNameController.text = definition.name;
    _careerTagAttributesController.text = definition.attributes
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
    _careerTagLimitController.text = definition.playerLimit?.toString() ?? '';
    _careerTagInitialValidityController.text =
        definition.initialValiditySeasons?.toString() ?? '';
    _careerTagExtensionValidityController.text =
        definition.extensionValiditySeasons?.toString() ?? '';
    _careerTagAddOnExpiryController.text =
        definition.tagsToAddOnExpiry.join(', ');
    _careerTagRemoveOnInitialController.text =
        definition.tagsToRemoveOnInitialAssignment.join(', ');
    _careerTagRemoveOnExtensionController.text =
        definition.tagsToRemoveOnExtension.join(', ');
    setState(() {});
  }

  void _beginEditSeasonTagRule(CareerSeasonTagRule rule) {
    _editingSeasonTagRuleId = rule.id;
    _selectedSeasonTagRuleTagName = rule.tagName;
    _selectedSeasonTagRuleRankingId = rule.rankingId;
    _seasonTagRuleAction = rule.action;
    _seasonTagRuleRankMode = rule.rankMode;
    _seasonTagRuleCheckMode = rule.checkMode;
    _selectedSeasonTagRuleCheckTagName = rule.checkTagName;
    _seasonTagRuleFromController.text = rule.fromRank.toString();
    _seasonTagRuleToController.text = rule.toRank.toString();
    _seasonTagRuleReferenceRankController.text =
        rule.referenceRank?.toString() ?? '';
    _seasonTagRuleCheckRemainingController.text =
        rule.checkRemainingSeasons?.toString() ?? '';
    setState(() {});
  }

  void _beginEditRanking(CareerRankingDefinition ranking) {
      _editingRankingId = ranking.id;
      _rankingNameController.text = ranking.name;
    _rankingValidSeasons = ranking.validSeasons;
    _rankingValidSeasonsController.text = '${ranking.validSeasons}';
    _rankingResetAtSeasonEnd = ranking.resetAtSeasonEnd;
    setState(() {});
  }

  void _resetCareerTagForm() {
    _editingCareerTagId = null;
    _careerTagNameController.clear();
    _careerTagAttributesController.clear();
    _careerTagLimitController.clear();
    _careerTagInitialValidityController.clear();
    _careerTagExtensionValidityController.clear();
    _careerTagAddOnExpiryController.clear();
    _careerTagRemoveOnInitialController.clear();
    _careerTagRemoveOnExtensionController.clear();
  }

  void _resetSeasonTagRuleForm(CareerDefinition career) {
    _editingSeasonTagRuleId = null;
    _selectedSeasonTagRuleTagName = career.careerTagDefinitions.isEmpty
        ? null
        : career.careerTagDefinitions.first.name;
    _selectedSeasonTagRuleRankingId = career.rankings.isEmpty
        ? null
        : career.rankings.first.id;
    _seasonTagRuleAction = CareerSeasonTagRuleAction.add;
    _seasonTagRuleRankMode = CareerSeasonTagRuleRankMode.range;
    _seasonTagRuleCheckMode = CareerSeasonTagRuleCheckMode.none;
    _selectedSeasonTagRuleCheckTagName = career.careerTagDefinitions.isEmpty
        ? null
        : career.careerTagDefinitions.first.name;
    _seasonTagRuleFromController.text = '1';
    _seasonTagRuleToController.text = '1';
    _seasonTagRuleReferenceRankController.clear();
    _seasonTagRuleCheckRemainingController.clear();
  }

  void _resetRankingForm() {
    _editingRankingId = null;
    _rankingNameController.clear();
    _rankingValidSeasons = 1;
    _rankingValidSeasonsController.text = '1';
    _rankingResetAtSeasonEnd = false;
  }

  void _toggleAssignmentCareerTag(String tagName) {
    final tags = _parseCareerTags(
      _databasePlayerTagsController.text,
    ).map((entry) => entry.tagName).toSet();
    if (tags.contains(tagName)) {
      tags.remove(tagName);
    } else {
      tags.add(tagName);
    }
    _databasePlayerTagsController.text = tags.join(', ');
    setState(() {});
  }

  void _removeRanking(String rankingId) {
    _repository.removeRanking(rankingId);
    final activeCareer = _repository.activeCareer;
    if (activeCareer == null) {
      return;
    }
    final validRankingIds = activeCareer.rankings.map((entry) => entry.id).toSet();
    _selectedRankingIds.remove(rankingId);
    if (!validRankingIds.contains(_seedingRankingId)) {
      _seedingRankingId = null;
    }
    if (!validRankingIds.contains(_qualificationRankingId)) {
      _qualificationRankingId = null;
    }
    if (!validRankingIds.contains(_fillRankingId)) {
      _fillRankingId = null;
    }
    _qualificationConditions.removeWhere(
      (condition) => condition.rankingId == rankingId,
    );
    if (_editingCalendarItemId != null) {
      for (final item in activeCareer.currentSeason.calendar) {
        if (item.id == _editingCalendarItemId) {
          _beginEdit(item);
          return;
        }
      }
    }
    setState(() {});
  }
}

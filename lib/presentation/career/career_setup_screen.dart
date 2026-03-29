import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models/computer_player.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/career_repository.dart';
import '../../data/repositories/career_template_repository.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/career/career_models.dart';
import '../../domain/career/career_template.dart';
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
import 'widgets/career_tags_editor.dart';
import 'widgets/career_tournament_editor.dart';
import 'widgets/career_tournament_prize_editor.dart';
import 'widgets/career_validation_panel.dart';
import '../tournament/tournament_form_models.dart';

class CareerSetupScreen extends StatefulWidget {
  const CareerSetupScreen({super.key});

  @override
  State<CareerSetupScreen> createState() => _CareerSetupScreenState();
}

class _CareerRosterViewData {
  const _CareerRosterViewData({
    required this.availableTags,
    required this.addablePlayers,
  });

  final List<String> availableTags;
  final List<ComputerPlayer> addablePlayers;
}

enum _TemplateCareerPoolMode {
  empty,
  allDatabasePlayers,
  selectedDatabasePlayers,
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
  String? _selectedSeasonTagRuleTagName;
  String? _selectedSeasonTagRuleRankingId;
  String? _selectedSeasonTagRuleCheckTagName;
  String? _selectedTournamentTagGateTagName;
  bool _tournamentOccursWhenTagGateMet = true;
  String? _lastCareerId;
  String? _editingCalendarItemId;
  final Set<String> _selectedRankingIds = <String>{};
  final Set<String> _selectedDatabasePlayerIds = <String>{};
  final Set<String> _selectedCareerRosterPlayerIds = <String>{};
  final Set<String> _selectedDatabaseTagFilters = <String>{};
  final Set<String> _selectedTemplateDatabasePlayerIds = <String>{};
  final Set<String> _selectedTemplateDatabaseTagFilters = <String>{};
  bool _isBusy = false;
  String _busyMessage = '';
  double? _busyProgress;
  final Set<String> _selectedQualificationTagNames = <String>{};
  final Set<String> _selectedQualificationExcludedTagNames = <String>{};
  final Set<String> _selectedFillTagNames = <String>{};
  final Set<String> _selectedFillExcludedTagNames = <String>{};
  final List<CareerQualificationCondition> _qualificationConditions =
      <CareerQualificationCondition>[];
  bool _createAsSeries = false;
  bool _expandLeagueIntoMatchdays = false;
  _TemplateCareerPoolMode _templateCareerPoolMode =
      _TemplateCareerPoolMode.allDatabasePlayers;
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
        if (_selectedTemplateId == null && templates.isNotEmpty) {
          _selectedTemplateId = templates.first.id;
        } else if (_selectedTemplateId != null &&
            templates.every((template) => template.id != _selectedTemplateId)) {
          _selectedTemplateId = templates.isEmpty ? null : templates.first.id;
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
                _buildCareerCard(
                  context,
                  careers: careers,
                  activeCareer: activeCareer,
                  templates: templates,
                  players: players,
                ),
                const SizedBox(height: 16),
                if (activeCareer == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'Erstelle oder lade oben eine Karriere, um den Saisonkalender zu planen.',
                      ),
                    ),
                  )
                else ...<Widget>[
                  _buildHeaderCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildTemplatesCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildRankingsCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildCareerTagsCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildDatabasePlayersCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildTournamentCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildCalendarCard(context, activeCareer),
                  const SizedBox(height: 16),
                  _buildValidationCard(context, activeCareer),
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
              onPressed: _createCareer,
              icon: const Icon(Icons.add),
              label: const Text('Karriere erstellen'),
            ),
            if (templates.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>(_selectedTemplateId ?? 'no-template'),
                initialValue: _selectedTemplateId,
                decoration: const InputDecoration(labelText: 'Vorlage'),
                items: templates
                    .map(
                      (template) => DropdownMenuItem<String>(
                        value: template.id,
                        child: Text(template.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedTemplateId = value);
                },
              ),
              const SizedBox(height: 12),
              _buildTemplatePoolSelector(context),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _createCareerFromTemplate,
                icon: const Icon(Icons.copy_all),
                label: const Text('Aus Vorlage erstellen'),
              ),
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

  Widget _buildHeaderCard(BuildContext context, CareerDefinition career) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(career.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Saison ${career.currentSeason.seasonNumber} | ${career.participantMode == CareerParticipantMode.withHuman ? 'Mit mir' : 'Nur Computer'}${career.playerProfileId != null ? ' | ${_playerName(career.playerProfileId!)}' : ''}${career.replaceWeakestPlayerWithHuman ? ' | ersetzt schwaechsten Spieler' : ''}',
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
    );
  }

  Widget _buildValidationCard(BuildContext context, CareerDefinition career) {
    final issues = _collectValidationIssues(career);
    final previews = career.currentSeason.calendar
        .take(6)
        .map((item) => _buildTournamentPreview(career, item))
        .toList();
    return CareerValidationPanel(
      issues: issues,
      previews: previews,
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
    );
  }

  bool _matchesTagFilters(
    CareerDatabasePlayer player, {
    required List<String> requiredTags,
    required List<String> excludedTags,
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
    return true;
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
    return _buildExpandableSection(
      context: context,
      title: 'Saisonkalender',
      subtitle: '${career.currentSeason.calendar.length} Turniere',
      initiallyExpanded: career.currentSeason.calendar.isNotEmpty,
      children: <Widget>[
        if (career.currentSeason.calendar.isEmpty)
          const Text(
            'Noch keine Turniere angelegt. Weiter unten kannst du das erste Turnier hinzufuegen.',
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: career.currentSeason.calendar.length,
            onReorder: (oldIndex, newIndex) {
              var target = newIndex;
              if (target > oldIndex) {
                target -= 1;
              }
              _repository.reorderCalendar(oldIndex, target);
            },
            itemBuilder: (context, index) {
              final item = career.currentSeason.calendar[index];
              final rankingsLabel = item.countsForRankingIds.isEmpty
                  ? 'Keine Rangliste'
                  : career.rankings
                      .where(
                        (ranking) =>
                            item.countsForRankingIds.contains(ranking.id),
                      )
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
              return Card(
                key: ValueKey(item.id),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.format == TournamentFormat.league
                        ? '${item.fieldSize} Spieler | Liga ${item.roundRobinRepeats}x | '
                            '${item.pointsForWin}/${item.pointsForDraw} Punkte | '
                            '${item.startScore} | Preisgeld ${item.prizePool} | '
                            '$rankingsLabel'
                        : item.format == TournamentFormat.leaguePlayoff
                            ? '${item.fieldSize} Spieler | Liga ${item.roundRobinRepeats}x + Top ${item.playoffQualifierCount} Playoffs | '
                                '${item.pointsForWin}/${item.pointsForDraw} Punkte | '
                                '${item.startScore} | Preisgeld ${item.prizePool} | '
                                '$rankingsLabel'
                            : '${item.fieldSize} Spieler | First to ${item.legsToWin} | '
                                '${item.matchMode == MatchMode.legs ? 'Legs' : 'Sets ${item.setsToWin} / Legs ${item.legsPerSet}'} | '
                                '${item.startScore} | Preisgeld ${item.prizePool} | '
                                '$rankingsLabel | $seedingLabel Top ${item.seedCount}'}'
                    '${item.tagGate == null ? '' : ' | Tag-Regel ${item.tagGate!.tagName} ${item.tagGate!.minimumPlayerCount}+'}',
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
    );
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
    return CareerRankingsEditor(
      rankings: career.rankings,
      rankingNameController: _rankingNameController,
      rankingValidSeasons: _rankingValidSeasons,
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
    );
  }

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
    return CareerTagsEditor(
      isEditingCareerTag: _editingCareerTagId != null,
      careerTagCount: career.careerTagDefinitions.length,
      tagDefinitionSection: _buildCareerTagDefinitionSection(career),
      seasonRulesSection: _buildSeasonRulesSection(career),
      existingTagsSection: _buildExistingCareerTagsSection(career),
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
        Text(
          'Trainingsmodus',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Passe die Average-Spanne eines Karriere-Pools an. Die Werte werden nur in dieser Karriere geaendert, nie in der Datenbank.',
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          key: ValueKey<String?>(
            _selectedTrainingPoolTagName ?? 'training-pool-all',
          ),
          initialValue: _selectedTrainingPoolTagName,
          decoration: const InputDecoration(labelText: 'Pool'),
          items: <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Gesamter Karriere-Kader'),
            ),
            ...career.careerTagDefinitions.map(
              (definition) => DropdownMenuItem<String?>(
                value: definition.name,
                child: Text('Karriere-Tag: ${definition.name}'),
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
              : 'Im aktuell gewaehlten Pool sind keine Karriere-Spieler vorhanden.',
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _trainingMinAverageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Wunsch-Minimum',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _trainingMaxAverageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              onPressed: hasPool ? () => _applyTrainingModeToPool(career) : null,
              icon: const Icon(Icons.fitness_center),
              label: const Text('Auf Karriere-Pool anwenden'),
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
    final poolPlayers = (_selectedTrainingPoolTagName == null ||
            _selectedTrainingPoolTagName!.trim().isEmpty)
        ? career.databasePlayers
        : career.databasePlayers
            .where(
              (player) =>
                  player.activeTagNames.contains(_selectedTrainingPoolTagName),
            )
            .toList();
    if (humanPlayerProfileId == null) {
      return poolPlayers;
    }
    return poolPlayers
        .where((player) => player.databasePlayerId != humanPlayerProfileId)
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

    final sortedPlayers = List<CareerDatabasePlayer>.from(poolPlayers)
      ..sort((left, right) => left.average.compareTo(right.average));
    final currentMin = sortedPlayers.first.average;
    final currentMax = sortedPlayers.last.average;
    await _runBusyAction(
      message:
          'Trainingsmodus wird angewendet... (0/${sortedPlayers.length} Spieler)',
      action: () async {
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
          final resolution =
              _computerRepository.resolveSkillsForTheoreticalAverageQuick(
            targetAverage,
          );
          updatedPlayers.add(
            player.copyWith(
              average: resolution.theoreticalAverage,
              skill: resolution.skill,
              finishingSkill: resolution.finishingSkill,
            ),
          );
          if (mounted) {
            setState(() {
              _busyMessage =
                  'Trainingsmodus wird angewendet... (${index + 1}/${sortedPlayers.length} Spieler)';
              _busyProgress = (index + 1) / sortedPlayers.length;
            });
          }
          if ((index + 1) % 8 == 0) {
            await Future<void>.delayed(Duration.zero);
          }
        }
        _repository.updateDatabasePlayers(players: updatedPlayers);
      },
    );
    if (mounted) {
      setState(() {});
    }
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
    _careerNameController.clear();
    final activeCareer = _repository.activeCareer;
    if (activeCareer != null) {
      _applyCareerDefaults(activeCareer);
    }
    setState(() {});
  }

  Future<void> _createCareerFromTemplate() async {
    final templateId = _selectedTemplateId;
    if (templateId == null) {
      return;
    }
    CareerTemplate? selectedTemplate;
    for (final template in _templateRepository.templates) {
      if (template.id == templateId) {
        selectedTemplate = template;
        break;
      }
    }
    if (selectedTemplate == null) {
      return;
    }

    final templateDatabasePlayers =
        _templateCreationPoolPlayers(selectedTemplate);

    final shouldContinue = await _confirmTemplateCreation(
      selectedTemplate,
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
          template: selectedTemplate!,
          databasePlayers: templateDatabasePlayers,
          participantMode: _participantMode,
          playerProfileId: _participantMode == CareerParticipantMode.withHuman
              ? _selectedPlayerProfileId
              : null,
          replaceWeakestPlayerWithHuman:
              _participantMode == CareerParticipantMode.withHuman &&
                  _replaceWeakestPlayerWithHuman,
        );
        _careerNameController.clear();
        final activeCareer = _repository.activeCareer;
        if (activeCareer != null) {
          _applyCareerDefaults(activeCareer);
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<bool> _confirmTemplateCreation(
    CareerTemplate template,
    int selectedPoolCount,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Vorlage erstellen?'),
          content: Text(
            'Die Vorlage "${template.name}" wird als neue Karriere angelegt.\n\n'
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

  Widget _buildTemplatePoolSelector(BuildContext context) {
    final template = _selectedTemplate();
    final poolViewData = _buildTemplatePoolViewData();
    final selectedCount = template == null
        ? 0
        : _templateCreationPoolPlayers(template).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DropdownButtonFormField<_TemplateCareerPoolMode>(
          key: ValueKey<_TemplateCareerPoolMode>(_templateCareerPoolMode),
          initialValue: _templateCareerPoolMode,
          decoration: const InputDecoration(
            labelText: 'Karriere-Pool fuer Vorlage',
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
            setState(() => _templateCareerPoolMode = value);
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

  _CareerRosterViewData _buildTemplatePoolViewData() {
    final availablePlayers = _computerRepository.players;
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
    CareerTemplate template,
  ) {
    switch (_templateCareerPoolMode) {
      case _TemplateCareerPoolMode.empty:
        return const <CareerDatabasePlayer>[];
      case _TemplateCareerPoolMode.allDatabasePlayers:
        return _computerRepository.players
            .map(
              (player) => _careerDatabasePlayerFromComputerPlayer(
                player: player,
                template: template,
              ),
            )
            .toList();
      case _TemplateCareerPoolMode.selectedDatabasePlayers:
        return _computerRepository.players
            .where(
              (player) => _selectedTemplateDatabasePlayerIds.contains(player.id),
            )
            .map(
              (player) => _careerDatabasePlayerFromComputerPlayer(
                player: player,
                template: template,
              ),
            )
            .toList();
    }
  }

  CareerDatabasePlayer _careerDatabasePlayerFromComputerPlayer({
    required ComputerPlayer player,
    required CareerTemplate template,
  }) {
    final tagDefinitionsByLowerName = <String, CareerTagDefinition>{
      for (final definition in template.careerTagDefinitions)
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
      careerTags: careerTags,
    );
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
    if (_editingRankingId == null) {
      _repository.addRanking(
        name: _rankingNameController.text,
        validSeasons: _rankingValidSeasons,
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
        validSeasons: _rankingValidSeasons,
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
    if (fieldSize == null || fieldSize < 2 || startScore == null || startScore <= 1) {
      return;
    }
    if (_editingCalendarItemId != null) {
        _repository.updateCalendarItem(
        itemId: _editingCalendarItemId!,
        name: _itemNameController.text,
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
    _editingCalendarItemId = item.id;
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
    _selectedQualificationTagNames.clear();
    _selectedQualificationExcludedTagNames.clear();
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
    _fillRankingId = rankingFillRule?.rankingId;
    _fillTopByRankingController.text =
        rankingFillRule != null && rankingFillRule.maxCount > 0
        ? rankingFillRule.maxCount.toString()
        : '';
    _fillTopByAverageController.text =
        averageFillRule != null && averageFillRule.maxCount > 0
        ? averageFillRule.maxCount.toString()
        : '';
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
    _qualificationEntryRoundController.text = '1';
    _qualificationSlotCountController.clear();
    _selectedFillTagNames.clear();
    _selectedFillExcludedTagNames.clear();
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
    if (_qualificationConditionType ==
            CareerQualificationConditionType.careerTagOnly &&
        requiredTags.isEmpty) {
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
          excludedCareerTags:
              List<String>.from(_selectedQualificationExcludedTagNames),
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

    if (_fillRankingId != null) {
      rules.add(
        CareerTournamentFillRule(
          id: 'editor-fill-ranking',
          sourceType: CareerTournamentFillSourceType.ranking,
          rankingId: _fillRankingId,
          requiredCareerTags: requiredTags,
          excludedCareerTags: excludedTags,
          maxCount: rankingCount < 0 ? 0 : rankingCount,
        ),
      );
    }

    if (averageCount > 0 ||
        requiredTags.isNotEmpty ||
        excludedTags.isNotEmpty ||
        _fillRankingId == null) {
      rules.add(
        CareerTournamentFillRule(
          id: 'editor-fill-average',
          sourceType: CareerTournamentFillSourceType.average,
          requiredCareerTags: requiredTags,
          excludedCareerTags: excludedTags,
          maxCount: averageCount < 0 ? 0 : averageCount,
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
    _selectedRankingIds.clear();
    _seedingRankingId = null;
    _qualificationRankingId = null;
    _qualificationConditions.clear();
    _selectedQualificationTagNames.clear();
    _selectedQualificationExcludedTagNames.clear();
    _selectedFillTagNames.clear();
    _selectedFillExcludedTagNames.clear();
    _fillTopByAverageController.clear();
    _selectedTrainingPoolTagName = null;
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
    return '$baseLabel$slotLabel$roundLabel$requiredLabel$excludedLabel';
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

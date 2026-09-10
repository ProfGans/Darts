import 'package:flutter/material.dart';

import '../../data/models/computer_player.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/tournament/tournament_models.dart';
import '../widgets/theo_display.dart';
import 'tournament_basics_form.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_form_models.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Players Championship');
  final TextEditingController _computerCountController =
      TextEditingController(text: '7');
  final TextEditingController _minimumAverageController =
      TextEditingController(text: '0');
  final TextEditingController _maximumAverageController =
      TextEditingController(text: '180');

  TournamentFormData _formData = const TournamentFormData(
    fieldSizeInput: '8',
    legsValue: 3,
  );
  bool _includeHumanPlayer = true;
  bool _showValidation = false;
  String? _selectedCommunityId;
  List<String> _selectedPlayerIds = <String>[];
  List<String> _selectedComputerIds = <String>[];
  String? _selectedComputerPresetId;

  @override
  void dispose() {
    _nameController.dispose();
    _computerCountController.dispose();
    _minimumAverageController.dispose();
    _maximumAverageController.dispose();
    super.dispose();
  }

  void _startTournament() {
    setState(() {
      _showValidation = true;
    });
    final fieldSize = _formData.effectiveFieldSize;
    final startScore = _formData.parsedStartScore;
    if (fieldSize == null || fieldSize < 2 || startScore == null || startScore <= 1) {
      return;
    }
    final activePlayer = PlayerRepository.instance.activePlayer;
    final community = CommunityRepository.instance.communityById(_selectedCommunityId ?? '');
    final effectiveSelectedPlayerIds =
        _effectiveSelectedPlayerIds(activePlayer?.id);
    final humanSlots = _includeHumanPlayer && activePlayer != null ? 1 : 0;
    final selectedProfileSlots = effectiveSelectedPlayerIds.length;
    final requestedComputerCount =
        int.tryParse(_computerCountController.text.trim()) ?? 0;
    final computerOpponentCount = requestedComputerCount.clamp(
      0,
      fieldSize > humanSlots + selectedProfileSlots
          ? fieldSize - humanSlots - selectedProfileSlots
          : 0,
    );
    final minimumAverage =
        _tryParseAverage(_minimumAverageController.text) ?? 0;
    final maximumAverage =
        _tryParseAverage(_maximumAverageController.text) ?? 180;
    final averageFloor =
        minimumAverage <= maximumAverage ? minimumAverage : maximumAverage;
    final averageCeiling =
        minimumAverage <= maximumAverage ? maximumAverage : minimumAverage;

    TournamentRepository.instance.createTournament(
      name: _nameController.text.trim().isEmpty
          ? 'Turnier'
          : _nameController.text.trim(),
      community: community,
      phases: _formData.isSeriesMode
          ? _formData.effectivePhaseTournaments
              .asMap()
              .entries
              .map(
                (entry) => TournamentPhaseDefinition(
                  phaseNumber: entry.key + 1,
                  tournaments: entry.value
                      .asMap()
                      .entries
                      .map(
                        (tournamentEntry) => TournamentPhaseTournamentDefinition(
                          tournamentNumber: tournamentEntry.key + 1,
                          format: tournamentEntry.value.format,
                          qualificationRules: tournamentEntry.value.qualificationRules
                              .where(
                                (rule) =>
                                    rule.targetPhaseNumber != null &&
                                    rule.targetTournamentNumber != null,
                              )
                              .map(
                                (rule) => TournamentQualificationRuleDefinition(
                                  startPlacement: rule.startPlacement,
                                  endPlacement: rule.endPlacement,
                                  targetPhaseNumber: rule.targetPhaseNumber!,
                                  targetTournamentNumber:
                                      rule.targetTournamentNumber!,
                                ),
                              )
                              .toList(),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList()
          : <TournamentPhaseDefinition>[
              TournamentPhaseDefinition(
                phaseNumber: 1,
                tournaments: <TournamentPhaseTournamentDefinition>[
                  TournamentPhaseTournamentDefinition(
                    tournamentNumber: 1,
                    format: _formData.primaryFormat,
                  ),
                ],
              ),
            ],
      game: _formData.game,
      format: _formData.primaryFormat,
      fieldSize: fieldSize,
      matchMode: _formData.matchMode,
      legsToWin: _formData.effectiveLegsToWin,
      startScore: startScore,
      startRequirement: _formData.startRequirement,
      checkoutRequirement: _formData.checkoutRequirement,
      setsToWin: _formData.effectiveSetsToWin,
      legsPerSet: _formData.effectiveLegsPerSet,
      roundDistanceValues: _formData.effectiveRoundDistanceValues,
      pointsForWin: _formData.pointsForWin,
      pointsForDraw: _formData.pointsForDraw,
      roundRobinRepeats: _formData.roundRobinRepeats,
      maxLeagueMatchesPerParticipant: _formData.maxLeagueMatchesPerParticipant,
      playoffQualifierCount: _formData.playoffQualifierCount,
      groupCount: _formData.groupCount,
      playersPerGroup: _formData.playersPerGroup,
      includeHumanPlayer: _includeHumanPlayer,
      selectedPlayerIds: effectiveSelectedPlayerIds,
      computerOpponentCount: computerOpponentCount,
      minimumComputerAverage: averageFloor,
      maximumComputerAverage: averageCeiling,
      selectedComputerIds: _selectedComputerIds,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TournamentBracketScreen(),
      ),
    );
  }

  Future<void> _openComputerSelectionDialog() async {
    final players = ComputerRepository.instance.players;
    final validIds = players.map((player) => player.id).toSet();
    final tempSelection = _selectedComputerIds
        .where(validIds.contains)
        .toList();
    var searchText = '';

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredPlayers = players.where((player) {
              final query = searchText.trim().toLowerCase();
              if (query.isEmpty) {
                return true;
              }
              return player.name.toLowerCase().contains(query) ||
                  (player.nationality ?? '').toLowerCase().contains(query) ||
                  player.tags.any((tag) => tag.toLowerCase().contains(query));
            }).toList();

            return AlertDialog(
              title: const Text('CPU Gegner aus Datenbank'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Suche',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredPlayers.length,
                        itemBuilder: (context, index) {
                          final player = filteredPlayers[index];
                          final isSelected = tempSelection.contains(player.id);
                          return CheckboxListTile(
                            value: isSelected,
                            contentPadding: EdgeInsets.zero,
                            title: Text(player.name),
                              subtitle: wrapWithTheoTooltip(
                                skill: player.skill,
                                finishingSkill: player.finishingSkill,
                                child: Text(
                                  'Theo ${formatTheoValue(player.theoreticalAverage)}'
                                  '${player.nationality == null ? '' : ' | ${player.nationality}'}',
                                ),
                              ),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  if (!tempSelection.contains(player.id)) {
                                    tempSelection.add(player.id);
                                  }
                                } else {
                                  tempSelection.remove(player.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(List<String>.from(tempSelection)),
                  child: const Text('Uebernehmen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedComputerIds = result;
      _selectedComputerPresetId = null;
    });
  }

  Future<void> _openPlayerSelectionDialog() async {
    final repository = PlayerRepository.instance;
    final players = repository.players;
    final community = CommunityRepository.instance.communityById(_selectedCommunityId ?? '');
    final communityIds = community?.playerIds.toSet();
    final validIds = players.map((player) => player.id).toSet();
    final tempSelection = _selectedPlayerIds.where(validIds.contains).toList();
    var searchText = '';

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredPlayers = players.where((player) {
              final query = searchText.trim().toLowerCase();
              if (query.isEmpty) {
                return true;
              }
              return player.name.toLowerCase().contains(query) ||
                  (player.nationality ?? '').toLowerCase().contains(query) ||
                  player.tags.any((tag) => tag.toLowerCase().contains(query));
            }).toList();
            filteredPlayers.sort((left, right) {
              final leftInCommunity = communityIds?.contains(left.id) ?? false;
              final rightInCommunity = communityIds?.contains(right.id) ?? false;
              if (leftInCommunity != rightInCommunity) {
                return leftInCommunity ? -1 : 1;
              }
              return left.name.compareTo(right.name);
            });

            return AlertDialog(
              title: const Text('Spielerprofile aus der App'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Suche',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchText = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 360,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredPlayers.length,
                        itemBuilder: (context, index) {
                          final player = filteredPlayers[index];
                          final isSelected = tempSelection.contains(player.id);
                          final isActive = repository.activePlayer?.id == player.id;
                          return CheckboxListTile(
                            value: isSelected,
                            contentPadding: EdgeInsets.zero,
                            title: Text(player.name),
                            subtitle: Text(
                              '${player.average.toStringAsFixed(1)} Avg'
                              '${player.nationality == null ? '' : ' | ${player.nationality}'}'
                              '${communityIds?.contains(player.id) ?? false ? ' | Community' : ''}'
                              '${isActive ? ' | Aktiv' : ''}',
                            ),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  if (!tempSelection.contains(player.id)) {
                                    tempSelection.add(player.id);
                                  }
                                } else {
                                  tempSelection.remove(player.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pop(List<String>.from(tempSelection)),
                  child: const Text('Uebernehmen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedPlayerIds = result;
    });
  }

  Future<void> _saveCurrentSelectionAsPreset() async {
    if (_selectedComputerIds.isEmpty) {
      return;
    }
    TournamentComputerSelectionPreset? existingPreset;
    for (final preset in TournamentRepository.instance.savedComputerSelections) {
      if (preset.id == _selectedComputerPresetId) {
        existingPreset = preset;
        break;
      }
    }
    final controller = TextEditingController(
      text: existingPreset?.name ?? 'CPU Auswahl',
    );

    final presetName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CPU Auswahl speichern'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset Name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (presetName == null || presetName.trim().isEmpty) {
      return;
    }

    final saved = await TournamentRepository.instance.saveComputerSelectionPreset(
      existingPresetId: existingPreset?.id,
      name: presetName,
      computerIds: _selectedComputerIds,
    );
    if (!mounted || saved == null) {
      return;
    }

    setState(() {
      _selectedComputerPresetId = saved.id;
    });
  }

  Future<void> _deleteSelectedPreset() async {
    final presetId = _selectedComputerPresetId;
    if (presetId == null) {
      return;
    }
    await TournamentRepository.instance.deleteComputerSelectionPreset(presetId);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedComputerPresetId = null;
    });
  }

  void _applyPreset(String? presetId) {
    if (presetId == null) {
      setState(() {
        _selectedComputerPresetId = null;
      });
      return;
    }
    TournamentComputerSelectionPreset? preset;
    for (final entry in TournamentRepository.instance.savedComputerSelections) {
      if (entry.id == presetId) {
        preset = entry;
        break;
      }
    }
    if (preset == null) {
      return;
    }
    final selectedPreset = preset;
    final validIds = ComputerRepository.instance.players.map((entry) => entry.id).toSet();
    setState(() {
      _selectedComputerPresetId = selectedPreset.id;
      _selectedComputerIds =
          selectedPreset.computerIds.where(validIds.contains).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tournamentRepository = TournamentRepository.instance;
    final computerRepository = ComputerRepository.instance;
    final playerRepository = PlayerRepository.instance;
    final communityRepository = CommunityRepository.instance;
    final presets = tournamentRepository.savedComputerSelections;
    final availablePlayers = computerRepository.players;
    final validIds = availablePlayers.map((player) => player.id).toSet();
    final availableProfiles = playerRepository.players;
    final validProfileIds = availableProfiles.map((player) => player.id).toSet();
    final communities = communityRepository.communities;
    if (_selectedCommunityId == null && communityRepository.activeCommunity != null) {
      _selectedCommunityId = communityRepository.activeCommunity!.id;
    }
    if (_selectedCommunityId != null &&
        communities.every((community) => community.id != _selectedCommunityId)) {
      _selectedCommunityId = null;
    }
    _selectedPlayerIds =
        _selectedPlayerIds.where(validProfileIds.contains).toList();
    _selectedComputerIds = _selectedComputerIds.where(validIds.contains).toList();
    if (_selectedComputerPresetId != null &&
        presets.every((preset) => preset.id != _selectedComputerPresetId)) {
      _selectedComputerPresetId = null;
    }
    final selectedProfiles = _selectedProfiles(availableProfiles);
    final activePlayer = playerRepository.activePlayer;
    final selectedCommunity = _selectedCommunityId == null
        ? null
        : communityRepository.communityById(_selectedCommunityId!);
    final communityProfiles = selectedCommunity == null
        ? const <PlayerProfile>[]
        : selectedCommunity.playerIds
            .map((id) => playerRepository.playerById(id))
            .whereType<PlayerProfile>()
            .toList();
    final selectedPlayers = _selectedPlayers(availablePlayers);
    final fieldSize = _formData.effectiveFieldSize;
    final startScore = _formData.parsedStartScore;
    final effectiveSelectedPlayerIds =
        _effectiveSelectedPlayerIds(activePlayer?.id);
    final participantSlots =
        (_includeHumanPlayer && activePlayer != null ? 1 : 0) +
            effectiveSelectedPlayerIds.length;
    final requestedComputerCount =
        int.tryParse(_computerCountController.text.trim());
    final issues = <String>[
      if (fieldSize == null || fieldSize < 2)
        'Feldgroesse muss mindestens 2 sein.',
      if (startScore == null || startScore <= 1)
        'Startscore muss groesser als 1 sein.',
      if (_nameController.text.trim().isEmpty)
        'Vergib einen Turniernamen.',
      if (participantSlots > 0 &&
          fieldSize != null &&
          participantSlots > fieldSize)
        'Mehr Spielerprofile ausgewaehlt als ins Teilnehmerfeld passen.',
      if (requestedComputerCount != null &&
          fieldSize != null &&
          requestedComputerCount + participantSlots > fieldSize)
        'Spielerprofile und CPU Gegner ueberschreiten gemeinsam die Feldgroesse.',
      if ((_tryParseAverage(_minimumAverageController.text) ?? 0) >
          (_tryParseAverage(_maximumAverageController.text) ?? 180))
        'Min- und Max-Average passen noch nicht zusammen.',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnier konfigurieren'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_showValidation && issues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  issues.first,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8C2F39),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            FilledButton(
              onPressed: _startTournament,
              child: const Text('Turnier starten'),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Turnier erstellen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _TournamentInfoPill(
                                label:
                                    '${fieldSize ?? '-'} Teilnehmer',
                              ),
                              _TournamentInfoPill(
                                label: _formData.primaryFormat == TournamentFormat.knockout
                                    ? 'KO'
                                    : _formData.primaryFormat == TournamentFormat.league
                                        ? 'Liga'
                                        : _formData.primaryFormat ==
                                                TournamentFormat.leaguePlayoff
                                            ? 'Liga + Playoff'
                                            : 'Gruppenphase',
                              ),
                              _TournamentInfoPill(
                                label: _formData.isSeriesMode
                                    ? '${_formData.phaseCount} Turnierphasen'
                                    : 'Einzelturnier',
                              ),
                              if (_formData.primaryFormat ==
                                  TournamentFormat.groupStage)
                                _TournamentInfoPill(
                                  label:
                                      '${_formData.groupCount} Gruppen x ${_formData.playersPerGroup}',
                                ),
                              _TournamentInfoPill(
                                label: 'Start $startScore',
                              ),
                              _TournamentInfoPill(
                                label: '$participantSlots App-Spieler',
                              ),
                              _TournamentInfoPill(
                                label: '${selectedPlayers.length} feste CPU',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            issues.isEmpty
                                ? 'Die Grunddaten sind komplett. Jetzt noch Feld und CPU-Auswahl pruefen und direkt starten.'
                                : 'Noch offen: ${issues.take(2).join(' ')}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: issues.isEmpty
                                      ? const Color(0xFF365F4B)
                                      : const Color(0xFF8C2F39),
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (_showValidation && issues.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: issues
                              .map((issue) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text('- $issue'),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TournamentBasicsForm(
                      nameController: _nameController,
                      formData: _formData,
                      roundDistancesCollapsible: true,
                      roundDistancesInitiallyExpanded: false,
                      onChanged: (value) {
                        setState(() {
                          _formData = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Community',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCommunityId,
                      decoration: const InputDecoration(
                        labelText: 'Turnier-Community',
                      ),
                      items: communities
                          .map(
                            (community) => DropdownMenuItem<String>(
                              value: community.id,
                              child: Text(
                                '${community.name} (${community.playerIds.length} Spieler)',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: communities.isEmpty
                          ? null
                          : (value) {
                              setState(() {
                                _selectedCommunityId = value;
                              });
                            },
                    ),
                    if (communities.isEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Noch keine Community vorhanden. Lege im Turnier-Hub zuerst eine Community an, um einen festen Spielerpool zu nutzen.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5D7285),
                            ),
                      ),
                    ],
                    if (selectedCommunity != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        selectedCommunity.description ??
                            'Diese Community liefert dir einen festen Spielerpool fuer schnelle Turnierstarts.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF5D7285),
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _includeHumanPlayer,
                      onChanged: (value) {
                        setState(() {
                          _includeHumanPlayer = value;
                        });
                      },
                      title: const Text('Aktiven Spieler aufnehmen'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Spieler aus der App',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Waehle bestehende Spielerprofile fuer Vereinsabende und Turniere aus. Der aktive Spieler kann optional zusaetzlich aufgenommen werden.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: availableProfiles.isEmpty
                          ? null
                          : _openPlayerSelectionDialog,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Spielerprofile waehlen'),
                    ),
                    if (selectedCommunity != null &&
                        communityProfiles.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            final merged = <String>[
                              ..._selectedPlayerIds,
                              ...communityProfiles.map((player) => player.id),
                            ];
                            _selectedPlayerIds = merged.toSet().toList();
                          });
                        },
                        icon: const Icon(Icons.download_done_outlined),
                        label: Text(
                          '${selectedCommunity.name} Spielerpool uebernehmen',
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_includeHumanPlayer && activePlayer != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InputChip(
                          avatar: const Icon(Icons.person, size: 18),
                          label: Text(
                            '${activePlayer.name} (aktiv, ${activePlayer.average.toStringAsFixed(1)} Avg)',
                          ),
                          onDeleted: () {
                            setState(() {
                              _includeHumanPlayer = false;
                            });
                          },
                        ),
                      ),
                    if (_includeHumanPlayer && activePlayer != null &&
                        selectedProfiles.isNotEmpty)
                      const SizedBox(height: 8),
                    if (selectedProfiles.isEmpty)
                      Text(
                        selectedCommunity == null
                            ? 'Noch keine zusaetzlichen Spielerprofile ausgewaehlt.'
                            : 'Noch keine zusaetzlichen Spielerprofile aus ${selectedCommunity.name} oder der App ausgewaehlt.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedProfiles.map((player) {
                          return InputChip(
                            avatar: const Icon(Icons.badge_outlined, size: 18),
                            label: Text(
                              '${player.name} (${player.average.toStringAsFixed(1)} Avg)${selectedCommunity?.playerIds.contains(player.id) ?? false ? ' · Community' : ''}',
                            ),
                            onDeleted: () {
                              setState(() {
                                _selectedPlayerIds.remove(player.id);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Teilnehmerfeld',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _computerCountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Computergegner',
                        helperText:
                            'Noch frei fuer CPU: ${fieldSize == null ? '-' : (fieldSize - participantSlots).clamp(0, fieldSize)}',
                        errorText: _showValidation &&
                                (requestedComputerCount == null ||
                                    requestedComputerCount < 0)
                            ? 'Bitte eine gueltige Anzahl eingeben'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _minimumAverageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Min. Average',
                              helperText: 'Standard ist offen.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maximumAverageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Max. Average',
                              helperText: 'Standard ist offen.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CPU Gegner aus Datenbank',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ausgewaehlte Gegner werden zuerst ins Teilnehmerfeld gesetzt. Freie CPU-Slots werden danach mit generischen Gegnern aufgefuellt.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    if (presets.isNotEmpty) ...<Widget>[
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>(
                          _selectedComputerPresetId ?? 'no-cpu-preset',
                        ),
                        initialValue: _selectedComputerPresetId,
                        decoration: const InputDecoration(
                          labelText: 'Gespeicherte CPU Auswahl',
                        ),
                        items: presets
                            .map(
                              (preset) => DropdownMenuItem<String>(
                                value: preset.id,
                                child: Text(preset.name),
                              ),
                            )
                            .toList(),
                        onChanged: _applyPreset,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                availablePlayers.isEmpty ? null : _openComputerSelectionDialog,
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('CPU Gegner waehlen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _selectedComputerIds.isEmpty
                                ? null
                                : _saveCurrentSelectionAsPreset,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Auswahl speichern'),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedComputerPresetId != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _deleteSelectedPreset,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Aktuelles Preset loeschen'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (selectedPlayers.isEmpty)
                      const Text('Noch keine festen CPU Gegner ausgewaehlt.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedPlayers.map((player) {
                          return InputChip(
                              label: wrapWithTheoTooltip(
                                skill: player.skill,
                                finishingSkill: player.finishingSkill,
                                child: Text(
                                  '${player.name} (${formatTheoValue(player.theoreticalAverage)})',
                                ),
                              ),
                            onDeleted: () {
                              setState(() {
                                _selectedComputerIds.remove(player.id);
                                _selectedComputerPresetId = null;
                              });
                            },
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ComputerPlayer> _selectedPlayers(List<ComputerPlayer> availablePlayers) {
    final byId = <String, ComputerPlayer>{
      for (final player in availablePlayers) player.id: player,
    };
    final result = <ComputerPlayer>[];
    for (final id in _selectedComputerIds) {
      final player = byId[id];
      if (player != null) {
        result.add(player);
      }
    }
    return result;
  }

  List<PlayerProfile> _selectedProfiles(List<PlayerProfile> availableProfiles) {
    final byId = <String, PlayerProfile>{
      for (final player in availableProfiles) player.id: player,
    };
    final result = <PlayerProfile>[];
    for (final id in _effectiveSelectedPlayerIds(
      PlayerRepository.instance.activePlayer?.id,
    )) {
      final player = byId[id];
      if (player != null) {
        result.add(player);
      }
    }
    return result;
  }

  List<String> _effectiveSelectedPlayerIds(String? activePlayerId) {
    final seenIds = <String>{};
    final result = <String>[];
    for (final id in _selectedPlayerIds) {
      if (id.isEmpty) {
        continue;
      }
      if (_includeHumanPlayer && activePlayerId != null && id == activePlayerId) {
        continue;
      }
      if (seenIds.add(id)) {
        result.add(id);
      }
    }
    return result;
  }

  double? _tryParseAverage(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}

class _TournamentInfoPill extends StatelessWidget {
  const _TournamentInfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

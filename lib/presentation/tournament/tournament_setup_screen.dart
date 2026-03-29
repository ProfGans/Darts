import 'package:flutter/material.dart';

import '../../data/models/computer_player.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/tournament_repository.dart';
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
    final fieldSize = _formData.parsedFieldSize;
    final startScore = _formData.parsedStartScore;
    if (fieldSize == null || fieldSize < 2 || startScore == null || startScore <= 1) {
      return;
    }
    final humanSlots = _includeHumanPlayer ? 1 : 0;
    final requestedComputerCount =
        int.tryParse(_computerCountController.text.trim()) ?? 0;
    final computerOpponentCount = requestedComputerCount.clamp(
      0,
      fieldSize > humanSlots ? fieldSize - humanSlots : 0,
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
      game: _formData.game,
      format: _formData.format,
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
      playoffQualifierCount: _formData.playoffQualifierCount,
      includeHumanPlayer: _includeHumanPlayer,
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
                            subtitle: Text(
                              'Theo ${player.theoreticalAverage.toStringAsFixed(1)}'
                              '${player.nationality == null ? '' : ' | ${player.nationality}'}',
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
    final presets = tournamentRepository.savedComputerSelections;
    final availablePlayers = computerRepository.players;
    final validIds = availablePlayers.map((player) => player.id).toSet();
    _selectedComputerIds = _selectedComputerIds.where(validIds.contains).toList();
    if (_selectedComputerPresetId != null &&
        presets.every((preset) => preset.id != _selectedComputerPresetId)) {
      _selectedComputerPresetId = null;
    }
    final selectedPlayers = _selectedPlayers(availablePlayers);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnier Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                      'Teilnehmerfeld',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _computerCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Computergegner',
                        helperText:
                            'Wenn weniger Gegner verfuegbar sind, entstehen automatisch Freilose.',
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
                            label: Text(
                              '${player.name} (${player.theoreticalAverage.toStringAsFixed(1)})',
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
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _startTournament,
                      child: const Text('Turnier starten'),
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

  double? _tryParseAverage(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}

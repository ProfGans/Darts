import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/export/file_export_service.dart';
import '../../data/models/player_profile.dart';
import '../../data/repositories/player_repository.dart';

class PlayerProfilesScreen extends StatefulWidget {
  const PlayerProfilesScreen({super.key});

  @override
  State<PlayerProfilesScreen> createState() => _PlayerProfilesScreenState();
}

class _PlayerProfilesScreenState extends State<PlayerProfilesScreen> {
  final PlayerRepository _repository = PlayerRepository.instance;
  final FileExportService _fileExportService = createFileExportService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _accentColorController =
      TextEditingController(text: '#1565C0');
  final TextEditingController _avatarEmojiController =
      TextEditingController(text: '?');
  final TextEditingController _avatarColorController =
      TextEditingController(text: '#1565C0');
  final TextEditingController _favoriteFormatsController =
      TextEditingController();
  final TextEditingController _newTagController = TextEditingController();
  final TextEditingController _trainingModeController = TextEditingController();
  final TextEditingController _trainingScoreController = TextEditingController();
  final TextEditingController _trainingAverageController =
      TextEditingController();
  final TextEditingController _trainingNotesController =
      TextEditingController();
  final TextEditingController _importController = TextEditingController();
  final TextEditingController _equipmentNameController =
      TextEditingController();
  final TextEditingController _equipmentWeightController =
      TextEditingController();
  final TextEditingController _equipmentBarrelController =
      TextEditingController();
  final TextEditingController _equipmentMaterialController =
      TextEditingController();
  final TextEditingController _equipmentPointController =
      TextEditingController();
  final TextEditingController _equipmentPointLengthController =
      TextEditingController();
  final TextEditingController _equipmentShaftController =
      TextEditingController();
  final TextEditingController _equipmentShaftLengthController =
      TextEditingController();
  final TextEditingController _equipmentFlightController =
      TextEditingController();
  final TextEditingController _equipmentFlightSystemController =
      TextEditingController();
  final TextEditingController _equipmentGripController =
      TextEditingController();
  final TextEditingController _equipmentNotesController =
      TextEditingController();

  String? _editingId;
  String? _editingEquipmentId;
  String? _selectedNationality;
  PlayerProfileSource _selectedSource = PlayerProfileSource.manual;
  String _preferredView = 'overview';
  String _defaultTrainingMode = 'X01';
  String _defaultMatchMode = 'X01';
  String? _compareFirstPlayerId;
  String? _compareSecondPlayerId;
  final List<String> _draftTags = <String>[];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    _displayNameController.dispose();
    _accentColorController.dispose();
    _avatarEmojiController.dispose();
    _avatarColorController.dispose();
    _favoriteFormatsController.dispose();
    _newTagController.dispose();
    _trainingModeController.dispose();
    _trainingScoreController.dispose();
    _trainingAverageController.dispose();
    _trainingNotesController.dispose();
    _importController.dispose();
    _equipmentNameController.dispose();
    _equipmentWeightController.dispose();
    _equipmentBarrelController.dispose();
    _equipmentMaterialController.dispose();
    _equipmentPointController.dispose();
    _equipmentPointLengthController.dispose();
    _equipmentShaftController.dispose();
    _equipmentShaftLengthController.dispose();
    _equipmentFlightController.dispose();
    _equipmentFlightSystemController.dispose();
    _equipmentGripController.dispose();
    _equipmentNotesController.dispose();
    super.dispose();
  }

  String _sourceLabel(PlayerProfileSource value) => switch (value) {
        PlayerProfileSource.imported => 'Importiert',
        PlayerProfileSource.manual => 'Manuell',
        PlayerProfileSource.guest => 'Gast',
      };

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _activeEquipmentName(PlayerProfile player) {
    for (final setup in player.equipmentSetups) {
      if (setup.id == player.activeEquipmentId) {
        return setup.name;
      }
    }
    return player.equipmentSetups.isEmpty ? '-' : player.equipmentSetups.first.name;
  }

  void _toggleDraftTag(String tag) {
    setState(() {
      final index = _draftTags.indexWhere(
        (entry) => entry.toLowerCase() == tag.toLowerCase(),
      );
      if (index >= 0) {
        _draftTags.removeAt(index);
      } else {
        _draftTags.add(tag);
      }
    });
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _selectedNationality = null;
      _selectedSource = PlayerProfileSource.manual;
      _preferredView = 'overview';
      _defaultTrainingMode = 'X01';
      _defaultMatchMode = 'X01';
      _draftTags.clear();
      _nameController.clear();
      _ageController.clear();
      _notesController.clear();
      _displayNameController.clear();
      _accentColorController.text = '#1565C0';
      _avatarEmojiController.text = '?';
      _avatarColorController.text = '#1565C0';
      _favoriteFormatsController.clear();
      _newTagController.clear();
    });
  }

  void _clearEquipmentForm() {
    setState(() {
      _editingEquipmentId = null;
      _equipmentNameController.clear();
      _equipmentWeightController.clear();
      _equipmentBarrelController.clear();
      _equipmentMaterialController.clear();
      _equipmentPointController.clear();
      _equipmentPointLengthController.clear();
      _equipmentShaftController.clear();
      _equipmentShaftLengthController.clear();
      _equipmentFlightController.clear();
      _equipmentFlightSystemController.clear();
      _equipmentGripController.clear();
      _equipmentNotesController.clear();
    });
  }

  void _edit(PlayerProfile player) {
    setState(() {
      _editingId = player.id;
      _selectedNationality = player.nationality;
      _selectedSource = player.source;
      _preferredView = player.preferences.preferredView;
      _defaultTrainingMode = player.preferences.defaultTrainingMode;
      _defaultMatchMode = player.preferences.defaultMatchMode;
      _draftTags
        ..clear()
        ..addAll(player.tags);
      _nameController.text = player.name;
      _ageController.text = player.age?.toString() ?? '';
      _notesController.text = player.notes ?? '';
      _displayNameController.text = player.preferences.displayName ?? '';
      _accentColorController.text = player.preferences.accentColor;
      _avatarEmojiController.text = player.preferences.avatarEmoji;
      _avatarColorController.text = player.preferences.avatarColor;
      _favoriteFormatsController.text =
          player.preferences.favoriteFormats.join(', ');
    });
  }

  void _editEquipment(PlayerEquipmentSetup setup) {
    setState(() {
      _editingEquipmentId = setup.id;
      _equipmentNameController.text = setup.name;
      _equipmentWeightController.text =
          setup.barrelWeight?.toStringAsFixed(1) ?? '';
      _equipmentBarrelController.text = setup.barrelModel ?? '';
      _equipmentMaterialController.text = setup.barrelMaterial ?? '';
      _equipmentPointController.text = setup.pointType ?? '';
      _equipmentPointLengthController.text = setup.pointLength ?? '';
      _equipmentShaftController.text = setup.shaftType ?? '';
      _equipmentShaftLengthController.text = setup.shaftLength ?? '';
      _equipmentFlightController.text = setup.flightShape ?? '';
      _equipmentFlightSystemController.text = setup.flightSystem ?? '';
      _equipmentGripController.text = setup.gripWax ?? '';
      _equipmentNotesController.text = setup.notes ?? '';
    });
  }

  void _addTagDefinition() {
    final tag = _newTagController.text.trim();
    if (tag.isEmpty) {
      return;
    }
    _repository.addTagDefinition(tag);
    _toggleDraftTag(tag);
    _newTagController.clear();
  }

  void _submit() {
    final age = int.tryParse(_ageController.text.trim());
    if (_nameController.text.trim().isEmpty) {
      return;
    }
    if (age != null && (age < 10 || age > 100)) {
      _showMessage('Alter bitte zwischen 10 und 100 eingeben.');
      return;
    }
    final preferences = PlayerProfilePreferences(
      preferredView: _preferredView,
      defaultTrainingMode: _defaultTrainingMode,
      defaultMatchMode: _defaultMatchMode,
      accentColor: _accentColorController.text.trim().isEmpty
          ? '#1565C0'
          : _accentColorController.text.trim(),
      displayName: _displayNameController.text.trim().isEmpty
          ? null
          : _displayNameController.text.trim(),
      avatarEmoji: _avatarEmojiController.text.trim().isEmpty
          ? '?'
          : _avatarEmojiController.text.trim(),
      avatarColor: _avatarColorController.text.trim().isEmpty
          ? '#1565C0'
          : _avatarColorController.text.trim(),
      favoriteFormats: _favoriteFormatsController.text
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(),
    );

    if (_editingId == null) {
      _repository.createPlayer(
        name: _nameController.text,
        nationality: _selectedNationality,
        age: age,
        tags: _draftTags,
        notes: _notesController.text,
        source: _selectedSource,
        preferences: preferences,
      );
    } else {
      final existing = _repository.playerById(_editingId!);
      if (existing == null) {
        return;
      }
      _repository.updatePlayer(
        playerId: _editingId!,
        name: _nameController.text,
        nationality: _selectedNationality,
        age: age,
        tags: _draftTags,
        notes: _notesController.text,
        source: _selectedSource,
        isFavorite: existing.isFavorite,
        isProtected: existing.isProtected,
        preferences: preferences,
      );
    }
    _clearForm();
  }

  void _saveEquipment(PlayerProfile player) {
    final name = _equipmentNameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Bitte einen Setup-Namen eingeben.');
      return;
    }
    _repository.saveEquipmentSetup(
      playerId: player.id,
      equipmentId: _editingEquipmentId,
      name: name,
      barrelWeight: double.tryParse(
        _equipmentWeightController.text.trim().replaceAll(',', '.'),
      ),
      barrelModel: _equipmentBarrelController.text,
      barrelMaterial: _equipmentMaterialController.text,
      pointType: _equipmentPointController.text,
      pointLength: _equipmentPointLengthController.text,
      shaftType: _equipmentShaftController.text,
      shaftLength: _equipmentShaftLengthController.text,
      flightShape: _equipmentFlightController.text,
      flightSystem: _equipmentFlightSystemController.text,
      gripWax: _equipmentGripController.text,
      notes: _equipmentNotesController.text,
      setActive: true,
    );
    _clearEquipmentForm();
  }

  Future<void> _exportProfiles({required bool json}) async {
    final content = json
        ? _repository.exportAsJsonString()
        : _repository.exportAsCsvString();
    final path = await _fileExportService.exportTextFile(
      folderName: 'exports',
      fileName:
          'player_profiles_${DateTime.now().millisecondsSinceEpoch}.${json ? 'json' : 'csv'}',
      content: content,
    );
    _showMessage(
      path == null ? 'Dateiexport nicht verfuegbar.' : 'Export gespeichert: $path',
    );
  }

  Future<void> _showImportDialog({required bool json}) async {
    var replaceExisting = false;
    _importController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(json ? 'Profile JSON importieren' : 'Profile CSV importieren'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _importController,
                  minLines: 10,
                  maxLines: 18,
                  decoration: InputDecoration(
                    labelText: json ? 'JSON Inhalt' : 'CSV Inhalt',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bestehende Profile ersetzen'),
                  value: replaceExisting,
                  onChanged: (value) {
                    setDialogState(() => replaceExisting = value ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (json) {
                    await _repository.importFromJsonString(
                      _importController.text,
                      replaceExisting: replaceExisting,
                    );
                  } else {
                    await _repository.importFromCsvString(
                      _importController.text,
                      replaceExisting: replaceExisting,
                    );
                  }
                  if (!mounted || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop();
                  _showMessage('Import erfolgreich.');
                } catch (_) {
                  _showMessage('Import fehlgeschlagen.');
                }
              },
              child: const Text('Importieren'),
            ),
          ],
        ),
      ),
    );
  }

  void _recordTraining(PlayerProfile player) {
    final mode = _trainingModeController.text.trim();
    final score = _trainingScoreController.text.trim();
    if (mode.isEmpty || score.isEmpty) {
      _showMessage('Bitte Trainingsmodus und Ergebnis angeben.');
      return;
    }
    _repository.recordTrainingSession(
      playerId: player.id,
      mode: mode,
      scoreLabel: score,
      average: double.tryParse(
        _trainingAverageController.text.trim().replaceAll(',', '.'),
      ),
      notes: _trainingNotesController.text,
    );
    _trainingModeController.clear();
    _trainingScoreController.clear();
    _trainingAverageController.clear();
    _trainingNotesController.clear();
  }

  Future<void> _openDetails(PlayerProfile player) async {
    final analytics = _repository.buildAnalytics(player);
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: <Widget>[
                Text(
                  player.preferences.displayName ?? player.name,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_sourceLabel(player.source)} | ${player.nationality ?? 'Keine Nationalitaet'} | Equipment: ${_activeEquipmentName(player)}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (player.isFavorite) const Chip(label: Text('Favorit')),
                    if (player.isProtected) const Chip(label: Text('Geschuetzt')),
                    if (player.age != null) Chip(label: Text('Alter ${player.age}')),
                    ...player.tags.map((tag) => Chip(label: Text(tag))),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatChip('Avg', player.stats.average.toStringAsFixed(1)),
                    _StatChip('First 3', player.stats.firstThreeAverage.toStringAsFixed(1)),
                    _StatChip('First 9', player.stats.firstNineAverage.toStringAsFixed(1)),
                    _StatChip('Checkout %', '${player.stats.checkoutQuote.toStringAsFixed(1)} %'),
                    _StatChip('Doppel %', '${player.stats.doubleQuote.toStringAsFixed(1)} %'),
                    _StatChip('180er', '${player.stats.scores180}'),
                    _StatChip('Best Finish', '${player.stats.highestFinish}'),
                    _StatChip('100+ Finishes', '${player.stats.hundredPlusCheckouts}'),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Formkurve (gleitender Schnitt)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: analytics.movingAverage.length < 2
                      ? const Center(child: Text('Zu wenig Matchdaten fuer Verlauf.'))
                      : CustomPaint(
                          painter: _TrendPainter(
                            values: analytics.movingAverage,
                            lineColor: theme.colorScheme.primary,
                            guideColor: theme.colorScheme.outlineVariant,
                            textColor: theme.colorScheme.onSurface,
                          ),
                          child: const SizedBox.expand(),
                        ),
                ),
                const SizedBox(height: 16),
                Text('Form-Zeitraeume', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatChip('Letzte 5', analytics.last5.stats.average.toStringAsFixed(1)),
                    _StatChip('Letzte 10', analytics.last10.stats.average.toStringAsFixed(1)),
                    _StatChip('Letzte 25', analytics.last25.stats.average.toStringAsFixed(1)),
                    _StatChip('3 Monate', analytics.last3Months.stats.average.toStringAsFixed(1)),
                    _StatChip('All Time', analytics.allTime.stats.average.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Split-Stats', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatChip('Mit Anwurf', player.stats.withThrowAverage.toStringAsFixed(1)),
                    _StatChip('Ohne Anwurf', player.stats.againstThrowAverage.toStringAsFixed(1)),
                    _StatChip('Decider Avg', player.stats.decidingLegAverage.toStringAsFixed(1)),
                    _StatChip('Decider %', '${player.stats.decidingLegsWonQuote.toStringAsFixed(1)} %'),
                    _StatChip('Best of Short', analytics.bestOfShort.stats.average.toStringAsFixed(1)),
                    _StatChip('Best of Long', analytics.bestOfLong.stats.average.toStringAsFixed(1)),
                    _StatChip('vs Mensch', analytics.vsHuman.stats.average.toStringAsFixed(1)),
                    _StatChip('vs CPU', analytics.vsCpu.stats.average.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Checkout und Scoring', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatChip('1-Dart', '${player.stats.checkoutQuote1Dart.toStringAsFixed(1)} %'),
                    _StatChip('2-Dart', '${player.stats.checkoutQuote2Dart.toStringAsFixed(1)} %'),
                    _StatChip('3-Dart', '${player.stats.checkoutQuote3Dart.toStringAsFixed(1)} %'),
                    _StatChip('Bull', '${player.stats.bullCheckouts}/${player.stats.bullCheckoutAttempts}'),
                    _StatChip('100+/140+/171+', '${player.stats.scores100Plus}/${player.stats.scores140Plus}/${player.stats.scores171Plus}'),
                    _StatChip('180s pro Leg', player.stats.legsPlayed <= 0 ? '0.00' : (player.stats.scores180 / player.stats.legsPlayed).toStringAsFixed(2)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Head-to-Head', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (analytics.headToHead.isEmpty)
                  const Text('Noch keine Gegnerdaten vorhanden.')
                else
                  ...analytics.headToHead.take(8).map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.opponentName),
                          subtitle: Text(
                            '${entry.wins}/${entry.matches} Siege | ${entry.opponentType == PlayerOpponentKind.human ? 'Mensch' : entry.opponentType == PlayerOpponentKind.cpu ? 'CPU' : 'Unbekannt'} | Avg ${entry.average.toStringAsFixed(1)} | ${_formatDateTime(entry.lastPlayedAt)}',
                          ),
                        ),
                      ),
                if (analytics.favoriteOpponent != null)
                  Text('Lieblingsgegner: ${analytics.favoriteOpponent!.opponentName} (${analytics.favoriteOpponent!.winRate.toStringAsFixed(1)} %)'),
                if (analytics.toughestOpponent != null)
                  Text('Angstgegner: ${analytics.toughestOpponent!.opponentName} (${analytics.toughestOpponent!.winRate.toStringAsFixed(1)} %)'),
                const SizedBox(height: 16),
                Text('Equipment-Performance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (analytics.equipment.isEmpty)
                  const Text('Noch keine Equipment-Daten vorhanden.')
                else
                  ...analytics.equipment.map(
                        (entry) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.equipmentName),
                          subtitle: Text(
                            '${entry.matchCount} Matches | ${entry.trainingCount} Trainings | Avg ${entry.stats.average.toStringAsFixed(1)} | Checkout ${entry.stats.checkoutQuote.toStringAsFixed(1)} % | Winrate ${entry.winRate.toStringAsFixed(1)} %',
                          ),
                        ),
                      ),
                const SizedBox(height: 16),
                Text('Profil-Presets', style: theme.textTheme.titleMedium),
                Text('Ansicht: ${player.preferences.preferredView}'),
                Text('Training: ${player.preferences.defaultTrainingMode}'),
                Text('Match: ${player.preferences.defaultMatchMode}'),
                Text('Akzentfarbe: ${player.preferences.accentColor}'),
                if ((player.notes ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text('Notizen', style: theme.textTheme.titleMedium),
                  Text(player.notes!),
                ],
                const SizedBox(height: 16),
                Text('Audit', style: theme.textTheme.titleMedium),
                Text('Erstellt: ${_formatDateTime(player.createdAt)}'),
                Text('Geaendert: ${_formatDateTime(player.updatedAt)}'),
                Text('Letzte Aenderung: ${player.lastModifiedReason}'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spielerprofile'),
        actions: <Widget>[
          IconButton(
            tooltip: 'JSON exportieren',
            onPressed: () => _exportProfiles(json: true),
            icon: const Icon(Icons.upload_file_outlined),
          ),
          IconButton(
            tooltip: 'JSON importieren',
            onPressed: () => _showImportDialog(json: true),
            icon: const Icon(Icons.download_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _repository,
        builder: (context, _) {
          final players = _repository.players;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _editingId == null ? 'Profil anlegen' : 'Profil bearbeiten',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(labelText: 'Anzeigename'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Alter'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        value: _selectedNationality,
                        decoration: const InputDecoration(labelText: 'Nationalitaet'),
                        items: <DropdownMenuItem<String?>>[
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Keine Nationalitaet'),
                          ),
                          ..._repository.nationalityDefinitions.map(
                            (entry) => DropdownMenuItem<String?>(
                              value: entry,
                              child: Text(entry),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedNationality = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PlayerProfileSource>(
                        value: _selectedSource,
                        decoration: const InputDecoration(labelText: 'Quelle'),
                        items: PlayerProfileSource.values
                            .map(
                              (entry) => DropdownMenuItem<PlayerProfileSource>(
                                value: entry,
                                child: Text(_sourceLabel(entry)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _selectedSource = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _repository.tagDefinitions
                            .map(
                              (tag) => FilterChip(
                                label: Text(tag),
                                selected: _draftTags.any(
                                  (entry) => entry.toLowerCase() == tag.toLowerCase(),
                                ),
                                onSelected: (_) => _toggleDraftTag(tag),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller: _newTagController,
                              decoration: const InputDecoration(
                                labelText: 'Neues Tag',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _addTagDefinition,
                            child: const Text('Tag hinzufuegen'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _notesController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: const InputDecoration(labelText: 'Notizen'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          FilledButton(
                            onPressed: _submit,
                            child: Text(
                              _editingId == null ? 'Speichern' : 'Aktualisieren',
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearForm,
                            child: const Text('Zuruecksetzen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Profile', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ...players.map(
                (player) => Card(
                  child: ListTile(
                    title: Text(player.preferences.displayName ?? player.name),
                    subtitle: Text(
                      '${_sourceLabel(player.source)} | Avg ${player.stats.average.toStringAsFixed(1)} | Legs ${player.stats.legsWon}/${player.stats.legsPlayed}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: <Widget>[
                        IconButton(
                          tooltip: 'Details',
                          onPressed: () => _openDetails(player),
                          icon: const Icon(Icons.insights_outlined),
                        ),
                        IconButton(
                          tooltip: 'Bearbeiten',
                          onPressed: () => _edit(player),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Loeschen',
                          onPressed: player.isProtected
                              ? null
                              : () => _repository.deletePlayer(player.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  const _TrendPainter({
    required this.values,
    required this.lineColor,
    required this.guideColor,
    required this.textColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color guideColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final valueRange = math.max(1.0, maxValue - minValue);
    final chartRect = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);

    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index += 1) {
      final y = chartRect.top + (chartRect.height * index / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        guidePaint,
      );
    }

    final path = Path();
    for (var index = 0; index < values.length; index += 1) {
      final x = chartRect.left +
          (chartRect.width * index / math.max(1, values.length - 1));
      final normalized = (values[index] - minValue) / valueRange;
      final y = chartRect.bottom - (chartRect.height * normalized);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.textColor != textColor;
  }
}

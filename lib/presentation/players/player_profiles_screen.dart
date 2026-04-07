import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
  final TextEditingController _favoriteDoubleController =
      TextEditingController();
  final TextEditingController _hatedDoubleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _importController = TextEditingController();

  String? _editingId;
  String? _selectedNationality;
  PlayerProfileSource _selectedSource = PlayerProfileSource.manual;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _favoriteDoubleController.dispose();
    _hatedDoubleController.dispose();
    _notesController.dispose();
    _displayNameController.dispose();
    _importController.dispose();
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

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
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

  void _clearForm() {
    setState(() {
      _editingId = null;
      _selectedNationality = null;
      _selectedSource = PlayerProfileSource.manual;
      _nameController.clear();
      _ageController.clear();
      _favoriteDoubleController.clear();
      _hatedDoubleController.clear();
      _notesController.clear();
      _displayNameController.clear();
    });
  }

  void _edit(PlayerProfile player) {
    setState(() {
      _editingId = player.id;
      _selectedNationality = player.nationality;
      _selectedSource = player.source;
      _nameController.text = player.name;
      _ageController.text = player.age?.toString() ?? '';
      _favoriteDoubleController.text = player.favoriteDouble ?? '';
      _hatedDoubleController.text = player.hatedDouble ?? '';
      _notesController.text = player.notes ?? '';
      _displayNameController.text = player.preferences.displayName ?? '';
    });
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
      preferredView: 'overview',
      defaultTrainingMode: 'X01',
      defaultMatchMode: 'X01',
      accentColor: '#1565C0',
      displayName: _displayNameController.text.trim().isEmpty
          ? null
          : _displayNameController.text.trim(),
      avatarEmoji: '?',
      avatarColor: '#1565C0',
      favoriteFormats: const <String>[],
    );

    if (_editingId == null) {
      _repository.createPlayer(
        name: _nameController.text,
        nationality: _selectedNationality,
        age: age,
        favoriteDouble: _favoriteDoubleController.text,
        hatedDouble: _hatedDoubleController.text,
        tags: const <String>[],
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
        favoriteDouble: _favoriteDoubleController.text,
        hatedDouble: _hatedDoubleController.text,
        tags: existing.tags,
        notes: _notesController.text,
        source: _selectedSource,
        isFavorite: existing.isFavorite,
        isProtected: existing.isProtected,
        preferences: preferences,
      );
    }
    _clearForm();
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

  Future<void> _openDetails(PlayerProfile player) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlayerProfileDetailsPage(
          player: player,
          sourceLabel: _sourceLabel(player.source),
          activeEquipmentName: _activeEquipmentName(player),
          formatDate: _formatDate,
          formatDateTime: _formatDateTime,
        ),
      ),
    );
  }

  Future<void> _openEquipmentPage(PlayerProfile player) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlayerEquipmentPage(player: player),
      ),
    );
  }

  Future<void> _openTrainingPage(PlayerProfile player) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PlayerTrainingPage(player: player),
      ),
    );
  }

  Widget _buildProfileSwitcherCard({
    required ThemeData theme,
    required List<PlayerProfile> players,
    required PlayerProfile? activePlayer,
  }) {
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderedPlayers = <PlayerProfile>[
      if (activePlayer != null) activePlayer,
      ...players.where((player) => player.id != activePlayer?.id),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Aktiver Spieler',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Alle Profile im Schnellzugriff. Tippe auf eine Box fuer die Statistiken, der Haken schaltet aktiv.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: orderedPlayers.length,
                separatorBuilder: (context, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final player = orderedPlayers[index];
                  final isActive = activePlayer?.id == player.id;
                  return SizedBox(
                    width: 260,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openDetails(player),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        player.preferences.displayName ?? player.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_sourceLabel(player.source)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: isActive
                                      ? 'Aktives Profil'
                                      : 'Als aktiven Spieler setzen',
                                  onPressed: () => _repository.setActivePlayer(player.id),
                                  icon: Icon(
                                    isActive
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isActive
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ProfileMiniStat(
                              label: 'Avg',
                              value: player.stats.average.toStringAsFixed(1),
                            ),
                            const SizedBox(height: 4),
                            _ProfileMiniStat(
                              label: 'First 9',
                              value: player.stats.firstNineAverage.toStringAsFixed(1),
                            ),
                            const SizedBox(height: 4),
                            _ProfileMiniStat(
                              label: 'Checkout',
                              value: '${player.stats.checkoutQuote.toStringAsFixed(1)} %',
                            ),
                            const SizedBox(height: 4),
                            _ProfileMiniStat(
                              label: 'Equipment',
                              value: _activeEquipmentName(player),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tippen fuer Statistiken',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            if (isActive) ...<Widget>[
                              const SizedBox(height: 12),
                              const Chip(label: Text('Aktiv')),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileManagementSection({
    required ThemeData theme,
    required List<PlayerProfile> players,
    required PlayerProfile? activePlayer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Profilverwaltung', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        ...players.map(
          (player) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (activePlayer?.id == player.id) ...<Widget>[
                    const Chip(label: Text('Aktiv')),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    player.preferences.displayName ?? player.name,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_sourceLabel(player.source)} | Avg ${player.stats.average.toStringAsFixed(1)} | Legs ${player.stats.legsWon}/${player.stats.legsPlayed}',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () => _openDetails(player),
                        child: const Text('Statistiken'),
                      ),
                      OutlinedButton(
                        onPressed: () => _edit(player),
                        child: const Text('Bearbeiten'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openEquipmentPage(player),
                        child: const Text('Equipment'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openTrainingPage(player),
                        child: const Text('Training'),
                      ),
                      OutlinedButton(
                        onPressed: player.isProtected
                            ? null
                            : () => _repository.deletePlayer(player.id),
                        child: const Text('Loeschen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          final theme = Theme.of(context);
          final players = _repository.players;
          final activePlayer = _repository.activePlayer;
          return ExcludeSemantics(
            excluding: _suppressAccessibilityUpdates,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
              _buildProfileSwitcherCard(
                theme: theme,
                players: players,
                activePlayer: activePlayer,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Schnell anlegen',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _favoriteDoubleController,
                        decoration: const InputDecoration(
                          labelText: 'Lieblingsdoppel optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _hatedDoubleController,
                        decoration: const InputDecoration(
                          labelText: 'Hassdoppel optional',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('Profil speichern'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildProfileManagementSection(
                theme: theme,
                players: players,
                activePlayer: activePlayer,
              ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlayerProfileDetailsPage extends StatefulWidget {
  const _PlayerProfileDetailsPage({
    required this.player,
    required this.sourceLabel,
    required this.activeEquipmentName,
    required this.formatDate,
    required this.formatDateTime,
  });

  final PlayerProfile player;
  final String sourceLabel;
  final String activeEquipmentName;
  final String Function(DateTime value) formatDate;
  final String Function(DateTime value) formatDateTime;

  @override
  State<_PlayerProfileDetailsPage> createState() =>
      _PlayerProfileDetailsPageState();
}

class _PlayerProfileDetailsPageState extends State<_PlayerProfileDetailsPage> {
  final PlayerRepository _repository = PlayerRepository.instance;

  PlayerAnalyticsRange _selectedRange = PlayerAnalyticsRange.allTime;
  String _selectedEquipmentId = '';
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows;

  Future<void> _pickRangeDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_selectedStartDate ?? _selectedEndDate ?? now)
        : (_selectedEndDate ?? _selectedStartDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _selectedStartDate = picked;
        if (_selectedEndDate != null &&
            _selectedEndDate!.isBefore(_selectedStartDate!)) {
          _selectedEndDate = _selectedStartDate;
        }
      } else {
        _selectedEndDate = picked;
        if (_selectedStartDate != null &&
            _selectedStartDate!.isAfter(_selectedEndDate!)) {
          _selectedStartDate = _selectedEndDate;
        }
      }
    });
  }

  String _rangeLabel() {
    if (_selectedStartDate == null && _selectedEndDate == null) {
      return 'Alle Tage';
    }
    if (_selectedStartDate != null && _selectedEndDate == null) {
      return 'Ab ${widget.formatDate(_selectedStartDate!)}';
    }
    if (_selectedStartDate == null && _selectedEndDate != null) {
      return 'Bis ${widget.formatDate(_selectedEndDate!)}';
    }
    return '${widget.formatDate(_selectedStartDate!)} - ${widget.formatDate(_selectedEndDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPlayer = _repository.playerById(widget.player.id) ?? widget.player;
    final sourceLabel = switch (currentPlayer.source) {
      PlayerProfileSource.imported => 'Importiert',
      PlayerProfileSource.manual => 'Manuell',
      PlayerProfileSource.guest => 'Gast',
    };
    final selectedSetupId =
        _selectedEquipmentId.isEmpty ? null : _selectedEquipmentId;
    final analytics = _repository.buildAnalytics(
      currentPlayer,
      range: _selectedRange,
      equipmentId: selectedSetupId,
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
    );
    final filteredStats = analytics.filtered.stats;
    String activeEquipmentName = '-';
    for (final setup in currentPlayer.equipmentSetups) {
      if (setup.id == currentPlayer.activeEquipmentId) {
        activeEquipmentName = setup.name;
        break;
      }
    }
    if (activeEquipmentName == '-' && currentPlayer.equipmentSetups.isNotEmpty) {
      activeEquipmentName = currentPlayer.equipmentSetups.first.name;
    }
    String selectedEquipmentLabel = 'Alle Setups';
    if (selectedSetupId != null) {
      for (final setup in currentPlayer.equipmentSetups) {
        if (setup.id == selectedSetupId) {
          selectedEquipmentLabel = setup.name;
          break;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(currentPlayer.preferences.displayName ?? currentPlayer.name),
      ),
      body: ExcludeSemantics(
        excluding: _suppressAccessibilityUpdates,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
          _SectionCard(
            title: 'Profil',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$sourceLabel | ${currentPlayer.nationality ?? 'Keine Nationalitaet'} | Equipment: $activeEquipmentName',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (currentPlayer.isFavorite) const Chip(label: Text('Favorit')),
                    if (currentPlayer.isProtected)
                      const Chip(label: Text('Geschuetzt')),
                    if (currentPlayer.age != null)
                      Chip(label: Text('Alter ${currentPlayer.age}')),
                    ...currentPlayer.tags.map((tag) => Chip(label: Text(tag))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Filter',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<PlayerAnalyticsRange>(
                  initialValue: _selectedRange,
                  decoration: const InputDecoration(labelText: 'Zeitraum'),
                  items: PlayerAnalyticsRange.values
                      .map(
                        (range) => DropdownMenuItem<PlayerAnalyticsRange>(
                          value: range,
                          child: Text(range.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selectedRange = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedEquipmentId,
                  decoration: const InputDecoration(labelText: 'Setup-Filter'),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Alle Setups'),
                    ),
                    ...currentPlayer.equipmentSetups.map(
                      (setup) => DropdownMenuItem<String>(
                        value: setup.id,
                        child: Text(setup.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedEquipmentId = value ?? '');
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _pickRangeDate(isStart: true),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _selectedStartDate == null
                            ? 'Von'
                            : widget.formatDate(_selectedStartDate!),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickRangeDate(isStart: false),
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(
                        _selectedEndDate == null
                            ? 'Bis'
                            : widget.formatDate(_selectedEndDate!),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _selectedStartDate == null && _selectedEndDate == null
                          ? null
                          : () => setState(() {
                              _selectedStartDate = null;
                              _selectedEndDate = null;
                            }),
                      child: const Text('Range zuruecksetzen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Kernwerte',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatChip('Avg', filteredStats.average.toStringAsFixed(1)),
                _StatChip('First 9', filteredStats.firstNineAverage.toStringAsFixed(1)),
                _StatChip('Checkout %', '${filteredStats.checkoutQuote.toStringAsFixed(1)} %'),
                _StatChip('Doppel %', '${filteredStats.doubleQuote.toStringAsFixed(1)} %'),
                _StatChip('180er', '${filteredStats.scores180}'),
                _StatChip('Best Finish', '${filteredStats.highestFinish}'),
                _StatChip('100+ Finishes', '${filteredStats.hundredPlusCheckouts}'),
                _StatChip('Matches', '${analytics.filtered.matchCount}'),
                _StatChip('Trainings', '${analytics.filteredTrainingCount}'),
                _StatChip('Zeitraum', _selectedRange.label),
                _StatChip('Setup', selectedEquipmentLabel),
                _StatChip(
                  'Kalender',
                  _rangeLabel(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Formkurve',
            child: SizedBox(
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
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Split-Stats',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatChip('Mit Anwurf', analytics.withThrow.stats.withThrowAverage.toStringAsFixed(1)),
                _StatChip('Ohne Anwurf', analytics.againstThrow.stats.againstThrowAverage.toStringAsFixed(1)),
                _StatChip('Decider Avg', analytics.decider.stats.decidingLegAverage.toStringAsFixed(1)),
                _StatChip('Decider %', '${analytics.decider.stats.decidingLegsWonQuote.toStringAsFixed(1)} %'),
                _StatChip('Best of Short', analytics.bestOfShort.stats.average.toStringAsFixed(1)),
                _StatChip('Best of Long', analytics.bestOfLong.stats.average.toStringAsFixed(1)),
                _StatChip('vs Mensch', analytics.vsHuman.stats.average.toStringAsFixed(1)),
                _StatChip('vs CPU', analytics.vsCpu.stats.average.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Checkout und Scoring',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _StatChip('1-Dart', '${filteredStats.checkoutQuote1Dart.toStringAsFixed(1)} %'),
                _StatChip('2-Dart', '${filteredStats.checkoutQuote2Dart.toStringAsFixed(1)} %'),
                _StatChip('3-Dart', '${filteredStats.checkoutQuote3Dart.toStringAsFixed(1)} %'),
                _StatChip('Bull', '${filteredStats.bullCheckouts}/${filteredStats.bullCheckoutAttempts}'),
                _StatChip('100+', '${filteredStats.scores100Plus}'),
                _StatChip('140+', '${filteredStats.scores140Plus}'),
                _StatChip('171+', '${filteredStats.scores171Plus}'),
                _StatChip(
                  '180s pro Leg',
                  filteredStats.legsPlayed <= 0
                      ? '0.00'
                      : (filteredStats.scores180 / filteredStats.legsPlayed).toStringAsFixed(2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Gegnerprofil',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (analytics.favoriteOpponent != null)
                  Text(
                    'Lieblingsgegner: ${analytics.favoriteOpponent!.opponentName} (${analytics.favoriteOpponent!.winRate.toStringAsFixed(1)} %)',
                  ),
                if (analytics.toughestOpponent != null)
                  Text(
                    'Angstgegner: ${analytics.toughestOpponent!.opponentName} (${analytics.toughestOpponent!.winRate.toStringAsFixed(1)} %)',
                  ),
                if (analytics.favoriteOpponent != null ||
                    analytics.toughestOpponent != null)
                  const SizedBox(height: 12),
                if (analytics.headToHead.isEmpty)
                  const Text('Noch keine Gegnerdaten vorhanden.')
                else
                  ...analytics.headToHead.take(8).map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${entry.opponentName} | ${entry.wins}/${entry.matches} Siege | Avg ${entry.average.toStringAsFixed(1)} | ${widget.formatDateTime(entry.lastPlayedAt)}',
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Equipment-Performance',
            child: analytics.equipment.isEmpty
                ? const Text('Noch keine Equipment-Daten vorhanden.')
                : Column(
                    children: analytics.equipment
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.equipmentName,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${entry.matchCount} Matches | ${entry.trainingCount} Trainings | Avg ${entry.stats.average.toStringAsFixed(1)} | Checkout ${entry.stats.checkoutQuote.toStringAsFixed(1)} % | Winrate ${entry.winRate.toStringAsFixed(1)} %',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Profil-Presets und Notizen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Ansicht: ${currentPlayer.preferences.preferredView}'),
                Text('Training: ${currentPlayer.preferences.defaultTrainingMode}'),
                Text('Match: ${currentPlayer.preferences.defaultMatchMode}'),
                if ((currentPlayer.favoriteDouble ?? '').isNotEmpty)
                  Text('Lieblingsdoppel: ${currentPlayer.favoriteDouble}'),
                if ((currentPlayer.hatedDouble ?? '').isNotEmpty)
                  Text('Hassdoppel: ${currentPlayer.hatedDouble}'),
                if ((currentPlayer.notes ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(currentPlayer.notes!),
                ],
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlayerEquipmentPage extends StatefulWidget {
  const _PlayerEquipmentPage({
    required this.player,
  });

  final PlayerProfile player;

  @override
  State<_PlayerEquipmentPage> createState() => _PlayerEquipmentPageState();
}

class _PlayerEquipmentPageState extends State<_PlayerEquipmentPage> {
  final PlayerRepository _repository = PlayerRepository.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _barrelController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _editingEquipmentId;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _barrelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _load(PlayerEquipmentSetup setup) {
    setState(() {
      _editingEquipmentId = setup.id;
      _nameController.text = setup.name;
      _weightController.text = setup.barrelWeight?.toStringAsFixed(1) ?? '';
      _barrelController.text = setup.barrelModel ?? '';
      _notesController.text = setup.notes ?? '';
    });
  }

  void _clear() {
    setState(() {
      _editingEquipmentId = null;
      _nameController.clear();
      _weightController.clear();
      _barrelController.clear();
      _notesController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = _repository.playerById(widget.player.id) ?? widget.player;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Equipment - ${player.preferences.displayName ?? player.name}'),
      ),
      body: ExcludeSemantics(
        excluding: _suppressAccessibilityUpdates,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
          _SectionCard(
            title: _editingEquipmentId == null ? 'Setup anlegen' : 'Setup bearbeiten',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Setup-Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Barrelgewicht'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _barrelController,
                  decoration: const InputDecoration(labelText: 'Barrel-Modell'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notizen'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton(
                      onPressed: () {
                        if (_nameController.text.trim().isEmpty) {
                          return;
                        }
                        _repository.saveEquipmentSetup(
                          playerId: player.id,
                          equipmentId: _editingEquipmentId,
                          name: _nameController.text,
                          barrelWeight: double.tryParse(
                            _weightController.text.trim().replaceAll(',', '.'),
                          ),
                          barrelModel: _barrelController.text,
                          notes: _notesController.text,
                          setActive: true,
                        );
                        _clear();
                      },
                      child: Text(
                        _editingEquipmentId == null ? 'Setup speichern' : 'Setup aktualisieren',
                      ),
                    ),
                    TextButton(
                      onPressed: _clear,
                      child: const Text('Leeren'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Gespeicherte Setups',
            child: player.equipmentSetups.isEmpty
                ? const Text('Noch kein Equipment gespeichert.')
                : Column(
                    children: player.equipmentSetups
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.name,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.summary),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: <Widget>[
                                      if (player.activeEquipmentId == entry.id)
                                        const Chip(label: Text('Aktiv')),
                                      OutlinedButton(
                                        onPressed: () => _load(entry),
                                        child: const Text('Bearbeiten'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _repository.setActiveEquipment(
                                          player.id,
                                          entry.id,
                                        ),
                                        child: const Text('Aktiv setzen'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () => _repository.deleteEquipment(
                                          player.id,
                                          entry.id,
                                        ),
                                        child: const Text('Loeschen'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTrainingPage extends StatefulWidget {
  const _PlayerTrainingPage({
    required this.player,
  });

  final PlayerProfile player;

  @override
  State<_PlayerTrainingPage> createState() => _PlayerTrainingPageState();
}

class _PlayerTrainingPageState extends State<_PlayerTrainingPage> {
  final PlayerRepository _repository = PlayerRepository.instance;

  final TextEditingController _modeController = TextEditingController();
  final TextEditingController _scoreController = TextEditingController();
  final TextEditingController _averageController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows;

  @override
  void dispose() {
    _modeController.dispose();
    _scoreController.dispose();
    _averageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final player = _repository.playerById(widget.player.id) ?? widget.player;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Training - ${player.preferences.displayName ?? player.name}'),
      ),
      body: ExcludeSemantics(
        excluding: _suppressAccessibilityUpdates,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
          _SectionCard(
            title: 'Training eintragen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _modeController,
                  decoration: const InputDecoration(labelText: 'Trainingsmodus'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _scoreController,
                  decoration: const InputDecoration(labelText: 'Ergebnis / Punkte'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _averageController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Average optional'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notiz optional'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    if (_modeController.text.trim().isEmpty ||
                        _scoreController.text.trim().isEmpty) {
                      return;
                    }
                    _repository.recordTrainingSession(
                      playerId: player.id,
                      mode: _modeController.text,
                      scoreLabel: _scoreController.text,
                      average: double.tryParse(
                        _averageController.text.trim().replaceAll(',', '.'),
                      ),
                      notes: _notesController.text,
                    );
                    _modeController.clear();
                    _scoreController.clear();
                    _averageController.clear();
                    _notesController.clear();
                    setState(() {});
                  },
                  child: const Text('Training speichern'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Letzte Trainings',
            child: player.trainingHistory.isEmpty
                ? const Text('Noch keine Trainingseintraege vorhanden.')
                : Column(
                    children: player.trainingHistory
                        .take(20)
                        .map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${entry.mode} - ${entry.scoreLabel}',
                                    style: theme.textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_formatDateTime(entry.playedAt)}${entry.average == null ? '' : ' - Avg ${entry.average!.toStringAsFixed(1)}'}${entry.equipmentName == null ? '' : ' - ${entry.equipmentName}'}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          ],
        ),
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

class _ProfileMiniStat extends StatelessWidget {
  const _ProfileMiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium,
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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

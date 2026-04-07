import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/export/file_export_service.dart';
import '../../data/models/computer_player.dart';
import '../../data/repositories/computer_repository.dart';
import '../../data/storage/app_storage.dart';

enum _PlayerSortOption {
  theoreticalAverage,
  realAverage,
  age,
  matches,
  wins,
  alphabetical,
}

enum _TriStateChoice {
  unchanged,
  yes,
  no,
}

class _DatabasePreset {
  const _DatabasePreset({
    required this.name,
    required this.data,
  });

  final String name;
  final Map<String, dynamic> data;
}

class _VisiblePlayersCacheEntry {
  const _VisiblePlayersCacheEntry({
    required this.key,
    required this.players,
  });

  final String key;
  final List<ComputerPlayer> players;
}

class _HeadToHeadSummary {
  const _HeadToHeadSummary({
    required this.opponentName,
    required this.matches,
    required this.wins,
    required this.average,
    required this.lastPlayedAt,
    required this.lastResultWon,
  });

  final String opponentName;
  final int matches;
  final int wins;
  final double average;
  final DateTime lastPlayedAt;
  final bool lastResultWon;

  int get losses => matches - wins;
  double get winRate => matches <= 0 ? 0 : (wins / matches) * 100;
}

class ComputerDatabaseScreen extends StatefulWidget {
  const ComputerDatabaseScreen({super.key});

  @override
  State<ComputerDatabaseScreen> createState() => _ComputerDatabaseScreenState();
}

class _ComputerDatabaseScreenState extends State<ComputerDatabaseScreen> {
  final ComputerRepository _repository = ComputerRepository.instance;
  final FileExportService _fileExportService = createFileExportService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _theoreticalAverageController =
      TextEditingController(text: '60.0');
  final TextEditingController _skillController = TextEditingController();
  final TextEditingController _finishingSkillController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _newTagController = TextEditingController();

  final TextEditingController _bulkPrefixController =
      TextEditingController(text: 'CPU');
  final TextEditingController _bulkCountController =
      TextEditingController(text: '10');
  final TextEditingController _bulkMinAverageController =
      TextEditingController(text: '80');
  final TextEditingController _bulkMaxAverageController =
      TextEditingController(text: '95');
  final TextEditingController _bulkMinAgeController = TextEditingController();
  final TextEditingController _bulkMaxAgeController = TextEditingController();

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _filterMinTheoController =
      TextEditingController();
  final TextEditingController _filterMaxTheoController =
      TextEditingController();
  final TextEditingController _filterMinAgeController = TextEditingController();
  final TextEditingController _filterMaxAgeController = TextEditingController();

  final TextEditingController _bulkEditMinAgeController =
      TextEditingController();
  final TextEditingController _bulkEditMaxAgeController =
      TextEditingController();

  String? _editingId;
  String? _selectedNationality;
  final List<String> _draftTags = <String>[];
  final List<String> _bulkNationalities = <String>[];
  final List<String> _bulkTags = <String>[];
  bool _useCustomSkills = false;

  String? _filterNationality;
  String? _filterTag;
  ComputerPlayerSource? _filterSource;
  bool _onlyRealPlayers = false;
  bool _onlyFavorites = false;
  bool _onlyProtected = false;
  _PlayerSortOption _sortOption = _PlayerSortOption.theoreticalAverage;
  bool _sortDescending = true;

  final Set<String> _selectedPlayerIds = <String>{};
  String? _bulkEditNationality;
  bool _bulkEditClearNationality = false;
  bool _bulkEditClearAge = false;
  _TriStateChoice _bulkEditFavoriteChoice = _TriStateChoice.unchanged;
  _TriStateChoice _bulkEditProtectedChoice = _TriStateChoice.unchanged;
  final Set<String> _bulkEditAddTags = <String>{};
  final Set<String> _bulkEditRemoveTags = <String>{};
  final List<_DatabasePreset> _savedPresets = <_DatabasePreset>[];
  final Set<String> _visibleColumns = <String>{
    'name',
    'source',
    'theo',
    'real',
    'age',
    'nationality',
    'tags',
    'stats',
    'actions',
  };
  int _manualTablePage = 0;
  int _bulkTablePage = 0;
  int _manualRowsPerPage = 10;
  int _bulkRowsPerPage = 10;
  _VisiblePlayersCacheEntry? _manualVisiblePlayersCache;
  _VisiblePlayersCacheEntry? _bulkVisiblePlayersCache;
  bool _expertMode = false;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _theoreticalAverageController.dispose();
    _skillController.dispose();
    _finishingSkillController.dispose();
    _birthDateController.dispose();
    _newTagController.dispose();
    _bulkPrefixController.dispose();
    _bulkCountController.dispose();
    _bulkMinAverageController.dispose();
    _bulkMaxAverageController.dispose();
    _bulkMinAgeController.dispose();
    _bulkMaxAgeController.dispose();
    _searchController.dispose();
    _filterMinTheoController.dispose();
    _filterMaxTheoController.dispose();
    _filterMinAgeController.dispose();
    _filterMaxAgeController.dispose();
    _bulkEditMinAgeController.dispose();
    _bulkEditMaxAgeController.dispose();
    super.dispose();
  }

  double? _parseDouble(String rawValue) {
    final normalized = rawValue.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  DateTime? _parseBirthDate(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) {
      return DateTime(iso.year, iso.month, iso.day);
    }
    final parts = trimmed.split(RegExp(r'[./-]'));
    if (parts.length != 3) {
      return null;
    }
    final first = int.tryParse(parts[0]);
    final second = int.tryParse(parts[1]);
    final third = int.tryParse(parts[2]);
    if (first == null || second == null || third == null) {
      return null;
    }
    if (parts[0].length == 4) {
      return DateTime.tryParse(
        '${first.toString().padLeft(4, '0')}-${second.toString().padLeft(2, '0')}-${third.toString().padLeft(2, '0')}',
      );
    }
    return DateTime.tryParse(
      '${third.toString().padLeft(4, '0')}-${second.toString().padLeft(2, '0')}-${first.toString().padLeft(2, '0')}',
    );
  }

  String _formatBirthDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  bool _isRealPlayer(ComputerPlayer player) {
    return player.tags.any((tag) => tag.toLowerCase() == 'echter spieler');
  }

  void _toggleDraftTag(String definition) {
    setState(() {
      final existingIndex = _draftTags.indexWhere(
        (entry) => entry.toLowerCase() == definition.toLowerCase(),
      );
      if (existingIndex >= 0) {
        _draftTags.removeAt(existingIndex);
        return;
      }
      _draftTags.add(definition);
    });
  }

  void _toggleBulkNationality(String nationality) {
    setState(() {
      final index = _bulkNationalities.indexWhere(
        (entry) => entry.toLowerCase() == nationality.toLowerCase(),
      );
      if (index >= 0) {
        _bulkNationalities.removeAt(index);
        return;
      }
      _bulkNationalities.add(nationality);
    });
  }

  void _toggleBulkTag(String tag) {
    setState(() {
      final index = _bulkTags.indexWhere(
        (entry) => entry.toLowerCase() == tag.toLowerCase(),
      );
      if (index >= 0) {
        _bulkTags.removeAt(index);
        return;
      }
      _bulkTags.add(tag);
    });
  }

  void _togglePlayerSelection(String playerId) {
    setState(() {
      if (_selectedPlayerIds.contains(playerId)) {
        _selectedPlayerIds.remove(playerId);
      } else {
        _selectedPlayerIds.add(playerId);
      }
    });
  }

  void _selectVisiblePlayers(Iterable<ComputerPlayer> players) {
    setState(() {
      _selectedPlayerIds.addAll(players.map((player) => player.id));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPlayerIds.clear();
    });
  }

  int _tablePage(bool bulkOnly) => bulkOnly ? _bulkTablePage : _manualTablePage;

  int _tableRowsPerPage(bool bulkOnly) =>
      bulkOnly ? _bulkRowsPerPage : _manualRowsPerPage;

  void _setTablePage(bool bulkOnly, int page) {
    setState(() {
      if (bulkOnly) {
        _bulkTablePage = math.max(0, page);
      } else {
        _manualTablePage = math.max(0, page);
      }
    });
  }

  void _setTableRowsPerPage(bool bulkOnly, int rowsPerPage) {
    setState(() {
      if (bulkOnly) {
        _bulkRowsPerPage = rowsPerPage;
        _bulkTablePage = 0;
      } else {
        _manualRowsPerPage = rowsPerPage;
        _manualTablePage = 0;
      }
    });
  }

  void _toggleBulkEditAddTag(String tag) {
    setState(() {
      _bulkEditRemoveTags.removeWhere(
        (entry) => entry.toLowerCase() == tag.toLowerCase(),
      );
      final existing = _bulkEditAddTags.lookup(tag);
      if (existing != null) {
        _bulkEditAddTags.remove(existing);
      } else {
        _bulkEditAddTags.add(tag);
      }
    });
  }

  void _toggleBulkEditRemoveTag(String tag) {
    setState(() {
      _bulkEditAddTags.removeWhere(
        (entry) => entry.toLowerCase() == tag.toLowerCase(),
      );
      final existing = _bulkEditRemoveTags.lookup(tag);
      if (existing != null) {
        _bulkEditRemoveTags.remove(existing);
      } else {
        _bulkEditRemoveTags.add(tag);
      }
    });
  }

  void _submit() {
    if (!_validateManualInputs()) {
      return;
    }
    final name = _nameController.text.trim();
    final targetAverage = _parseDouble(_theoreticalAverageController.text);
    final customSkill = int.tryParse(_skillController.text.trim());
    final customFinishingSkill = int.tryParse(
      _finishingSkillController.text.trim(),
    );
    final birthDate = _parseBirthDate(_birthDateController.text);
    if (name.isEmpty || (!_useCustomSkills && targetAverage == null)) {
      return;
    }

    if (_editingId == null) {
      _repository.addPlayer(
        name: name,
        targetTheoreticalAverage: (targetAverage ?? 0).clamp(0, 180).toDouble(),
        skill: _useCustomSkills ? customSkill : null,
        finishingSkill: _useCustomSkills ? customFinishingSkill : null,
        birthDate: birthDate,
        nationality: _selectedNationality,
        tags: List<String>.from(_draftTags),
        source: ComputerPlayerSource.manual,
      );
    } else {
      final existing = _repository.players.firstWhere(
        (player) => player.id == _editingId,
      );
      _repository.updatePlayer(
        id: _editingId!,
        name: name,
        targetTheoreticalAverage: (targetAverage ?? 0).clamp(0, 180).toDouble(),
        skill: _useCustomSkills ? customSkill : null,
        finishingSkill: _useCustomSkills ? customFinishingSkill : null,
        birthDate: birthDate,
        nationality: _selectedNationality,
        tags: List<String>.from(_draftTags),
        source: existing.source,
        isFavorite: existing.isFavorite,
        isProtected: existing.isProtected,
      );
    }

    _clearForm();
  }

  void _clearForm() {
    setState(() {
      _editingId = null;
      _nameController.clear();
      _theoreticalAverageController.text = '60.0';
      _skillController.clear();
      _finishingSkillController.clear();
      _birthDateController.clear();
      _selectedNationality = null;
      _draftTags.clear();
      _useCustomSkills = false;
    });
  }

  void _edit(ComputerPlayer player) {
    setState(() {
      _editingId = player.id;
      _nameController.text = player.name;
      _theoreticalAverageController.text =
          player.theoreticalAverage.toStringAsFixed(1);
      _skillController.text = player.skill.toString();
      _finishingSkillController.text = player.finishingSkill.toString();
      _birthDateController.text =
          player.birthDate == null ? '' : _formatBirthDate(player.birthDate);
      _selectedNationality = player.nationality;
      _draftTags
        ..clear()
        ..addAll(player.tags);
      _useCustomSkills = false;
    });
  }

  void _addTagDefinition() {
    final name = _newTagController.text.trim();
    if (name.isEmpty) {
      return;
    }
    _repository.addTagDefinition(name);
    _toggleDraftTag(name);
    _newTagController.clear();
  }

  void _createBulkPlayers() {
    if (!_validateBulkInputs()) {
      return;
    }
    final count = int.tryParse(_bulkCountController.text.trim());
    final minAverage = _parseDouble(_bulkMinAverageController.text);
    final maxAverage = _parseDouble(_bulkMaxAverageController.text);
    final minAge = int.tryParse(_bulkMinAgeController.text.trim());
    final maxAge = int.tryParse(_bulkMaxAgeController.text.trim());
    if (count == null || minAverage == null || maxAverage == null) {
      return;
    }

    _repository.addPlayersBulk(
      namePrefix: _bulkPrefixController.text,
      count: count,
      minimumAverage: minAverage,
      maximumAverage: maxAverage,
      minimumAge: minAge,
      maximumAge: maxAge,
      nationalities: List<String>.from(_bulkNationalities),
      tags: List<String>.from(_bulkTags),
    );

    setState(() {
      _bulkPrefixController.text = 'CPU';
      _bulkCountController.text = '10';
      _bulkMinAverageController.text = '80';
      _bulkMaxAverageController.text = '95';
      _bulkMinAgeController.clear();
      _bulkMaxAgeController.clear();
      _bulkNationalities.clear();
      _bulkTags.clear();
    });
  }

  void _applyBulkEdits(List<ComputerPlayer> visiblePlayers) {
    final selectedIds = _visibleSelection(visiblePlayers);
    if (selectedIds.isEmpty) {
      return;
    }

    final minimumAge = int.tryParse(_bulkEditMinAgeController.text.trim());
    final maximumAge = int.tryParse(_bulkEditMaxAgeController.text.trim());
    _repository.bulkUpdatePlayers(
      ids: selectedIds,
      nationality: _bulkEditNationality,
      clearNationality: _bulkEditClearNationality,
      minimumAge: minimumAge,
      maximumAge: maximumAge,
      clearAge: _bulkEditClearAge,
      addTags: _bulkEditAddTags.toList(),
      removeTags: _bulkEditRemoveTags.toList(),
      isFavorite: _bulkEditFavoriteChoice == _TriStateChoice.unchanged
          ? null
          : _bulkEditFavoriteChoice == _TriStateChoice.yes,
      isProtected: _bulkEditProtectedChoice == _TriStateChoice.unchanged
          ? null
          : _bulkEditProtectedChoice == _TriStateChoice.yes,
    );

    setState(() {
      _bulkEditNationality = null;
      _bulkEditClearNationality = false;
      _bulkEditMinAgeController.clear();
      _bulkEditMaxAgeController.clear();
      _bulkEditClearAge = false;
      _bulkEditFavoriteChoice = _TriStateChoice.unchanged;
      _bulkEditProtectedChoice = _TriStateChoice.unchanged;
      _bulkEditAddTags.clear();
      _bulkEditRemoveTags.clear();
    });
  }

  void _deleteSelectedPlayers(List<ComputerPlayer> visiblePlayers) {
    final selectedIds = _visibleSelection(visiblePlayers);
    if (selectedIds.isEmpty) {
      return;
    }
    _repository.deletePlayers(selectedIds);
    setState(() {
      _selectedPlayerIds.removeWhere(
        (id) => !_repository.players.any((player) => player.id == id),
      );
    });
  }

  void _deleteFilteredPlayers(Iterable<ComputerPlayer> players) {
    _repository.deletePlayers(players.map((player) => player.id));
    setState(() {
      _selectedPlayerIds.removeWhere(
        (id) => !_repository.players.any((player) => player.id == id),
      );
    });
  }

  void _tagCurrentPlayersAsReal() {
    _repository.assignTagToAllPlayers('Echter Spieler');
  }

  Future<void> _refreshTheoreticalAveragesWithLoading() async {
    final mode = await _showTheoRefreshModeDialog();
    if (mode == null) {
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    final repository = _repository;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AnimatedBuilder(
          animation: repository,
          builder: (context, _) {
            final progress = repository.theoreticalRefreshProgress;
            final label = repository.theoreticalRefreshLabel.isNotEmpty
                ? repository.theoreticalRefreshLabel
                : 'Theoretische Averages werden neu berechnet...';
            final hasDeterminateProgress = progress > 0 && progress <= 1;
            final percentText =
                '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}%';
            return AlertDialog(
              title: const Text('Theo-Berechnung laeuft'),
              content: ExcludeSemantics(
                excluding: _suppressAccessibilityUpdates,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 42,
                            height: 42,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              value: hasDeterminateProgress ? progress : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  hasDeterminateProgress
                                      ? '$percentText abgeschlossen'
                                      : 'Berechnung wird vorbereitet...',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Bitte die App waehrend der Berechnung offen lassen.',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Hinweis: Die erste Berechnung mit neuen Einstellungen kann deutlich laenger dauern.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 12,
                          value: hasDeterminateProgress ? progress : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(label),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        hasDeterminateProgress
                            ? 'Fortschritt wird laufend aktualisiert.'
                            : 'Der Fortschritt springt an, sobald die ersten Referenz-Matches abgeschlossen sind.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      try {
        await _repository.refreshTheoreticalAverages(mode: mode);
      } finally {
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    _showMessage('Theoretische Averages wurden neu berechnet.');
  }

  Future<ComputerTheoRefreshMode?> _showTheoRefreshModeDialog() {
    return showDialog<ComputerTheoRefreshMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Theo-Berechnung'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Bitte den Berechnungsmodus auswaehlen.'),
              SizedBox(height: 12),
              Text('Schnell: sehr leicht, grobere Naeherung'),
              Text('Standard: guter Mittelweg'),
              Text('Praezise: 100 Referenzmatches, deutlich langsamer'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ComputerTheoRefreshMode.fast),
              child: const Text('Schnell'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(ComputerTheoRefreshMode.standard),
              child: const Text('Standard'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(ComputerTheoRefreshMode.precise),
              child: const Text('Praezise'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _displayAuditReason(String value) {
    switch (value) {
      case 'manual_create':
        return 'Manuell erstellt';
      case 'manual_update':
        return 'Manuell bearbeitet';
      case 'bulk_create':
        return 'Per Bulk-Erstellung erzeugt';
      case 'bulk_edit':
        return 'Per Mehrfachbearbeitung angepasst';
      case 'record_match':
        return 'Matchhistorie aktualisiert';
      case 'toggle_favorite':
        return 'Favoritenstatus geaendert';
      case 'toggle_protected':
        return 'Schutzstatus geaendert';
      case 'assign_tag_all':
        return 'Globaler Tag gesetzt';
      case 'tour_card_import':
        return 'Tour-Card-Import';
      case 'electron_import':
        return 'Electron-Import';
      case 'legacy_import':
        return 'Altbestand importiert';
      case 'seed_default':
        return 'Standardwert';
      default:
        return value;
    }
  }

  Future<void> _loadPresets() async {
    final json = await AppStorage.instance.readJsonMap('computer_database_ui');
    final presets = (json?['presets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((entry) {
          final map = entry.cast<String, dynamic>();
          return _DatabasePreset(
            name: map['name'] as String? ?? 'Preset',
            data: (map['data'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{},
          );
        })
        .toList();
    final columns = (json?['visibleColumns'] as List<dynamic>? ?? const <dynamic>[])
        .map((entry) => entry.toString())
        .toSet();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedPresets
        ..clear()
        ..addAll(presets);
      if (columns.isNotEmpty) {
        _visibleColumns
          ..clear()
          ..addAll(columns);
      }
    });
  }

  Future<void> _persistUiState() {
    return AppStorage.instance.writeJson(
      'computer_database_ui',
      <String, dynamic>{
        'presets': _savedPresets
            .map((preset) => <String, dynamic>{
                  'name': preset.name,
                  'data': preset.data,
                })
            .toList(),
        'visibleColumns': _visibleColumns.toList(),
      },
    );
  }

  Map<String, dynamic> _captureCurrentPresetData() {
    return <String, dynamic>{
      'filterNationality': _filterNationality,
      'filterTag': _filterTag,
      'filterSource': _filterSource?.storageValue,
      'onlyRealPlayers': _onlyRealPlayers,
      'onlyFavorites': _onlyFavorites,
      'onlyProtected': _onlyProtected,
      'sortOption': _sortOption.name,
      'sortDescending': _sortDescending,
      'search': _searchController.text,
      'filterMinTheo': _filterMinTheoController.text,
      'filterMaxTheo': _filterMaxTheoController.text,
      'filterMinAge': _filterMinAgeController.text,
      'filterMaxAge': _filterMaxAgeController.text,
      'visibleColumns': _visibleColumns.toList(),
    };
  }

  void _applyPreset(_DatabasePreset preset) {
    final data = preset.data;
    setState(() {
      _filterNationality = data['filterNationality'] as String?;
      _filterTag = data['filterTag'] as String?;
      _filterSource = ComputerPlayerSourceSerialization.fromStorageValue(
        data['filterSource'] as String?,
      );
      _onlyRealPlayers = data['onlyRealPlayers'] as bool? ?? false;
      _onlyFavorites = data['onlyFavorites'] as bool? ?? false;
      _onlyProtected = data['onlyProtected'] as bool? ?? false;
      _sortOption = _PlayerSortOption.values.firstWhere(
        (value) => value.name == data['sortOption'],
        orElse: () => _PlayerSortOption.theoreticalAverage,
      );
      _sortDescending = data['sortDescending'] as bool? ?? true;
      _searchController.text = data['search'] as String? ?? '';
      _filterMinTheoController.text = data['filterMinTheo'] as String? ?? '';
      _filterMaxTheoController.text = data['filterMaxTheo'] as String? ?? '';
      _filterMinAgeController.text = data['filterMinAge'] as String? ?? '';
      _filterMaxAgeController.text = data['filterMaxAge'] as String? ?? '';
      final columns = (data['visibleColumns'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .toSet();
      if (columns.isNotEmpty) {
        _visibleColumns
          ..clear()
          ..addAll(columns);
      }
    });
  }

  Future<void> _saveCurrentPreset() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Preset speichern'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Preset-Name'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) {
                  return;
                }
                final navigator = Navigator.of(context);
                _savedPresets.removeWhere(
                  (preset) => preset.name.toLowerCase() == name.toLowerCase(),
                );
                _savedPresets.add(
                  _DatabasePreset(
                    name: name,
                    data: _captureCurrentPresetData(),
                  ),
                );
                await _persistUiState();
                if (mounted) {
                  navigator.pop();
                  _showMessage('Preset gespeichert.');
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToFile({
    required String format,
    required String content,
  }) async {
    final filePath = await _fileExportService.exportTextFile(
      folderName: 'exports',
      fileName:
          'computer_players_${DateTime.now().millisecondsSinceEpoch}.$format',
      content: content,
    );
    if (filePath == null) {
      _showMessage('Dateiexport ist auf dieser Plattform nicht verfuegbar.');
      return;
    }
    _showMessage('Datei exportiert nach $filePath');
  }

  bool _validateManualInputs() {
    final name = _nameController.text.trim();
    final targetAverage = _parseDouble(_theoreticalAverageController.text);
    final skill = int.tryParse(_skillController.text.trim());
    final finishingSkill = int.tryParse(_finishingSkillController.text.trim());
    final birthDateText = _birthDateController.text.trim();
    final birthDate = _parseBirthDate(birthDateText);
    if (name.isEmpty) {
      _showMessage('Bitte einen Namen eingeben.');
      return false;
    }
    if (!_useCustomSkills &&
        (targetAverage == null || targetAverage < 0 || targetAverage > 180)) {
      _showMessage('Theo Average muss zwischen 0 und 180 liegen.');
      return false;
    }
    if (_useCustomSkills) {
      if (skill == null || skill < 1 || skill > 1000) {
        _showMessage('Skill muss zwischen 1 und 1000 liegen.');
        return false;
      }
      if (finishingSkill == null ||
          finishingSkill < 1 ||
          finishingSkill > 1000) {
        _showMessage('Finishing Skill muss zwischen 1 und 1000 liegen.');
        return false;
      }
    }
    if (birthDateText.isNotEmpty && birthDate == null) {
      _showMessage('Geburtsdatum bitte als TT.MM.JJJJ oder JJJJ-MM-TT eingeben.');
      return false;
    }
    return true;
  }

  bool _validateBulkInputs() {
    final count = int.tryParse(_bulkCountController.text.trim());
    final minAverage = _parseDouble(_bulkMinAverageController.text);
    final maxAverage = _parseDouble(_bulkMaxAverageController.text);
    final minAge = int.tryParse(_bulkMinAgeController.text.trim());
    final maxAge = int.tryParse(_bulkMaxAgeController.text.trim());
    if (count == null || count < 1 || count > 500) {
      _showMessage('Anzahl muss zwischen 1 und 500 liegen.');
      return false;
    }
    if (minAverage == null ||
        maxAverage == null ||
        minAverage < 0 ||
        minAverage > 180 ||
        maxAverage < 0 ||
        maxAverage > 180) {
      _showMessage('Theo Average muss zwischen 0 und 180 liegen.');
      return false;
    }
    if (minAge != null && (minAge < 10 || minAge > 100)) {
      _showMessage('Minimum Alter muss zwischen 10 und 100 liegen.');
      return false;
    }
    if (maxAge != null && (maxAge < 10 || maxAge > 100)) {
      _showMessage('Maximum Alter muss zwischen 10 und 100 liegen.');
      return false;
    }
    return true;
  }

  Set<String> _visibleSelection(Iterable<ComputerPlayer> visiblePlayers) {
    final visibleIds = visiblePlayers.map((player) => player.id).toSet();
    return _selectedPlayerIds.where(visibleIds.contains).toSet();
  }

  Future<void> _showExportDialog({
    required String title,
    required String content,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 800,
            child: SingleChildScrollView(
              child: SelectableText(content),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Schliessen'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImportDialog({required bool json}) async {
    final controller = TextEditingController();
    var replaceExisting = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(json ? 'JSON importieren' : 'CSV importieren'),
              content: SizedBox(
                width: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: controller,
                      minLines: 12,
                      maxLines: 20,
                      decoration: InputDecoration(
                        labelText: json ? 'JSON Inhalt' : 'CSV Inhalt',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bestehende Spieler ersetzen'),
                      value: replaceExisting,
                      onChanged: (value) {
                        setStateDialog(() {
                          replaceExisting = value ?? false;
                        });
                      },
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
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    try {
                      if (json) {
                        await _repository.importFromJsonString(
                          controller.text,
                          replaceExisting: replaceExisting,
                        );
                      } else {
                        await _repository.importFromCsvString(
                          controller.text,
                          replaceExisting: replaceExisting,
                        );
                      }
                      navigator.pop();
                      _showMessage('Import erfolgreich.');
                    } catch (_) {
                      _showMessage('Import fehlgeschlagen. Bitte Format pruefen.');
                    }
                  },
                  child: const Text('Importieren'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openPlayerDetails(ComputerPlayer player) async {
    final grouped = <String, List<ComputerMatchHistoryEntry>>{};
    for (final entry in player.history) {
      grouped
          .putIfAbsent(entry.opponentName, () => <ComputerMatchHistoryEntry>[])
          .add(entry);
    }
    final headToHeadRows = grouped.entries
        .map((entry) {
          final matches = entry.value.length;
          final wins = entry.value.where((match) => match.won).length;
          final average = entry.value.fold<double>(
                0,
                (sum, match) => sum + match.average,
              ) /
              matches;
          final sortedEntries = List<ComputerMatchHistoryEntry>.from(entry.value)
            ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
          final lastMatch = sortedEntries.first;
          return _HeadToHeadSummary(
            opponentName: entry.key,
            matches: matches,
            wins: wins,
            average: average,
            lastPlayedAt: lastMatch.playedAt,
            lastResultWon: lastMatch.won,
          );
        })
        .toList()
      ..sort((left, right) {
        final byMatches = right.matches.compareTo(left.matches);
        if (byMatches != 0) {
          return byMatches;
        }
        return right.lastPlayedAt.compareTo(left.lastPlayedAt);
      });
    final winRate = player.matchesPlayed <= 0
        ? 0.0
        : (player.matchesWon / player.matchesPlayed) * 100;
    final lastForm =
        player.history.take(5).map((entry) => entry.won ? 'W' : 'L').join(' ');
    final recentAverages = player.history
        .take(12)
        .toList()
        .reversed
        .map((entry) => entry.average)
        .toList();
    final recentMatches = player.history.take(8).toList();
    final trendDelta = recentAverages.length < 2
        ? 0.0
        : recentAverages.last - recentAverages.first;
    final realAverage = player.average.toStringAsFixed(1);
    final sourceLabel = switch (player.source) {
      ComputerPlayerSource.imported => 'Importiert',
      ComputerPlayerSource.manual => 'Manuell',
      ComputerPlayerSource.bulk => 'Bulk',
    };

    await showDialog<void>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 980,
              maxHeight: 760,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              player.name,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$sourceLabel · ${player.nationality ?? 'Keine Nationalitaet'}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Schliessen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _StatisticTile(
                        label: 'Theo',
                        value: player.theoreticalAverage.toStringAsFixed(1),
                      ),
                      _StatisticTile(
                        label: 'Real Average',
                        value: realAverage,
                      ),
                      _StatisticTile(
                        label: 'Winrate',
                        value: '${winRate.toStringAsFixed(1)} %',
                      ),
                      _StatisticTile(
                        label: 'Matches',
                        value: '${player.matchesPlayed}',
                      ),
                      _StatisticTile(
                        label: 'Form',
                        value: lastForm.isEmpty ? '-' : lastForm,
                      ),
                      _StatisticTile(
                        label: 'Trend',
                        value:
                            '${trendDelta >= 0 ? '+' : ''}${trendDelta.toStringAsFixed(1)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Verlaufsgrafik',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 180,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: recentAverages.length < 2
                                ? const Center(
                                    child: Text('Zu wenig Daten fuer Verlauf.'),
                                  )
                                : CustomPaint(
                                    painter: _AverageTrendPainter(
                                      values: recentAverages,
                                      lineColor: theme.colorScheme.primary,
                                      guideColor:
                                          theme.colorScheme.outlineVariant,
                                      textColor: theme.colorScheme.onSurface,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Head-to-Head',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (headToHeadRows.isEmpty)
                            const Text('Noch keine Gegnerdaten vorhanden.')
                          else
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DataTable(
                                columns: const <DataColumn>[
                                  DataColumn(label: Text('Gegner')),
                                  DataColumn(label: Text('Bilanz')),
                                  DataColumn(label: Text('Winrate')),
                                  DataColumn(label: Text('Avg')),
                                  DataColumn(label: Text('Letztes Match')),
                                ],
                                rows: headToHeadRows.take(10).map((entry) {
                                  return DataRow(
                                    cells: <DataCell>[
                                      DataCell(Text(entry.opponentName)),
                                      DataCell(
                                        Text(
                                          '${entry.wins}-${entry.losses} (${entry.matches})',
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${entry.winRate.toStringAsFixed(1)} %',
                                        ),
                                      ),
                                      DataCell(
                                        Text(entry.average.toStringAsFixed(1)),
                                      ),
                                      DataCell(
                                        Text(
                                          '${entry.lastResultWon ? 'Sieg' : 'Niederlage'} · ${_formatDateTime(entry.lastPlayedAt)}',
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            'Letzte Matches',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (recentMatches.isEmpty)
                            const Text('Noch keine Matchhistorie vorhanden.')
                          else
                            ...recentMatches.map((entry) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  entry.won
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: entry.won
                                      ? Colors.green
                                      : theme.colorScheme.error,
                                ),
                                title: Text(
                                  '${entry.opponentName} · ${entry.scoreText}',
                                ),
                                subtitle: Text(
                                  '${_formatDateTime(entry.playedAt)} · Avg ${entry.average.toStringAsFixed(1)}',
                                ),
                              );
                            }),
                          const SizedBox(height: 12),
                          Text(
                            'Audit',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('Erstellt: ${_formatDateTime(player.createdAt)}'),
                          Text(
                            'Zuletzt geaendert: ${_formatDateTime(player.updatedAt)}',
                          ),
                          Text(
                            'Letzte Aenderung: ${_displayAuditReason(player.lastModifiedReason)}',
                          ),
                          if (player.tags.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              'Tags',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: player.tags
                                  .map((tag) => Chip(label: Text(tag)))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showTheoSkillValues(ComputerPlayer player) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Skill-Werte - ${player.name}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Theo Average: ${player.theoreticalAverage.toStringAsFixed(1)}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatisticTile(
                      label: 'Skill',
                      value: '${player.skill}',
                    ),
                    _StatisticTile(
                      label: 'Finishing Skill',
                      value: '${player.finishingSkill}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Schliessen'),
            ),
          ],
        );
      },
    );
  }

  List<ComputerPlayer> _visiblePlayers({required bool bulkOnly}) {
    final query = _searchController.text.trim().toLowerCase();
    final minTheo = _parseDouble(_filterMinTheoController.text);
    final maxTheo = _parseDouble(_filterMaxTheoController.text);
    final minAge = int.tryParse(_filterMinAgeController.text.trim());
    final maxAge = int.tryParse(_filterMaxAgeController.text.trim());
    final lowTheo = minTheo == null && maxTheo == null
        ? null
        : ((minTheo ?? maxTheo ?? 0) <= (maxTheo ?? minTheo ?? 0)
            ? (minTheo ?? maxTheo ?? 0)
            : (maxTheo ?? minTheo ?? 0));
    final highTheo = minTheo == null && maxTheo == null
        ? null
        : ((minTheo ?? maxTheo ?? 0) <= (maxTheo ?? minTheo ?? 0)
            ? (maxTheo ?? minTheo ?? 0)
            : (minTheo ?? maxTheo ?? 0));
    final lowAge = minAge == null && maxAge == null
        ? null
        : ((minAge ?? maxAge ?? 0) <= (maxAge ?? minAge ?? 0)
            ? (minAge ?? maxAge ?? 0)
            : (maxAge ?? minAge ?? 0));
    final highAge = minAge == null && maxAge == null
        ? null
        : ((minAge ?? maxAge ?? 0) <= (maxAge ?? minAge ?? 0)
            ? (maxAge ?? minAge ?? 0)
            : (minAge ?? maxAge ?? 0));
    final cacheKey = <Object?>[
      bulkOnly,
      _repository.changeToken,
      query,
      lowTheo,
      highTheo,
      lowAge,
      highAge,
      _filterNationality,
      _filterTag?.toLowerCase(),
      _filterSource,
      _onlyRealPlayers,
      _onlyFavorites,
      _onlyProtected,
      _sortOption,
      _sortDescending,
    ].join('|');
    final cacheEntry =
        bulkOnly ? _bulkVisiblePlayersCache : _manualVisiblePlayersCache;
    if (cacheEntry != null && cacheEntry.key == cacheKey) {
      return cacheEntry.players;
    }

    final players = _repository.players.where((player) {
      if (bulkOnly && player.source != ComputerPlayerSource.bulk) {
        return false;
      }
      if (!bulkOnly && player.source == ComputerPlayerSource.bulk) {
        return false;
      }
      if (_filterSource != null && player.source != _filterSource) {
        return false;
      }
      if (query.isNotEmpty && !player.name.toLowerCase().contains(query)) {
        return false;
      }
      if (_filterNationality != null &&
          player.nationality != _filterNationality) {
        return false;
      }
      if (_filterTag != null &&
          !player.tags.any(
            (tag) => tag.toLowerCase() == _filterTag!.toLowerCase(),
          )) {
        return false;
      }
      if (_onlyRealPlayers && !_isRealPlayer(player)) {
        return false;
      }
      if (_onlyFavorites && !player.isFavorite) {
        return false;
      }
      if (_onlyProtected && !player.isProtected) {
        return false;
      }
      if (lowTheo != null &&
          (player.theoreticalAverage < lowTheo ||
              player.theoreticalAverage > highTheo!)) {
        return false;
      }
      if (lowAge != null) {
        final age = player.effectiveAge;
        if (age == null || age < lowAge || age > highAge!) {
          return false;
        }
      }
      return true;
    }).toList();

    players.sort((left, right) {
      int result;
      switch (_sortOption) {
        case _PlayerSortOption.theoreticalAverage:
          result = left.theoreticalAverage.compareTo(right.theoreticalAverage);
        case _PlayerSortOption.realAverage:
          result = left.average.compareTo(right.average);
        case _PlayerSortOption.age:
          result = (left.effectiveAge ?? -1).compareTo(right.effectiveAge ?? -1);
        case _PlayerSortOption.matches:
          result = left.matchesPlayed.compareTo(right.matchesPlayed);
        case _PlayerSortOption.wins:
          result = left.matchesWon.compareTo(right.matchesWon);
        case _PlayerSortOption.alphabetical:
          result = left.name.toLowerCase().compareTo(right.name.toLowerCase());
      }
      return _sortDescending ? -result : result;
    });

    final cachedPlayers = List<ComputerPlayer>.unmodifiable(players);
    final nextEntry = _VisiblePlayersCacheEntry(
      key: cacheKey,
      players: cachedPlayers,
    );
    if (bulkOnly) {
      _bulkVisiblePlayersCache = nextEntry;
    } else {
      _manualVisiblePlayersCache = nextEntry;
    }

    return cachedPlayers;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _repository,
      builder: (context, _) {
        if (!_expertMode) {
          final visiblePlayers = _visiblePlayers(bulkOnly: false);
          return Scaffold(
            appBar: AppBar(
              title: const Text('Computer-Datenbank'),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _expertMode = true;
                    });
                  },
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Expertenmodus'),
                ),
              ],
            ),
            body: ExcludeSemantics(
              excluding: _suppressAccessibilityUpdates,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Standardansicht',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Schneller Zugriff auf Suche, neue Gegner und eine lesbare Kartenansicht. Bulk-Aktionen und Tabellen gibt es nur im Expertenmodus.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildManualCreationCard(context),
                  const SizedBox(height: 20),
                  _buildFilterCard(
                    context,
                    bulkOnly: false,
                    visiblePlayers: visiblePlayers,
                  ),
                  const SizedBox(height: 20),
                  if (visiblePlayers.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keine Spieler fuer diese Filter gefunden.'),
                      ),
                    )
                  else
                    _buildCompactPlayersList(context, visiblePlayers),
                ],
              ),
            ),
          );
        }
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Computer-Datenbank'),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _expertMode = false;
                    });
                  },
                  icon: const Icon(Icons.view_agenda_outlined, size: 18),
                  label: const Text('Standardansicht'),
                ),
              ],
              bottom: const TabBar(
                tabs: <Widget>[
                  Tab(text: 'Erstellte Spieler'),
                  Tab(text: 'Bulk-Spieler'),
                ],
              ),
            ),
            body: ExcludeSemantics(
              excluding: _suppressAccessibilityUpdates,
              child: TabBarView(
                children: <Widget>[
                  _buildPlayersTab(context, bulkOnly: false),
                  _buildPlayersTab(context, bulkOnly: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimplePlayerCard(BuildContext context, ComputerPlayer player) {
    final sourceLabel = switch (player.source) {
      ComputerPlayerSource.imported => 'Importiert',
      ComputerPlayerSource.manual => 'Manuell',
      ComputerPlayerSource.bulk => 'Bulk',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    player.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (player.isFavorite)
                  const Icon(Icons.star, color: Color(0xFF8A5A0E)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _SimpleInfoChip(label: sourceLabel),
                _SimpleInfoChip(
                  label: 'Theo ${player.theoreticalAverage.toStringAsFixed(1)}',
                ),
                _SimpleInfoChip(
                  label: 'Real ${player.average.toStringAsFixed(1)}',
                ),
                _SimpleInfoChip(
                  label: player.nationality ?? 'Ohne Nation',
                ),
              ],
            ),
            if (player.tags.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                player.tags.join(', '),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => _openPlayerDetails(player),
                  child: const Text('Details'),
                ),
                OutlinedButton(
                  onPressed: () => _edit(player),
                  child: const Text('Bearbeiten'),
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
    );
  }

  Widget _buildCompactPlayersList(
    BuildContext context,
    List<ComputerPlayer> players,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Spielerliste',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '${players.length} Spieler',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
                ],
              ),
            ),
            ...players.map(
              (player) => _CompactPlayerRow(
                player: player,
                onOpen: () => _openPlayerDetails(player),
                onEdit: () => _edit(player),
                onDelete: player.isProtected
                    ? null
                    : () => _repository.deletePlayer(player.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersTab(BuildContext context, {required bool bulkOnly}) {
    final visiblePlayers = _visiblePlayers(bulkOnly: bulkOnly);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: <Widget>[
          if (bulkOnly)
            _buildBulkCreationCard(context)
          else
            _buildManualCreationCard(context),
          const SizedBox(height: 20),
          _buildFilterCard(
            context,
            bulkOnly: bulkOnly,
            visiblePlayers: visiblePlayers,
          ),
          const SizedBox(height: 20),
          _buildBulkActionsCard(context, visiblePlayers: visiblePlayers),
          const SizedBox(height: 20),
          if (visiblePlayers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Keine Spieler fuer diese Filter gefunden.'),
              ),
            )
          else
            _buildPlayersTable(
              context,
              visiblePlayers,
              bulkOnly: bulkOnly,
            ),
        ],
      ),
    );
  }

  Widget _buildManualCreationCard(BuildContext context) {
    final customSkill = int.tryParse(_skillController.text.trim());
    final customFinishingSkill = int.tryParse(_finishingSkillController.text.trim());
    final customTheoPreview = customSkill != null &&
            customSkill >= 1 &&
            customSkill <= 1000 &&
            customFinishingSkill != null &&
            customFinishingSkill >= 1 &&
            customFinishingSkill <= 1000
        ? _repository.estimateTheoreticalAverageForSkills(
            skill: customSkill,
            finishingSkill: customFinishingSkill,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Skill-Werte manuell bearbeiten'),
              subtitle: const Text(
                'Ausgeschaltet: nur Theo eingeben. Eingeschaltet: Skill und Finishing Skill direkt setzen.',
              ),
              value: _useCustomSkills,
              onChanged: (value) {
                setState(() {
                  _useCustomSkills = value;
                });
              },
            ),
            const SizedBox(height: 12),
            if (_useCustomSkills) ...<Widget>[
              TextField(
                controller: _skillController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Skill',
                  helperText: '1 bis 1000',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _finishingSkillController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Finishing Skill',
                  helperText: '1 bis 1000',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                customTheoPreview == null
                    ? 'Abgeleiteter Theo Average: -'
                    : 'Abgeleiteter Theo Average: ${customTheoPreview.toStringAsFixed(1)}',
              ),
            ] else
              TextField(
                controller: _theoreticalAverageController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Ziel Theo Average',
                  helperText:
                      '0 bis 180. Skill und Finishing Skill werden automatisch berechnet.',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthDateController,
              decoration: const InputDecoration(
                labelText: 'Geburtsdatum',
                helperText: 'Optional, z. B. 09.04.1985',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _repository.nationalityDefinitions.any(
                (entry) => entry == _selectedNationality,
              )
                  ? _selectedNationality
                  : null,
              decoration: const InputDecoration(labelText: 'Nationalitaet'),
              items: _repository.nationalityDefinitions.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry,
                  child: Text(entry),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedNationality = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Datenbank-Tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newTagController,
              decoration: const InputDecoration(labelText: 'Neuer Tag'),
              onSubmitted: (_) => _addTagDefinition(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _addTagDefinition,
              child: const Text('Hinzufuegen'),
            ),
            const SizedBox(height: 20),
            Text(
              'Spieler-Tags',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_repository.tagDefinitions.isEmpty)
              const Text('Noch keine Tags angelegt.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _repository.tagDefinitions.map((tag) {
                  final isSelected = _draftTags.any(
                    (entry) => entry.toLowerCase() == tag.toLowerCase(),
                  );
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => _toggleDraftTag(tag),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    _editingId == null
                        ? 'Computer anlegen'
                        : 'Computer aktualisieren',
                  ),
                ),
                OutlinedButton(
                  onPressed: _clearForm,
                  child: const Text('Zuruecksetzen'),
                ),
                OutlinedButton(
                  onPressed: _refreshTheoreticalAveragesWithLoading,
                  child: const Text('Theo Averages neu berechnen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkCreationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Bulk-Erstellung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkPrefixController,
              decoration: const InputDecoration(
                labelText: 'Fallback-Praefix',
                helperText:
                    'Wird nur genutzt, wenn fuer ein Land kein Name erzeugt werden kann.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Wie viele Spieler',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkMinAverageController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum Theo Average',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkMaxAverageController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum Theo Average',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkMinAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minimum Alter',
                helperText:
                    'Optional. Wenn gesetzt, wird pro Bulk-Spieler ein zufaelliges Alter vergeben.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkMaxAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum Alter'),
            ),
            const SizedBox(height: 16),
            Text(
              'Nationalitaeten fuer Bulk-Spieler',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _repository.nationalityDefinitions.map((nationality) {
                final isSelected = _bulkNationalities.any(
                  (entry) => entry.toLowerCase() == nationality.toLowerCase(),
                );
                return FilterChip(
                  label: Text(nationality),
                  selected: isSelected,
                  onSelected: (_) => _toggleBulkNationality(nationality),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Tags fuer Bulk-Spieler',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _repository.tagDefinitions.map((tag) {
                final isSelected = _bulkTags.any(
                  (entry) => entry.toLowerCase() == tag.toLowerCase(),
                );
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) => _toggleBulkTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton(
                  onPressed: _createBulkPlayers,
                  child: const Text('Bulk-Spieler erstellen'),
                ),
                OutlinedButton(
                  onPressed: _tagCurrentPlayersAsReal,
                  child: const Text(
                    'Allen aktuellen Spielern "Echter Spieler" geben',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard(
    BuildContext context, {
    required bool bulkOnly,
    required List<ComputerPlayer> visiblePlayers,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Filter und Sortierung',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Suche nach Name',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _saveCurrentPreset,
                  child: const Text('Preset speichern'),
                ),
                if (_savedPresets.isNotEmpty)
                  DropdownButton<_DatabasePreset>(
                    hint: const Text('Preset laden'),
                    value: null,
                    items: _savedPresets.map((preset) {
                      return DropdownMenuItem<_DatabasePreset>(
                        value: preset,
                        child: Text(preset.name),
                      );
                    }).toList(),
                    onChanged: (preset) {
                      if (preset == null) {
                        return;
                      }
                      _applyPreset(preset);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _filterNationality,
              decoration: const InputDecoration(
                labelText: 'Nationalitaet filtern',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Alle Nationalitaeten'),
                ),
                ..._repository.nationalityDefinitions.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry,
                    child: Text(entry),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _filterNationality = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _filterTag,
              decoration: const InputDecoration(labelText: 'Tag filtern'),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Alle Tags'),
                ),
                ..._repository.tagDefinitions.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry,
                    child: Text(entry),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _filterTag = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ComputerPlayerSource>(
              initialValue: _filterSource,
              decoration: const InputDecoration(labelText: 'Quelle filtern'),
              items: <DropdownMenuItem<ComputerPlayerSource>>[
                const DropdownMenuItem<ComputerPlayerSource>(
                  value: null,
                  child: Text('Alle Quellen'),
                ),
                if (!bulkOnly)
                  const DropdownMenuItem<ComputerPlayerSource>(
                    value: ComputerPlayerSource.manual,
                    child: Text('Nur manuell'),
                  ),
                if (!bulkOnly)
                  const DropdownMenuItem<ComputerPlayerSource>(
                    value: ComputerPlayerSource.imported,
                    child: Text('Nur importiert'),
                  ),
                const DropdownMenuItem<ComputerPlayerSource>(
                  value: ComputerPlayerSource.bulk,
                  child: Text('Nur bulk'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _filterSource = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterMinTheoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum Theo Average',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterMaxTheoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum Theo Average',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterMinAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum Alter'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _filterMaxAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum Alter'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilterChip(
                  label: const Text('Nur Echter Spieler'),
                  selected: _onlyRealPlayers,
                  onSelected: (value) {
                    setState(() {
                      _onlyRealPlayers = value;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Nur Favoriten'),
                  selected: _onlyFavorites,
                  onSelected: (value) {
                    setState(() {
                      _onlyFavorites = value;
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Nur geschuetzte'),
                  selected: _onlyProtected,
                  onSelected: (value) {
                    setState(() {
                      _onlyProtected = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Spalten',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <MapEntry<String, String>>[
                const MapEntry('name', 'Name'),
                const MapEntry('source', 'Quelle'),
                const MapEntry('theo', 'Theo'),
                const MapEntry('real', 'Real'),
                const MapEntry('age', 'Geburtsdatum'),
                const MapEntry('nationality', 'Nationalitaet'),
                const MapEntry('tags', 'Tags'),
                const MapEntry('stats', 'Stats'),
                const MapEntry('actions', 'Aktionen'),
              ].map((entry) {
                return FilterChip(
                  label: Text(entry.value),
                  selected: _visibleColumns.contains(entry.key),
                  onSelected: (selected) async {
                    setState(() {
                      if (selected) {
                        _visibleColumns.add(entry.key);
                      } else if (_visibleColumns.length > 1) {
                        _visibleColumns.remove(entry.key);
                      }
                    });
                    await _persistUiState();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_PlayerSortOption>(
              initialValue: _sortOption,
              decoration: const InputDecoration(labelText: 'Sortierung'),
              items: const <DropdownMenuItem<_PlayerSortOption>>[
                DropdownMenuItem(
                  value: _PlayerSortOption.theoreticalAverage,
                  child: Text('Theo Average'),
                ),
                DropdownMenuItem(
                  value: _PlayerSortOption.realAverage,
                  child: Text('Real Average'),
                ),
                DropdownMenuItem(
                  value: _PlayerSortOption.age,
                  child: Text('Geburtsdatum'),
                ),
                DropdownMenuItem(
                  value: _PlayerSortOption.matches,
                  child: Text('Matches'),
                ),
                DropdownMenuItem(
                  value: _PlayerSortOption.wins,
                  child: Text('Siege'),
                ),
                DropdownMenuItem(
                  value: _PlayerSortOption.alphabetical,
                  child: Text('Alphabetisch'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _sortOption = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Absteigend sortieren'),
              value: _sortDescending,
              onChanged: (value) {
                setState(() {
                  _sortDescending = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Text('Gefundene Spieler: ${visiblePlayers.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkActionsCard(
    BuildContext context, {
    required List<ComputerPlayer> visiblePlayers,
  }) {
    final selectedVisibleIds = _visibleSelection(visiblePlayers);
    final selectedVisibleCount = selectedVisibleIds.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Mehrfachaktionen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Ausgewaehlt: $selectedVisibleCount / ${visiblePlayers.length}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                OutlinedButton(
                  onPressed: () => _selectVisiblePlayers(visiblePlayers),
                  child: const Text('Alle auswaehlen'),
                ),
                OutlinedButton(
                  onPressed: () => _selectVisiblePlayers(visiblePlayers),
                  child: const Text('Gefilterte auswaehlen'),
                ),
                OutlinedButton(
                  onPressed: _clearSelection,
                  child: const Text('Auswahl leeren'),
                ),
                OutlinedButton(
                  onPressed: () => _deleteFilteredPlayers(visiblePlayers),
                  child: const Text('Gefilterte loeschen'),
                ),
                FilledButton(
                  onPressed: () => _deleteSelectedPlayers(visiblePlayers),
                  child: const Text('Ausgewaehlte loeschen'),
                ),
                OutlinedButton(
                  onPressed: _repository.canUndo
                      ? () async {
                          await _repository.undoLastChange();
                          _showMessage('Letzte Aenderung rueckgaengig gemacht.');
                        }
                      : null,
                  child: const Text('Undo'),
                ),
                OutlinedButton(
                  onPressed: () => _showExportDialog(
                    title: 'JSON Export',
                    content: _repository.exportAsJsonString(),
                  ),
                  child: const Text('JSON exportieren'),
                ),
                OutlinedButton(
                  onPressed: () => _exportToFile(
                    format: 'json',
                    content: _repository.exportAsJsonString(),
                  ),
                  child: const Text('JSON als Datei'),
                ),
                OutlinedButton(
                  onPressed: () => _showExportDialog(
                    title: 'CSV Export',
                    content: _repository.exportAsCsvString(),
                  ),
                  child: const Text('CSV exportieren'),
                ),
                OutlinedButton(
                  onPressed: () => _exportToFile(
                    format: 'csv',
                    content: _repository.exportAsCsvString(),
                  ),
                  child: const Text('CSV als Datei'),
                ),
                OutlinedButton(
                  onPressed: () => _showImportDialog(json: true),
                  child: const Text('JSON importieren'),
                ),
                OutlinedButton(
                  onPressed: () => _showImportDialog(json: false),
                  child: const Text('CSV importieren'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _bulkEditNationality,
              decoration: const InputDecoration(
                labelText: 'Neue Nationalitaet fuer Auswahl',
              ),
              items: <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Unveraendert lassen'),
                ),
                ..._repository.nationalityDefinitions.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry,
                    child: Text(entry),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _bulkEditNationality = value;
                });
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Nationalitaet loeschen'),
              value: _bulkEditClearNationality,
              onChanged: (value) {
                setState(() {
                  _bulkEditClearNationality = value ?? false;
                });
              },
            ),
            TextField(
              controller: _bulkEditMinAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bulk-Minimum-Alter',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkEditMaxAgeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Bulk-Maximum-Alter',
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Alter loeschen'),
              value: _bulkEditClearAge,
              onChanged: (value) {
                setState(() {
                  _bulkEditClearAge = value ?? false;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_TriStateChoice>(
              initialValue: _bulkEditFavoriteChoice,
              decoration: const InputDecoration(labelText: 'Favorit setzen'),
              items: const <DropdownMenuItem<_TriStateChoice>>[
                DropdownMenuItem(
                  value: _TriStateChoice.unchanged,
                  child: Text('Unveraendert'),
                ),
                DropdownMenuItem(
                  value: _TriStateChoice.yes,
                  child: Text('Als Favorit markieren'),
                ),
                DropdownMenuItem(
                  value: _TriStateChoice.no,
                  child: Text('Favorit entfernen'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _bulkEditFavoriteChoice = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<_TriStateChoice>(
              initialValue: _bulkEditProtectedChoice,
              decoration: const InputDecoration(labelText: 'Schutz setzen'),
              items: const <DropdownMenuItem<_TriStateChoice>>[
                DropdownMenuItem(
                  value: _TriStateChoice.unchanged,
                  child: Text('Unveraendert'),
                ),
                DropdownMenuItem(
                  value: _TriStateChoice.yes,
                  child: Text('Schuetzen'),
                ),
                DropdownMenuItem(
                  value: _TriStateChoice.no,
                  child: Text('Schutz entfernen'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _bulkEditProtectedChoice = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Tags hinzufuegen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _repository.tagDefinitions.map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: _bulkEditAddTags.contains(tag),
                  onSelected: (_) => _toggleBulkEditAddTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Tags entfernen',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _repository.tagDefinitions.map((tag) {
                return FilterChip(
                  label: Text(tag),
                  selected: _bulkEditRemoveTags.contains(tag),
                  onSelected: (_) => _toggleBulkEditRemoveTag(tag),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _applyBulkEdits(visiblePlayers),
              child: const Text('Aenderungen auf Auswahl anwenden'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayersTable(
    BuildContext context,
    List<ComputerPlayer> players,
    {
    required bool bulkOnly,
  }) {
    final configuredRowsPerPage = _tableRowsPerPage(bulkOnly);
    final rowsPerPage = math.max(
      1,
      math.min(configuredRowsPerPage, math.max(1, players.length)),
    );
    final pageCount = math.max(1, (players.length / rowsPerPage).ceil());
    final currentPage = math.min(_tablePage(bulkOnly), pageCount - 1);
    final startIndex = currentPage * rowsPerPage;
    final endIndex = math.min(startIndex + rowsPerPage, players.length);
    final visiblePagePlayers = players.sublist(startIndex, endIndex);
    final availableRowsPerPage = <int>{
      rowsPerPage,
      if (players.length >= 10) 10,
      if (players.length >= 20) 20,
      if (players.length >= 50) 50,
    }.toList()
      ..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Spielerliste',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${startIndex + 1}-$endIndex von ${players.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 1100),
                child: DataTable(
                  columns: <DataColumn>[
                    const DataColumn(label: Text('Auswahl')),
                    if (_visibleColumns.contains('name'))
                      const DataColumn(label: Text('Name')),
                    if (_visibleColumns.contains('source'))
                      const DataColumn(label: Text('Quelle')),
                    if (_visibleColumns.contains('theo'))
                      const DataColumn(label: Text('Theo')),
                    if (_visibleColumns.contains('real'))
                      const DataColumn(label: Text('Real')),
                    if (_visibleColumns.contains('age'))
                      const DataColumn(label: Text('Geburtsdatum')),
                    if (_visibleColumns.contains('nationality'))
                      const DataColumn(label: Text('Nationalitaet')),
                    if (_visibleColumns.contains('tags'))
                      const DataColumn(label: Text('Tags')),
                    if (_visibleColumns.contains('stats'))
                      const DataColumn(label: Text('Stats')),
                    if (_visibleColumns.contains('actions'))
                      const DataColumn(label: Text('Aktionen')),
                  ],
                  rows: List<DataRow>.generate(
                    visiblePagePlayers.length,
                    (index) => _buildPlayerTableRow(
                      visiblePagePlayers[index],
                      index: startIndex + index,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                DropdownButton<int>(
                  value: rowsPerPage,
                  items: availableRowsPerPage.map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value pro Seite'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    _setTableRowsPerPage(bulkOnly, value);
                  },
                ),
                OutlinedButton(
                  onPressed: currentPage > 0
                      ? () => _setTablePage(bulkOnly, currentPage - 1)
                      : null,
                  child: const Text('Zurueck'),
                ),
                OutlinedButton(
                  onPressed: currentPage + 1 < pageCount
                      ? () => _setTablePage(bulkOnly, currentPage + 1)
                      : null,
                  child: const Text('Weiter'),
                ),
                Text('Seite ${currentPage + 1} / $pageCount'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildPlayerTableRow(ComputerPlayer player, {required int index}) {
    final sourceLabel = switch (player.source) {
      ComputerPlayerSource.imported => 'Importiert',
      ComputerPlayerSource.manual => 'Manuell',
      ComputerPlayerSource.bulk => 'Bulk',
    };
    final tags = player.tags.isEmpty ? '-' : player.tags.join(', ');
    return DataRow.byIndex(
      index: index,
      selected: _selectedPlayerIds.contains(player.id),
      cells: <DataCell>[
        DataCell(
          Checkbox(
            value: _selectedPlayerIds.contains(player.id),
            onChanged: (_) => _togglePlayerSelection(player.id),
          ),
        ),
        if (_visibleColumns.contains('name'))
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(player.name, overflow: TextOverflow.ellipsis),
            ),
          ),
        if (_visibleColumns.contains('source')) DataCell(Text(sourceLabel)),
        if (_visibleColumns.contains('theo'))
          DataCell(
            Text(
              player.theoreticalAverage.toStringAsFixed(1),
              style: const TextStyle(
                decoration: TextDecoration.underline,
              ),
            ),
            onTap: () => _showTheoSkillValues(player),
          ),
        if (_visibleColumns.contains('real'))
          DataCell(Text(player.average.toStringAsFixed(1))),
        if (_visibleColumns.contains('age'))
          DataCell(Text(_formatBirthDate(player.birthDate))),
        if (_visibleColumns.contains('nationality'))
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                player.nationality ?? '-',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (_visibleColumns.contains('tags'))
          DataCell(
            SizedBox(
              width: 220,
              child: Text(
                _isRealPlayer(player) ? '$tags, Echter Spieler' : tags,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (_visibleColumns.contains('stats'))
          DataCell(Text('${player.matchesWon}/${player.matchesPlayed}')),
        if (_visibleColumns.contains('actions'))
          DataCell(
            SizedBox(
              width: 220,
              child: Row(
                mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Details',
                  onPressed: () => _openPlayerDetails(player),
                  icon: const Icon(Icons.insights_outlined),
                ),
                IconButton(
                  tooltip: 'Bearbeiten',
                  onPressed: () => _edit(player),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: player.isFavorite ? 'Favorit entfernen' : 'Favorit',
                  onPressed: () => _repository.toggleFavorite(player.id),
                  icon: Icon(
                    player.isFavorite ? Icons.star : Icons.star_outline,
                  ),
                ),
                IconButton(
                  tooltip: player.isProtected ? 'Schutz entfernen' : 'Schuetzen',
                  onPressed: () => _repository.toggleProtected(player.id),
                  icon: Icon(
                    player.isProtected ? Icons.lock : Icons.lock_open,
                  ),
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
      ],
    );
  }
}

class _StatisticTile extends StatelessWidget {
  const _StatisticTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _SimpleInfoChip extends StatelessWidget {
  const _SimpleInfoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _CompactPlayerRow extends StatelessWidget {
  const _CompactPlayerRow({
    required this.player,
    required this.onOpen,
    required this.onEdit,
    this.onDelete,
  });

  final ComputerPlayer player;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      'Theo ${player.theoreticalAverage.toStringAsFixed(1)}',
      'Real ${player.average.toStringAsFixed(1)}',
      if (player.nationality != null && player.nationality!.trim().isNotEmpty)
        player.nationality!,
      switch (player.source) {
        ComputerPlayerSource.imported => 'Importiert',
        ComputerPlayerSource.manual => 'Manuell',
        ComputerPlayerSource.bulk => 'Bulk',
      },
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      if (player.isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xFF8A5A0E),
                          ),
                        ),
                      if (player.isProtected)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.lock,
                            size: 16,
                            color: Color(0xFF556372),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meta.join('  |  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
                  if (player.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      player.tags.join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF7A8794),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Bearbeiten',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Details',
              onPressed: onOpen,
              icon: const Icon(Icons.insights_outlined, size: 18),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Loeschen',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _AverageTrendPainter extends CustomPainter {
  _AverageTrendPainter({
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

    const leftPadding = 28.0;
    const bottomPadding = 22.0;
    const topPadding = 12.0;
    const rightPadding = 8.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    if (chartWidth <= 0 || chartHeight <= 0) {
      return;
    }

    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final paddedMin = math.max(0, minValue - 2);
    final paddedMax = math.max(paddedMin + 1, maxValue + 2);
    final range = paddedMax - paddedMin;

    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          lineColor.withValues(alpha: 0.18),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(
        Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight),
      );
    final pointPaint = Paint()..color = lineColor;

    for (var step = 0; step < 3; step += 1) {
      final ratio = step / 2;
      final y = topPadding + (chartHeight * ratio);
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        guidePaint,
      );
      final labelValue = paddedMax - (range * ratio);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelValue.toStringAsFixed(1),
          style: TextStyle(fontSize: 11, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPadding - 4);
      textPainter.paint(canvas, Offset(0, y - (textPainter.height / 2)));
    }

    final points = <Offset>[];
    for (var index = 0; index < values.length; index += 1) {
      final x = leftPadding +
          (chartWidth * (index / math.max(1, values.length - 1)));
      final normalized = (values[index] - paddedMin) / range;
      final y = topPadding + chartHeight - (normalized * chartHeight);
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, topPadding + chartHeight)
      ..lineTo(points.first.dx, topPadding + chartHeight)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
    for (final point in points) {
      canvas.drawCircle(point, 2.8, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AverageTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.textColor != textColor;
  }
}

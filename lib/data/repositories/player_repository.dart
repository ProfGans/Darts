import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../presentation/match/bob27_result_models.dart';
import '../../presentation/match/cricket_result_models.dart';
import '../../presentation/match/match_result_models.dart';
import '../models/nationality_catalog.dart';
import '../models/player_profile.dart';
import '../storage/app_storage.dart';

class PlayerStatsWindow {
  const PlayerStatsWindow({
    required this.label,
    required this.matchCount,
    required this.winCount,
    required this.stats,
  });

  final String label;
  final int matchCount;
  final int winCount;
  final PlayerProfileStats stats;

  double get winRate => matchCount <= 0 ? 0 : (winCount / matchCount) * 100;
}

class PlayerHeadToHeadStats {
  const PlayerHeadToHeadStats({
    required this.opponentName,
    required this.opponentType,
    required this.matches,
    required this.wins,
    required this.average,
    required this.lastPlayedAt,
  });

  final String opponentName;
  final PlayerOpponentKind opponentType;
  final int matches;
  final int wins;
  final double average;
  final DateTime lastPlayedAt;

  double get winRate => matches <= 0 ? 0 : (wins / matches) * 100;
}

class PlayerEquipmentPerformance {
  const PlayerEquipmentPerformance({
    required this.equipmentId,
    required this.equipmentName,
    required this.matchCount,
    required this.trainingCount,
    required this.stats,
    required this.winCount,
  });

  final String equipmentId;
  final String equipmentName;
  final int matchCount;
  final int trainingCount;
  final PlayerProfileStats stats;
  final int winCount;

  double get winRate => matchCount <= 0 ? 0 : (winCount / matchCount) * 100;
}

enum PlayerAnalyticsRange {
  allTime,
  last5,
  last10,
  last25,
  last3Months,
}

extension PlayerAnalyticsRangePresentation on PlayerAnalyticsRange {
  String get label => switch (this) {
        PlayerAnalyticsRange.allTime => 'All Time',
        PlayerAnalyticsRange.last5 => 'Letzte 5 Matches',
        PlayerAnalyticsRange.last10 => 'Letzte 10 Matches',
        PlayerAnalyticsRange.last25 => 'Letzte 25 Matches',
        PlayerAnalyticsRange.last3Months => 'Letzte 3 Monate',
      };
}

class PlayerProfileAnalytics {
  const PlayerProfileAnalytics({
    required this.filterRange,
    required this.filterEquipmentId,
    required this.filterStartDate,
    required this.filterEndDate,
    required this.filtered,
    required this.filteredTrainingCount,
    required this.last5,
    required this.last10,
    required this.last25,
    required this.last3Months,
    required this.allTime,
    required this.withThrow,
    required this.againstThrow,
    required this.decider,
    required this.bestOfShort,
    required this.bestOfLong,
    required this.vsHuman,
    required this.vsCpu,
    required this.headToHead,
    required this.favoriteOpponent,
    required this.toughestOpponent,
    required this.movingAverage,
    required this.equipment,
  });

  final PlayerAnalyticsRange filterRange;
  final String? filterEquipmentId;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;
  final PlayerStatsWindow filtered;
  final int filteredTrainingCount;
  final PlayerStatsWindow last5;
  final PlayerStatsWindow last10;
  final PlayerStatsWindow last25;
  final PlayerStatsWindow last3Months;
  final PlayerStatsWindow allTime;
  final PlayerStatsWindow withThrow;
  final PlayerStatsWindow againstThrow;
  final PlayerStatsWindow decider;
  final PlayerStatsWindow bestOfShort;
  final PlayerStatsWindow bestOfLong;
  final PlayerStatsWindow vsHuman;
  final PlayerStatsWindow vsCpu;
  final List<PlayerHeadToHeadStats> headToHead;
  final PlayerHeadToHeadStats? favoriteOpponent;
  final PlayerHeadToHeadStats? toughestOpponent;
  final List<double> movingAverage;
  final List<PlayerEquipmentPerformance> equipment;
}

class PlayerRepository extends ChangeNotifier {
  PlayerRepository._();

  static final PlayerRepository instance = PlayerRepository._();

  static const _storageKey = 'player_profiles';

  final List<PlayerProfile> _players = <PlayerProfile>[
    PlayerProfile(
      id: 'player-johannes',
      name: 'Johannes',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      lastModifiedReason: 'seed_default',
    ),
  ];
  final List<String> _tagDefinitions = <String>[];

  String _activePlayerId = 'player-johannes';

  List<PlayerProfile> get players => List<PlayerProfile>.unmodifiable(_players);
  List<String> get tagDefinitions => List<String>.unmodifiable(_tagDefinitions);
  List<String> get nationalityDefinitions =>
      List<String>.unmodifiable(NationalityCatalog.officialNationalities);

  PlayerProfile? get activePlayer {
    for (final player in _players) {
      if (player.id == _activePlayerId) {
        return player;
      }
    }
    return _players.isEmpty ? null : _players.first;
  }

  PlayerProfile? playerById(String playerId) {
    for (final player in _players) {
      if (player.id == playerId) {
        return player;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    final json = await AppStorage.instance.readJsonMap(_storageKey);
    if (json == null) {
      _syncTagDefinitions();
      return;
    }

    final loadedPlayers =
        (json['players'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) =>
                  PlayerProfile.fromJson((entry as Map).cast<String, dynamic>()),
            )
            .map(_normalizePlayer)
            .toList();
    if (loadedPlayers.isNotEmpty) {
      _players
        ..clear()
        ..addAll(loadedPlayers);
    }
    _activePlayerId = json['activePlayerId'] as String? ?? _players.first.id;
    final tagDefinitions =
        (json['tagDefinitions'] as List<dynamic>? ?? const <dynamic>[])
            .map((entry) => entry.toString())
            .toList();
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(tagDefinitions, _players));
    notifyListeners();
    await _persist();
  }

  void createPlayer({
    required String name,
    String? nationality,
    int? age,
    String? favoriteDouble,
    String? hatedDouble,
    List<String> tags = const <String>[],
    String? notes,
    PlayerProfileSource source = PlayerProfileSource.manual,
    PlayerProfilePreferences preferences = const PlayerProfilePreferences(),
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final profile = PlayerProfile(
      id: 'player-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      createdAt: now,
      updatedAt: now,
      lastModifiedReason: 'manual_create',
      nationality: _normalizeNationality(nationality),
      age: age,
      favoriteDouble: _normalizeNullableText(favoriteDouble),
      hatedDouble: _normalizeNullableText(hatedDouble),
      tags: _normalizeTags(tags),
      notes: _normalizeNullableText(notes),
      source: source,
      preferences: preferences,
    );
    _players.add(profile);
    _activePlayerId = profile.id;
    _syncTagDefinitions();
    notifyListeners();
    unawaited(_persist());
  }

  void saveEquipmentSetup({
    required String playerId,
    String? equipmentId,
    required String name,
    double? barrelWeight,
    String? barrelModel,
    String? barrelMaterial,
    String? pointType,
    String? pointLength,
    String? shaftType,
    String? shaftLength,
    String? flightShape,
    String? flightSystem,
    String? gripWax,
    String? notes,
    bool setActive = true,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    final trimmedName = name.trim();
    if (index < 0 || trimmedName.isEmpty) {
      return;
    }

    final current = _players[index];
    final setups = List<PlayerEquipmentSetup>.from(current.equipmentSetups);
    final now = DateTime.now();
    final existingIndex = equipmentId == null
        ? -1
        : setups.indexWhere((entry) => entry.id == equipmentId);
    if (existingIndex >= 0) {
      setups[existingIndex] = setups[existingIndex].copyWith(
        name: trimmedName,
        updatedAt: now,
        barrelWeight: barrelWeight,
        clearBarrelWeight: barrelWeight == null,
        barrelModel: _normalizeNullableText(barrelModel),
        clearBarrelModel: _normalizeNullableText(barrelModel) == null,
        barrelMaterial: _normalizeNullableText(barrelMaterial),
        clearBarrelMaterial: _normalizeNullableText(barrelMaterial) == null,
        pointType: _normalizeNullableText(pointType),
        clearPointType: _normalizeNullableText(pointType) == null,
        pointLength: _normalizeNullableText(pointLength),
        clearPointLength: _normalizeNullableText(pointLength) == null,
        shaftType: _normalizeNullableText(shaftType),
        clearShaftType: _normalizeNullableText(shaftType) == null,
        shaftLength: _normalizeNullableText(shaftLength),
        clearShaftLength: _normalizeNullableText(shaftLength) == null,
        flightShape: _normalizeNullableText(flightShape),
        clearFlightShape: _normalizeNullableText(flightShape) == null,
        flightSystem: _normalizeNullableText(flightSystem),
        clearFlightSystem: _normalizeNullableText(flightSystem) == null,
        gripWax: _normalizeNullableText(gripWax),
        clearGripWax: _normalizeNullableText(gripWax) == null,
        notes: _normalizeNullableText(notes),
        clearNotes: _normalizeNullableText(notes) == null,
      );
    } else {
      setups.add(
        PlayerEquipmentSetup(
          id: equipmentId ?? 'equipment-${DateTime.now().microsecondsSinceEpoch}',
          name: trimmedName,
          createdAt: now,
          updatedAt: now,
          barrelWeight: barrelWeight,
          barrelModel: _normalizeNullableText(barrelModel),
          barrelMaterial: _normalizeNullableText(barrelMaterial),
          pointType: _normalizeNullableText(pointType),
          pointLength: _normalizeNullableText(pointLength),
          shaftType: _normalizeNullableText(shaftType),
          shaftLength: _normalizeNullableText(shaftLength),
          flightShape: _normalizeNullableText(flightShape),
          flightSystem: _normalizeNullableText(flightSystem),
          gripWax: _normalizeNullableText(gripWax),
          notes: _normalizeNullableText(notes),
        ),
      );
    }

    final nextActiveId = setActive
        ? (existingIndex >= 0 ? setups[existingIndex].id : setups.last.id)
        : current.activeEquipmentId;
    _players[index] = current.copyWith(
      equipmentSetups: setups,
      activeEquipmentId: nextActiveId,
      updatedAt: now,
      lastModifiedReason: 'equipment_update',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void setActiveEquipment(String playerId, String? equipmentId) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }
    _players[index] = _players[index].copyWith(
      activeEquipmentId: equipmentId,
      clearActiveEquipmentId: equipmentId == null,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'equipment_activate',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void deleteEquipment(String playerId, String equipmentId) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }
    final current = _players[index];
    final nextSetups = current.equipmentSetups
        .where((entry) => entry.id != equipmentId)
        .toList();
    _players[index] = current.copyWith(
      equipmentSetups: nextSetups,
      activeEquipmentId:
          current.activeEquipmentId == equipmentId ? null : current.activeEquipmentId,
      clearActiveEquipmentId: current.activeEquipmentId == equipmentId,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'equipment_delete',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void updatePlayer({
    required String playerId,
    required String name,
    String? nationality,
    int? age,
    String? favoriteDouble,
    String? hatedDouble,
    List<String> tags = const <String>[],
    String? notes,
    PlayerProfileSource? source,
    bool? isFavorite,
    bool? isProtected,
    PlayerProfilePreferences? preferences,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    final trimmedName = name.trim();
    if (index < 0 || trimmedName.isEmpty) {
      return;
    }

    _players[index] = _players[index].copyWith(
      name: trimmedName,
      nationality: _normalizeNationality(nationality),
      clearNationality:
          _normalizeNullableText(nationality) == null,
      age: age,
      clearAge: age == null,
      favoriteDouble: _normalizeNullableText(favoriteDouble),
      clearFavoriteDouble: _normalizeNullableText(favoriteDouble) == null,
      hatedDouble: _normalizeNullableText(hatedDouble),
      clearHatedDouble: _normalizeNullableText(hatedDouble) == null,
      tags: _normalizeTags(tags),
      notes: _normalizeNullableText(notes),
      clearNotes: _normalizeNullableText(notes) == null,
      source: source ?? _players[index].source,
      isFavorite: isFavorite ?? _players[index].isFavorite,
      isProtected: isProtected ?? _players[index].isProtected,
      preferences: preferences ?? _players[index].preferences,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'manual_update',
    );
    _syncTagDefinitions();
    notifyListeners();
    unawaited(_persist());
  }

  void addTagDefinition(String name) {
    final normalized = _normalizeNullableText(name);
    if (normalized == null) {
      return;
    }
    if (_tagDefinitions.any(
      (entry) => entry.toLowerCase() == normalized.toLowerCase(),
    )) {
      return;
    }
    _tagDefinitions.add(normalized);
    notifyListeners();
    unawaited(_persist());
  }

  void toggleFavorite(String playerId) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }
    _players[index] = _players[index].copyWith(
      isFavorite: !_players[index].isFavorite,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'toggle_favorite',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void toggleProtected(String playerId) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }
    _players[index] = _players[index].copyWith(
      isProtected: !_players[index].isProtected,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'toggle_protected',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void setActivePlayer(String playerId) {
    _activePlayerId = playerId;
    notifyListeners();
    unawaited(_persist());
  }

  void deletePlayer(String playerId) {
    if (_players.length <= 1) {
      return;
    }
    _players.removeWhere(
      (player) => player.id == playerId && !player.isProtected,
    );
    if (_activePlayerId == playerId && _players.isNotEmpty) {
      _activePlayerId = _players.first.id;
    }
    _syncTagDefinitions();
    notifyListeners();
    unawaited(_persist());
  }

  void recordMatch({
    required String playerId,
    required String opponentName,
    required bool won,
    required MatchResultSummary result,
    required double average,
    PlayerOpponentKind opponentType = PlayerOpponentKind.unknown,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final activeEquipment = _resolveActiveEquipment(current);
    final historyEntry = PlayerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      opponentType: opponentType,
      equipmentId: activeEquipment?.id,
      equipmentName: activeEquipment?.name,
      match: result,
    );
    final nextHistory = <PlayerMatchHistoryEntry>[
      historyEntry,
      ...current.history,
    ];
    final rebuiltStats = _buildX01StatsFromEntries(
      playerId: current.id,
      playerName: current.name,
      entries: nextHistory,
    );

    _players[index] = current.copyWith(
      matchesPlayed: current.matchesPlayed + 1,
      matchesWon: current.matchesWon + (won ? 1 : 0),
      average: rebuiltStats.average,
      history: nextHistory,
      stats: rebuiltStats,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_match',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void recordCricketMatch({
    required String playerId,
    required String opponentName,
    required bool won,
    required CricketResultSummary result,
    required double average,
    PlayerOpponentKind opponentType = PlayerOpponentKind.unknown,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final activeEquipment = _resolveActiveEquipment(current);
    final historyEntry = PlayerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      opponentType: opponentType,
      equipmentId: activeEquipment?.id,
      equipmentName: activeEquipment?.name,
      cricketMatch: result,
    );

    _players[index] = current.copyWith(
      matchesPlayed: current.matchesPlayed + 1,
      matchesWon: current.matchesWon + (won ? 1 : 0),
      cricketStats: current.cricketStats.merge(
        PlayerCricketStats.fromParticipantStats(
          _resolveCricketParticipantStats(
            playerId: playerId,
            playerName: current.name,
            result: result,
          ),
          won: won,
        ),
      ),
      history: <PlayerMatchHistoryEntry>[
        historyEntry,
        ...current.history,
      ],
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_cricket_match',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void recordBob27Match({
    required String playerId,
    required String opponentName,
    required bool won,
    required Bob27ResultSummary result,
    required double average,
    PlayerOpponentKind opponentType = PlayerOpponentKind.unknown,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final activeEquipment = _resolveActiveEquipment(current);
    final historyEntry = PlayerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      opponentType: opponentType,
      equipmentId: activeEquipment?.id,
      equipmentName: activeEquipment?.name,
      bob27Match: result,
    );

    _players[index] = current.copyWith(
      matchesPlayed: current.matchesPlayed + 1,
      matchesWon: current.matchesWon + (won ? 1 : 0),
      bob27Stats: current.bob27Stats.merge(
        PlayerBob27Stats.fromParticipantStats(
          _resolveBob27ParticipantStats(
            playerId: playerId,
            playerName: current.name,
            result: result,
          ),
          won: won,
        ),
      ),
      history: <PlayerMatchHistoryEntry>[
        historyEntry,
        ...current.history,
      ],
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_bob27_match',
    );
    notifyListeners();
    unawaited(_persist());
  }

  void recordTrainingSession({
    required String playerId,
    required String mode,
    required String scoreLabel,
    double? average,
    String? notes,
  }) {
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }
    final current = _players[index];
    final activeEquipment = _resolveActiveEquipment(current);
    final entry = PlayerTrainingEntry(
      id: 'training-${DateTime.now().microsecondsSinceEpoch}',
      mode: mode,
      scoreLabel: scoreLabel,
      playedAt: DateTime.now(),
      equipmentId: activeEquipment?.id,
      equipmentName: activeEquipment?.name,
      average: average,
      notes: _normalizeNullableText(notes),
    );
    _players[index] = current.copyWith(
      trainingHistory: <PlayerTrainingEntry>[entry, ...current.trainingHistory],
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_training',
    );
    notifyListeners();
    unawaited(_persist());
  }

  String exportAsJsonString() {
    return const JsonEncoder.withIndent('  ').convert(<String, dynamic>{
      'activePlayerId': _activePlayerId,
      'tagDefinitions': _tagDefinitions,
      'players': _players.map((entry) => entry.toJson()).toList(),
    });
  }

  String exportAsCsvString() {
    final rows = <List<String>>[
      <String>[
        'id',
        'name',
        'source',
        'nationality',
        'age',
        'favorite',
        'protected',
        'favoriteDouble',
        'hatedDouble',
        'tags',
        'favoriteFormats',
        'avatarEmoji',
        'avatarColor',
        'preferredView',
        'defaultTrainingMode',
        'defaultMatchMode',
        'notes',
      ],
      ..._players.map((player) => <String>[
            player.id,
            player.name,
            player.source.storageValue,
            player.nationality ?? '',
            player.age?.toString() ?? '',
            player.isFavorite.toString(),
            player.isProtected.toString(),
            player.favoriteDouble ?? '',
            player.hatedDouble ?? '',
            player.tags.join('|'),
            player.preferences.favoriteFormats.join('|'),
            player.preferences.avatarEmoji,
            player.preferences.avatarColor,
            player.preferences.preferredView,
            player.preferences.defaultTrainingMode,
            player.preferences.defaultMatchMode,
            player.notes ?? '',
          ]),
    ];
    return rows.map(_toCsvRow).join('\n');
  }

  Future<void> importFromJsonString(
    String rawValue, {
    bool replaceExisting = false,
  }) async {
    final decoded = jsonDecode(rawValue);
    if (decoded is! Map) {
      return;
    }
    final map = decoded.cast<String, dynamic>();
    final importedPlayers =
        (map['players'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) =>
                  PlayerProfile.fromJson((entry as Map).cast<String, dynamic>()),
            )
            .toList();
    if (replaceExisting) {
      _players
        ..clear()
        ..addAll(importedPlayers.map(_normalizePlayer));
    } else {
      for (final player in importedPlayers) {
        final normalized = _normalizePlayer(player);
        final index = _players.indexWhere((entry) => entry.id == normalized.id);
        if (index >= 0) {
          _players[index] = normalized;
          continue;
        }
        _players.add(normalized);
      }
    }
    _activePlayerId = map['activePlayerId'] as String? ??
        (_players.isNotEmpty ? _players.first.id : _activePlayerId);
    _syncTagDefinitions();
    notifyListeners();
    await _persist();
  }

  Future<void> importFromCsvString(
    String rawValue, {
    bool replaceExisting = false,
  }) async {
    final rows = _parseCsv(rawValue);
    if (rows.length <= 1) {
      return;
    }
    final header = rows.first;
    final importedPlayers = <PlayerProfile>[];
    for (final row in rows.skip(1)) {
      if (row.isEmpty) {
        continue;
      }
      final values = <String, String>{};
      for (var index = 0; index < header.length && index < row.length; index += 1) {
        values[header[index]] = row[index];
      }
      final now = DateTime.now();
      importedPlayers.add(
        PlayerProfile(
          id: values['id']?.trim().isNotEmpty == true
              ? values['id']!.trim()
              : 'player-${DateTime.now().microsecondsSinceEpoch}',
          name: values['name']?.trim() ?? 'Spieler',
          createdAt: now,
          updatedAt: now,
          lastModifiedReason: 'csv_import',
          source: PlayerProfileSourceSerialization.fromStorageValue(
            values['source'],
          ),
          isFavorite: values['favorite'] == 'true',
          isProtected: values['protected'] == 'true',
          age: int.tryParse(values['age'] ?? ''),
          nationality: _normalizeNationality(values['nationality']),
          favoriteDouble: _normalizeNullableText(values['favoriteDouble']),
          hatedDouble: _normalizeNullableText(values['hatedDouble']),
          tags: _normalizeTags((values['tags'] ?? '').split('|')),
          notes: _normalizeNullableText(values['notes']),
          preferences: PlayerProfilePreferences(
            preferredView: values['preferredView']?.trim().isEmpty ?? true
                ? 'overview'
                : values['preferredView']!.trim(),
            defaultTrainingMode:
                values['defaultTrainingMode']?.trim().isEmpty ?? true
                    ? 'X01'
                    : values['defaultTrainingMode']!.trim(),
            defaultMatchMode:
                values['defaultMatchMode']?.trim().isEmpty ?? true
                    ? 'X01'
                    : values['defaultMatchMode']!.trim(),
            avatarEmoji: values['avatarEmoji']?.trim().isEmpty ?? true
                ? '🎯'
                : values['avatarEmoji']!.trim(),
            avatarColor: values['avatarColor']?.trim().isEmpty ?? true
                ? '#1565C0'
                : values['avatarColor']!.trim(),
            favoriteFormats: (values['favoriteFormats'] ?? '')
                .split('|')
                .map((entry) => entry.trim())
                .where((entry) => entry.isNotEmpty)
                .toList(),
          ),
        ),
      );
    }
    await importFromJsonString(
      jsonEncode(<String, dynamic>{
        'activePlayerId': _activePlayerId,
        'players': importedPlayers.map((entry) => entry.toJson()).toList(),
      }),
      replaceExisting: replaceExisting,
    );
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, dynamic>{
        'activePlayerId': _activePlayerId,
        'tagDefinitions': _tagDefinitions,
        'players': _players.map((entry) => entry.toJson()).toList(),
      },
    );
  }

  PlayerProfile _normalizePlayer(PlayerProfile player) {
    final normalizedTags = _normalizeTags(player.tags);
    final rebuiltStats = _rebuildStatsFromHistory(player);
    final rebuiltCricketStats = _rebuildCricketStatsFromHistory(player);
    final rebuiltBob27Stats = _rebuildBob27StatsFromHistory(player);
    final average = rebuiltStats.dartsThrown > 0
        ? rebuiltStats.average
        : player.average;
    return player.copyWith(
      nationality: _normalizeNationality(player.nationality),
      clearNationality: _normalizeNationality(player.nationality) == null,
      tags: normalizedTags,
      notes: _normalizeNullableText(player.notes),
      clearNotes: _normalizeNullableText(player.notes) == null,
      equipmentSetups: player.equipmentSetups,
      activeEquipmentId: _resolveActiveEquipment(player)?.id,
      stats: rebuiltStats,
      cricketStats: rebuiltCricketStats,
      bob27Stats: rebuiltBob27Stats,
      average: average,
      matchesPlayed: player.history.length > player.matchesPlayed
          ? player.history.length
          : player.matchesPlayed,
      matchesWon: _historyWinCount(player) > player.matchesWon
          ? _historyWinCount(player)
          : player.matchesWon,
    );
  }

  int _historyWinCount(PlayerProfile player) {
    return player.history.where((entry) => entry.won).length;
  }

  PlayerProfileStats _rebuildStatsFromHistory(PlayerProfile player) {
    final aggregate = _buildX01StatsFromEntries(
      playerId: player.id,
      playerName: player.name,
      entries: player.history,
    );
    if (aggregate.dartsThrown <= 0 && player.stats.dartsThrown > 0) {
      return player.stats;
    }
    return aggregate;
  }

  PlayerProfileAnalytics buildAnalytics(
    PlayerProfile player, {
    PlayerAnalyticsRange range = PlayerAnalyticsRange.allTime,
    String? equipmentId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final x01Entries = player.history.where((entry) => entry.match != null).toList()
      ..sort((left, right) => right.playedAt.compareTo(left.playedAt));

    PlayerStatsWindow buildWindow(String label, List<PlayerMatchHistoryEntry> entries) {
      return PlayerStatsWindow(
        label: label,
        matchCount: entries.length,
        winCount: entries.where((entry) => entry.won).length,
        stats: _buildX01StatsFromEntries(
          playerId: player.id,
          playerName: player.name,
          entries: entries,
        ),
      );
    }

    final setupFilteredEntries = equipmentId == null
        ? x01Entries
        : x01Entries
            .where((entry) => entry.equipmentId == equipmentId)
            .toList();
    final dateFilteredEntries = _filterMatchEntriesByRange(
      setupFilteredEntries,
      startDate: startDate,
      endDate: endDate,
    );
    final filteredX01Entries =
        startDate == null && endDate == null
            ? _applyRangeToMatchEntries(dateFilteredEntries, range)
            : dateFilteredEntries;
    final setupFilteredTrainingEntries = equipmentId == null
        ? player.trainingHistory
        : player.trainingHistory
            .where((entry) => entry.equipmentId == equipmentId)
            .toList();
    final filteredTrainingEntries = _applyRangeToTrainingEntries(
      _filterTrainingEntriesByRange(
        setupFilteredTrainingEntries,
        startDate: startDate,
        endDate: endDate,
      ),
      startDate == null && endDate == null
          ? range
          : PlayerAnalyticsRange.allTime,
    );
    final filteredStats = _buildX01StatsFromEntries(
      playerId: player.id,
      playerName: player.name,
      entries: filteredX01Entries,
    );
    final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
    final last5Entries = filteredX01Entries.take(5).toList();
    final last10Entries = filteredX01Entries.take(10).toList();
    final last25Entries = filteredX01Entries.take(25).toList();
    final last3MonthsEntries = filteredX01Entries
        .where((entry) => entry.playedAt.isAfter(threeMonthsAgo))
        .toList();
    final shortEntries = filteredX01Entries.where((entry) {
      final stats = _resolveParticipantStats(
        playerId: player.id,
        playerName: player.name,
        result: entry.match!,
      );
      return stats.legsPlayed <= 9;
    }).toList();
    final longEntries = filteredX01Entries.where((entry) {
      final stats = _resolveParticipantStats(
        playerId: player.id,
        playerName: player.name,
        result: entry.match!,
      );
      return stats.legsPlayed > 9;
    }).toList();
    final humanEntries = filteredX01Entries
        .where((entry) => entry.opponentType == PlayerOpponentKind.human)
        .toList();
    final cpuEntries = filteredX01Entries
        .where((entry) => entry.opponentType == PlayerOpponentKind.cpu)
        .toList();

    final allHeadToHead = _buildHeadToHead(player, filteredX01Entries);
    final favoriteOpponent = allHeadToHead.isEmpty
        ? null
        : (List<PlayerHeadToHeadStats>.from(allHeadToHead)
          ..sort((left, right) {
            final byWinRate = right.winRate.compareTo(left.winRate);
            if (byWinRate != 0) {
              return byWinRate;
            }
            return right.matches.compareTo(left.matches);
          })).first;
    final toughestOpponent = allHeadToHead.isEmpty
        ? null
        : (List<PlayerHeadToHeadStats>.from(allHeadToHead)
          ..sort((left, right) {
            final byWinRate = left.winRate.compareTo(right.winRate);
            if (byWinRate != 0) {
              return byWinRate;
            }
            return right.matches.compareTo(left.matches);
          })).first;

    return PlayerProfileAnalytics(
      filterRange: range,
      filterEquipmentId: equipmentId,
      filterStartDate: startDate,
      filterEndDate: endDate,
      filtered: buildWindow(range.label, filteredX01Entries),
      filteredTrainingCount: filteredTrainingEntries.length,
      last5: buildWindow('Letzte 5', last5Entries),
      last10: buildWindow('Letzte 10', last10Entries),
      last25: buildWindow('Letzte 25', last25Entries),
      last3Months: buildWindow('Letzte 3 Monate', last3MonthsEntries),
      allTime: buildWindow('All Time', filteredX01Entries),
      withThrow: PlayerStatsWindow(
        label: 'Mit Anwurf',
        matchCount: filteredX01Entries.length,
        winCount: filteredX01Entries.where((entry) => entry.won).length,
        stats: const PlayerProfileStats().copyWith(
          withThrowPoints: filteredStats.withThrowPoints,
          withThrowDarts: filteredStats.withThrowDarts,
        ),
      ),
      againstThrow: PlayerStatsWindow(
        label: 'Ohne Anwurf',
        matchCount: filteredX01Entries.length,
        winCount: filteredX01Entries.where((entry) => entry.won).length,
        stats: const PlayerProfileStats().copyWith(
          againstThrowPoints: filteredStats.againstThrowPoints,
          againstThrowDarts: filteredStats.againstThrowDarts,
        ),
      ),
      decider: buildWindow(
        'Decider',
        filteredX01Entries.where((entry) => _entryHasDecider(entry)).toList(),
      ),
      bestOfShort: buildWindow('Best of Short', shortEntries),
      bestOfLong: buildWindow('Best of Long', longEntries),
      vsHuman: buildWindow('Gegen Menschen', humanEntries),
      vsCpu: buildWindow('Gegen CPU', cpuEntries),
      headToHead: allHeadToHead,
      favoriteOpponent: favoriteOpponent,
      toughestOpponent: toughestOpponent,
      movingAverage: _buildMovingAverage(filteredX01Entries),
      equipment: _buildEquipmentPerformance(
        player,
        range: range,
        selectedEquipmentId: equipmentId,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  MatchParticipantStats _resolveParticipantStats({
    required String playerId,
    required String playerName,
    required MatchResultSummary result,
  }) {
    for (final participant in result.participants) {
      if (participant.participantId == playerId) {
        return participant;
      }
    }
    for (final participant in result.participants) {
      if (participant.participantName.trim().toLowerCase() ==
          playerName.trim().toLowerCase()) {
        return participant;
      }
    }
    return result.participants.first;
  }

  CricketParticipantStats _resolveCricketParticipantStats({
    required String playerId,
    required String playerName,
    required CricketResultSummary result,
  }) {
    for (final participant in result.participants) {
      if (participant.participantId == playerId) {
        return participant;
      }
    }
    for (final participant in result.participants) {
      if (participant.name.trim().toLowerCase() ==
          playerName.trim().toLowerCase()) {
        return participant;
      }
    }
    return result.participants.first;
  }

  Bob27ParticipantStats _resolveBob27ParticipantStats({
    required String playerId,
    required String playerName,
    required Bob27ResultSummary result,
  }) {
    for (final participant in result.participants) {
      if (participant.participantId == playerId) {
        return participant;
      }
    }
    for (final participant in result.participants) {
      if (participant.name.trim().toLowerCase() ==
          playerName.trim().toLowerCase()) {
        return participant;
      }
    }
    return result.participants.first;
  }

  PlayerCricketStats _rebuildCricketStatsFromHistory(PlayerProfile player) {
    var aggregate = const PlayerCricketStats();
    for (final entry in player.history) {
      if (entry.cricketMatch == null) {
        continue;
      }
      aggregate = aggregate.merge(
        PlayerCricketStats.fromParticipantStats(
          _resolveCricketParticipantStats(
            playerId: player.id,
            playerName: player.name,
            result: entry.cricketMatch!,
          ),
          won: entry.won,
        ),
      );
    }
    return aggregate.matchesPlayed <= 0 && player.cricketStats.matchesPlayed > 0
        ? player.cricketStats
        : aggregate;
  }

  PlayerBob27Stats _rebuildBob27StatsFromHistory(PlayerProfile player) {
    var aggregate = const PlayerBob27Stats();
    for (final entry in player.history) {
      if (entry.bob27Match == null) {
        continue;
      }
      aggregate = aggregate.merge(
        PlayerBob27Stats.fromParticipantStats(
          _resolveBob27ParticipantStats(
            playerId: player.id,
            playerName: player.name,
            result: entry.bob27Match!,
          ),
          won: entry.won,
        ),
      );
    }
    return aggregate.matchesPlayed <= 0 && player.bob27Stats.matchesPlayed > 0
        ? player.bob27Stats
        : aggregate;
  }

  PlayerEquipmentSetup? _resolveActiveEquipment(PlayerProfile player) {
    for (final setup in player.equipmentSetups) {
      if (setup.id == player.activeEquipmentId) {
        return setup;
      }
    }
    return player.equipmentSetups.isEmpty ? null : player.equipmentSetups.first;
  }

  PlayerProfileStats _buildX01StatsFromEntries({
    required String playerId,
    required String playerName,
    required List<PlayerMatchHistoryEntry> entries,
  }) {
    var aggregate = const PlayerProfileStats();
    for (final entry in entries) {
      final match = entry.match;
      if (match == null) {
        continue;
      }
      final participantStats = _resolveParticipantStats(
        playerId: playerId,
        playerName: playerName,
        result: match,
      );
      aggregate = aggregate.merge(
        PlayerProfileStats.fromMatchParticipantStats(participantStats).merge(
          _buildVisitDerivedStats(
            participantId: participantStats.participantId,
            result: match,
          ),
        ),
      );
    }
    return aggregate;
  }

  PlayerProfileStats _buildVisitDerivedStats({
    required String participantId,
    required MatchResultSummary result,
  }) {
    var firstThreePoints = 0.0;
    var firstThreeDarts = 0;
    var hundredPlusCheckouts = 0;
    for (final leg in result.legs) {
      final firstVisit = leg.visits.cast<MatchVisitEntry?>().firstWhere(
            (entry) => entry != null && entry.side == participantId,
            orElse: () => null,
          );
      if (firstVisit != null) {
        firstThreePoints += firstVisit.scoredPoints;
        firstThreeDarts += firstVisit.dartsUsed;
      }
      for (final visit in leg.visits) {
        if (visit.side != participantId) {
          continue;
        }
        if (visit.checkout && (visit.checkoutValue ?? 0) >= 100) {
          hundredPlusCheckouts += 1;
        }
      }
    }
    return PlayerProfileStats(
      hundredPlusCheckouts: hundredPlusCheckouts,
      firstThreePoints: firstThreePoints,
      firstThreeDarts: firstThreeDarts,
    );
  }

  bool _entryHasDecider(PlayerMatchHistoryEntry entry) {
    final match = entry.match;
    if (match == null) {
      return false;
    }
    return match.legs.any((leg) => leg.decidingLeg);
  }

  List<PlayerHeadToHeadStats> _buildHeadToHead(
    PlayerProfile player,
    List<PlayerMatchHistoryEntry> entries,
  ) {
    final grouped = <String, List<PlayerMatchHistoryEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.opponentName, () => <PlayerMatchHistoryEntry>[]).add(entry);
    }

    final summaries = grouped.entries.map((entry) {
      final matches = entry.value.length;
      final wins = entry.value.where((item) => item.won).length;
      final average = entry.value.fold<double>(0, (sum, item) => sum + item.average) / matches;
      final lastPlayedAt = entry.value
          .map((item) => item.playedAt)
          .reduce((left, right) => left.isAfter(right) ? left : right);
      final opponentType = entry.value.first.opponentType;
      return PlayerHeadToHeadStats(
        opponentName: entry.key,
        opponentType: opponentType,
        matches: matches,
        wins: wins,
        average: average,
        lastPlayedAt: lastPlayedAt,
      );
    }).toList();
    summaries.sort((left, right) => right.matches.compareTo(left.matches));
    return summaries;
  }

  List<double> _buildMovingAverage(List<PlayerMatchHistoryEntry> entries) {
    if (entries.isEmpty) {
      return const <double>[];
    }
    final chronological = entries.toList()
      ..sort((left, right) => left.playedAt.compareTo(right.playedAt));
    final result = <double>[];
    for (var index = 0; index < chronological.length; index += 1) {
      final start = index < 4 ? 0 : index - 4;
      final window = chronological.sublist(start, index + 1);
      final average =
          window.fold<double>(0, (sum, item) => sum + item.average) / window.length;
      result.add(average);
    }
    return result;
  }

  List<PlayerMatchHistoryEntry> _applyRangeToMatchEntries(
    List<PlayerMatchHistoryEntry> entries,
    PlayerAnalyticsRange range,
  ) {
    final sorted = entries.toList()
      ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
    switch (range) {
      case PlayerAnalyticsRange.allTime:
        return sorted;
      case PlayerAnalyticsRange.last5:
        return sorted.take(5).toList();
      case PlayerAnalyticsRange.last10:
        return sorted.take(10).toList();
      case PlayerAnalyticsRange.last25:
        return sorted.take(25).toList();
      case PlayerAnalyticsRange.last3Months:
        final threshold = DateTime.now().subtract(const Duration(days: 90));
        return sorted.where((entry) => entry.playedAt.isAfter(threshold)).toList();
    }
  }

  List<PlayerMatchHistoryEntry> _filterMatchEntriesByRange(
    List<PlayerMatchHistoryEntry> entries, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate == null && endDate == null) {
      return entries.toList()
        ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
    }
    final normalizedStart = startDate == null ? null : _startOfDay(startDate);
    final normalizedEnd = endDate == null ? null : _endOfDay(endDate);
    return entries.where((entry) {
      final playedAt = entry.playedAt.toLocal();
      if (normalizedStart != null && playedAt.isBefore(normalizedStart)) {
        return false;
      }
      if (normalizedEnd != null && playedAt.isAfter(normalizedEnd)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
  }

  List<PlayerTrainingEntry> _applyRangeToTrainingEntries(
    List<PlayerTrainingEntry> entries,
    PlayerAnalyticsRange range,
  ) {
    final sorted = entries.toList()
      ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
    switch (range) {
      case PlayerAnalyticsRange.allTime:
        return sorted;
      case PlayerAnalyticsRange.last5:
        return sorted.take(5).toList();
      case PlayerAnalyticsRange.last10:
        return sorted.take(10).toList();
      case PlayerAnalyticsRange.last25:
        return sorted.take(25).toList();
      case PlayerAnalyticsRange.last3Months:
        final threshold = DateTime.now().subtract(const Duration(days: 90));
        return sorted.where((entry) => entry.playedAt.isAfter(threshold)).toList();
    }
  }

  List<PlayerTrainingEntry> _filterTrainingEntriesByRange(
    List<PlayerTrainingEntry> entries, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate == null && endDate == null) {
      return entries.toList()
        ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
    }
    final normalizedStart = startDate == null ? null : _startOfDay(startDate);
    final normalizedEnd = endDate == null ? null : _endOfDay(endDate);
    return entries.where((entry) {
      final playedAt = entry.playedAt.toLocal();
      if (normalizedStart != null && playedAt.isBefore(normalizedStart)) {
        return false;
      }
      if (normalizedEnd != null && playedAt.isAfter(normalizedEnd)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((left, right) => right.playedAt.compareTo(left.playedAt));
  }

  DateTime _startOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _endOfDay(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day, 23, 59, 59, 999, 999);
  }

  List<PlayerEquipmentPerformance> _buildEquipmentPerformance(
    PlayerProfile player, {
    required PlayerAnalyticsRange range,
    String? selectedEquipmentId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final setupsById = <String, PlayerEquipmentSetup>{
      for (final setup in player.equipmentSetups) setup.id: setup,
    };
    final buckets = <String, ({List<PlayerMatchHistoryEntry> matches, List<PlayerTrainingEntry> trainings})>{};

    final dateFilteredHistory = _filterMatchEntriesByRange(
      player.history.where((entry) => entry.match != null).toList(),
      startDate: startDate,
      endDate: endDate,
    );
    final filteredHistory =
        startDate == null && endDate == null
            ? _applyRangeToMatchEntries(dateFilteredHistory, range)
            : dateFilteredHistory;
    final dateFilteredTrainings = _filterTrainingEntriesByRange(
      player.trainingHistory,
      startDate: startDate,
      endDate: endDate,
    );
    final filteredTrainings = _applyRangeToTrainingEntries(
      dateFilteredTrainings,
      startDate == null && endDate == null
          ? range
          : PlayerAnalyticsRange.allTime,
    );

    for (final entry in filteredHistory) {
      final equipmentId = entry.equipmentId;
      if (equipmentId == null ||
          entry.match == null ||
          (selectedEquipmentId != null && equipmentId != selectedEquipmentId)) {
        continue;
      }
      final bucket = buckets[equipmentId] ??
          (matches: <PlayerMatchHistoryEntry>[], trainings: <PlayerTrainingEntry>[]);
      bucket.matches.add(entry);
      buckets[equipmentId] = bucket;
    }
    for (final entry in filteredTrainings) {
      final equipmentId = entry.equipmentId;
      if (equipmentId == null ||
          (selectedEquipmentId != null && equipmentId != selectedEquipmentId)) {
        continue;
      }
      final bucket = buckets[equipmentId] ??
          (matches: <PlayerMatchHistoryEntry>[], trainings: <PlayerTrainingEntry>[]);
      bucket.trainings.add(entry);
      buckets[equipmentId] = bucket;
    }

    final performances = <PlayerEquipmentPerformance>[];
    for (final bucket in buckets.entries) {
      final setup = setupsById[bucket.key];
      final firstMatchName =
          bucket.value.matches.isEmpty ? null : bucket.value.matches.first.equipmentName;
      final firstTrainingName = bucket.value.trainings.isEmpty
          ? null
          : bucket.value.trainings.first.equipmentName;
      final name = setup?.name ??
          firstMatchName ??
          firstTrainingName ??
          'Equipment';
      final stats = _buildX01StatsFromEntries(
        playerId: player.id,
        playerName: player.name,
        entries: bucket.value.matches,
      );
      performances.add(
        PlayerEquipmentPerformance(
          equipmentId: bucket.key,
          equipmentName: name,
          matchCount: bucket.value.matches.length,
          trainingCount: bucket.value.trainings.length,
          stats: stats,
          winCount: bucket.value.matches.where((entry) => entry.won).length,
        ),
      );
    }
    performances.sort((left, right) => right.matchCount.compareTo(left.matchCount));
    return performances;
  }

  void _syncTagDefinitions() {
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
  }

  List<String> _mergeTagDefinitions(
    List<String> existing,
    List<PlayerProfile> players,
  ) {
    final seen = <String>{};
    final merged = <String>[];
    void add(String? value) {
      final normalized = _normalizeNullableText(value);
      if (normalized == null) {
        return;
      }
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        merged.add(normalized);
      }
    }

    for (final value in existing) {
      add(value);
    }
    for (final player in players) {
      for (final tag in player.tags) {
        add(tag);
      }
    }
    merged.sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return merged;
  }

  String? _normalizeNationality(String? value) {
    final normalized = _normalizeNullableText(value);
    if (normalized == null) {
      return null;
    }
    for (final nationality in NationalityCatalog.officialNationalities) {
      if (nationality.toLowerCase() == normalized.toLowerCase()) {
        return nationality;
      }
    }
    return normalized;
  }

  List<String> _normalizeTags(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      final next = _normalizeNullableText(value);
      if (next == null) {
        continue;
      }
      final key = next.toLowerCase();
      if (seen.add(key)) {
        normalized.add(next);
      }
    }
    normalized.sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
    return normalized;
  }

  String? _normalizeNullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _toCsvRow(List<String> values) {
    return values
        .map((value) => '"${value.replaceAll('"', '""')}"')
        .join(',');
  }

  List<List<String>> _parseCsv(String rawValue) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    void pushCell() {
      currentRow.add(buffer.toString());
      buffer.clear();
    }

    void pushRow() {
      if (currentRow.isNotEmpty || buffer.isNotEmpty) {
        pushCell();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
      }
    }

    for (var index = 0; index < rawValue.length; index += 1) {
      final char = rawValue[index];
      if (char == '"') {
        if (inQuotes &&
            index + 1 < rawValue.length &&
            rawValue[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        pushCell();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' &&
            index + 1 < rawValue.length &&
            rawValue[index + 1] == '\n') {
          index += 1;
        }
        pushRow();
      } else {
        buffer.write(char);
      }
    }
    pushRow();
    return rows;
  }
}

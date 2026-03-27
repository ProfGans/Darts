import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/bot/bot_engine.dart';
import '../../domain/career/career_template.dart';
import '../../presentation/match/bob27_result_models.dart';
import '../../presentation/match/cricket_result_models.dart';
import '../../presentation/match/match_result_models.dart';
import '../models/generated_name_catalog.dart';
import '../models/nationality_catalog.dart';
import '../models/computer_player.dart';
import 'settings_repository.dart';
import '../storage/app_storage.dart';

class ComputerSkillResolution {
  const ComputerSkillResolution({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
}

class _SkillResolutionCandidate {
  const _SkillResolutionCandidate({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
    required this.error,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
  final double error;

  int get gap => (skill - finishingSkill).abs();

  ComputerSkillResolution toResolution() {
    return ComputerSkillResolution(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: theoreticalAverage,
    );
  }
}

class _RepositorySnapshot {
  const _RepositorySnapshot({
    required this.players,
    required this.tagDefinitions,
    required this.nationalityDefinitions,
  });

  final List<ComputerPlayer> players;
  final List<String> tagDefinitions;
  final List<String> nationalityDefinitions;
}

class ComputerRepository extends ChangeNotifier {
  ComputerRepository._();

  static final ComputerRepository instance = ComputerRepository._();

  static const _storageKey = 'computer_players';
  static const _bundledDefaultsAssetPath =
      'assets/data/default_computer_players.json';
  static const _bundledTemplateAssetPath =
      'assets/templates/basic_pdc_template.json';
  static const bulkTag = 'Bulk';
  static const realPlayerTag = 'Echter Spieler';
  static const List<String> officialNationalities =
      NationalityCatalog.officialNationalities;

  final BotEngine _botEngine = BotEngine();
  final List<ComputerPlayer> _players = <ComputerPlayer>[];
  final List<String> _tagDefinitions = <String>[];
  final List<String> _nationalityDefinitions = <String>[];
  final List<_RepositorySnapshot> _undoStack = <_RepositorySnapshot>[];
  int _changeToken = 0;

  List<ComputerPlayer> get players =>
      List<ComputerPlayer>.unmodifiable(_players);
  List<String> get tagDefinitions => List<String>.unmodifiable(_tagDefinitions);
  List<String> get nationalityDefinitions =>
      List<String>.unmodifiable(_nationalityDefinitions);
  bool get canUndo => _undoStack.isNotEmpty;
  int get changeToken => _changeToken;

  @override
  void notifyListeners() {
    _changeToken += 1;
    super.notifyListeners();
  }

  Future<void> initialize() async {
    final storedJson = await AppStorage.instance.readJsonMap(_storageKey);
    final bundledJson = await _loadBundledDefaults();
    final json = _shouldUseBundledDefaults(storedJson)
        ? (bundledJson ?? storedJson)
        : (storedJson ?? bundledJson);
    if (json == null) {
      _seedDefaults();
      _tagDefinitions
        ..clear()
        ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
      _nationalityDefinitions
        ..clear()
        ..addAll(_mergeNationalityDefinitions(_nationalityDefinitions, _players));
      _sortPlayers();
      notifyListeners();
      await _persist();
      return;
    }
    _applyStoragePayload(json);
    notifyListeners();
    await _persist();
  }

  bool _shouldUseBundledDefaults(Map<String, dynamic>? json) {
    if (json == null) {
      return true;
    }

    final players = json['players'] as List<dynamic>? ?? const <dynamic>[];
    if (players.isEmpty) {
      return true;
    }

    if (players.length > 6) {
      return false;
    }

    final allSeedDefaults = players.every((entry) {
      if (entry is! Map) {
        return false;
      }
      final map = entry.cast<String, dynamic>();
      final reason = (map['lastModifiedReason'] ?? '').toString();
      return reason == 'seed_default';
    });

    return allSeedDefaults;
  }

  void _applyStoragePayload(Map<String, dynamic> json) {
    final loadedDefinitions =
        ((json['tagDefinitions'] ?? json['attributeDefinitions']) as List<dynamic>? ??
                const <dynamic>[])
        .map((entry) => entry.toString())
        .toList();
    final loadedNationalities =
        (json['nationalityDefinitions'] as List<dynamic>? ?? const <dynamic>[])
            .map((entry) => entry.toString())
            .toList();
    final loadedPlayers =
        (json['players'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (entry) => _normalizePlayer(
                ComputerPlayer.fromJson(
                  (entry as Map).cast<String, dynamic>(),
                ),
              ),
            )
            .toList();
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(loadedDefinitions, loadedPlayers));
    _nationalityDefinitions
      ..clear()
      ..addAll(_mergeNationalityDefinitions(loadedNationalities, loadedPlayers));
    final normalizedPlayers = _normalizePlayers(loadedPlayers);
    _players
      ..clear()
      ..addAll(normalizedPlayers);
    _sortPlayers();
  }

  Future<Map<String, dynamic>?> _loadBundledDefaults() async {
    try {
      final raw = await rootBundle.loadString(_bundledDefaultsAssetPath);
      final decoded = jsonDecode(raw.replaceFirst('\uFEFF', ''));
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
              ? decoded.cast<String, dynamic>()
              : null;
      if (_isValidStoragePayload(payload)) {
        return payload;
      }
    } catch (_) {
      // Fall back to rebuilding defaults from the bundled career template.
    }
    return _buildBundledDefaultsFromTemplateAsset();
  }

  bool _isValidStoragePayload(Map<String, dynamic>? payload) {
    if (payload == null) {
      return false;
    }
    final players = payload['players'] as List<dynamic>? ?? const <dynamic>[];
    if (players.isEmpty) {
      return false;
    }
    return players.every((entry) {
      if (entry is! Map) {
        return false;
      }
      final map = entry.cast<String, dynamic>();
      return map['id'] is String &&
          map['name'] is String &&
          map['skill'] is num &&
          map['finishingSkill'] is num &&
          map['theoreticalAverage'] is num;
    });
  }

  Future<Map<String, dynamic>?> _buildBundledDefaultsFromTemplateAsset() async {
    try {
      final raw = await rootBundle.loadString(_bundledTemplateAssetPath);
      final decoded = jsonDecode(raw.replaceFirst('\uFEFF', ''));
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
              ? decoded.cast<String, dynamic>()
              : null;
      if (payload == null) {
        return null;
      }

      final template = CareerTemplate.fromJson(payload);
      final nowIso = DateTime.now().toIso8601String();
      final players = template.databasePlayers.map((entry) {
        final tags = <String>{
          realPlayerTag,
          ...entry.careerTags.map((tag) => tag.tagName.trim()).where(
                (tag) => tag.isNotEmpty,
              ),
        }.toList();
        return <String, dynamic>{
          'id': entry.databasePlayerId,
          'name': entry.name,
          'skill': entry.skill,
          'finishingSkill': entry.finishingSkill,
          'theoreticalAverage': entry.average,
          'createdAt': nowIso,
          'updatedAt': nowIso,
          'lastModifiedReason': 'bundled_asset',
          'source': ComputerPlayerSource.imported.storageValue,
          'isFavorite': false,
          'isProtected': false,
          'tags': tags,
          'matchesPlayed': 0,
          'matchesWon': 0,
          'average': 0,
          'history': const <dynamic>[],
        };
      }).toList();

      final rebuiltPayload = <String, dynamic>{
        'tagDefinitions': <String>[
          realPlayerTag,
          ...template.databasePlayers
              .expand((entry) => entry.careerTags.map((tag) => tag.tagName))
              .where((tag) => tag.trim().isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
        ],
        'nationalityDefinitions': officialNationalities,
        'players': players,
      };

      return _isValidStoragePayload(rebuiltPayload) ? rebuiltPayload : null;
    } catch (_) {
      return null;
    }
  }

  void _captureSnapshot() {
    _undoStack.add(
      _RepositorySnapshot(
      players: _players
          .map((player) => ComputerPlayer.fromJson(player.toJson()))
          .toList(),
      tagDefinitions: List<String>.from(_tagDefinitions),
      nationalityDefinitions: List<String>.from(_nationalityDefinitions),
      ),
    );
    if (_undoStack.length > 20) {
      _undoStack.removeAt(0);
    }
  }

  Future<void> undoLastChange() async {
    if (_undoStack.isEmpty) {
      return;
    }
    final snapshot = _undoStack.removeLast();
    _players
      ..clear()
      ..addAll(snapshot.players);
    _tagDefinitions
      ..clear()
      ..addAll(snapshot.tagDefinitions);
    _nationalityDefinitions
      ..clear()
      ..addAll(snapshot.nationalityDefinitions);
    _sortPlayers();
    notifyListeners();
    await _persist();
  }

  void _seedDefaults() {
    if (_players.isNotEmpty) {
      return;
    }

    _players.addAll(
      <ComputerPlayer>[
        _createPlayer('Luke Humphries', 840, 840),
        _createPlayer('Luke Littler', 860, 820),
        _createPlayer('Michael van Gerwen', 820, 790),
        _createPlayer('Gerwyn Price', 790, 770),
        _createPlayer('Gary Anderson', 770, 750),
        _createPlayer('Nathan Aspinall', 740, 760),
      ],
    );
  }

  ComputerPlayer _createPlayer(String name, int skill, int finishingSkill) {
    final theoreticalAverage = _estimateTheoreticalAverage(
      skill: skill,
      finishingSkill: finishingSkill,
    );
    final now = DateTime.now();
    return ComputerPlayer(
      id: 'computer-${DateTime.now().microsecondsSinceEpoch}-${name.length}',
      name: name,
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: theoreticalAverage,
      createdAt: now,
      updatedAt: now,
      lastModifiedReason: 'seed_default',
    );
  }

  void addPlayer({
    required String name,
    required double targetTheoreticalAverage,
    int? age,
    String? nationality,
    List<String> tags = const <String>[],
    ComputerPlayerSource source = ComputerPlayerSource.manual,
  }) {
    _captureSnapshot();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final resolution =
        resolveSkillsForTheoreticalAverage(targetTheoreticalAverage);
    final normalizedNationality = _normalizeNationality(nationality);
    final normalizedTags = _normalizeTags(tags);
    _tagDefinitions
      ..clear()
      ..addAll(
        _mergeTagDefinitions(_tagDefinitions, <ComputerPlayer>[
          ComputerPlayer(
            id: '',
            name: trimmed,
            skill: resolution.skill,
            finishingSkill: resolution.finishingSkill,
            theoreticalAverage: resolution.theoreticalAverage,
            createdAt: now,
            updatedAt: now,
            lastModifiedReason: 'manual_create',
            source: source,
            age: age,
            nationality: normalizedNationality,
            tags: normalizedTags,
          ),
        ]),
      );
    _nationalityDefinitions
      ..clear()
      ..addAll(
        _mergeNationalityDefinitions(_nationalityDefinitions, <ComputerPlayer>[
          ComputerPlayer(
            id: '',
            name: trimmed,
            skill: resolution.skill,
            finishingSkill: resolution.finishingSkill,
            theoreticalAverage: resolution.theoreticalAverage,
            createdAt: now,
            updatedAt: now,
            lastModifiedReason: 'manual_create',
            source: source,
            age: age,
            nationality: normalizedNationality,
            tags: normalizedTags,
          ),
        ]),
      );
    _players.add(
      ComputerPlayer(
        id: 'computer-${DateTime.now().microsecondsSinceEpoch}-${trimmed.length}',
        name: trimmed,
        skill: resolution.skill,
        finishingSkill: resolution.finishingSkill,
        theoreticalAverage: resolution.theoreticalAverage,
        createdAt: now,
        updatedAt: now,
        lastModifiedReason: 'manual_create',
        source: source,
        age: age,
        nationality: normalizedNationality,
        tags: normalizedTags,
      ),
    );
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  void addPlayersBulk({
    required String namePrefix,
    required int count,
    required double minimumAverage,
    required double maximumAverage,
    int? minimumAge,
    int? maximumAge,
    List<String> nationalities = const <String>[],
    List<String> tags = const <String>[],
  }) {
    _captureSnapshot();
    final trimmedPrefix = namePrefix.trim().isEmpty ? 'CPU' : namePrefix.trim();
    final safeCount = count.clamp(1, 500);
    final minAverage = minimumAverage.clamp(0, 180).toDouble();
    final maxAverage = maximumAverage.clamp(0, 180).toDouble();
    final lowAverage = minAverage <= maxAverage ? minAverage : maxAverage;
    final highAverage = minAverage <= maxAverage ? maxAverage : minAverage;
    final explicitAgeRange = _resolveOptionalRange(minimumAge, maximumAge);
    final normalizedNationalities = nationalities
        .map(_normalizeNationality)
        .whereType<String>()
        .toList();
    final nextPlayers = <ComputerPlayer>[];
    final usedNamesLowercase = _players
        .map((player) => player.name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    final random = Random();

    for (var index = 0; index < safeCount; index += 1) {
      final progress = safeCount == 1 ? 0.0 : index / (safeCount - 1);
      final targetAverage =
          lowAverage + ((highAverage - lowAverage) * progress);
      final resolution = resolveSkillsForTheoreticalAverage(targetAverage);
      final nationality = normalizedNationalities.isEmpty
          ? null
          : normalizedNationalities[index % normalizedNationalities.length];
      final ageRange =
          explicitAgeRange ?? _suggestAgeRangeForAverage(targetAverage);
      final age = _randomFromRange(ageRange, random);
      final normalizedTags = _normalizeTags(
        <String>[
          ...tags,
          bulkTag,
          ..._suggestTagsForBulkProfile(
            targetAverage: targetAverage,
            age: age,
            source: ComputerPlayerSource.bulk,
          ),
        ],
      );
      final generatedName = GeneratedNameCatalog.generateUniquePlayerName(
        random: random,
        usedNamesLowercase: usedNamesLowercase,
        nationality: nationality,
        fallbackPrefix: trimmedPrefix,
      );
      final now = DateTime.now();
      nextPlayers.add(
        ComputerPlayer(
          id: 'computer-${DateTime.now().microsecondsSinceEpoch}-$index',
          name: generatedName,
          skill: resolution.skill,
          finishingSkill: resolution.finishingSkill,
          theoreticalAverage: resolution.theoreticalAverage,
          createdAt: now,
          updatedAt: now,
          lastModifiedReason: 'bulk_create',
          source: ComputerPlayerSource.bulk,
          age: age,
          nationality: nationality,
          tags: normalizedTags,
        ),
      );
    }

    _players.addAll(nextPlayers);
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
    _nationalityDefinitions
      ..clear()
      ..addAll(_mergeNationalityDefinitions(_nationalityDefinitions, _players));
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> importPlayers(
    List<ComputerPlayer> importedPlayers, {
    bool replaceExisting = false,
  }) async {
    _captureSnapshot();
    if (importedPlayers.isEmpty) {
      return;
    }

    final nextPlayers = replaceExisting
        ? <ComputerPlayer>[]
        : List<ComputerPlayer>.from(_players);

    for (final imported in importedPlayers) {
      final index = nextPlayers.indexWhere((entry) => entry.id == imported.id);
      if (index >= 0) {
        nextPlayers[index] = imported;
        continue;
      }

      final nameIndex = nextPlayers.indexWhere(
        (entry) => entry.name.toLowerCase() == imported.name.toLowerCase(),
      );
      if (nameIndex >= 0) {
        nextPlayers[nameIndex] = imported;
        continue;
      }
      final duplicateIndex = _findLikelyDuplicateIndex(
        players: nextPlayers,
        candidate: imported,
      );
      if (duplicateIndex >= 0) {
        nextPlayers[duplicateIndex] = imported;
        continue;
      }
      nextPlayers.add(imported);
    }

    final normalizedPlayers = _normalizePlayers(nextPlayers);
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, normalizedPlayers));
    _nationalityDefinitions
      ..clear()
      ..addAll(
        _mergeNationalityDefinitions(_nationalityDefinitions, normalizedPlayers),
      );
    _players
      ..clear()
      ..addAll(normalizedPlayers);
    _sortPlayers();
    notifyListeners();
    await _persist();
  }

  void updatePlayer({
    required String id,
    required String name,
    required double targetTheoreticalAverage,
    int? age,
    String? nationality,
    List<String> tags = const <String>[],
    ComputerPlayerSource? source,
    bool? isFavorite,
    bool? isProtected,
  }) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == id);
    if (index < 0) {
      return;
    }

    final resolution =
        resolveSkillsForTheoreticalAverage(targetTheoreticalAverage);
    final normalizedNationality = _normalizeNationality(nationality);
    final normalizedTags = _normalizeTags(tags);
    _players[index] = _players[index].copyWith(
      name: name.trim(),
      skill: resolution.skill,
      finishingSkill: resolution.finishingSkill,
      theoreticalAverage: resolution.theoreticalAverage,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'manual_update',
      source: source ?? _players[index].source,
      isFavorite: isFavorite ?? _players[index].isFavorite,
      isProtected: isProtected ?? _players[index].isProtected,
      age: age,
      clearAge: age == null,
      nationality: normalizedNationality,
      clearNationality: normalizedNationality == null,
      tags: normalizedTags,
    );
    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
    _nationalityDefinitions
      ..clear()
      ..addAll(_mergeNationalityDefinitions(_nationalityDefinitions, _players));
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  void addTagDefinition(String name) {
    final normalizedName = _normalizeText(name);
    if (normalizedName == null) {
      return;
    }
    if (_tagDefinitions.any(
      (entry) => entry.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      return;
    }
    _tagDefinitions.add(normalizedName);
    notifyListeners();
    unawaited(_persist());
  }

  void assignTagToAllPlayers(String tag) {
    _captureSnapshot();
    final normalizedTag = _normalizeText(tag);
    if (normalizedTag == null || _players.isEmpty) {
      return;
    }

    if (_tagDefinitions.every(
      (entry) => entry.toLowerCase() != normalizedTag.toLowerCase(),
    )) {
      _tagDefinitions.add(normalizedTag);
    }

    for (var index = 0; index < _players.length; index += 1) {
      final current = _players[index];
      final hasTag = current.tags.any(
        (entry) => entry.toLowerCase() == normalizedTag.toLowerCase(),
      );
      if (hasTag) {
        continue;
      }
      _players[index] = current.copyWith(
        tags: <String>[...current.tags, normalizedTag],
        updatedAt: DateTime.now(),
        lastModifiedReason: 'assign_tag_all',
      );
    }

    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
    notifyListeners();
    unawaited(_persist());
  }

  void addNationalityDefinition(String name) {
    final normalizedName = _normalizeText(name);
    if (normalizedName == null) {
      return;
    }
    if (_nationalityDefinitions.any(
      (entry) => entry.toLowerCase() == normalizedName.toLowerCase(),
    )) {
      return;
    }
    _nationalityDefinitions.add(normalizedName);
    notifyListeners();
    unawaited(_persist());
  }

  ComputerSkillResolution resolveSkillsForTheoreticalAverage(
    double targetTheoreticalAverage,
  ) {
    final target = targetTheoreticalAverage.clamp(0, 180).toDouble();
    final bestEqual = _findBestEqualCandidate(target);
    final bestSplit = _findBestSplitCandidate(target, fallback: bestEqual);
    const improvementEpsilon = 0.01;

    if (bestSplit.error + improvementEpsilon < bestEqual.error) {
      return bestSplit.toResolution();
    }
    return bestEqual.toResolution();
  }

  Future<void> refreshTheoreticalAverages() async {
    _captureSnapshot();
    final normalizedPlayers = _normalizePlayers(_players);
    _players
      ..clear()
      ..addAll(normalizedPlayers);
    _sortPlayers();
    notifyListeners();
    await _persist();
  }

  void deletePlayer(String id) {
    _captureSnapshot();
    _players.removeWhere((player) => player.id == id && !player.isProtected);
    notifyListeners();
    unawaited(_persist());
  }

  void deletePlayers(Iterable<String> ids) {
    _captureSnapshot();
    final idSet = ids.toSet();
    if (idSet.isEmpty) {
      return;
    }
    _players.removeWhere(
      (player) => idSet.contains(player.id) && !player.isProtected,
    );
    notifyListeners();
    unawaited(_persist());
  }

  void toggleFavorite(String id) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == id);
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

  void toggleProtected(String id) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == id);
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

  void bulkUpdatePlayers({
    required Iterable<String> ids,
    String? nationality,
    bool clearNationality = false,
    int? minimumAge,
    int? maximumAge,
    bool clearAge = false,
    List<String> addTags = const <String>[],
    List<String> removeTags = const <String>[],
    bool? isFavorite,
    bool? isProtected,
  }) {
    _captureSnapshot();
    final idSet = ids.toSet();
    if (idSet.isEmpty) {
      return;
    }

    final normalizedNationality = clearNationality
        ? null
        : _normalizeNationality(nationality);
    final normalizedAddTags = _normalizeTags(addTags);
    final normalizedRemoveTags = _normalizeTags(removeTags);
    final ageRange = clearAge ? null : _resolveOptionalRange(minimumAge, maximumAge);
    final random = Random();

    for (var index = 0; index < _players.length; index += 1) {
      final player = _players[index];
      if (!idSet.contains(player.id)) {
        continue;
      }

      final nextTags = <String>[
        ...player.tags.where(
          (entry) => !normalizedRemoveTags.any(
            (removeTag) => removeTag.toLowerCase() == entry.toLowerCase(),
          ),
        ),
      ];
      for (final tag in normalizedAddTags) {
        if (nextTags.any((entry) => entry.toLowerCase() == tag.toLowerCase())) {
          continue;
        }
        nextTags.add(tag);
      }

      final nextAge = clearAge
          ? null
          : ageRange == null
              ? player.age
              : _randomFromRange(ageRange, random);

      _players[index] = player.copyWith(
        nationality: clearNationality ? null : normalizedNationality ?? player.nationality,
        clearNationality: clearNationality,
        age: nextAge,
        clearAge: clearAge,
        tags: nextTags,
        isFavorite: isFavorite ?? player.isFavorite,
        isProtected: isProtected ?? player.isProtected,
        updatedAt: DateTime.now(),
        lastModifiedReason: 'bulk_edit',
      );
    }

    _tagDefinitions
      ..clear()
      ..addAll(_mergeTagDefinitions(_tagDefinitions, _players));
    _nationalityDefinitions
      ..clear()
      ..addAll(_mergeNationalityDefinitions(_nationalityDefinitions, _players));
    notifyListeners();
    unawaited(_persist());
  }

  void clearPlayers() {
    _captureSnapshot();
    _players.clear();
    notifyListeners();
    unawaited(_persist());
  }

  void recordMatch({
    required String playerId,
    required String opponentName,
    required bool won,
    required MatchResultSummary result,
    required double average,
  }) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final nextMatchesPlayed = current.matchesPlayed + 1;
    final nextMatchesWon = current.matchesWon + (won ? 1 : 0);
    final nextAverage = current.matchesPlayed <= 0
        ? average
        : ((current.average * current.matchesPlayed) + average) /
            nextMatchesPlayed;

    final historyEntry = ComputerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      match: result,
    );

    _players[index] = current.copyWith(
      matchesPlayed: nextMatchesPlayed,
      matchesWon: nextMatchesWon,
      average: nextAverage,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_match',
      history: <ComputerMatchHistoryEntry>[
        historyEntry,
        ...current.history,
      ],
    );
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  void recordCricketMatch({
    required String playerId,
    required String opponentName,
    required bool won,
    required CricketResultSummary result,
    required double average,
  }) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final historyEntry = ComputerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      cricketMatch: result,
    );

    _players[index] = current.copyWith(
      matchesPlayed: current.matchesPlayed + 1,
      matchesWon: current.matchesWon + (won ? 1 : 0),
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_cricket_match',
      history: <ComputerMatchHistoryEntry>[
        historyEntry,
        ...current.history,
      ],
    );
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  void recordBob27Match({
    required String playerId,
    required String opponentName,
    required bool won,
    required Bob27ResultSummary result,
    required double average,
  }) {
    _captureSnapshot();
    final index = _players.indexWhere((player) => player.id == playerId);
    if (index < 0) {
      return;
    }

    final current = _players[index];
    final historyEntry = ComputerMatchHistoryEntry(
      id: 'match-${DateTime.now().microsecondsSinceEpoch}',
      opponentName: opponentName,
      won: won,
      average: average,
      scoreText: result.scoreText,
      playedAt: DateTime.now(),
      bob27Match: result,
    );

    _players[index] = current.copyWith(
      matchesPlayed: current.matchesPlayed + 1,
      matchesWon: current.matchesWon + (won ? 1 : 0),
      updatedAt: DateTime.now(),
      lastModifiedReason: 'record_bob27_match',
      history: <ComputerMatchHistoryEntry>[
        historyEntry,
        ...current.history,
      ],
    );
    _sortPlayers();
    notifyListeners();
    unawaited(_persist());
  }

  void _sortPlayers() {
    _players.sort(
      (left, right) =>
          right.theoreticalAverage.compareTo(left.theoreticalAverage),
    );
  }

  List<ComputerPlayer> _normalizePlayers(List<ComputerPlayer> players) {
    return players
        .map(
          (player) => _normalizePlayer(
            player.copyWith(
            theoreticalAverage: _estimateTheoreticalAverage(
              skill: player.skill,
              finishingSkill: player.finishingSkill,
            ),
          ),
          ),
        )
        .toList();
  }

  double _estimateTheoreticalAverage({
    required int skill,
    required int finishingSkill,
  }) {
    return _botEngine.estimateThreeDartAverage(
      SettingsRepository.instance.createBotProfile(
        skill: skill,
        finishingSkill: finishingSkill,
      ),
    );
  }

  _SkillResolutionCandidate _findBestEqualCandidate(double target) {
    return _searchCandidate(
      target: target,
      minimumValue: 1,
      maximumValue: 1000,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: value,
          finishingSkill: value,
        );
      },
    );
  }

  _SkillResolutionCandidate _findBestSplitCandidate(
    double target, {
    required _SkillResolutionCandidate fallback,
  }) {
    final moveUp = target >= fallback.theoreticalAverage;
    final minimumValue = moveUp ? fallback.skill : 1;
    final maximumValue = moveUp ? 1000 : fallback.skill;

    final skillDriven = _searchCandidate(
      target: target,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: value,
          finishingSkill: fallback.finishingSkill,
        );
      },
    );
    final finishingDriven = _searchCandidate(
      target: target,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: fallback.skill,
          finishingSkill: value,
        );
      },
    );

    return _pickBetterCandidate(
          current: skillDriven,
          next: finishingDriven,
        ) ??
        fallback;
  }

  _SkillResolutionCandidate _searchCandidate({
    required double target,
    required int minimumValue,
    required int maximumValue,
    required _SkillResolutionCandidate Function(int value) buildCandidate,
  }) {
    var low = minimumValue;
    var high = maximumValue;
    _SkillResolutionCandidate? best;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final middleCandidate = buildCandidate(middle);
      best = _pickBetterCandidate(current: best, next: middleCandidate);

      if (middleCandidate.theoreticalAverage < target) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    for (final value in <int>{low, high, low - 1, high + 1}) {
      if (value < minimumValue || value > maximumValue) {
        continue;
      }
      best = _pickBetterCandidate(
        current: best,
        next: buildCandidate(value),
      );
    }

    return best!;
  }

  _SkillResolutionCandidate _buildCandidate({
    required double target,
    required int skill,
    required int finishingSkill,
  }) {
    final average = _estimateTheoreticalAverage(
      skill: skill,
      finishingSkill: finishingSkill,
    );
    return _SkillResolutionCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: average,
      error: (average - target).abs(),
    );
  }

  _SkillResolutionCandidate? _pickBetterCandidate({
    required _SkillResolutionCandidate? current,
    required _SkillResolutionCandidate next,
  }) {
    if (current == null) {
      return next;
    }

    const errorEpsilon = 0.0001;
    if (next.error + errorEpsilon < current.error) {
      return next;
    }
    if (current.error + errorEpsilon < next.error) {
      return current;
    }

    if (next.gap != current.gap) {
      return next.gap < current.gap ? next : current;
    }

    if (next.skill != current.skill) {
      return next.skill < current.skill ? next : current;
    }

    if (next.finishingSkill != current.finishingSkill) {
      return next.finishingSkill < current.finishingSkill ? next : current;
    }

    return current;
  }

  String exportAsJsonString() {
    return const JsonEncoder.withIndent('  ').convert(_createStoragePayload());
  }

  String exportAsCsvString() {
    final rows = <List<String>>[
      <String>[
        'id',
        'name',
        'source',
        'isFavorite',
        'isProtected',
        'age',
        'nationality',
        'tags',
        'theoreticalAverage',
        'skill',
        'finishingSkill',
        'average',
        'matchesPlayed',
        'matchesWon',
        'createdAt',
        'updatedAt',
        'lastModifiedReason',
      ],
      ..._players.map((player) {
        return <String>[
          player.id,
          player.name,
          player.source.storageValue,
          player.isFavorite.toString(),
          player.isProtected.toString(),
          player.age?.toString() ?? '',
          player.nationality ?? '',
          player.tags.join('|'),
          player.theoreticalAverage.toStringAsFixed(2),
          player.skill.toString(),
          player.finishingSkill.toString(),
          player.average.toStringAsFixed(2),
          player.matchesPlayed.toString(),
          player.matchesWon.toString(),
          player.createdAt.toIso8601String(),
          player.updatedAt.toIso8601String(),
          player.lastModifiedReason,
        ];
      }),
    ];
    return rows.map(_toCsvRow).join('\n');
  }

  Future<void> importFromJsonString(
    String raw, {
    bool replaceExisting = false,
  }) async {
    final decoded = jsonDecode(raw);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final players = (map['players'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (entry) => ComputerPlayer.fromJson(
            (entry as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
    await importPlayers(players, replaceExisting: replaceExisting);
  }

  Future<void> importFromCsvString(
    String raw, {
    bool replaceExisting = false,
  }) async {
    final rows = _parseCsv(raw);
    if (rows.length <= 1) {
      return;
    }
    final header = rows.first;
    final players = <ComputerPlayer>[];
    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final data = <String, String>{};
      for (var index = 0; index < header.length && index < row.length; index += 1) {
        data[header[index]] = row[index];
      }
      players.add(
        ComputerPlayer(
          id: data['id']?.trim().isNotEmpty == true
              ? data['id']!.trim()
              : 'csv-${DateTime.now().microsecondsSinceEpoch}-${players.length}',
          name: data['name']?.trim() ?? 'CSV Player',
          skill: int.tryParse(data['skill'] ?? '') ?? 1,
          finishingSkill: int.tryParse(data['finishingSkill'] ?? '') ?? 1,
          theoreticalAverage:
              double.tryParse((data['theoreticalAverage'] ?? '').replaceAll(',', '.')) ??
                  0,
          createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
          lastModifiedReason:
              (data['lastModifiedReason'] ?? '').trim().isEmpty
                  ? 'csv_import'
                  : data['lastModifiedReason']!.trim(),
          source: ComputerPlayerSourceSerialization.fromStorageValue(
            data['source'],
          ),
          isFavorite: (data['isFavorite'] ?? '').toLowerCase() == 'true',
          isProtected: (data['isProtected'] ?? '').toLowerCase() == 'true',
          age: int.tryParse(data['age'] ?? ''),
          nationality: _normalizeNationality(data['nationality']),
          tags: _normalizeTags(
            (data['tags'] ?? '')
                .split('|')
                .map((entry) => entry.trim())
                .where((entry) => entry.isNotEmpty)
                .toList(),
          ),
          matchesPlayed: int.tryParse(data['matchesPlayed'] ?? '') ?? 0,
          matchesWon: int.tryParse(data['matchesWon'] ?? '') ?? 0,
          average:
              double.tryParse((data['average'] ?? '').replaceAll(',', '.')) ?? 0,
          history: const <ComputerMatchHistoryEntry>[],
        ),
      );
    }
    await importPlayers(players, replaceExisting: replaceExisting);
  }

  Map<String, dynamic> _createStoragePayload() {
    return <String, dynamic>{
      'tagDefinitions': _tagDefinitions,
      'nationalityDefinitions': _nationalityDefinitions,
      'players': _players.map((entry) => entry.toJson()).toList(),
    };
  }

  ({int min, int max})? _resolveOptionalRange(int? first, int? second) {
    if (first == null && second == null) {
      return null;
    }
    final resolvedFirst = first ?? second!;
    final resolvedSecond = second ?? first!;
    return (
      min: min(resolvedFirst, resolvedSecond),
      max: max(resolvedFirst, resolvedSecond),
    );
  }

  ({int min, int max}) _suggestAgeRangeForAverage(double targetAverage) {
    if (targetAverage >= 95) {
      return (min: 23, max: 38);
    }
    if (targetAverage >= 85) {
      return (min: 20, max: 36);
    }
    if (targetAverage >= 75) {
      return (min: 18, max: 32);
    }
    return (min: 16, max: 28);
  }

  int _randomFromRange(({int min, int max}) range, Random random) {
    return range.min + random.nextInt((range.max - range.min) + 1);
  }

  List<String> _suggestTagsForBulkProfile({
    required double targetAverage,
    required int age,
    required ComputerPlayerSource source,
  }) {
    final tags = <String>[source == ComputerPlayerSource.bulk ? bulkTag : source.storageValue];
    if (age <= 21) {
      tags.add('Nachwuchs');
    } else if (age >= 34) {
      tags.add('Erfahren');
    }
    if (targetAverage >= 95) {
      tags.add('Topspieler');
    } else if (targetAverage >= 85) {
      tags.add('Tour-Niveau');
    } else if (targetAverage < 75) {
      tags.add('Entwicklung');
    }
    return tags;
  }

  int _findLikelyDuplicateIndex({
    required List<ComputerPlayer> players,
    required ComputerPlayer candidate,
  }) {
    final candidateName = _normalizeNameForDuplicateCheck(candidate.name);
    final candidateNationality = (candidate.nationality ?? '').trim().toLowerCase();
    for (var index = 0; index < players.length; index += 1) {
      final existing = players[index];
      final existingName = _normalizeNameForDuplicateCheck(existing.name);
      final exactName = existingName == candidateName;
      final fuzzyName =
          _levenshteinDistance(existingName, candidateName) <= 2 ||
          existingName.contains(candidateName) ||
          candidateName.contains(existingName);
      final sameNationality =
          (existing.nationality ?? '').trim().toLowerCase() ==
              candidateNationality;
      final similarTheo =
          (existing.theoreticalAverage - candidate.theoreticalAverage).abs() <=
              1.5;
      if ((exactName || fuzzyName) && sameNationality && similarTheo) {
        return index;
      }
    }
    return -1;
  }

  String _normalizeNameForDuplicateCheck(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _levenshteinDistance(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);

    for (var i = 0; i < left.length; i += 1) {
      current[0] = i + 1;
      for (var j = 0; j < right.length; j += 1) {
        final substitutionCost = left[i] == right[j] ? 0 : 1;
        current[j + 1] = min(
          min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + substitutionCost,
        );
      }
      for (var j = 0; j < current.length; j += 1) {
        previous[j] = current[j];
      }
    }

    return previous[right.length];
  }

  String _toCsvRow(List<String> values) {
    return values.map((value) {
      final escaped = value.replaceAll('"', '""');
      if (escaped.contains(',') ||
          escaped.contains('"') ||
          escaped.contains('\n')) {
        return '"$escaped"';
      }
      return escaped;
    }).join(',');
  }

  List<List<String>> _parseCsv(String raw) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < raw.length; index += 1) {
      final char = raw[index];
      if (char == '"') {
        final nextChar = index + 1 < raw.length ? raw[index + 1] : '';
        if (inQuotes && nextChar == '"') {
          currentCell.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && char == ',') {
        currentRow.add(currentCell.toString());
        currentCell.clear();
        continue;
      }
      if (!inQuotes && (char == '\n' || char == '\r')) {
        if (char == '\r' && index + 1 < raw.length && raw[index + 1] == '\n') {
          index += 1;
        }
        currentRow.add(currentCell.toString());
        currentCell.clear();
        if (currentRow.any((cell) => cell.isNotEmpty)) {
          rows.add(currentRow);
        }
        currentRow = <String>[];
        continue;
      }
      currentCell.write(char);
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      if (currentRow.any((cell) => cell.isNotEmpty)) {
        rows.add(currentRow);
      }
    }

    return rows;
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      _createStoragePayload(),
    );
  }

  String? _normalizeText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizeNationality(String? value) {
    final normalized = _normalizeText(value);
    if (normalized == null) {
      return null;
    }

    const aliasMap = <String, String>{
      'belgien': 'Belgium',
      'belgium': 'Belgium',
      'croatia': 'Croatia',
      'kroatien': 'Croatia',
      'czech republic': 'Czech Republic',
      'czechia': 'Czech Republic',
      'tschechien': 'Czech Republic',
      'england': 'England',
      'deutschland': 'Germany',
      'germany': 'Germany',
      'hungary': 'Hungary',
      'ungarn': 'Hungary',
      'ireland': 'Ireland',
      'irland': 'Ireland',
      'netherlands': 'Netherlands',
      'niederlande': 'Netherlands',
      'northern ireland': 'Northern Ireland',
      'nordirland': 'Northern Ireland',
      'poland': 'Poland',
      'polen': 'Poland',
      'scotland': 'Scotland',
      'schottland': 'Scotland',
      'serbia': 'Serbia',
      'serbien': 'Serbia',
      'wales': 'Wales',
    };

    final alias = aliasMap[normalized.toLowerCase()];
    if (alias != null) {
      return alias;
    }

    for (final nationality in officialNationalities) {
      if (nationality.toLowerCase() == normalized.toLowerCase()) {
        return nationality;
      }
    }

    return null;
  }

  List<String> _normalizeTags(List<String> tags) {
    final normalized = <String>[];
    for (final tag in tags) {
      final value = tag.trim();
      if (value.isEmpty) {
        continue;
      }
      if (normalized.any((entry) => entry.toLowerCase() == value.toLowerCase())) {
        continue;
      }
      normalized.add(value);
    }
    return normalized;
  }

  List<String> _mergeTagDefinitions(
    List<String> definitions,
    List<ComputerPlayer> players,
  ) {
    final merged = <String>[];

    void addIfMissing(String rawValue) {
      final normalizedValue = _normalizeText(rawValue);
      if (normalizedValue == null) {
        return;
      }
      if (merged.any((entry) => entry.toLowerCase() == normalizedValue.toLowerCase())) {
        return;
      }
      merged.add(normalizedValue);
    }

    for (final definition in definitions) {
      addIfMissing(definition);
    }
    for (final player in players) {
      for (final tag in player.tags) {
        addIfMissing(tag);
      }
    }

    return merged;
  }

  List<String> _mergeNationalityDefinitions(
    List<String> definitions,
    List<ComputerPlayer> players,
  ) {
    final merged = <String>[...officialNationalities];

    void addIfMissing(String rawValue) {
      final normalizedValue = _normalizeNationality(rawValue);
      if (normalizedValue == null) {
        return;
      }
      if (merged.any(
        (entry) => entry.toLowerCase() == normalizedValue.toLowerCase(),
      )) {
        return;
      }
      merged.add(normalizedValue);
    }

    for (final definition in definitions) {
      addIfMissing(definition);
    }
    for (final player in players) {
      addIfMissing(player.nationality ?? '');
    }

    return merged;
  }

  ComputerPlayer _normalizePlayer(ComputerPlayer player) {
    return player.copyWith(
      source: player.source,
      nationality: _normalizeNationality(player.nationality),
      clearNationality: _normalizeNationality(player.nationality) == null,
      tags: _normalizeTags(player.tags),
    );
  }
}

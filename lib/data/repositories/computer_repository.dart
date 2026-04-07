import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_match_engine.dart';
import '../../domain/x01/x01_models.dart';
import '../../presentation/match/bob27_result_models.dart';
import '../../presentation/match/cricket_result_models.dart';
import '../../presentation/match/match_result_models.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../models/generated_name_catalog.dart';
import '../models/nationality_catalog.dart';
import '../models/computer_player.dart';
import '../background/simulation_service.dart';
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

class _TheoAverageCacheEntry {
  const _TheoAverageCacheEntry({
    required this.average,
    required this.sampleCount,
  });

  final double average;
  final int sampleCount;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'average': average,
      'sampleCount': sampleCount,
    };
  }

  static _TheoAverageCacheEntry? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }
    final map = value.cast<String, dynamic>();
    final average = (map['average'] as num?)?.toDouble();
    final sampleCount = (map['sampleCount'] as num?)?.toInt();
    if (average == null || sampleCount == null || sampleCount <= 0) {
      return null;
    }
    return _TheoAverageCacheEntry(
      average: average.clamp(0, 180).toDouble(),
      sampleCount: sampleCount,
    );
  }
}

enum ComputerTheoRefreshMode {
  fast,
  standard,
  precise,
}

class ComputerRepository extends ChangeNotifier {
  ComputerRepository._();

  static final ComputerRepository instance = ComputerRepository._();

  static const _storageKey = 'computer_players';
  static const _theoreticalAverageCacheKey = 'computer_theoretical_average_cache';
  static const _theoreticalAverageCacheVersion = 2;
  static const _bundledTheoreticalAverageCacheAssetPath =
      'assets/data/bundled_theoretical_average_cache.json';
  static const int _bundledTheoSeedSampleCount = 24;
  static const _skillResolutionVersion = 2;
  static const _bundledDefaultsAssetPath =
      'assets/data/default_computer_players.json';
  static const Set<String> _legacySeedPlayerNames = <String>{
    'Luke Humphries',
    'Luke Littler',
    'Michael van Gerwen',
    'Gerwyn Price',
    'Gary Anderson',
    'Nathan Aspinall',
  };
  static const bulkTag = 'Bulk';
  static const realPlayerTag = 'Echter Spieler';
  static const List<String> officialNationalities =
      NationalityCatalog.officialNationalities;
  static const int _interactiveTheoReferenceMatchCount = 8;
  static const int _fastRefreshTheoReferenceMatchCount = 6;
  static const int _standardRefreshTheoReferenceMatchCount = 24;
  static const int _preciseRefreshTheoReferenceMatchCount = 100;
  static const int _manualTheoReferenceMatchCount = 24;

  final BotEngine _botEngine = BotEngine(recordPerformanceLogs: false);
  late final X01MatchSimulator _theoreticalMatchSimulator = X01MatchSimulator(
    matchEngine: X01MatchEngine(),
    botEngine: _botEngine,
    recordPerformanceLogs: false,
  );
  final List<ComputerPlayer> _players = <ComputerPlayer>[];
  final List<String> _tagDefinitions = <String>[];
  final List<String> _nationalityDefinitions = <String>[];
  final List<_RepositorySnapshot> _undoStack = <_RepositorySnapshot>[];
  final Map<String, ComputerSkillResolution> _resolutionCache =
      <String, ComputerSkillResolution>{};
  final Map<String, _TheoAverageCacheEntry> _theoreticalAverageCache =
      <String, _TheoAverageCacheEntry>{};
  int _changeToken = 0;
  bool _isRefreshingTheoreticalAverages = false;
  double _theoreticalRefreshProgress = 0;
  String _theoreticalRefreshLabel = '';
  Timer? _theoreticalAverageCachePersistTimer;

  List<ComputerPlayer> get players =>
      List<ComputerPlayer>.unmodifiable(_players);
  List<String> get tagDefinitions => List<String>.unmodifiable(_tagDefinitions);
  List<String> get nationalityDefinitions =>
      List<String>.unmodifiable(_nationalityDefinitions);
  bool get canUndo => _undoStack.isNotEmpty;
  int get changeToken => _changeToken;
  bool get isRefreshingTheoreticalAverages => _isRefreshingTheoreticalAverages;
  double get theoreticalRefreshProgress => _theoreticalRefreshProgress;
  String get theoreticalRefreshLabel => _theoreticalRefreshLabel;

  @override
  void notifyListeners() {
    _changeToken += 1;
    _resolutionCache.clear();
    super.notifyListeners();
  }

  Future<void> initialize() async {
    final bundledJson = await _loadBundledDefaults();
    _primeTheoreticalAverageCacheFromBundledDefaults(bundledJson);
    await _loadBundledTheoreticalAverageCache();
    await _loadTheoreticalAverageCache();
    final storedJson = await AppStorage.instance.readJsonMap(_storageKey);
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

    if (_isLegacySeedPlayerList(players)) {
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

  bool _isLegacySeedPlayerList(List<dynamic> players) {
    if (players.length != _legacySeedPlayerNames.length) {
      return false;
    }

    final loadedNames = players
        .whereType<Map>()
        .map((entry) => (entry['name'] ?? '').toString().trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    return loadedNames.length == _legacySeedPlayerNames.length &&
        loadedNames.containsAll(_legacySeedPlayerNames);
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
      // Fall back to stored defaults only; career templates no longer define
      // the database player pool.
    }
    return null;
  }

  Future<void> _loadTheoreticalAverageCache() async {
    final payload = await AppStorage.instance.readJsonMap(
      _theoreticalAverageCacheKey,
    );
    if (payload == null) {
      return;
    }
    final version = (payload['version'] as num?)?.toInt() ?? 0;
    if (version != _theoreticalAverageCacheVersion) {
      return;
    }
    final values = payload['values'];
    if (values is! Map) {
      return;
    }
    for (final entry in values.entries) {
      final cacheEntry = _TheoAverageCacheEntry.fromJson(entry.value);
      if (cacheEntry != null) {
        _theoreticalAverageCache[entry.key.toString()] = cacheEntry;
      }
    }
  }

  Future<void> _loadBundledTheoreticalAverageCache() async {
    try {
      final raw = await rootBundle.loadString(
        _bundledTheoreticalAverageCacheAssetPath,
      );
      final decoded = jsonDecode(raw.replaceFirst('\uFEFF', ''));
      if (decoded is! Map) {
        return;
      }
      final payload = decoded.cast<String, dynamic>();
      final version = (payload['version'] as num?)?.toInt() ?? 0;
      if (version != _theoreticalAverageCacheVersion) {
        return;
      }
      final values = payload['values'];
      if (values is! Map) {
        return;
      }
      for (final entry in values.entries) {
        final cacheEntry = _TheoAverageCacheEntry.fromJson(entry.value);
        if (cacheEntry != null) {
          _theoreticalAverageCache.putIfAbsent(
            entry.key.toString(),
            () => cacheEntry,
          );
        }
      }
    } catch (_) {
      // Fall back to bundled defaults and local cache only.
    }
  }

  void _primeTheoreticalAverageCacheFromBundledDefaults(
    Map<String, dynamic>? bundledJson,
  ) {
    if (!_isValidStoragePayload(bundledJson)) {
      return;
    }
    final bundledPlayers =
        (bundledJson!['players'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .toList();
    for (final player in bundledPlayers) {
      final skill = (player['skill'] as num?)?.toInt();
      final finishingSkill = (player['finishingSkill'] as num?)?.toInt();
      final theoreticalAverage =
          (player['theoreticalAverage'] as num?)?.toDouble();
      if (skill == null || finishingSkill == null || theoreticalAverage == null) {
        continue;
      }
      final cacheKey = _theoreticalAverageCacheKeyFor(skill, finishingSkill);
      _theoreticalAverageCache.putIfAbsent(
        cacheKey,
        () => _TheoAverageCacheEntry(
          average: theoreticalAverage.clamp(0, 180).toDouble(),
          sampleCount: _bundledTheoSeedSampleCount,
        ),
      );
    }
  }

  void _scheduleTheoreticalAverageCachePersist() {
    _theoreticalAverageCachePersistTimer?.cancel();
    _theoreticalAverageCachePersistTimer = Timer(
      const Duration(milliseconds: 250),
      () {
        unawaited(_persistTheoreticalAverageCache());
      },
    );
  }

  Future<void> _persistTheoreticalAverageCache() {
    return AppStorage.instance.writeJson(
      _theoreticalAverageCacheKey,
      <String, dynamic>{
        'version': _theoreticalAverageCacheVersion,
        'values': <String, dynamic>{
          for (final entry in _theoreticalAverageCache.entries)
            entry.key: entry.value.toJson(),
        },
      },
    );
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
    int? skill,
    int? finishingSkill,
    int? age,
    DateTime? birthDate,
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
        resolveSkillsForTheoreticalAverageQuick(targetTheoreticalAverage);
    final normalizedSkill = skill?.clamp(1, 1000).toInt();
    final normalizedFinishingSkill = finishingSkill?.clamp(1, 1000).toInt();
    final resolvedSkill = normalizedSkill ?? resolution.skill;
    final resolvedFinishingSkill =
        normalizedFinishingSkill ?? resolution.finishingSkill;
    final resolvedTheo =
        normalizedSkill != null && normalizedFinishingSkill != null
            ? _estimateTheoreticalAverage(
                skill: resolvedSkill,
                finishingSkill: resolvedFinishingSkill,
              )
            : resolution.theoreticalAverage;
    final normalizedNationality = _normalizeNationality(nationality);
    final normalizedTags = _normalizeTags(tags);
    _tagDefinitions
      ..clear()
      ..addAll(
        _mergeTagDefinitions(_tagDefinitions, <ComputerPlayer>[
          ComputerPlayer(
            id: '',
            name: trimmed,
            skill: resolvedSkill,
            finishingSkill: resolvedFinishingSkill,
            theoreticalAverage: resolvedTheo,
            createdAt: now,
            updatedAt: now,
            lastModifiedReason: 'manual_create',
            source: source,
            age: age ?? _deriveAgeFromBirthDate(birthDate),
            birthDate: birthDate,
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
            skill: resolvedSkill,
            finishingSkill: resolvedFinishingSkill,
            theoreticalAverage: resolvedTheo,
            createdAt: now,
            updatedAt: now,
            lastModifiedReason: 'manual_create',
            source: source,
            age: age ?? _deriveAgeFromBirthDate(birthDate),
            birthDate: birthDate,
            nationality: normalizedNationality,
            tags: normalizedTags,
          ),
        ]),
      );
    _players.add(
      ComputerPlayer(
        id: 'computer-${DateTime.now().microsecondsSinceEpoch}-${trimmed.length}',
        name: trimmed,
        skill: resolvedSkill,
        finishingSkill: resolvedFinishingSkill,
        theoreticalAverage: resolvedTheo,
        createdAt: now,
        updatedAt: now,
        lastModifiedReason: 'manual_create',
        source: source,
        age: age ?? _deriveAgeFromBirthDate(birthDate),
        birthDate: birthDate,
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
      final birthDate = _randomBirthDateForAge(age, random);
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
          birthDate: birthDate,
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
    int? skill,
    int? finishingSkill,
    int? age,
    DateTime? birthDate,
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
        resolveSkillsForTheoreticalAverageQuick(targetTheoreticalAverage);
    final normalizedSkill = skill?.clamp(1, 1000).toInt();
    final normalizedFinishingSkill = finishingSkill?.clamp(1, 1000).toInt();
    final resolvedSkill = normalizedSkill ?? resolution.skill;
    final resolvedFinishingSkill =
        normalizedFinishingSkill ?? resolution.finishingSkill;
    final resolvedTheo =
        normalizedSkill != null && normalizedFinishingSkill != null
            ? _estimateTheoreticalAverage(
                skill: resolvedSkill,
                finishingSkill: resolvedFinishingSkill,
              )
            : resolution.theoreticalAverage;
    final normalizedNationality = _normalizeNationality(nationality);
    final normalizedTags = _normalizeTags(tags);
    _players[index] = _players[index].copyWith(
      name: name.trim(),
      skill: resolvedSkill,
      finishingSkill: resolvedFinishingSkill,
      theoreticalAverage: resolvedTheo,
      updatedAt: DateTime.now(),
      lastModifiedReason: 'manual_update',
      source: source ?? _players[index].source,
      isFavorite: isFavorite ?? _players[index].isFavorite,
      isProtected: isProtected ?? _players[index].isProtected,
      age: age ?? _deriveAgeFromBirthDate(birthDate),
      clearAge: age == null && birthDate == null,
      birthDate: birthDate,
      clearBirthDate: age == null && birthDate == null,
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
    final cacheKey = target.toStringAsFixed(4);
    final cached = _resolutionCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final bestEqual = _findBestEqualCandidate(target);
    final bestSplit = _findBestSplitCandidate(target, fallback: bestEqual);
    const improvementEpsilon = 0.01;

    final resolution = bestSplit.error + improvementEpsilon < bestEqual.error
        ? bestSplit.toResolution()
        : bestEqual.toResolution();
    _resolutionCache[cacheKey] = resolution;
    return resolution;
  }

  ComputerSkillResolution resolveSkillsForTheoreticalAverageQuick(
    double targetTheoreticalAverage,
  ) {
    final target = targetTheoreticalAverage.clamp(0, 180).toDouble();
    final cacheKey = 'quick:${target.toStringAsFixed(4)}';
    final cached = _resolutionCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    if (_players.isEmpty) {
      return resolveSkillsForTheoreticalAverage(target);
    }
    final sortedPlayers = List<ComputerPlayer>.from(_players)
      ..sort(
        (left, right) =>
            left.theoreticalAverage.compareTo(right.theoreticalAverage),
      );
    final firstPlayer = sortedPlayers.first;
    final lastPlayer = sortedPlayers.last;

    if (target <= firstPlayer.theoreticalAverage ||
        target >= lastPlayer.theoreticalAverage) {
      final resolution = resolveSkillsForTheoreticalAverage(target);
      _resolutionCache[cacheKey] = resolution;
      return resolution;
    }

    ComputerPlayer lowerPlayer = firstPlayer;
    ComputerPlayer upperPlayer = lastPlayer;
    for (var index = 0; index < sortedPlayers.length - 1; index += 1) {
      final current = sortedPlayers[index];
      final next = sortedPlayers[index + 1];
      if (current.theoreticalAverage <= target &&
          next.theoreticalAverage >= target) {
        lowerPlayer = current;
        upperPlayer = next;
        break;
      }
    }

    final averageSpan =
        upperPlayer.theoreticalAverage - lowerPlayer.theoreticalAverage;
    if (averageSpan.abs() < 0.0001) {
      final lowerGap = (lowerPlayer.theoreticalAverage - target).abs();
      final upperGap = (upperPlayer.theoreticalAverage - target).abs();
      final chosen = lowerGap <= upperGap ? lowerPlayer : upperPlayer;
      final resolution = ComputerSkillResolution(
        skill: chosen.skill,
        finishingSkill: chosen.finishingSkill,
        theoreticalAverage: target,
      );
      _resolutionCache[cacheKey] = resolution;
      return resolution;
    }

    final progress =
        ((target - lowerPlayer.theoreticalAverage) / averageSpan).clamp(0, 1);
    final interpolatedSkill = (lowerPlayer.skill +
            ((upperPlayer.skill - lowerPlayer.skill) * progress))
        .round()
        .clamp(1, 1000);
    final interpolatedFinishingSkill = (lowerPlayer.finishingSkill +
            ((upperPlayer.finishingSkill - lowerPlayer.finishingSkill) *
                progress))
        .round()
        .clamp(1, 1000);
    final resolution = ComputerSkillResolution(
      skill: interpolatedSkill,
      finishingSkill: interpolatedFinishingSkill,
      theoreticalAverage: target,
    );
    _resolutionCache[cacheKey] = resolution;
    return resolution;
  }

  Future<void> refreshTheoreticalAverages({
    ComputerTheoRefreshMode mode = ComputerTheoRefreshMode.standard,
  }) async {
      final refreshStopwatch = Stopwatch()..start();
      final refreshMatchCount = _matchCountForRefreshMode(mode);
      if (kDebugMode) {
        debugPrint(
          '[TheoRefresh] START mode=$mode players=${_players.length} matchCount=$refreshMatchCount '
          'radius=${SettingsRepository.instance.settings.radiusCalibrationPercent} '
          'spread=${SettingsRepository.instance.settings.simulationSpreadPercent}',
        );
      }
      _captureSnapshot();
      _isRefreshingTheoreticalAverages = true;
      _theoreticalRefreshProgress = 0;
      _theoreticalRefreshLabel = 'Theoretische Averages werden vorbereitet...';
      notifyListeners();
        try {
          await _prewarmTheoRefreshWorkerIfNeeded(matchCount: refreshMatchCount);
          final normalizedPlayers = <ComputerPlayer>[];
          final now = DateTime.now();
        for (var index = 0; index < _players.length; index += 1) {
          final player = _players[index];
        final playerStopwatch = Stopwatch()..start();
        _theoreticalRefreshLabel =
            'Theo wird berechnet: ${player.name} (${index + 1}/${_players.length})';
        _theoreticalRefreshProgress =
            _players.isEmpty ? 0 : index / _players.length;
          if (index == 0 || index % 3 == 0 || index == _players.length - 1) {
            notifyListeners();
          }
          await Future<void>.delayed(Duration.zero);

          final theoreticalAverage = await _estimateRefreshTheoreticalAverage(
            skill: player.skill,
            finishingSkill: player.finishingSkill,
            playerName: player.name,
            matchCount: refreshMatchCount,
            onProgress: (matchIndex, matchCount) {
              final totalSteps = (_players.length * matchCount).clamp(1, 1 << 30);
              final completedSteps = (index * matchCount) + matchIndex;
              _theoreticalRefreshLabel =
                  'Theo wird berechnet: ${player.name} (${index + 1}/${_players.length}) '
                  '- Referenz-Match $matchIndex/$matchCount';
              _theoreticalRefreshProgress = completedSteps / totalSteps;
              if (matchIndex == 0 ||
                  matchIndex == matchCount ||
                  matchIndex % 4 == 0) {
                notifyListeners();
              }
            },
          );
        normalizedPlayers.add(
          _normalizePlayer(
            player.copyWith(
              theoreticalAverage: theoreticalAverage,
              updatedAt: now,
              lastModifiedReason: 'manual_theoretical_refresh',
            ),
          ),
        );
        if (kDebugMode) {
          debugPrint(
            '[TheoRefresh] PLAYER_DONE index=${index + 1}/${_players.length} '
            'name="${player.name}" oldTheo=${player.theoreticalAverage.toStringAsFixed(2)} '
            'newTheo=${theoreticalAverage.toStringAsFixed(2)} '
            'skill=${player.skill} finish=${player.finishingSkill} '
            'durationMs=${playerStopwatch.elapsedMilliseconds}',
          );
        }

        _theoreticalRefreshProgress = (index + 1) / _players.length;
        notifyListeners();
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
      _players
        ..clear()
        ..addAll(normalizedPlayers);
      _sortPlayers();
      notifyListeners();
      await _persist();
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[TheoRefresh] END totalDurationMs=${refreshStopwatch.elapsedMilliseconds} '
          'players=${_players.length}',
        );
      }
      _isRefreshingTheoreticalAverages = false;
      _theoreticalRefreshProgress = 0;
      _theoreticalRefreshLabel = '';
      notifyListeners();
    }
  }

  Future<void> prewarmTheoreticalRefresh({
    ComputerTheoRefreshMode mode = ComputerTheoRefreshMode.fast,
  }) {
    return _prewarmTheoRefreshWorkerIfNeeded(
      matchCount: _matchCountForRefreshMode(mode),
    );
  }

  Future<void> _prewarmTheoRefreshWorkerIfNeeded({
    required int matchCount,
  }) async {
    final profilesById = <String, Object?>{};
    for (final player in _players) {
      final cacheKey = _theoreticalAverageCacheKeyFor(
        player.skill,
        player.finishingSkill,
      );
      final cached = _theoreticalAverageCache[cacheKey];
      if (cached != null && cached.sampleCount >= matchCount) {
        continue;
      }
      final profile = SettingsRepository.instance.createBotProfile(
        skill: player.skill,
        finishingSkill: player.finishingSkill,
      );
      final profileKey = [
        profile.skill,
        profile.finishingSkill,
        profile.radiusCalibrationPercent,
        profile.simulationSpreadPercent,
      ].join(':');
      profilesById[profileKey] = <String, Object?>{
        'skill': profile.skill,
        'finishingSkill': profile.finishingSkill,
        'radiusCalibrationPercent': profile.radiusCalibrationPercent,
        'simulationSpreadPercent': profile.simulationSpreadPercent,
      };
    }

    if (profilesById.isEmpty) {
      if (kDebugMode) {
        debugPrint('[TheoRefresh] PREWARM_SKIPPED all_profiles_cached');
      }
      return;
    }

    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint(
        '[TheoRefresh] PREWARM_START profiles=${profilesById.length} '
        'matchCount=$matchCount',
      );
    }
    await SimulationService.instance.prewarmProfiles(profilesById);
    if (kDebugMode) {
      debugPrint(
        '[TheoRefresh] PREWARM_DONE profiles=${profilesById.length} '
        'durationMs=${stopwatch.elapsedMilliseconds}',
      );
    }
  }

  Future<void> rebalanceSkillsFromCurrentTheoreticalAverages() async {
    _captureSnapshot();
    final now = DateTime.now();
    final rebalancedPlayers = _players.map((player) {
      final resolution = resolveSkillsForTheoreticalAverage(
        player.theoreticalAverage,
      );
      final changed = resolution.skill != player.skill ||
          resolution.finishingSkill != player.finishingSkill;
      return _normalizePlayer(
        player.copyWith(
          skill: resolution.skill,
          finishingSkill: resolution.finishingSkill,
          theoreticalAverage: player.theoreticalAverage,
          updatedAt: changed ? now : player.updatedAt,
          lastModifiedReason: changed
              ? 'theoretical_skill_rebalance'
              : player.lastModifiedReason,
        ),
      );
    }).toList();
    _players
      ..clear()
      ..addAll(rebalancedPlayers);
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
        _scheduleTheoreticalAverageCachePersist();
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

  List<ComputerPlayer> _normalizePlayers(
    List<ComputerPlayer> players, {
    bool recomputeTheoreticalAverage = false,
  }) {
    return players
        .map(
          (player) => _normalizePlayer(
            recomputeTheoreticalAverage
                ? player.copyWith(
                    theoreticalAverage: _estimateTheoreticalAverage(
                      skill: player.skill,
                      finishingSkill: player.finishingSkill,
                    ),
                  )
                : player,
          ),
        )
        .toList();
  }

  double estimateTheoreticalAverageForSkills({
    required int skill,
    required int finishingSkill,
  }) {
    return _estimateTheoreticalAverage(
      skill: skill,
      finishingSkill: finishingSkill,
    );
  }

  double _estimateTheoreticalAverage({
      required int skill,
      required int finishingSkill,
    }) {
      return _estimateOfficialReferenceTheoAverage(
        skill: skill,
        finishingSkill: finishingSkill,
        matchCount: _interactiveTheoReferenceMatchCount,
      );
    }

  Future<double> _estimateManualTheoreticalAverage({
      required int skill,
      required int finishingSkill,
      String playerName = 'Spieler',
      void Function(int matchIndex, int matchCount)? onProgress,
    }) async {
      final cached = _theoreticalAverageCache[_theoreticalAverageCacheKeyFor(
        skill,
        finishingSkill,
      )];
      if (cached != null &&
          cached.sampleCount >= _manualTheoReferenceMatchCount) {
        onProgress?.call(
          _manualTheoReferenceMatchCount,
          _manualTheoReferenceMatchCount,
        );
        return cached.average;
      }
      final profile = SettingsRepository.instance.createBotProfile(
        skill: skill,
        finishingSkill: finishingSkill,
      );
      onProgress?.call(0, _manualTheoReferenceMatchCount);
      await Future<void>.delayed(const Duration(milliseconds: 24));
      var totalAverage = 0.0;
      for (var index = 0; index < _manualTheoReferenceMatchCount; index += 1) {
        final matchIndex = index + 1;
        onProgress?.call(matchIndex, _manualTheoReferenceMatchCount);
        _theoreticalRefreshLabel =
            'Theo wird berechnet: $playerName - Referenz-Match $matchIndex/$_manualTheoReferenceMatchCount';
        if (matchIndex == 1 ||
            matchIndex == _manualTheoReferenceMatchCount ||
            matchIndex % 4 == 0) {
          notifyListeners();
        }
        if (index % 4 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 4));
        } else {
          await Future<void>.delayed(Duration.zero);
        }
        totalAverage += _simulateOfficialReferenceMatchAverage(
          profile: profile,
          matchIndex: index,
        );
        if (index % 4 == 3) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }
      await Future<void>.delayed(Duration.zero);
      final average = (totalAverage / _manualTheoReferenceMatchCount)
          .clamp(0, 180)
          .toDouble();
      _theoreticalAverageCache[_theoreticalAverageCacheKeyFor(
        skill,
        finishingSkill,
      )] = _TheoAverageCacheEntry(
        average: average,
        sampleCount: _manualTheoReferenceMatchCount,
      );
      _scheduleTheoreticalAverageCachePersist();
      return average;
    }

    Future<double> _estimateRefreshTheoreticalAverage({
      required int skill,
      required int finishingSkill,
      String playerName = 'Spieler',
      required int matchCount,
      void Function(int matchIndex, int matchCount)? onProgress,
    }) async {
      final cacheKey = _theoreticalAverageCacheKeyFor(skill, finishingSkill);
      final cached = _theoreticalAverageCache[cacheKey];
      if (cached != null && cached.sampleCount >= matchCount) {
        if (kDebugMode) {
          debugPrint(
            '[TheoRefresh] CACHE_HIT player="$playerName" skill=$skill finish=$finishingSkill '
            'sampleCount=${cached.sampleCount} requested=$matchCount '
            'average=${cached.average.toStringAsFixed(2)}',
          );
        }
        onProgress?.call(
          matchCount,
          matchCount,
        );
        return cached.average;
      }

      final settingsProfile = SettingsRepository.instance.createBotProfile(
        skill: skill,
        finishingSkill: finishingSkill,
      );
      if (kDebugMode) {
        debugPrint(
          '[TheoRefresh] WORKER_START player="$playerName" skill=$skill finish=$finishingSkill '
          'matchCount=$matchCount radius=${settingsProfile.radiusCalibrationPercent} '
          'spread=${settingsProfile.simulationSpreadPercent}',
        );
      }
      onProgress?.call(0, matchCount);
      final workerStopwatch = Stopwatch()..start();
      final handle = SimulationService.instance.startPersistentJob<double>(
        taskType: 'estimate_theo_average',
        initialLabel: 'Theo wird berechnet: $playerName',
        payload: <String, Object?>{
          'skill': skill,
          'finishingSkill': finishingSkill,
          'radiusCalibrationPercent': settingsProfile.radiusCalibrationPercent,
          'simulationSpreadPercent': settingsProfile.simulationSpreadPercent,
          'matchCount': matchCount,
          'playerName': playerName,
        },
      );
      void updateTheoProgress() {
        final rawProgress = handle.progress ?? 0;
        final matchProgress = (rawProgress * matchCount).clamp(
          0,
          matchCount.toDouble(),
        );
        onProgress?.call(
          matchProgress.round(),
          matchCount,
        );
        _theoreticalRefreshLabel = handle.label;
        if (handle.progress != null) {
          _theoreticalRefreshProgress = handle.progress!;
        }
        notifyListeners();
      }
      handle.addListener(updateTheoProgress);
      late final double average;
      try {
        average = await handle.result;
      } finally {
        handle.removeListener(updateTheoProgress);
      }
      if (kDebugMode) {
        debugPrint(
          '[TheoRefresh] WORKER_DONE player="$playerName" average=${average.toStringAsFixed(2)} '
          'durationMs=${workerStopwatch.elapsedMilliseconds}',
        );
      }
      _theoreticalAverageCache[cacheKey] = _TheoAverageCacheEntry(
        average: average,
        sampleCount: matchCount,
      );
      _scheduleTheoreticalAverageCachePersist();
      return average;
    }

    int _matchCountForRefreshMode(ComputerTheoRefreshMode mode) {
      switch (mode) {
        case ComputerTheoRefreshMode.fast:
          return _fastRefreshTheoReferenceMatchCount;
        case ComputerTheoRefreshMode.standard:
          return _standardRefreshTheoReferenceMatchCount;
        case ComputerTheoRefreshMode.precise:
          return _preciseRefreshTheoReferenceMatchCount;
      }
    }

    double _estimateOfficialReferenceTheoAverage({
      required int skill,
      required int finishingSkill,
      required int matchCount,
    }) {
      final cacheKey = _theoreticalAverageCacheKeyFor(skill, finishingSkill);
      final cached = _theoreticalAverageCache[cacheKey];
      if (cached != null && cached.sampleCount >= matchCount) {
        return cached.average;
      }
      final profile = SettingsRepository.instance.createBotProfile(
        skill: skill,
        finishingSkill: finishingSkill,
      );
      var totalAverage = 0.0;

      for (var index = 0; index < matchCount; index += 1) {
        totalAverage += _simulateOfficialReferenceMatchAverage(
          profile: profile,
          matchIndex: index,
        );
      }

      final average = (totalAverage / matchCount).clamp(0, 180).toDouble();
      _theoreticalAverageCache[cacheKey] = _TheoAverageCacheEntry(
        average: average,
        sampleCount: matchCount,
      );
      _scheduleTheoreticalAverageCachePersist();
      return average;
    }

    String _theoreticalAverageCacheKeyFor(int skill, int finishingSkill) {
      final settings = SettingsRepository.instance.settings;
      return [
        skill,
        finishingSkill,
        settings.radiusCalibrationPercent,
        settings.simulationSpreadPercent,
      ].join(':');
    }

  double _simulateOfficialReferenceMatchAverage({
    required BotProfile profile,
    required int matchIndex,
  }) {
    final player = SimulatedPlayer(
      name: 'Theo',
      profile: profile,
    );
    const config = MatchConfig(
      startScore: 501,
      mode: MatchMode.legs,
      checkoutRequirement: CheckoutRequirement.doubleOut,
      legsToWin: 8,
    );
    final result = _theoreticalMatchSimulator.simulateAutoMatch(
      playerA: player,
      playerB: player,
      config: config,
      detailed: false,
      random: Random(7919 * (matchIndex + 1)),
    );
    return ((result.averageA + result.averageB) / 2).clamp(0, 180).toDouble();
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

    final nextMaxSkill = max(next.skill, next.finishingSkill);
    final currentMaxSkill = max(current.skill, current.finishingSkill);
    if (nextMaxSkill != currentMaxSkill) {
      return nextMaxSkill < currentMaxSkill ? next : current;
    }

    final nextMinSkill = min(next.skill, next.finishingSkill);
    final currentMinSkill = min(current.skill, current.finishingSkill);
    if (nextMinSkill != currentMinSkill) {
      return nextMinSkill < currentMinSkill ? next : current;
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
        'birthDate',
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
          player.birthDate?.toIso8601String() ?? '',
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
      final parsedBirthDate = DateTime.tryParse(data['birthDate'] ?? '');
      final parsedAge = int.tryParse(data['age'] ?? '');
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
          birthDate: parsedBirthDate,
          age: parsedAge ?? _deriveAgeFromBirthDate(parsedBirthDate),
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
      'skillResolutionVersion': _skillResolutionVersion,
      'tagDefinitions': _tagDefinitions,
      'nationalityDefinitions': _nationalityDefinitions,
      'players': _players.map((entry) => entry.toJson()).toList(),
    };
  }

  void _migratePlayersToBalancedSkillPreference() {
    final now = DateTime.now();
    final migratedPlayers = _players.map((player) {
      final resolution = resolveSkillsForTheoreticalAverage(
        player.theoreticalAverage,
      );
      final changed = resolution.skill != player.skill ||
          resolution.finishingSkill != player.finishingSkill;
      return _normalizePlayer(
        player.copyWith(
          skill: resolution.skill,
          finishingSkill: resolution.finishingSkill,
          theoreticalAverage: player.theoreticalAverage,
          updatedAt: changed ? now : player.updatedAt,
          lastModifiedReason:
              changed ? 'skill_balance_migration' : player.lastModifiedReason,
        ),
      );
    }).toList();
    _players
      ..clear()
      ..addAll(migratedPlayers);
    _sortPlayers();
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

  int? _deriveAgeFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) {
      return null;
    }
    final now = DateTime.now();
    var years = now.year - birthDate.year;
    final hadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hadBirthday) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }

  DateTime _randomBirthDateForAge(int age, Random random) {
    final now = DateTime.now();
    final year = now.year - age;
    final month = random.nextInt(12) + 1;
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = random.nextInt(maxDay) + 1;
    return DateTime(year, month, day);
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

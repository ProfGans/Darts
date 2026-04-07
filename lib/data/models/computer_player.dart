import '../../presentation/match/bob27_result_models.dart';
import '../../presentation/match/cricket_result_models.dart';
import '../../presentation/match/match_result_models.dart';

enum ComputerPlayerSource {
  imported,
  manual,
  bulk,
}

extension ComputerPlayerSourceSerialization on ComputerPlayerSource {
  String get storageValue {
    switch (this) {
      case ComputerPlayerSource.imported:
        return 'imported';
      case ComputerPlayerSource.manual:
        return 'manual';
      case ComputerPlayerSource.bulk:
        return 'bulk';
    }
  }

  static ComputerPlayerSource fromStorageValue(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'imported':
        return ComputerPlayerSource.imported;
      case 'bulk':
        return ComputerPlayerSource.bulk;
      case 'manual':
      default:
        return ComputerPlayerSource.manual;
    }
  }
}

class ComputerMatchHistoryEntry {
  const ComputerMatchHistoryEntry({
    required this.id,
    required this.opponentName,
    required this.won,
    required this.average,
    required this.scoreText,
    required this.playedAt,
    this.match,
    this.cricketMatch,
    this.bob27Match,
  });

  final String id;
  final String opponentName;
  final bool won;
  final double average;
  final String scoreText;
  final DateTime playedAt;
  final MatchResultSummary? match;
  final CricketResultSummary? cricketMatch;
  final Bob27ResultSummary? bob27Match;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'opponentName': opponentName,
      'won': won,
      'average': average,
      'scoreText': scoreText,
      'playedAt': playedAt.toIso8601String(),
      if (match != null) 'match': match!.toJson(),
      if (cricketMatch != null) 'cricketMatch': cricketMatch!.toJson(),
      if (bob27Match != null) 'bob27Match': bob27Match!.toJson(),
    };
  }

  static ComputerMatchHistoryEntry fromJson(Map<String, dynamic> json) {
    return ComputerMatchHistoryEntry(
      id: json['id'] as String,
      opponentName: json['opponentName'] as String,
      won: json['won'] as bool? ?? false,
      average: (json['average'] as num).toDouble(),
      scoreText: json['scoreText'] as String,
      playedAt: DateTime.parse(json['playedAt'] as String),
      match: json['match'] == null
          ? null
          : MatchResultSummary.fromJson(
              (json['match'] as Map).cast<String, dynamic>(),
            ),
      cricketMatch: json['cricketMatch'] == null
          ? null
          : CricketResultSummary.fromJson(
              (json['cricketMatch'] as Map).cast<String, dynamic>(),
            ),
      bob27Match: json['bob27Match'] == null
          ? null
          : Bob27ResultSummary.fromJson(
              (json['bob27Match'] as Map).cast<String, dynamic>(),
            ),
    );
  }
}

class ComputerPlayer {
  ComputerPlayer({
    required this.id,
    required this.name,
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
    required this.createdAt,
    required this.updatedAt,
    required this.lastModifiedReason,
    this.source = ComputerPlayerSource.manual,
    this.isFavorite = false,
    this.isProtected = false,
    this.age,
    this.birthDate,
    this.nationality,
    this.tags = const <String>[],
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    this.average = 0,
    this.history = const <ComputerMatchHistoryEntry>[],
  });

  final String id;
  final String name;
  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastModifiedReason;
  final ComputerPlayerSource source;
  final bool isFavorite;
  final bool isProtected;
  final int? age;
  final DateTime? birthDate;
  final String? nationality;
  final List<String> tags;
  final int matchesPlayed;
  final int matchesWon;
  final double average;
  final List<ComputerMatchHistoryEntry> history;

  ComputerPlayer copyWith({
    String? id,
    String? name,
    int? skill,
    int? finishingSkill,
    double? theoreticalAverage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastModifiedReason,
    ComputerPlayerSource? source,
    bool? isFavorite,
    bool? isProtected,
    int? age,
    bool clearAge = false,
    DateTime? birthDate,
    bool clearBirthDate = false,
    String? nationality,
    bool clearNationality = false,
    List<String>? tags,
    int? matchesPlayed,
    int? matchesWon,
    double? average,
    List<ComputerMatchHistoryEntry>? history,
  }) {
    return ComputerPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      skill: skill ?? this.skill,
      finishingSkill: finishingSkill ?? this.finishingSkill,
      theoreticalAverage: theoreticalAverage ?? this.theoreticalAverage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedReason: lastModifiedReason ?? this.lastModifiedReason,
      source: source ?? this.source,
      isFavorite: isFavorite ?? this.isFavorite,
      isProtected: isProtected ?? this.isProtected,
      age: clearAge ? null : age ?? this.age,
      birthDate: clearBirthDate ? null : birthDate ?? this.birthDate,
      nationality: clearNationality ? null : nationality ?? this.nationality,
      tags: tags ?? this.tags,
      matchesPlayed: matchesPlayed ?? this.matchesPlayed,
      matchesWon: matchesWon ?? this.matchesWon,
      average: average ?? this.average,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'skill': skill,
      'finishingSkill': finishingSkill,
      'theoreticalAverage': theoreticalAverage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastModifiedReason': lastModifiedReason,
      'source': source.storageValue,
      'isFavorite': isFavorite,
      'isProtected': isProtected,
      'age': age,
      'birthDate': birthDate?.toIso8601String(),
      'nationality': nationality,
      'tags': tags,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'average': average,
      'history': history.map((entry) => entry.toJson()).toList(),
    };
  }

  static ComputerPlayer fromJson(Map<String, dynamic> json) {
    final rawNationality = (json['nationality'] as String?)?.trim();
    final parsedTags = (json['tags'] as List<dynamic>?)
        ?.map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    final legacyAttributeKeys =
        (json['customAttributes'] as Map<dynamic, dynamic>? ??
                const <dynamic, dynamic>{})
            .keys
            .map((entry) => entry.toString().trim())
            .where((entry) => entry.isNotEmpty)
            .toList();
    final resolvedTags = parsedTags ?? legacyAttributeKeys;
    final source = _resolveLegacySource(
      rawSource: json['source'] as String?,
      tags: resolvedTags,
      id: json['id'] as String?,
    );
    return ComputerPlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      skill: (json['skill'] as num).toInt(),
      finishingSkill: (json['finishingSkill'] as num).toInt(),
      theoreticalAverage: (json['theoreticalAverage'] as num).toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastModifiedReason:
          json['lastModifiedReason'] as String? ?? 'legacy_import',
      source: source,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isProtected: json['isProtected'] as bool? ?? false,
      age: (json['age'] as num?)?.toInt(),
      birthDate: DateTime.tryParse((json['birthDate'] as String?) ?? ''),
      nationality: rawNationality == null || rawNationality.isEmpty
          ? null
          : rawNationality,
      tags: resolvedTags,
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
      average: (json['average'] as num?)?.toDouble() ?? 0,
      history: (json['history'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (entry) => ComputerMatchHistoryEntry.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }

  static ComputerPlayerSource _resolveLegacySource({
    required String? rawSource,
    required List<String> tags,
    required String? id,
  }) {
    if ((rawSource ?? '').trim().isNotEmpty) {
      return ComputerPlayerSourceSerialization.fromStorageValue(rawSource);
    }
    if (tags.any((entry) => entry.toLowerCase() == 'bulk')) {
      return ComputerPlayerSource.bulk;
    }
    if ((id ?? '').startsWith('db-player-')) {
      return ComputerPlayerSource.imported;
    }
    return ComputerPlayerSource.manual;
  }

  int? get effectiveAge {
    if (birthDate != null) {
      final now = DateTime.now();
      var years = now.year - birthDate!.year;
      final hadBirthday =
          now.month > birthDate!.month ||
          (now.month == birthDate!.month && now.day >= birthDate!.day);
      if (!hadBirthday) {
        years -= 1;
      }
      return years < 0 ? null : years;
    }
    return age;
  }
}

class TournamentCommunity {
  const TournamentCommunity({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.playerIds = const <String>[],
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final List<String> playerIds;

  TournamentCommunity copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    bool clearDescription = false,
    List<String>? playerIds,
  }) {
    return TournamentCommunity(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: clearDescription ? null : description ?? this.description,
      playerIds: playerIds ?? this.playerIds,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'playerIds': playerIds,
    };
  }

  static TournamentCommunity fromJson(Map<String, dynamic> json) {
    return TournamentCommunity(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Community',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      description: (json['description'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['description'] as String?)?.trim(),
      playerIds: (json['playerIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((entry) => entry.toString())
          .where((entry) => entry.trim().isNotEmpty)
          .toList(),
    );
  }
}

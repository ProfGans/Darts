import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/tournament_community.dart';
import '../storage/app_storage.dart';
import 'player_repository.dart';

class CommunityRepository extends ChangeNotifier {
  CommunityRepository._();

  static final CommunityRepository instance = CommunityRepository._();

  static const _storageKey = 'tournament_communities';

  final List<TournamentCommunity> _communities = <TournamentCommunity>[];
  String? _activeCommunityId;

  List<TournamentCommunity> get communities =>
      List<TournamentCommunity>.unmodifiable(_communities);

  TournamentCommunity? get activeCommunity {
    final activeId = _activeCommunityId;
    if (activeId == null) {
      return _communities.isEmpty ? null : _communities.first;
    }
    for (final community in _communities) {
      if (community.id == activeId) {
        return community;
      }
    }
    return _communities.isEmpty ? null : _communities.first;
  }

  TournamentCommunity? communityById(String communityId) {
    for (final community in _communities) {
      if (community.id == communityId) {
        return community;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    final json = await AppStorage.instance.readJsonMap(_storageKey);
    if (json == null) {
      return;
    }
    _communities
      ..clear()
      ..addAll(
        (json['communities'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (entry) =>
                  TournamentCommunity.fromJson(entry.cast<String, dynamic>()),
            ),
      );
    _activeCommunityId = json['activeCommunityId'] as String?;
    _pruneInvalidPlayerReferences();
    if (_communities.isNotEmpty &&
        _communities.every((entry) => entry.id != _activeCommunityId)) {
      _activeCommunityId = _communities.first.id;
    }
    notifyListeners();
    await _persist();
  }

  void createCommunity({
    required String name,
    String? description,
    List<String> playerIds = const <String>[],
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return;
    }
    final now = DateTime.now();
    final community = TournamentCommunity(
      id: 'community-${now.microsecondsSinceEpoch}',
      name: trimmedName,
      createdAt: now,
      updatedAt: now,
      description: _normalizeNullableText(description),
      playerIds: _normalizePlayerIds(playerIds),
    );
    _communities.insert(0, community);
    _activeCommunityId = community.id;
    notifyListeners();
    unawaited(_persist());
  }

  void updateCommunity({
    required String communityId,
    required String name,
    String? description,
    List<String>? playerIds,
  }) {
    final index = _communities.indexWhere((community) => community.id == communityId);
    final trimmedName = name.trim();
    if (index < 0 || trimmedName.isEmpty) {
      return;
    }
    _communities[index] = _communities[index].copyWith(
      name: trimmedName,
      description: _normalizeNullableText(description),
      playerIds: playerIds == null ? null : _normalizePlayerIds(playerIds),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    unawaited(_persist());
  }

  void deleteCommunity(String communityId) {
    _communities.removeWhere((community) => community.id == communityId);
    if (_activeCommunityId == communityId) {
      _activeCommunityId = _communities.isEmpty ? null : _communities.first.id;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void setActiveCommunity(String? communityId) {
    if (communityId == null) {
      _activeCommunityId = null;
    } else if (_communities.any((community) => community.id == communityId)) {
      _activeCommunityId = communityId;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void assignPlayers({
    required String communityId,
    required List<String> playerIds,
  }) {
    final community = communityById(communityId);
    if (community == null) {
      return;
    }
    updateCommunity(
      communityId: communityId,
      name: community.name,
      description: community.description,
      playerIds: playerIds,
    );
  }

  void _pruneInvalidPlayerReferences() {
    final validIds = PlayerRepository.instance.players.map((player) => player.id).toSet();
    var changed = false;
    for (var index = 0; index < _communities.length; index += 1) {
      final community = _communities[index];
      final nextIds =
          community.playerIds.where((id) => validIds.contains(id)).toList();
      if (listEquals(nextIds, community.playerIds)) {
        continue;
      }
      _communities[index] = community.copyWith(
        playerIds: nextIds,
        updatedAt: DateTime.now(),
      );
      changed = true;
    }
    if (changed) {
      unawaited(_persist());
    }
  }

  List<String> _normalizePlayerIds(List<String> playerIds) {
    final validIds = PlayerRepository.instance.players.map((player) => player.id).toSet();
    final normalized = <String>[];
    for (final id in playerIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || normalized.contains(trimmed) || !validIds.contains(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  String? _normalizeNullableText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _persist() {
    return AppStorage.instance.writeJson(
      _storageKey,
      <String, dynamic>{
        'activeCommunityId': _activeCommunityId,
        'communities': _communities.map((entry) => entry.toJson()).toList(),
      },
    );
  }
}

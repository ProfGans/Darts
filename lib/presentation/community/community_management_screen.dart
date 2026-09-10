import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models/player_profile.dart';
import '../../data/models/tournament_community.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/tournament/tournament_models.dart';
import 'community_dashboard_screen.dart';

class CommunityManagementScreen extends StatefulWidget {
  const CommunityManagementScreen({super.key});

  @override
  State<CommunityManagementScreen> createState() =>
      _CommunityManagementScreenState();
}

class _CommunityManagementScreenState extends State<CommunityManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _editingCommunityId;
  List<String> _selectedPlayerIds = <String>[];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startCreate() {
    setState(() {
      _editingCommunityId = null;
      _selectedPlayerIds = <String>[];
      _nameController.text = '';
      _descriptionController.text = '';
    });
  }

  void _startEdit(TournamentCommunity community) {
    setState(() {
      _editingCommunityId = community.id;
      _selectedPlayerIds = List<String>.from(community.playerIds);
      _nameController.text = community.name;
      _descriptionController.text = community.description ?? '';
    });
  }

  void _save() {
    final repository = CommunityRepository.instance;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    if (_editingCommunityId == null) {
      repository.createCommunity(
        name: name,
        description: _descriptionController.text,
        playerIds: _selectedPlayerIds,
      );
    } else {
      repository.updateCommunity(
        communityId: _editingCommunityId!,
        name: name,
        description: _descriptionController.text,
        playerIds: _selectedPlayerIds,
      );
    }
    _startCreate();
  }

  Future<void> _pickPlayers() async {
    final players = PlayerRepository.instance.players;
    final validIds = players.map((player) => player.id).toSet();
    final tempSelection =
        _selectedPlayerIds.where(validIds.contains).toList(growable: true);
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
              title: const Text('Community-Spieler waehlen'),
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
                        itemCount: filteredPlayers.length,
                        itemBuilder: (context, index) {
                          final player = filteredPlayers[index];
                          final selected = tempSelection.contains(player.id);
                          return CheckboxListTile(
                            value: selected,
                            contentPadding: EdgeInsets.zero,
                            title: Text(player.name),
                            subtitle: Text(
                              '${player.average.toStringAsFixed(1)} Avg'
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
      _selectedPlayerIds = result;
    });
  }

  void _openDashboard(TournamentCommunity community) {
    CommunityRepository.instance.setActiveCommunity(community.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityDashboardScreen(communityId: community.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = CommunityRepository.instance;
    final playerRepository = PlayerRepository.instance;
    final tournamentRepository = TournamentRepository.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[repository, playerRepository, tournamentRepository],
      ),
      builder: (context, _) {
        final communities = repository.communities;
        final activeCommunity = repository.activeCommunity;
        final activeBracket = tournamentRepository.currentBracket;
        final playersById = <String, PlayerProfile>{
          for (final player in playerRepository.players) player.id: player,
        };
        return Scaffold(
          appBar: AppBar(title: const Text('Communities')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: <Widget>[
              if (activeCommunity != null) ...<Widget>[
                _CommunityTournamentCenterCard(
                  community: activeCommunity,
                  playersById: playersById,
                  activeBracket: activeBracket,
                  onOpenDashboard: () => _openDashboard(activeCommunity),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _editingCommunityId == null
                            ? 'Neue Community'
                            : 'Community bearbeiten',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name der Community',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Beschreibung',
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            playerRepository.players.isEmpty ? null : _pickPlayers,
                        icon: const Icon(Icons.groups_outlined),
                        label: const Text('Spielerpool waehlen'),
                      ),
                      const SizedBox(height: 12),
                      if (_selectedPlayerIds.isEmpty)
                        const Text('Noch keine Spieler fuer die Community ausgewaehlt.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedPlayerIds.map((id) {
                            final player = playersById[id];
                            if (player == null) {
                              return const SizedBox.shrink();
                            }
                            return InputChip(
                              label: Text(player.name),
                              onDeleted: () {
                                setState(() {
                                  _selectedPlayerIds.remove(id);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton(
                              onPressed: _save,
                              child: Text(
                                _editingCommunityId == null
                                    ? 'Community anlegen'
                                    : 'Community speichern',
                              ),
                            ),
                          ),
                          if (_editingCommunityId != null) ...<Widget>[
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _startCreate,
                                child: const Text('Abbrechen'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vorhandene Communities',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (communities.isEmpty)
                const Text('Noch keine Community vorhanden.')
              else
                ...communities.map(
                  (community) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommunityCard(
                      community: community,
                      playersById: playersById,
                      isActive: repository.activeCommunity?.id == community.id,
                      onActivate: () {
                        repository.setActiveCommunity(community.id);
                      },
                      onOpenDashboard: () => _openDashboard(community),
                      onEdit: () => _startEdit(community),
                      onDelete: () {
                        repository.deleteCommunity(community.id);
                        if (_editingCommunityId == community.id) {
                          _startCreate();
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.community,
    required this.playersById,
    required this.isActive,
    required this.onActivate,
    required this.onOpenDashboard,
    required this.onEdit,
    required this.onDelete,
  });

  final TournamentCommunity community;
  final Map<String, PlayerProfile> playersById;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onOpenDashboard;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final members = community.playerIds
        .map((id) => playersById[id])
        .whereType<PlayerProfile>()
        .toList();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpenDashboard,
        child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    community.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EEF5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('Aktiv'),
                  ),
              ],
            ),
            if ((community.description ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                community.description!,
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
                _InfoChip(label: '${members.length} Spieler'),
                _InfoChip(
                  label:
                      'Erstellt ${community.createdAt.day}.${community.createdAt.month}.${community.createdAt.year}',
                ),
              ],
            ),
            if (members.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members
                    .map((player) => InputChip(label: Text(player.name)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenDashboard,
                    child: const Text('Dashboard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: onActivate,
                    child: Text(isActive ? 'Aktiv' : 'Als aktiv setzen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Bearbeiten'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Loeschen',
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _CommunityTournamentCenterCard extends StatelessWidget {
  const _CommunityTournamentCenterCard({
    required this.community,
    required this.playersById,
    required this.activeBracket,
    required this.onOpenDashboard,
  });

  final TournamentCommunity community;
  final Map<String, PlayerProfile> playersById;
  final TournamentBracket? activeBracket;
  final VoidCallback onOpenDashboard;

  @override
  Widget build(BuildContext context) {
    final members = community.playerIds
        .map((id) => playersById[id])
        .whereType<PlayerProfile>()
        .toList();
    final bracketMatchesCommunity = activeBracket != null &&
        activeBracket?.definition.communityId == community.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Tunierzentrale: ${community.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Von hier aus startest du neue Turniere fuer diese Community und behaltest Spielerpool und aktives Turnier im Blick.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(label: '${members.length} Community-Spieler'),
                _InfoChip(
                  label: bracketMatchesCommunity
                      ? 'Aktives Turnier in dieser Community'
                      : 'Kein aktives Community-Turnier',
                ),
              ],
            ),
            if (members.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Schnellauswahl Spielerpool',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members
                    .take(10)
                    .map((player) => InputChip(label: Text(player.name)))
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenDashboard,
                    child: const Text('Dashboard oeffnen'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: bracketMatchesCommunity
                        ? () {
                            Navigator.of(context)
                                .pushNamed(AppRoutes.tournamentBracket);
                          }
                        : null,
                    child: const Text('Aktives Turnier'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

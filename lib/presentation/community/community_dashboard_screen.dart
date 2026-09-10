import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/models/player_profile.dart';
import '../../data/models/tournament_community.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/tournament/tournament_models.dart';

class CommunityDashboardScreen extends StatelessWidget {
  const CommunityDashboardScreen({
    super.key,
    required this.communityId,
  });

  final String communityId;

  @override
  Widget build(BuildContext context) {
    final communityRepository = CommunityRepository.instance;
    final playerRepository = PlayerRepository.instance;
    final tournamentRepository = TournamentRepository.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[
          communityRepository,
          playerRepository,
          tournamentRepository,
        ],
      ),
      builder: (context, _) {
        final community = communityRepository.communityById(communityId);
        if (community == null) {
          return const Scaffold(
            body: Center(
              child: Text('Community nicht gefunden.'),
            ),
          );
        }
        final playersById = <String, PlayerProfile>{
          for (final player in playerRepository.players) player.id: player,
        };
        final members = community.playerIds
            .map((id) => playersById[id])
            .whereType<PlayerProfile>()
            .toList();
        final activeBracket = tournamentRepository.currentBracket;
        final hasActiveTournament = activeBracket?.definition.communityId == community.id;

        return Scaffold(
          appBar: AppBar(
            title: Text(community.name),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  communityRepository.setActiveCommunity(community.id);
                  Navigator.of(context).pushNamed(AppRoutes.communities);
                },
                child: const Text('Verwalten'),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            children: <Widget>[
              _DashboardHero(
                community: community,
                memberCount: members.length,
                hasActiveTournament: hasActiveTournament,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Tunierzentrale',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Starte Turniere fuer diese Community und greife schnell auf laufende Wettbewerbe zu.',
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
                            label: hasActiveTournament
                                ? 'Aktives Turnier vorhanden'
                                : 'Kein aktives Turnier',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                communityRepository.setActiveCommunity(community.id);
                                Navigator.of(context)
                                    .pushNamed(AppRoutes.tournamentSetup);
                              },
                              child: const Text('Neues Turnier'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: hasActiveTournament
                                  ? () {
                                      Navigator.of(context).pushNamed(
                                        AppRoutes.tournamentBracket,
                                      );
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
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Spielerpool',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Diese Spieler stehen fuer schnelle Turniererstellung in der Community bereit.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF556372),
                              height: 1.35,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (members.isEmpty)
                        const Text('Noch keine Spieler in dieser Community.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: members
                              .map(
                                (player) => InputChip(
                                  label: Text(
                                    '${player.name} (${player.average.toStringAsFixed(1)})',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Community-Info',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        community.description?.trim().isNotEmpty == true
                            ? community.description!
                            : 'Keine Beschreibung hinterlegt.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF556372),
                              height: 1.35,
                            ),
                      ),
                    ],
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

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.community,
    required this.memberCount,
    required this.hasActiveTournament,
  });

  final TournamentCommunity community;
  final int memberCount;
  final bool hasActiveTournament;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF17324D),
            Color(0xFF245B78),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Community Dashboard',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            community.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${memberCount} Spieler im Pool${hasActiveTournament ? ' | aktives Turnier vorhanden' : ''}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.94),
                  height: 1.4,
                ),
          ),
        ],
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

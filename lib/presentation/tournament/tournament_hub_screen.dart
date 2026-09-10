import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/repositories/community_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/tournament/tournament_models.dart';

class TournamentHubScreen extends StatelessWidget {
  const TournamentHubScreen({
    super.key,
    this.embeddedInShell = false,
  });

  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final repository = TournamentRepository.instance;
    final playerRepository = PlayerRepository.instance;
    final communityRepository = CommunityRepository.instance;
    return AnimatedBuilder(
      animation: Listenable.merge(
        <Listenable>[repository, playerRepository, communityRepository],
      ),
      builder: (context, _) {
        final bracket = repository.currentBracket;
        final players = playerRepository.players;
        final activePlayer = playerRepository.activePlayer;
        final activeCommunity = communityRepository.activeCommunity;
        final content = ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: <Widget>[
            const _TournamentHero(),
            const SizedBox(height: 20),
            _SectionCard(
              title: 'Community',
              subtitle: activeCommunity == null
                  ? 'Lege zuerst eine Community mit festem Spielerpool an, damit Turniere spaeter schneller erstellt werden koennen.'
                  : 'Turniere koennen direkt unter ${activeCommunity.name} angelegt werden.',
              children: <Widget>[
                _StatWrap(
                  stats: <Widget>[
                    _StatChip(
                      label: activeCommunity == null
                          ? 'Keine aktive Community'
                          : 'Aktiv: ${activeCommunity.name}',
                    ),
                    _StatChip(
                      label:
                          '${communityRepository.communities.length} Communities',
                    ),
                    _StatChip(
                      label: activeCommunity == null
                          ? '0 Community-Spieler'
                          : '${activeCommunity.playerIds.length} Community-Spieler',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.groups_3_outlined,
                  title: 'Communities verwalten',
                  subtitle:
                      'Community anlegen, Spielerpool pflegen und eine aktive Community fuer neue Turniere festlegen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.communities);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Turnierzentrale',
              subtitle: bracket == null
                  ? 'Lege einen neuen Vereinsabend oder ein Turnier an.'
                  : 'Ein Turnier laeuft bereits und kann direkt fortgesetzt werden.',
              children: <Widget>[
                _ActionTile(
                  icon: Icons.add_chart_rounded,
                  title: 'Turnier oder Abend anlegen',
                  subtitle: activeCommunity == null
                      ? 'Modus waehlen, Teilnehmer festlegen und Paarungen automatisch erzeugen.'
                      : 'Neues Turnier unter ${activeCommunity.name} anlegen und den Community-Spielerpool nutzen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.tournamentSetup);
                  },
                ),
                _ActionTile(
                  icon: Icons.table_chart_outlined,
                  title: 'Aktives Turnier oeffnen',
                  subtitle: _activeTournamentSubtitle(bracket),
                  enabled: bracket != null,
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.tournamentBracket);
                  },
                ),
                _ActionTile(
                  icon: Icons.history_outlined,
                  title: 'Turnierhistorie',
                  subtitle:
                      '${repository.archive.length} gespeicherte Archiv-Eintraege fuer spaeteren Rueckblick.',
                  enabled: false,
                  trailingLabel: 'Demnaechst',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Spieler und Rollen',
              subtitle:
                  'Vorhandene Spielerprofile koennen direkt in Turniere aufgenommen werden.',
              children: <Widget>[
                _StatWrap(
                  stats: <Widget>[
                    _StatChip(label: '${players.length} Spielerprofile'),
                    _StatChip(
                      label: activePlayer == null
                          ? 'Kein aktiver Spieler'
                          : 'Aktiv: ${activePlayer.name}',
                    ),
                    const _StatChip(label: 'Rollen: lokal vorbereitet'),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Spieler verwalten',
                  subtitle:
                      'Spielerprofile anlegen, bearbeiten und spaeter im Turnier-Setup auswaehlen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.playerProfiles);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Online-Grundfunktionalitaet',
              subtitle:
                  'Die Turnierverwaltung ist fuer eine spaetere Firebase-Anbindung vorbereitet.',
              children: const <Widget>[
                _StatWrap(
                  stats: <Widget>[
                    _StatChip(label: 'Login vorgesehen'),
                    _StatChip(label: 'Sync vorgesehen'),
                    _StatChip(label: 'Zuschaueransicht vorgesehen'),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Aktuell noch lokal: Turnierstruktur, Teilnehmerauswahl und Ergebnisfluss sind so gebuendelt, dass sie als naechster Schritt an Authentication und Firestore angeschlossen werden koennen.',
                  style: TextStyle(
                    color: Color(0xFF556372),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ],
        );

        if (embeddedInShell) {
          return content;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Tunierverwaltung')),
          body: SafeArea(child: content),
        );
      },
    );
  }

  String _activeTournamentSubtitle(TournamentBracket? bracket) {
    if (bracket == null) {
      return 'Zurzeit ist kein aktives Turnier gespeichert.';
    }
    return '${bracket.definition.name} mit ${bracket.participants.length} Teilnehmern fortsetzen'
        '${bracket.definition.communityName == null ? '' : ' (${bracket.definition.communityName})'}'
        '${bracket.definition.phases.isEmpty ? '' : ' | ${bracket.definition.phases.length} Phasen'}.';
  }
}

class _TournamentHero extends StatelessWidget {
  const _TournamentHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF6B3410),
            Color(0xFFB85E13),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Tunierverwaltung',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Vereinsabende, Turniere und Paarungen an einem Ort.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lege Teilnehmer an, waehle Spielmodi aus, fuehre Ergebnisse ein und behalte Tabelle oder KO-Baum direkt in der App im Blick.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: enabled ? const Color(0xFFFFFCF8) : const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: enabled
                        ? const Color(0xFFF4E2D1)
                        : const Color(0xFFE2E5E9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: enabled
                        ? const Color(0xFF8A4A12)
                        : const Color(0xFF7A8794),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: enabled ? null : const Color(0xFF7A8794),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF556372),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailingLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EEF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailingLabel!,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: enabled
                        ? const Color(0xFF7A8794)
                        : const Color(0xFFB0B7C0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatWrap extends StatelessWidget {
  const _StatWrap({required this.stats});

  final List<Widget> stats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label});

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

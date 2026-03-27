import 'package:flutter/material.dart';

import '../../app/routes.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: <Widget>[
            Text(
              'Dart Karriere',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 24),
            _MenuSection(
              title: 'Spielen',
              children: <Widget>[
                _MenuTile(
                  icon: Icons.sports_score,
                  title: 'Match Setup',
                  subtitle: 'Direkt ein Einzelmatch gegen einen Bot starten.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.gameModes);
                  },
                ),
                _MenuTile(
                  icon: Icons.hub,
                  title: 'Turniere',
                  subtitle: 'Bracket erstellen, simulieren oder selbst eingreifen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.tournamentSetup);
                  },
                ),
                _MenuTile(
                  icon: Icons.timeline,
                  title: 'Karriere',
                  subtitle: 'Kalender planen, Saisons spielen und Ranglisten sehen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.careerSetup);
                  },
                ),
                _MenuTile(
                  icon: Icons.calculate_outlined,
                  title: 'Checkout Rechner',
                  subtitle: 'Restscore und Darts eingeben und mehrere Finishes bekommen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.checkoutCalculator);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            _MenuSection(
              title: 'Verwalten',
              children: <Widget>[
                _MenuTile(
                  icon: Icons.person,
                  title: 'Spielerprofile',
                  subtitle: 'Eigene Spieler und Matchhistorie verwalten.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.playerProfiles);
                  },
                ),
                _MenuTile(
                  icon: Icons.groups_2,
                  title: 'Computer-Datenbank',
                  subtitle: 'CPU-Spieler, Theo Averages und Staerken pruefen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.computerDatabase);
                  },
                ),
                _MenuTile(
                  icon: Icons.tune,
                  title: 'Einstellungen',
                  subtitle: 'Bot-Logik, Radius und Simulationswerte anpassen.',
                  onTap: () {
                    Navigator.of(context).pushNamed(AppRoutes.settings);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2EFEA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF0E5A52),
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
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7A8794),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

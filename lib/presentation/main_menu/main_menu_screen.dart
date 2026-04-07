import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/repositories/career_repository.dart';
import '../career/career_hub_screen.dart';

enum AppShellSection {
  play,
  career,
  manage,
  tools,
}

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    this.initialSection = AppShellSection.play,
  });

  final AppShellSection initialSection;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late AppShellSection _section = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForSection(_section)),
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _section.index,
          children: const <Widget>[
            _PlayHub(),
            _CareerHub(),
            _ManageHub(),
            _ToolsHub(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (index) {
          setState(() {
            _section = AppShellSection.values[index];
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.sports_score_outlined),
            selectedIcon: Icon(Icons.sports_score),
            label: 'Spielen',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline),
            label: 'Karriere',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: 'Verwalten',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman),
            label: 'Tools',
          ),
        ],
      ),
    );
  }

  String _titleForSection(AppShellSection section) {
    return switch (section) {
      AppShellSection.play => 'Spielen',
      AppShellSection.career => 'Karriere',
      AppShellSection.manage => 'Verwalten',
      AppShellSection.tools => 'Tools',
    };
  }
}

class _PlayHub extends StatelessWidget {
  const _PlayHub();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: <Widget>[
        const _HubHero(
          title: 'Schnell ins Spiel',
          subtitle:
              'Starte ein Match, lege ein Turnier an oder springe direkt in eine laufende Karriere.',
        ),
        const SizedBox(height: 20),
        _HubSection(
          title: 'Jetzt spielen',
          children: <Widget>[
            _HubTile(
              icon: Icons.sports_score,
              title: 'Match starten',
              subtitle: 'Einzelmatch oder Trainingsmodus direkt konfigurieren.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.gameModes);
              },
            ),
            _HubTile(
              icon: Icons.hub,
              title: 'Turnier starten',
              subtitle:
                  'Turnierfeld aufsetzen, simulieren oder selbst eingreifen.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.tournamentSetup);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _CareerHub extends StatelessWidget {
  const _CareerHub();

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final careers = repository.careers;
        final lastCareer =
            repository.activeCareer ?? (careers.isEmpty ? null : careers.last);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: <Widget>[
            _HubHero(
              title: lastCareer?.name ?? 'Neue Karriere starten',
              subtitle: lastCareer == null
                  ? 'Erstelle direkt eine neue Karriere oder lade eine bestehende.'
                  : 'Setze deine letzte Karriere dort fort, wo du aufgehoert hast.',
              accentColor: const Color(0xFF1C7A6F),
            ),
            const SizedBox(height: 20),
            _HubSection(
              title: 'Karriere',
              children: <Widget>[
                _HubTile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Karriere erstellen',
                  subtitle:
                      'Direkt in die Karriere-Erstellung mit Vorlage oder Quick-Tour.',
                  onTap: () {
                    repository.clearActiveCareer();
                    Navigator.of(context).pushNamed(AppRoutes.careerSetup);
                  },
                ),
                _HubTile(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Karriere fortsetzen',
                  subtitle: lastCareer == null
                      ? 'Keine bestehende Karriere gefunden.'
                      : 'Letzte Karriere direkt wieder aufnehmen.',
                  onTap: () {
                    if (lastCareer == null) {
                      return;
                    }
                    repository.setActiveCareer(lastCareer.id);
                    Navigator.of(context).pushNamed(
                      lastCareer.isStarted
                          ? AppRoutes.careerDetail
                          : AppRoutes.careerSetup,
                    );
                  },
                ),
                _HubTile(
                  icon: Icons.folder_open_rounded,
                  title: 'Karriere laden',
                  subtitle: careers.isEmpty
                      ? 'Noch keine gespeicherten Karrieren vorhanden.'
                      : '${careers.length} gespeicherte Karriere(n) ansehen und laden.',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CareerLibraryScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ManageHub extends StatelessWidget {
  const _ManageHub();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: <Widget>[
        const _HubHero(
          title: 'Spieler und Daten pflegen',
          subtitle:
              'Verwalte Profile, Computergegner und weitere App-Daten in einem eigenen Bereich.',
          accentColor: Color(0xFF17324D),
        ),
        const SizedBox(height: 20),
        _HubSection(
          title: 'Verwalten',
          children: <Widget>[
            _HubTile(
              icon: Icons.person,
              title: 'Spielerprofile',
              subtitle: 'Eigene Spieler, Training und Matchhistorie pflegen.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.playerProfiles);
              },
            ),
            _HubTile(
              icon: Icons.groups_2,
              title: 'Computergegner',
              subtitle:
                  'CPU-Spieler bearbeiten und bei Bedarf in den Expertenmodus wechseln.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.computerDatabase);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolsHub extends StatelessWidget {
  const _ToolsHub();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
      children: <Widget>[
        const _HubHero(
          title: 'Tools und Einstellungen',
          subtitle:
              'Hilfswerkzeuge, Debug-Helfer und App-Einstellungen an einem festen Ort.',
          accentColor: Color(0xFF8A5A0E),
        ),
        const SizedBox(height: 20),
        _HubSection(
          title: 'Tools',
          children: <Widget>[
            _HubTile(
              icon: Icons.calculate_outlined,
              title: 'Checkout-Rechner',
              subtitle:
                  'Restscore und Darts eingeben, passende Finishes vergleichen.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.checkoutCalculator);
              },
            ),
            _HubTile(
              icon: Icons.memory_rounded,
              title: 'Bot-Simulator',
              subtitle:
                  'Vergleiche Bot-Konfigurationen und pruefe Simulationsverhalten.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.botSimulator);
              },
            ),
            _HubTile(
              icon: Icons.tune,
              title: 'Einstellungen',
              subtitle:
                  'Geschwindigkeit, Streuung und Schnellwerte der App anpassen.',
              onTap: () {
                Navigator.of(context).pushNamed(AppRoutes.settings);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({
    required this.title,
    required this.subtitle,
    this.accentColor = const Color(0xFF0E5A52),
  });

  final String title;
  final String subtitle;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accentColor,
            accentColor.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'DartCore',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _HubSection extends StatelessWidget {
  const _HubSection({
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

class _HubTile extends StatelessWidget {
  const _HubTile({
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

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/repositories/career_repository.dart';
import '../../domain/career/career_models.dart';
class CareerHubScreen extends StatelessWidget {
  const CareerHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final careers = repository.careers;
        final lastCareer = repository.activeCareer ?? (careers.isEmpty ? null : careers.last);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Karriere'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: <Widget>[
                _CareerHubHero(
                  hasCareer: lastCareer != null,
                  title: lastCareer?.name ?? 'Neue Karriere starten',
                  subtitle: lastCareer == null
                      ? 'Plane eine neue Karriere, waehle einen Pool und starte direkt in deine erste Saison.'
                      : _careerSummary(lastCareer),
                ),
                const SizedBox(height: 16),
                _CareerHubActionCard(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Karriere erstellen',
                  subtitle:
                      'Eine neue Karriere ueber Vorlage oder Quick-Erstellung anlegen.',
                  onTap: () {
                    repository.clearActiveCareer();
                    Navigator.of(context).pushNamed(AppRoutes.careerSetup);
                  },
                ),
                _CareerHubActionCard(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Letzte Karriere fortsetzen',
                  subtitle: lastCareer == null
                      ? 'Keine bestehende Karriere gefunden.'
                      : 'Setzt ${lastCareer.name} an der letzten aktiven Stelle fort.',
                  enabled: lastCareer != null,
                  onTap: lastCareer == null
                      ? null
                      : () {
                          repository.setActiveCareer(lastCareer.id);
                          Navigator.of(context).pushNamed(
                            lastCareer.isStarted
                                ? AppRoutes.careerDetail
                                : AppRoutes.careerSetup,
                          );
                        },
                ),
                _CareerHubActionCard(
                  icon: Icons.folder_open_rounded,
                  title: 'Karriere laden',
                  subtitle: careers.isEmpty
                      ? 'Noch keine gespeicherten Karrieren vorhanden.'
                      : '${careers.length} gespeicherte Karriere(n) ansehen und laden.',
                  enabled: careers.isNotEmpty,
                  onTap: careers.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CareerLibraryScreen(),
                            ),
                          );
                        },
                ),
                if (lastCareer != null) ...<Widget>[
                  const SizedBox(height: 16),
                  _CareerLastSnapshotCard(career: lastCareer),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class CareerLibraryScreen extends StatelessWidget {
  const CareerLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final careers = repository.careers;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Karriere laden'),
          ),
          body: SafeArea(
            child: careers.isEmpty
                ? const Center(
                    child: Text('Noch keine gespeicherten Karrieren vorhanden.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: careers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final career = careers[index];
                      final isActive = repository.activeCareer?.id == career.id;
                      return _CareerLibraryTile(
                        career: career,
                        isActive: isActive,
                        onOpen: () {
                          repository.setActiveCareer(career.id);
                          Navigator.of(context).pop();
                          Navigator.of(context).pushNamed(
                            career.isStarted
                                ? AppRoutes.careerDetail
                                : AppRoutes.careerSetup,
                          );
                        },
                        onDelete: () async {
                          final shouldDelete =
                              await _confirmCareerDelete(context, career.name);
                          if (!context.mounted || !shouldDelete) {
                            return;
                          }
                          repository.deleteCareer(career.id);
                        },
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

Future<bool> _confirmCareerDelete(BuildContext context, String careerName) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Karriere loeschen?'),
        content: Text(
          'Die Karriere "$careerName" wird dauerhaft entfernt.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Loeschen'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

class _CareerHubHero extends StatelessWidget {
  const _CareerHubHero({
    required this.hasCareer,
    required this.title,
    required this.subtitle,
  });

  final bool hasCareer;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF0E5A52),
            Color(0xFF1C7A6F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hasCareer ? 'Letzte Karriere' : 'Karriere starten',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _CareerHubActionCard extends StatelessWidget {
  const _CareerHubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? const Color(0xFF17324A) : const Color(0xFF8794A1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: enabled ? const Color(0xFFFFFCF8) : const Color(0xFFF4F5F6),
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
                    color: enabled ? const Color(0xFFE2EFEA) : const Color(0xFFE8EAEC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: enabled ? const Color(0xFF0E5A52) : foreground),
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
                              color: foreground,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: foreground.withOpacity(0.8),
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: foreground.withOpacity(0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CareerLastSnapshotCard extends StatelessWidget {
  const _CareerLastSnapshotCard({
    required this.career,
  });

  final CareerDefinition career;

  @override
  Widget build(BuildContext context) {
    final completedCount = career.currentSeason.completedItemIds.length;
    final totalCount = career.currentSeason.calendar.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Letzter Stand',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CareerInfoPill(label: 'Saison ${career.currentSeason.seasonNumber}'),
              _CareerInfoPill(label: '$completedCount/$totalCount Events abgeschlossen'),
              _CareerInfoPill(label: career.isStarted ? 'Bereits gestartet' : 'Noch im Editor'),
              _CareerInfoPill(label: '${career.databasePlayers.length} Spieler'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CareerLibraryTile extends StatelessWidget {
  const _CareerLibraryTile({
    required this.career,
    required this.isActive,
    required this.onOpen,
    required this.onDelete,
  });

  final CareerDefinition career;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      career.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (isActive)
                    const _CareerInfoPill(label: 'Aktiv'),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Karriere loeschen',
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _careerSummary(career),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareerInfoPill extends StatelessWidget {
  const _CareerInfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

String _careerSummary(CareerDefinition career) {
  final completedCount = career.currentSeason.completedItemIds.length;
  final totalCount = career.currentSeason.calendar.length;
  return 'Saison ${career.currentSeason.seasonNumber} • $completedCount/$totalCount Events • ${career.databasePlayers.length} Spieler';
}

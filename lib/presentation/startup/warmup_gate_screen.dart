import 'package:flutter/material.dart';

import '../../data/background/background_task_runner.dart';
import '../../data/background/simulation_warmup_manager.dart';
import '../main_menu/main_menu_screen.dart';

class WarmupGateScreen extends StatefulWidget {
  const WarmupGateScreen({super.key});

  @override
  State<WarmupGateScreen> createState() => _WarmupGateScreenState();
}

class _WarmupGateScreenState extends State<WarmupGateScreen> {
  bool _showMainMenu = false;
  bool _warmupRequested = false;

  @override
  Widget build(BuildContext context) {
    if (_showMainMenu || SimulationWarmupManager.instance.hasWarmupData) {
      return const MainMenuScreen();
    }

    return AnimatedBuilder(
      animation: BackgroundTaskRunner.instance,
      builder: (context, _) {
        final runner = BackgroundTaskRunner.instance;
        final inProgress = runner.inProgress && runner.activeTaskType == 'prepare_simulation';
        final progress = runner.progress;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Color(0xFFE0EEE8),
                              Color(0xFFF8F3E6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Warm-up fuer schnellere erste Matches',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Beim ersten Bot-Match koennen einige Berechnungen sonst spuerbar ruckeln. '
                              'Hier kannst du vorab Referenzdaten vorbereiten lassen. Das laeuft im Background-Worker und friert die App nicht ein.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: const Color(0xFF4A5A68),
                                    height: 1.45,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            const _InfoRow(
                              icon: Icons.bolt,
                              text: 'Sorgt vor allem fuer einen weicheren Start ins erste X01-, Cricket- und Bob27-Match.',
                            ),
                            const SizedBox(height: 12),
                            const _InfoRow(
                              icon: Icons.memory,
                              text: 'Es werden nur Warm-up-Tabellen und Referenzsimulationen vorbereitet, keine Spielstaende veraendert.',
                            ),
                            const SizedBox(height: 12),
                            const _InfoRow(
                              icon: Icons.schedule,
                              text: 'Du kannst es jetzt starten oder ueberspringen und spaeter trotzdem normal weiterspielen.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_warmupRequested)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFCF8),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                inProgress
                                    ? (runner.label.isEmpty
                                        ? 'Warm-up wird vorbereitet'
                                        : runner.label)
                                    : 'Warm-up abgeschlossen',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: inProgress ? progress : 1,
                                  backgroundColor: const Color(0xFFE7E0D6),
                                  color: const Color(0xFF0E5A52),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                inProgress
                                    ? 'Die App bleibt dabei benutzbar. Du kannst auch direkt ohne Warm-up weitermachen.'
                                    : 'Die wichtigsten Referenzdaten sind jetzt vorbereitet.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF5D6B79),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: inProgress
                            ? null
                            : () async {
                                setState(() {
                                  _warmupRequested = true;
                                });
                                await SimulationWarmupManager.instance.startWarmupIfNeeded();
                                if (!mounted) {
                                  return;
                                }
                                setState(() {});
                              },
                        child: Text(_warmupRequested ? 'Warm-up erneut pruefen' : 'Jetzt vorbereiten'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showMainMenu = true;
                          });
                        },
                        child: Text(
                          _warmupRequested && !inProgress ? 'Zur App' : 'Ohne Warm-up fortfahren',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 20,
            color: const Color(0xFF0E5A52),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF4A5A68),
                  height: 1.4,
                ),
          ),
        ),
      ],
    );
  }
}

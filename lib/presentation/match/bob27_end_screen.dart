import 'package:flutter/material.dart';

import '../main_menu/main_menu_screen.dart';
import 'bob27_result_models.dart';

class Bob27EndScreen extends StatelessWidget {
  const Bob27EndScreen({
    required this.winnerName,
    required this.results,
    this.returnButtonLabel,
    super.key,
  });

  final String winnerName;
  final List<Bob27ParticipantStats> results;
  final String? returnButtonLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bob\'s 27 Ende'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF17324D),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Bestes Ergebnis',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFAFCCE4),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  winnerName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...results.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            result.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: result.survived
                                ? const Color(0xFFE2EFEA)
                                : const Color(0xFFF8E7E7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            result.survived ? 'Im Ziel' : 'Ausgeschieden',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: result.survived
                                      ? const Color(0xFF0E5A52)
                                      : const Color(0xFF8C2F39),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Score: ${result.score}'),
                    Text('Treffer: ${result.hits}'),
                    Text('Trefferquote: ${result.hitRate.toStringAsFixed(1)}%'),
                    Text('Erfolgsquote: ${result.successRate.toStringAsFixed(1)}%'),
                    Text('Abgeschlossene Ziele: ${result.completedTargets}/21'),
                    Text('3 Treffer Runden: ${result.perfectRounds}'),
                    Text('0 Treffer Runden: ${result.zeroHitRounds}'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(returnButtonLabel ?? 'Zurueck'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const MainMenuScreen(
                    initialSection: AppShellSection.play,
                  ),
                ),
                (route) => false,
              );
            },
            child: const Text('Zum Bereich Spielen'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'cricket_result_models.dart';

class CricketEndScreen extends StatelessWidget {
  const CricketEndScreen({
    required this.winnerName,
    required this.results,
    this.returnButtonLabel,
    super.key,
  });

  final String winnerName;
  final List<CricketParticipantStats> results;
  final String? returnButtonLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cricket Ende'),
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
                  'Sieger',
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
                    Text(
                      result.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Punkte: ${result.points}'),
                    Text('MPR: ${result.marksPerRound.toStringAsFixed(2)}'),
                    Text('Darts: ${result.dartsThrown}'),
                    Text('Turns: ${result.turns}'),
                    Text('Geschlossene Ziele: ${result.closedTargets}/7'),
                    Text('Best Marks Round: ${result.bestMarksRound}'),
                    Text('Best Point Round: ${result.highestScoringRound}'),
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'match_result_models.dart';

class MatchEndScreen extends StatelessWidget {
  const MatchEndScreen({
    required this.result,
    this.returnButtonLabel,
    super.key,
  });

  final MatchResultSummary result;
  final String? returnButtonLabel;

  @override
  Widget build(BuildContext context) {
    final participantNames = result.participants
        .map((entry) => entry.participantName)
        .join(' vs ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Ende'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1FA15A),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'WIN',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            result.winnerName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        Text(
                          result.scoreText,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      participantNames,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: result.participants
                  .map(
                    (stats) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildStatsCard(
                        context,
                        title: stats.participantName,
                        stats: stats,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            Text(
              'Leg Verlauf',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...result.legs.map(
              (leg) => Card(
                child: ExpansionTile(
                  title: Text(
                    'Leg ${leg.legNumber} - Sieger: ${_participantNameForId(leg.winnerSide)}',
                  ),
                  subtitle: Text(
                    leg.participants
                        .map(
                          (entry) =>
                              '${entry.participantName}: ${entry.average.toStringAsFixed(1)}',
                        )
                        .join(' | '),
                  ),
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: <Widget>[
                          ...leg.participants.asMap().entries.map(
                            (entry) => Padding(
                              padding: EdgeInsets.only(
                                bottom:
                                    entry.key == leg.participants.length - 1
                                        ? 12
                                        : 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: entry.key.isEven
                                      ? const Color(0xFFEDF3F8)
                                      : const Color(0xFFF7F9FB),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        entry.value.participantName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    Text(
                                      '${entry.value.dartsThrown} Darts | ${entry.value.average.toStringAsFixed(1)}',
                                      style:
                                          Theme.of(context).textTheme.labelLarge,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Table(
                            border: TableBorder.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            columnWidths: const <int, TableColumnWidth>{
                              0: FlexColumnWidth(0.7),
                              1: FlexColumnWidth(1.1),
                              2: FlexColumnWidth(0.9),
                              3: FlexColumnWidth(0.9),
                              4: FlexColumnWidth(0.9),
                              5: FlexColumnWidth(1.9),
                            },
                            children: <TableRow>[
                              _tableRow(
                                context,
                                const <String>[
                                  'Zug',
                                  'Seite',
                                  'Vorher',
                                  'Score',
                                  'Rest',
                                  'Info',
                                ],
                                isHeader: true,
                              ),
                              ...leg.visits.map(
                                (visit) => _tableRow(
                                  context,
                                  <String>[
                                  '${visit.turnNumber}',
                                    _participantNameForId(visit.side),
                                    '${visit.scoreBefore}',
                                    visit.bust
                                        ? 'BUST'
                                        : '${visit.scoredPoints}',
                                    '${visit.remainingScore}',
                                    visit.description,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(returnButtonLabel ?? 'Zurueck'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    BuildContext context, {
    required String title,
    required MatchParticipantStats stats,
  }) {
    final items = <(String, String)>[
      ('3DA', stats.average.toStringAsFixed(1)),
      ('PPD', stats.pointsPerDart.toStringAsFixed(2)),
      ('PPR', stats.pointsPerRound.toStringAsFixed(1)),
      ('F9', stats.firstNineAverage.toStringAsFixed(1)),
      ('Checkout', '${stats.checkoutQuote.toStringAsFixed(1)}%'),
      ('1D / 2D / 3D',
          '${stats.checkoutQuote1Dart.toStringAsFixed(0)} / ${stats.checkoutQuote2Dart.toStringAsFixed(0)} / ${stats.checkoutQuote3Dart.toStringAsFixed(0)}'),
      ('Highest Finish', '${stats.highestFinish}'),
      ('Average Finish', stats.averageFinish.toStringAsFixed(1)),
      ('Best Leg', stats.bestLegDarts > 0 ? '${stats.bestLegDarts} Darts' : '-'),
      ('Legs', '${stats.legsWon}/${stats.legsPlayed}'),
      ('Legs begonnen', '${stats.legsStarted}'),
      ('Mit Anwurf', '${stats.legsWonAsStarter}'),
      ('Ohne Anwurf', '${stats.legsWonWithoutStarter}'),
      ('With Throw Avg', stats.withThrowAverage.toStringAsFixed(1)),
      ('Against Throw Avg', stats.againstThrowAverage.toStringAsFixed(1)),
      ('Deciding Avg', stats.decidingLegAverage.toStringAsFixed(1)),
      ('Deciding Legs', '${stats.decidingLegsWonQuote.toStringAsFixed(1)}%'),
      ('12 / 15 / 18', '${stats.won12DarterQuote.toStringAsFixed(0)} / ${stats.won15DarterQuote.toStringAsFixed(0)} / ${stats.won18DarterQuote.toStringAsFixed(0)}%'),
      ('3rd Dart CO', '${stats.thirdDartCheckoutQuote.toStringAsFixed(1)}%'),
      ('Bull CO', '${stats.bullCheckoutQuote.toStringAsFixed(1)}%'),
      ('Func. Dbl', '${stats.functionalDoubleQuote.toStringAsFixed(1)}%'),
      ('Darts', '${stats.dartsThrown}'),
      ('Besuche', '${stats.visits}'),
      ('0-40 / 41-59', '${stats.scores0To40} / ${stats.scores41To59}'),
      ('60+ / 100+', '${stats.scores60Plus} / ${stats.scores100Plus}'),
      ('140+ / 171+ / 180', '${stats.scores140Plus} / ${stats.scores171Plus} / ${stats.scores180}'),
      ('180 pro Leg', stats.score180sPerLeg.toStringAsFixed(2)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items
                  .map(
                    (item) => Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.$1,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: const Color(0xFF607080),
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.$2,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _participantNameForId(String participantId) {
    for (final participant in result.participants) {
      if (participant.participantId == participantId) {
        return participant.participantName;
      }
    }
    return participantId;
  }

  TableRow _tableRow(
    BuildContext context,
    List<String> values, {
    bool isHeader = false,
  }) {
    return TableRow(
      children: values
          .map(
            (value) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                value,
                style: isHeader
                    ? Theme.of(context).textTheme.labelLarge
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
          .toList(),
    );
  }
}

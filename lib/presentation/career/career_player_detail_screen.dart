import 'package:flutter/material.dart';

import '../../data/repositories/career_repository.dart';
import '../../domain/career/career_models.dart';
import '../../domain/career/career_statistics.dart';

class CareerPlayerDetailScreen extends StatefulWidget {
  const CareerPlayerDetailScreen({
    super.key,
    required this.playerId,
  });

  final String playerId;

  @override
  State<CareerPlayerDetailScreen> createState() => _CareerPlayerDetailScreenState();
}

class _CareerPlayerDetailScreenState extends State<CareerPlayerDetailScreen> {
  CareerHistoryFilterMode _filterMode = CareerHistoryFilterMode.career;
  int? _selectedSeasonNumber;

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final history = repository.playerHistoryWithFilter(
          widget.playerId,
          filterMode: _filterMode,
          seasonNumber: _selectedSeasonNumber,
        );
        if (history == null) {
          return const Scaffold(
            body: Center(
              child: Text('Spielerhistorie konnte nicht geladen werden.'),
            ),
          );
        }

        final sortedTypes = history.typeTitleCounts.entries.toList()
          ..sort((left, right) {
            final countCompare = right.value.compareTo(left.value);
            if (countCompare != 0) {
              return countCompare;
            }
            return left.key.compareTo(right.key);
          });

        return Scaffold(
          appBar: AppBar(
            title: Text(history.playerName),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final metricWidth =
                    isWide ? 180.0 : (constraints.maxWidth - 44) / 2;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: <Widget>[
                    _PlayerHeaderCard(history: history),
                    const SizedBox(height: 16),
                    _FilterCard(
                      filterMode: _filterMode,
                      selectedSeasonNumber: _selectedSeasonNumber,
                      availableSeasons: history.availableSeasons,
                      onFilterModeChanged: (value) {
                        setState(() {
                          _filterMode = value;
                          if (_filterMode != CareerHistoryFilterMode.specificSeason) {
                            _selectedSeasonNumber = null;
                          } else {
                            _selectedSeasonNumber ??=
                                history.availableSeasons.isEmpty
                                    ? null
                                    : history.availableSeasons.first;
                          }
                        });
                      },
                      onSeasonChanged: (value) {
                        setState(() {
                          _selectedSeasonNumber = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        _MetricCard(
                          title: 'Titel',
                          value: '${history.totalTitles}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Finals',
                          value: '${history.totalFinals}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Halbfinals',
                          value: '${history.totalSemiFinals}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Viertelfinals',
                          value: '${history.totalQuarterFinals}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Teilnahmen',
                          value: '${history.totalAppearances}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Preisgeld',
                          value: '${history.totalMoney}',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: '3DA',
                          value: history.x01Stats.average.toStringAsFixed(1),
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'F9',
                          value: history.x01Stats.firstNineAverage.toStringAsFixed(1),
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: 'Checkout',
                          value: '${history.x01Stats.checkoutQuote.toStringAsFixed(1)}%',
                          width: metricWidth,
                        ),
                        _MetricCard(
                          title: '100+ / 140+ / 180',
                          value:
                              '${history.x01Stats.scores100Plus} / ${history.x01Stats.scores140Plus} / ${history.x01Stats.scores180}',
                          width: metricWidth,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _X01StatsCard(stats: history.x01Stats),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            flex: 3,
                            child: _TypeTitlesCard(sortedTypes: sortedTypes),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: _HistoryCard(entries: history.entries),
                          ),
                        ],
                      )
                    else ...<Widget>[
                      _TypeTitlesCard(sortedTypes: sortedTypes),
                      const SizedBox(height: 16),
                      _HistoryCard(entries: history.entries),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _PlayerHeaderCard extends StatelessWidget {
  const _PlayerHeaderCard({
    required this.history,
  });

  final CareerPlayerHistorySummary history;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              history.playerName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Karriereprofil mit Turnierhistorie und X01-Statistiken.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.filterMode,
    required this.selectedSeasonNumber,
    required this.availableSeasons,
    required this.onFilterModeChanged,
    required this.onSeasonChanged,
  });

  final CareerHistoryFilterMode filterMode;
  final int? selectedSeasonNumber;
  final List<int> availableSeasons;
  final ValueChanged<CareerHistoryFilterMode> onFilterModeChanged;
  final ValueChanged<int?> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Filter',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CareerHistoryFilterMode>(
              initialValue: filterMode,
              decoration: const InputDecoration(labelText: 'Zeitraum'),
              items: const <DropdownMenuItem<CareerHistoryFilterMode>>[
                DropdownMenuItem(
                  value: CareerHistoryFilterMode.career,
                  child: Text('Komplette Karriere'),
                ),
                DropdownMenuItem(
                  value: CareerHistoryFilterMode.currentSeason,
                  child: Text('Aktuelle Saison'),
                ),
                DropdownMenuItem(
                  value: CareerHistoryFilterMode.specificSeason,
                  child: Text('Bestimmte Saison'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onFilterModeChanged(value);
                }
              },
            ),
            if (filterMode == CareerHistoryFilterMode.specificSeason) ...<Widget>[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedSeasonNumber,
                decoration: const InputDecoration(labelText: 'Saison'),
                items: availableSeasons
                    .map(
                      (season) => DropdownMenuItem<int>(
                        value: season,
                        child: Text('Saison $season'),
                      ),
                    )
                    .toList(),
                onChanged: onSeasonChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _X01StatsCard extends StatelessWidget {
  const _X01StatsCard({
    required this.stats,
  });

  final CareerX01PlayerStats stats;

  @override
  Widget build(BuildContext context) {
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
      ('12 / 15 / 18',
          '${stats.won12DarterQuote.toStringAsFixed(0)} / ${stats.won15DarterQuote.toStringAsFixed(0)} / ${stats.won18DarterQuote.toStringAsFixed(0)}%'),
      ('3rd Dart CO', '${stats.thirdDartCheckoutQuote.toStringAsFixed(1)}%'),
      ('Bull CO', '${stats.bullCheckoutQuote.toStringAsFixed(1)}%'),
      ('Func. Dbl', '${stats.functionalDoubleQuote.toStringAsFixed(1)}%'),
      ('Darts', '${stats.dartsThrown}'),
      ('Besuche', '${stats.visits}'),
      ('0-40 / 41-59', '${stats.scores0To40} / ${stats.scores41To59}'),
      ('60+ / 100+', '${stats.scores60Plus} / ${stats.scores100Plus}'),
      ('140+ / 171+ / 180',
          '${stats.scores140Plus} / ${stats.scores171Plus} / ${stats.scores180}'),
      ('180 pro Leg', stats.score180sPerLeg.toStringAsFixed(2)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'X01-Statistiken',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const <int, TableColumnWidth>{
                0: FlexColumnWidth(1.4),
                1: FlexColumnWidth(1),
              },
              children: items
                  .map(
                    (item) => TableRow(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(item.$1),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            item.$2,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTitlesCard extends StatelessWidget {
  const _TypeTitlesCard({
    required this.sortedTypes,
  });

  final List<MapEntry<String, int>> sortedTypes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Titel nach Turnierart',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (sortedTypes.isEmpty)
              const Text('Noch keine Turniersiege.')
            else
              ...sortedTypes.asMap().entries.map((entry) {
                final index = entry.key;
                final type = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == sortedTypes.length - 1 ? 0 : 10,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text('${index + 1}'),
                    ),
                    title: Text(type.key),
                    trailing: Text('${type.value} Siege'),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.entries,
  });

  final List<CareerPlayerHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Karrierehistorie',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('Noch keine Karriereeintraege.')
            else
              ...entries.asMap().entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == entries.length - 1 ? 0 : 10,
                  ),
                  child: _HistoryEntryCard(historyEntry: entry.value),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({
    required this.historyEntry,
  });

  final CareerPlayerHistoryEntry historyEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  historyEntry.tournamentName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 12),
              Text('Saison ${historyEntry.seasonNumber}'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _HistoryTag(label: historyEntry.resultLabel),
              _HistoryTag(label: 'Preisgeld ${historyEntry.money}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTag extends StatelessWidget {
  const _HistoryTag({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.width,
  });

  final String title;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

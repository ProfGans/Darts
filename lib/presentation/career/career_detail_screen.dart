import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../data/debug/app_debug.dart';
import '../../data/repositories/career_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/tournament_repository.dart';
import '../../domain/career/career_models.dart';
import '../../domain/career/career_statistics.dart';
import '../../domain/rankings/ranking_engine.dart';
import '../../domain/x01/x01_models.dart';
import 'career_player_detail_screen.dart';

Future<bool> _runCareerTournamentSimulation({
  required CareerDefinition career,
  required CareerCalendarItem item,
  bool calledFromSeason = false,
}) async {
  if (!CareerRepository.instance.shouldTournamentTakePlace(
    item,
    career: career,
  )) {
    return false;
  }

  final repository = CareerRepository.instance;
  final completedBefore =
      repository.activeCareer?.currentSeason.completedItemIds.length ?? 0;
  final action = AppDebug.instance.startAction(
    'Karriere',
    'Turnier-Simulation "${item.name}"',
  );
  AppDebug.instance.info(
    'Trace',
    'Karriere-Simulation gestartet | Karriere=${career.name} | Turnier=${item.name} | ausSaison=$calledFromSeason',
  );
  try {
    final tournamentRepository = TournamentRepository.instance;
    final buildStopwatch = Stopwatch()..start();
    tournamentRepository.createCareerTournament(
      career: career,
      item: item,
      silent: calledFromSeason,
    );
    buildStopwatch.stop();
    AppDebug.instance.info(
      'Performance',
      'Turnieraufbau "${item.name}": ${buildStopwatch.elapsedMilliseconds} ms',
    );
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final simulationStopwatch = Stopwatch()..start();
    await tournamentRepository.simulateCurrentTournamentUntilComplete(
      includeHumanMatches: true,
      emitProgressUpdates: !calledFromSeason,
      preferResponsiveUi: true,
    );
    simulationStopwatch.stop();
    AppDebug.instance.info(
      'Performance',
      'Turniersimulation "${item.name}": ${simulationStopwatch.elapsedMilliseconds} ms',
    );
    if (tournamentRepository.currentBracket?.isCompleted ?? false) {
      final commitStopwatch = Stopwatch()..start();
      tournamentRepository.commitCurrentCareerTournament(
        silent: calledFromSeason,
      );
      commitStopwatch.stop();
      AppDebug.instance.info(
        'Performance',
        'Karriere-Commit "${item.name}": ${commitStopwatch.elapsedMilliseconds} ms',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
    } else {
      AppDebug.instance.error(
        'Karriere',
        'Turnier "${item.name}" wurde nicht abgeschlossen.',
      );
    }
    action.complete();
  } catch (error) {
    action.fail(error);
    rethrow;
  }

  final completedAfter =
      repository.activeCareer?.currentSeason.completedItemIds.length ??
          completedBefore;
  final progressed = completedAfter > completedBefore;
  if (!progressed) {
    AppDebug.instance.error(
      'Karriere',
      'Turnier "${item.name}" hat keinen Saison-Fortschritt erzeugt.',
    );
  }
  return progressed;
}

class CareerDetailScreen extends StatefulWidget {
  const CareerDetailScreen({super.key});

  @override
  State<CareerDetailScreen> createState() => _CareerDetailScreenState();
}

class _CareerDetailScreenState extends State<CareerDetailScreen> {
  bool _isSimulatingTournament = false;
  String? _simulationStatus;
  String? _scheduledPrewarmKey;
  bool _showSimulationOverlay = true;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows &&
      _isSimulatingTournament;

  void _openPlayerHistory(BuildContext context, String playerId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CareerPlayerDetailScreen(playerId: playerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;
    final tournamentRepository = TournamentRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[repository, tournamentRepository]),
      builder: (context, _) {
        final career = repository.activeCareer;
        final summary = repository.statisticsSummary();
        if (career == null) {
          return const Scaffold(
            body: Center(child: Text('Keine aktive Karriere geladen.')),
          );
        }

        final nextItem = repository.nextOpenCalendarItem();
        if (nextItem != null) {
          final prewarmKey =
              '${career.id}|${career.currentSeason.seasonNumber}|${nextItem.id}';
          if (_scheduledPrewarmKey != prewarmKey) {
            _scheduledPrewarmKey = prewarmKey;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              unawaited(
                tournamentRepository.prewarmCareerSimulation(
                  career: career,
                  item: nextItem,
                ),
              );
            });
          }
        }
        final remainingCount = repository.remainingTournamentsInCurrentSeason();
        final canFinishSeason = repository.canFinishCurrentSeason();
        final humanStatus = _MyCareerStatusData.fromCareer(
          career,
          repository: repository,
          nextItem: nextItem,
        );
        final bestAverageLeaders = _bestAverageLeaders(career);
        final runningCareerTournament =
            tournamentRepository.isCareerTournament &&
                    tournamentRepository.careerContext?.careerId == career.id &&
                    tournamentRepository.careerContext?.seasonNumber ==
                        career.currentSeason.seasonNumber
                ? tournamentRepository.careerContext
                : null;
        final eventSnapshot = _CareerEventSnapshot.fromCareer(
          career,
          nextItem: runningCareerTournament?.calendarItem ?? nextItem,
          repository: repository,
          myStatus: humanStatus,
        );

        return Scaffold(
          appBar: AppBar(title: Text(career.name)),
          body: ExcludeSemantics(
            excluding: _suppressAccessibilityUpdates,
            child: SafeArea(
              child: Stack(
                children: <Widget>[
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: <Widget>[
                const _ScreenLevelLabel(label: 'Jetzt wichtig'),
                _CareerFocusDashboard(
                  career: career,
                  nextItem: nextItem,
                  remainingCount: remainingCount,
                  runningCareerTournament: runningCareerTournament,
                  isSimulatingTournament: _isSimulatingTournament,
                  simulationStatus: _simulationStatus,
                  detailedSimulationStatus:
                      tournamentRepository.simulationProgressLabel,
                  simulationProgress: tournamentRepository.simulationProgress,
                  canFinishSeason: canFinishSeason,
                  onStartCareer: repository.startCareer,
                  onFinishSeason: repository.finishCurrentSeason,
                  onOpenRunningTournament: () {
                    Navigator.of(context).pushNamed(AppRoutes.tournamentBracket);
                  },
                  onPlayNextTournament: nextItem == null
                      ? null
                      : () => _playCareerItem(
                            context,
                            career: career,
                            item: nextItem,
                          ),
                  onSimulateNextTournament: nextItem == null
                      ? null
                      : () => _simulateNextTournament(
                            career: career,
                            item: nextItem,
                          ),
                  onOpenSeasonCalendar: () => _openSeasonCalendar(
                    context,
                    career: career,
                  ),
                  eventSnapshot: eventSnapshot,
                ),
                if (humanStatus != null) ...<Widget>[
                  const SizedBox(height: 12),
                  _MyCareerStatusCard(status: humanStatus),
                ],
                const SizedBox(height: 16),
                const _ScreenLevelLabel(label: 'Saison'),
                _SectionCard(
                  title: 'Aktuelle Saison',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Saison ${career.currentSeason.seasonNumber} mit ${career.currentSeason.calendar.length} geplanten Events.',
                      ),
                      const SizedBox(height: 12),
                      _ProgressBar(
                        totalCount: career.currentSeason.calendar.length,
                        completedCount:
                            career.currentSeason.completedItemIds.length,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => _openSeasonCalendar(
                          context,
                          career: career,
                        ),
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Saisonkalender oeffnen'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _ScreenLevelLabel(label: 'Ranglisten'),
                _SectionCard(
                  title: 'Ranglisten',
                  child: career.rankings.isEmpty
                      ? const Text('Noch keine Ranglisten angelegt.')
                      : _CareerRankingOverview(
                          rankings: career.rankings.take(2).toList(),
                          totalRankingCount: career.rankings.length,
                          standingsForRanking: repository.standingsForRanking,
                          onPlayerTap: (playerId) =>
                              _openPlayerHistory(context, playerId),
                          onOpenAll: () => _openRankingsOverview(context),
                        ),
                ),
                const SizedBox(height: 16),
                const _ScreenLevelLabel(label: 'Historie & Stats'),
                _SectionCard(
                  title: 'Saisonrueckblick',
                  child: career.completedSeasons.isEmpty
                      ? const Text('Noch keine abgeschlossene Saison.')
                      : _CompletedSeasonPreview(
                          snapshot: _CompletedSeasonSnapshot.fromCareer(career),
                          onOpenAll: () => _openCompletedSeasons(context),
                        ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                      title: 'Karriere-Statistiken',
                      child: summary == null
                          ? const Text('Noch keine Statistik verfuegbar.')
                          : _CareerStatsOverview(
                              summary: summary,
                              bestAverageLeaders: bestAverageLeaders,
                              myStatus: humanStatus,
                              onOpenAll: () => _openCareerStatistics(context),
                              onPlayerTap: (playerId) =>
                                  _openPlayerHistory(context, playerId),
                            ),
                ),
                ],
                  ),
                  if (_isSimulatingTournament ||
                      tournamentRepository.simulationInProgress)
                    _showSimulationOverlay
                        ? _SimulationProgressOverlay(
                            title:
                                _simulationStatus ?? 'Karriere-Simulation laeuft',
                            label:
                                tournamentRepository.simulationProgressLabel,
                            progress: tournamentRepository.simulationProgress,
                            onHide: () {
                              setState(() {
                                _showSimulationOverlay = false;
                              });
                            },
                          )
                        : _SimulationProgressHandle(
                            label:
                                tournamentRepository.simulationProgressLabel,
                            progress: tournamentRepository.simulationProgress,
                            onOpen: () {
                              setState(() {
                                _showSimulationOverlay = true;
                              });
                            },
                          ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openSeasonCalendar(
    BuildContext context, {
    required CareerDefinition career,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CareerSeasonCalendarScreen(careerId: career.id),
      ),
    );
  }

  void _openRankingsOverview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _CareerRankingsScreen(),
      ),
    );
  }

  void _openCompletedSeasons(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _CareerCompletedSeasonsScreen(),
      ),
    );
  }

  void _openCareerStatistics(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _CareerStatisticsScreen(),
      ),
    );
  }

  void _playCareerItem(
    BuildContext context, {
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    if (!CareerRepository.instance.shouldTournamentTakePlace(
      item,
      career: career,
    )) {
      return;
    }
    final tournamentRepository = TournamentRepository.instance;
    final contextData = tournamentRepository.careerContext;
    final isSameTournament = tournamentRepository.isCareerTournament &&
        contextData?.careerId == career.id &&
        contextData?.seasonNumber == career.currentSeason.seasonNumber &&
        contextData?.calendarItem.id == item.id;
    if (!isSameTournament) {
      tournamentRepository.createCareerTournament(
        career: career,
        item: item,
      );
    }
    Navigator.of(context).pushNamed(AppRoutes.tournamentBracket);
  }

  Future<bool> _simulateNextTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) async {
    if (_isSimulatingTournament) {
      return false;
    }
      AppDebug.instance.info(
        'Trace',
        'Button: Schnell simulieren | Karriere=${career.name} | Turnier=${item.name}',
      );
      setState(() {
        _isSimulatingTournament = true;
        _simulationStatus = 'Baue ${item.name} auf...';
        if (!_isSimulatingTournament) {
          _showSimulationOverlay = true;
        }
      });
      try {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        return await _runCareerTournamentSimulation(
          career: career,
          item: item,
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSimulatingTournament = false;
            _simulationStatus = null;
          });
        }
        TournamentRepository.instance.clearSimulationProgress();
      }
    }
  }

class _CareerSeasonCalendarScreen extends StatefulWidget {
  const _CareerSeasonCalendarScreen({
    required this.careerId,
  });

  final String careerId;

  @override
  State<_CareerSeasonCalendarScreen> createState() =>
      _CareerSeasonCalendarScreenState();
}

class _CareerSeasonCalendarScreenState extends State<_CareerSeasonCalendarScreen> {
  bool _isSimulatingTournament = false;
  bool _isSimulatingSeason = false;
  String? _simulationStatus;
  bool _showSimulationOverlay = true;

  bool get _suppressAccessibilityUpdates =>
      defaultTargetPlatform == TargetPlatform.windows &&
      (_isSimulatingTournament || _isSimulatingSeason);

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;
    final tournamentRepository = TournamentRepository.instance;

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[repository, tournamentRepository]),
      builder: (context, _) {
        CareerDefinition? career;
        for (final entry in repository.careers) {
          if (entry.id == widget.careerId) {
            career = entry;
            break;
          }
        }
        if (career == null) {
          return const Scaffold(
            body: Center(child: Text('Karriere konnte nicht geladen werden.')),
          );
        }
        final loadedCareer = career;

        final canFinishSeason = repository.activeCareer?.id == loadedCareer.id &&
            repository.canFinishCurrentSeason();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saisonkalender'),
          ),
          body: ExcludeSemantics(
            excluding: _suppressAccessibilityUpdates,
            child: SafeArea(
              child: Stack(
                children: <Widget>[
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: <Widget>[
                _SectionCard(
                  title: 'Saisonaktionen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _ProgressBar(
                        totalCount: loadedCareer.currentSeason.calendar.length,
                        completedCount:
                            loadedCareer.currentSeason.completedItemIds.length,
                      ),
                        if (_simulationStatus != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _simulationStatus!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF27415A),
                                  ),
                        ),
                        ],
                        if (_isSimulatingTournament || _isSimulatingSeason) ...<Widget>[
                          const SizedBox(height: 12),
                          _SimulationProgressCard(
                            label: tournamentRepository.simulationProgressLabel,
                            progress: tournamentRepository.simulationProgress,
                          ),
                        ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _isSimulatingSeason
                                ? null
                                : () => _simulateSeason(career: loadedCareer),
                            icon: const Icon(Icons.auto_awesome_motion),
                            label: const Text('Komplette Saison simulieren'),
                          ),
                          OutlinedButton.icon(
                            onPressed: canFinishSeason
                                ? repository.finishCurrentSeason
                                : null,
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Saison abschliessen'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Kompletter Saisonkalender',
                  child: loadedCareer.currentSeason.calendar.isEmpty
                      ? const Text('Noch keine Turniere geplant.')
                      : Column(
                          children: loadedCareer.currentSeason.calendar
                              .asMap()
                              .entries
                              .map(
                                (entry) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: entry.key ==
                                            loadedCareer.currentSeason.calendar.length - 1
                                        ? 0
                                        : 10,
                                  ),
                                  child: _CareerCalendarItemCard(
                                    career: loadedCareer,
                                    item: entry.value,
                                    index: entry.key,
                                    isSimulatingSeason: _isSimulatingSeason,
                                    takesPlace:
                                        repository.shouldTournamentTakePlace(
                                      entry.value,
                                      career: loadedCareer,
                                    ),
                                    onPlay: () => _playCareerItem(
                                      context,
                                      career: loadedCareer,
                                      item: entry.value,
                                    ),
                                    onSimulate: () => _simulateNextTournament(
                                      career: loadedCareer,
                                      item: entry.value,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                ],
                  ),
                  if (_isSimulatingTournament ||
                      _isSimulatingSeason ||
                      tournamentRepository.simulationInProgress)
                    _showSimulationOverlay
                        ? _SimulationProgressOverlay(
                            title: _simulationStatus ??
                                (_isSimulatingSeason
                                    ? 'Komplette Saison wird simuliert'
                                    : 'Turnier-Simulation laeuft'),
                            label:
                                tournamentRepository.simulationProgressLabel,
                            progress: tournamentRepository.simulationProgress,
                            onHide: () {
                              setState(() {
                                _showSimulationOverlay = false;
                              });
                            },
                          )
                        : _SimulationProgressHandle(
                            label:
                                tournamentRepository.simulationProgressLabel,
                            progress: tournamentRepository.simulationProgress,
                            onOpen: () {
                              setState(() {
                                _showSimulationOverlay = true;
                              });
                            },
                          ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _playCareerItem(
    BuildContext context, {
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    if (!CareerRepository.instance.shouldTournamentTakePlace(
      item,
      career: career,
    )) {
      return;
    }
    final tournamentRepository = TournamentRepository.instance;
    final contextData = tournamentRepository.careerContext;
    final isSameTournament = tournamentRepository.isCareerTournament &&
        contextData?.careerId == career.id &&
        contextData?.seasonNumber == career.currentSeason.seasonNumber &&
        contextData?.calendarItem.id == item.id;
    if (!isSameTournament) {
      tournamentRepository.createCareerTournament(
        career: career,
        item: item,
      );
    }
    Navigator.of(context).pushNamed(AppRoutes.tournamentBracket);
  }

  Future<bool> _simulateNextTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
    bool calledFromSeason = false,
  }) async {
    if (_isSimulatingTournament || (_isSimulatingSeason && !calledFromSeason)) {
      return false;
    }

      AppDebug.instance.info(
        'Trace',
        calledFromSeason
            ? 'Saisonlauf: naechstes Turnier | Karriere=${career.name} | Turnier=${item.name}'
            : 'Button: Turnier simulieren | Karriere=${career.name} | Turnier=${item.name}',
      );

      setState(() {
        _isSimulatingTournament = true;
        _simulationStatus = calledFromSeason
            ? 'Baue ${item.name} auf...'
            : 'Baue ${item.name} auf...';
        if (!_isSimulatingSeason && !_isSimulatingTournament) {
          _showSimulationOverlay = true;
        }
      });
      try {
        return await _runCareerTournamentSimulation(
        career: career,
        item: item,
        calledFromSeason: calledFromSeason,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSimulatingTournament = false;
            if (!_isSimulatingSeason) {
              _simulationStatus = null;
            }
          });
        }
        if (!_isSimulatingSeason) {
          TournamentRepository.instance.clearSimulationProgress();
        }
      }
    }

  Future<void> _simulateSeason({
    required CareerDefinition career,
  }) async {
    if (_isSimulatingSeason) {
      return;
    }
    final repository = CareerRepository.instance;
    setState(() {
      _isSimulatingSeason = true;
      _simulationStatus = 'Saison-Simulation gestartet...';
      _showSimulationOverlay = true;
    });
    final action = AppDebug.instance.startAction(
      'Karriere',
      'Komplette Saison-Simulation',
    );
    try {
      final total = career.currentSeason.calendar.length;
      while (mounted) {
        final nextItem = repository.nextOpenCalendarItem();
        if (nextItem == null) {
          break;
        }
        final completed =
            repository.activeCareer?.currentSeason.completedItemIds.length ?? 0;
        final currentIndex = completed + 1;
        setState(() {
          _simulationStatus =
              'Saison-Simulation: Turnier $currentIndex/$total - ${nextItem.name}';
        });
        final progressed = await _simulateNextTournament(
          career: career,
          item: nextItem,
          calledFromSeason: true,
        );
        if (!progressed) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }
      action.complete();
    } catch (error) {
      action.fail(error);
      rethrow;
    } finally {
      if (mounted) {
          setState(() {
            _isSimulatingSeason = false;
            _simulationStatus = null;
          });
        }
        TournamentRepository.instance.clearSimulationProgress();
      }
    }
}

class _CareerCalendarItemCard extends StatelessWidget {
  const _CareerCalendarItemCard({
    required this.career,
    required this.item,
    required this.index,
    required this.isSimulatingSeason,
    required this.takesPlace,
    required this.onPlay,
    required this.onSimulate,
  });

  final CareerDefinition career;
  final CareerCalendarItem item;
  final int index;
  final bool isSimulatingSeason;
  final bool takesPlace;
  final VoidCallback onPlay;
  final VoidCallback onSimulate;

  @override
  Widget build(BuildContext context) {
    final archive = TournamentRepository.instance.archiveForCareerItem(
      careerId: career.id,
      seasonNumber: career.currentSeason.seasonNumber,
      calendarItemId: item.id,
    );
    final isCompleted = career.currentSeason.completedItemIds.contains(item.id);
    final rankingNames = career.rankings
        .where((ranking) => item.countsForRankingIds.contains(ranking.id))
        .map((ranking) => ranking.name)
        .toList();

    String? seedingName;
    if (item.seedingRankingId != null) {
      for (final ranking in career.rankings) {
        if (ranking.id == item.seedingRankingId) {
          seedingName = ranking.name;
          break;
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.fieldSize} Spieler | ${_matchSummary(item)} | ${item.startScore} | Preisgeld ${item.prizePool}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  label: isCompleted
                      ? 'Abgeschlossen'
                      : takesPlace
                          ? 'Offen'
                          : 'Entfaellt',
                ),
                if (rankingNames.isNotEmpty)
                  _InfoPill(label: rankingNames.join(', ')),
                if (seedingName != null && item.seedCount > 0)
                  _InfoPill(label: 'Setzliste $seedingName Top ${item.seedCount}'),
                  if (item.qualificationConditions.isNotEmpty)
                    _InfoPill(
                      label:
                          '${item.qualificationConditions.length} Quali-Bedingungen',
                    ),
                  if (item.isLeagueSeriesItem && item.seriesIndex != null)
                    _InfoPill(
                      label: item.seriesStage == CareerLeagueSeriesStage.playoffRound
                          ? 'Playoff ${item.seriesIndex}/${item.seriesLength ?? item.seriesIndex}'
                          : 'Spieltag ${item.seriesIndex}/${item.seriesLength ?? item.seriesIndex}',
                    ),
                  if (item.tagGate != null)
                    _InfoPill(
                      label:
                          'Tag-Regel ${item.tagGate!.tagName} ${item.tagGate!.minimumPlayerCount}+',
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonal(
                  onPressed: isCompleted || !takesPlace ? null : onPlay,
                  child: Text(
                    isCompleted
                        ? 'Abgeschlossen'
                        : takesPlace
                            ? 'Turnier spielen'
                            : 'Turnier entfaellt',
                  ),
                ),
                if (!isCompleted && takesPlace)
                  OutlinedButton(
                    onPressed: isSimulatingSeason ? null : onSimulate,
                    child: const Text('Simulieren'),
                  ),
                if (archive != null)
                  OutlinedButton(
                    onPressed: () {
                      TournamentRepository.instance.openArchive(archive.id);
                      Navigator.of(context).pushNamed(AppRoutes.tournamentBracket);
                    },
                    child: const Text('Ansehen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _matchSummary(CareerCalendarItem item) {
  if (item.matchMode == MatchMode.sets) {
    return 'Sets ${item.setsToWin} / Legs ${item.legsPerSet}';
  }
  return 'Legs ${item.legsToWin}';
}

class _SimpleStandingsTable extends StatelessWidget {
  const _SimpleStandingsTable({
    required this.leaders,
    required this.onPlayerTap,
  });

  final List<RankingStanding> leaders;
  final ValueChanged<String> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    if (leaders.isEmpty) {
      return const ListTile(
        title: Text('Noch keine Turniere in dieser Rangliste gewertet.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const <DataColumn>[
          DataColumn(label: Text('Rang')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Geld')),
          DataColumn(label: Text('Titel')),
        ],
        rows: leaders.map((entry) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text('${entry.rank}')),
              DataCell(
                TextButton(
                  onPressed: () => onPlayerTap(entry.id),
                  child: Text(entry.name),
                ),
              ),
              DataCell(Text('${entry.money}')),
              DataCell(Text('${entry.titles}')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _CareerRankingOverview extends StatelessWidget {
  const _CareerRankingOverview({
    required this.rankings,
    required this.totalRankingCount,
    required this.standingsForRanking,
    required this.onPlayerTap,
    required this.onOpenAll,
  });

  final List<CareerRankingDefinition> rankings;
  final int totalRankingCount;
  final List<RankingStanding> Function(String rankingId) standingsForRanking;
  final ValueChanged<String> onPlayerTap;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ...rankings.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(bottom: entry.key == rankings.length - 1 ? 0 : 12),
            child: _RankingPreviewCard(
              ranking: entry.value,
              leaders: standingsForRanking(entry.value.id).take(5).toList(),
              onPlayerTap: onPlayerTap,
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenAll,
          icon: const Icon(Icons.format_list_numbered_rounded),
          label: Text(
            totalRankingCount > rankings.length
                ? 'Komplette Ranglisten oeffnen ($totalRankingCount)'
                : 'Komplette Rangliste oeffnen',
          ),
        ),
      ],
    );
  }
}

class _RankingPreviewCard extends StatelessWidget {
  const _RankingPreviewCard({
    required this.ranking,
    required this.leaders,
    required this.onPlayerTap,
  });

  final CareerRankingDefinition ranking;
  final List<RankingStanding> leaders;
  final ValueChanged<String> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ranking.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Top ${leaders.isEmpty ? 5 : leaders.length} • Gueltig ueber ${ranking.validSeasons} Saison(en)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5D7285),
                ),
          ),
          const SizedBox(height: 10),
          if (leaders.isEmpty)
            const Text('Noch keine Turniere in dieser Rangliste gewertet.')
          else
            Column(
              children: leaders
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry == leaders.last ? 0 : 8,
                      ),
                      child: _RankingLeaderRow(
                        entry: entry,
                        onPlayerTap: onPlayerTap,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _RankingLeaderRow extends StatelessWidget {
  const _RankingLeaderRow({
    required this.entry,
    required this.onPlayerTap,
  });

  final RankingStanding entry;
  final ValueChanged<String> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${entry.rank}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextButton(
            onPressed: () => onPlayerTap(entry.id),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${entry.money}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _StatsTable extends StatelessWidget {
  const _StatsTable({
    required this.title,
    required this.leaders,
    required this.valueLabel,
    this.onPlayerTap,
  });

  final String title;
  final List<CareerStatLeader> leaders;
  final String valueLabel;
  final ValueChanged<String>? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (leaders.isEmpty)
          const Text('Noch keine Daten vorhanden.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: <DataColumn>[
                const DataColumn(label: Text('Rang')),
                const DataColumn(label: Text('Name')),
                DataColumn(label: Text(valueLabel)),
              ],
              rows: leaders
                  .asMap()
                  .entries
                  .map(
                    (entry) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text('${entry.key + 1}')),
                        DataCell(
                          onPlayerTap == null
                              ? Text(entry.value.playerName)
                              : TextButton(
                                  onPressed: () =>
                                      onPlayerTap!(entry.value.playerId),
                                  child: Text(entry.value.playerName),
                                ),
                        ),
                        DataCell(Text('${entry.value.value}')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _CareerStatsOverview extends StatelessWidget {
  const _CareerStatsOverview({
    required this.summary,
    required this.bestAverageLeaders,
    required this.myStatus,
    required this.onOpenAll,
    required this.onPlayerTap,
  });

  final CareerStatisticsSummary summary;
  final List<_AverageLeader> bestAverageLeaders;
  final _MyCareerStatusData? myStatus;
  final VoidCallback onOpenAll;
  final ValueChanged<String> onPlayerTap;

  @override
  Widget build(BuildContext context) {
    final topTitles = summary.overallTitles.isEmpty ? null : summary.overallTitles.first;
    final topMoney = summary.overallMoney.isEmpty ? null : summary.overallMoney.first;
    final topAverage = bestAverageLeaders.isEmpty ? null : bestAverageLeaders.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: _StatsHighlightCard(
                label: 'Meiste Titel',
                title: topTitles?.playerName ?? 'Noch offen',
                value: topTitles == null ? '-' : '${topTitles.value}',
                onTap: topTitles == null ? null : () => onPlayerTap(topTitles.playerId),
              ),
            ),
            SizedBox(
              width: 220,
              child: _StatsHighlightCard(
                label: 'Meistes Preisgeld',
                title: topMoney?.playerName ?? 'Noch offen',
                value: topMoney == null ? '-' : '${topMoney.value}',
                onTap: topMoney == null ? null : () => onPlayerTap(topMoney.playerId),
              ),
            ),
            SizedBox(
              width: 220,
              child: _StatsHighlightCard(
                label: 'Bester Average',
                title: topAverage?.playerName ?? 'Noch offen',
                value: topAverage == null ? '-' : topAverage.averageLabel,
                onTap: topAverage == null ? null : () => onPlayerTap(topAverage.playerId),
              ),
            ),
            if (myStatus != null)
              SizedBox(
                width: 220,
                child: _StatsHighlightCard(
                  label: 'Mein Vergleich',
                  title: myStatus!.comparisonLabel,
                  value: myStatus!.averageLabel,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenAll,
          icon: const Icon(Icons.insights_rounded),
          label: const Text('Alle Karriere-Statistiken'),
        ),
      ],
    );
  }
}

class _StatsHighlightCard extends StatelessWidget {
  const _StatsHighlightCard({
    required this.label,
    required this.title,
    required this.value,
    this.onTap,
  });

  final String label;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF5D7285),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _CareerFocusDashboard extends StatelessWidget {
  const _CareerFocusDashboard({
    required this.career,
    required this.nextItem,
    required this.remainingCount,
    required this.runningCareerTournament,
    required this.isSimulatingTournament,
    required this.simulationStatus,
    required this.detailedSimulationStatus,
    required this.simulationProgress,
    required this.canFinishSeason,
    required this.onStartCareer,
    required this.onFinishSeason,
    required this.onOpenRunningTournament,
    required this.onPlayNextTournament,
    required this.onSimulateNextTournament,
    required this.onOpenSeasonCalendar,
    required this.eventSnapshot,
  });

  final CareerDefinition career;
  final CareerCalendarItem? nextItem;
  final int remainingCount;
  final CareerTournamentContext? runningCareerTournament;
  final bool isSimulatingTournament;
  final String? simulationStatus;
  final String? detailedSimulationStatus;
  final double? simulationProgress;
  final bool canFinishSeason;
  final VoidCallback onStartCareer;
  final VoidCallback onFinishSeason;
  final VoidCallback onOpenRunningTournament;
  final VoidCallback? onPlayNextTournament;
  final VoidCallback? onSimulateNextTournament;
  final VoidCallback onOpenSeasonCalendar;
  final _CareerEventSnapshot eventSnapshot;

  @override
  Widget build(BuildContext context) {
    final totalCount = career.currentSeason.calendar.length;
    final completedCount = career.currentSeason.completedItemIds.length;
    final progressLabel = totalCount == 0
        ? 'Noch kein Saisonkalender'
        : '$completedCount von $totalCount Events abgeschlossen';
    final focusTitle = runningCareerTournament != null
        ? runningCareerTournament!.calendarItem.name
        : nextItem?.name ?? 'Saison abgeschlossen';
    final focusSubtitle = runningCareerTournament != null
        ? 'Laufendes Event'
        : eventSnapshot.metaLine;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              career.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Saison ${career.currentSeason.seasonNumber}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoPill(
                  label: career.isStarted ? 'Karriere laeuft' : 'Noch nicht gestartet',
                ),
                _InfoPill(label: '$remainingCount offen'),
                _InfoPill(
                  label: career.participantMode == CareerParticipantMode.withHuman
                      ? 'Mit mir'
                      : 'Nur Computer',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    runningCareerTournament != null
                        ? 'Weiter mit'
                        : 'Naechstes Event',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    focusTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(focusSubtitle),
                  if (eventSnapshot.detailPills.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: eventSnapshot.detailPills
                          .map((entry) => _InfoPill(label: entry))
                          .toList(),
                    ),
                  ],
                  if (simulationStatus != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      simulationStatus!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF27415A),
                          ),
                    ),
                  ],
                  if ((isSimulatingTournament &&
                          (detailedSimulationStatus?.isNotEmpty ?? false)) ||
                      (simulationProgress != null)) ...<Widget>[
                    const SizedBox(height: 12),
                    _SimulationProgressCard(
                      label: detailedSimulationStatus,
                      progress: simulationProgress,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _ProgressBar(
              totalCount: totalCount,
              completedCount: completedCount,
            ),
            const SizedBox(height: 8),
            Text(progressLabel),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DashboardStatTile(
                    title: 'Turniere',
                    value: '$totalCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DashboardStatTile(
                    title: 'Abgeschlossen',
                    value: '$completedCount',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DashboardStatTile(
                    title: 'Offen',
                    value: '$remainingCount',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (runningCareerTournament != null)
                  FilledButton(
                    onPressed: onOpenRunningTournament,
                    child: const Text('Laufendes Event oeffnen'),
                  )
                else if (!career.isStarted)
                  FilledButton.icon(
                    onPressed: onStartCareer,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Karriere starten'),
                  )
                else
                  FilledButton(
                    onPressed: onPlayNextTournament,
                    child: const Text('Weiter spielen'),
                  ),
                OutlinedButton.icon(
                  onPressed: runningCareerTournament != null
                      ? null
                      : onSimulateNextTournament,
                  icon: const Icon(Icons.fast_forward),
                  label: const Text('Schnell simulieren'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSeasonCalendar,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Kalender'),
                ),
                if (canFinishSeason)
                  OutlinedButton.icon(
                    onPressed: onFinishSeason,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('Saison abschliessen'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

String _calendarItemMeta(CareerCalendarItem item) {
  final seriesLabel = item.isLeagueSeriesItem && item.seriesIndex != null
      ? item.seriesStage == CareerLeagueSeriesStage.playoffRound
          ? 'Playoff ${item.seriesIndex}/${item.seriesLength ?? item.seriesIndex}'
          : 'Spieltag ${item.seriesIndex}/${item.seriesLength ?? item.seriesIndex}'
      : null;
  final parts = <String>[
    'Tier ${item.tier}',
    if (seriesLabel != null) seriesLabel,
    '${item.fieldSize} Spieler',
    _matchSummary(item),
  ];
  return parts.join(' | ');
}

List<_AverageLeader> _bestAverageLeaders(CareerDefinition career) {
  final names = <String, String>{};
  final stats = <String, CareerX01PlayerStats>{};

  final human = career.playerProfileId == null
      ? PlayerRepository.instance.activePlayer
      : PlayerRepository.instance.playerById(career.playerProfileId!);
  if (human != null) {
    names[human.id] = human.name;
  }
  for (final player in career.databasePlayers) {
    names[player.databasePlayerId] = player.name;
  }
  for (final tournament in career.completedTournaments) {
    names[tournament.winnerId] = tournament.winnerName;
    if (tournament.runnerUpId != null && tournament.runnerUpName != null) {
      names[tournament.runnerUpId!] = tournament.runnerUpName!;
    }
    tournament.playerX01Stats.forEach((playerId, value) {
      stats[playerId] = (stats[playerId] ?? const CareerX01PlayerStats()).add(value);
    });
  }

  return stats.entries
      .where((entry) => entry.value.dartsThrown > 0)
      .map(
        (entry) => _AverageLeader(
          playerId: entry.key,
          playerName: names[entry.key] ?? entry.key,
          average: entry.value.average,
        ),
      )
      .toList()
    ..sort((left, right) {
        final averageCompare = right.average.compareTo(left.average);
        if (averageCompare != 0) {
          return averageCompare;
        }
        return left.playerName.compareTo(right.playerName);
      });
}

String _qualificationStatusLabel(
  CareerDefinition career,
  CareerCalendarItem item,
  String? playerId,
  CareerRepository repository,
) {
  if (playerId == null) {
    return 'Kein eigener Spieler aktiv';
  }

  final myPlayer = career.databasePlayers.where((entry) => entry.databasePlayerId == playerId);
  final myTags = myPlayer.isEmpty ? const <String>[] : myPlayer.first.activeTagNames;
  final rankings = <String, int>{};
  for (final ranking in career.rankings) {
    final standings = repository.standingsForRanking(ranking.id);
    for (final standing in standings) {
      if (standing.id == playerId) {
        rankings[ranking.id] = standing.rank;
        break;
      }
    }
  }

  if (item.seedingRankingId != null &&
      item.seedCount > 0 &&
      (rankings[item.seedingRankingId!] ?? 1 << 20) <= item.seedCount) {
    return 'Gesetzt';
  }

  for (final rule in item.effectiveSlotRules) {
    final matchesTags = rule.requiredCareerTags.every(myTags.contains) &&
        rule.excludedCareerTags.every((entry) => !myTags.contains(entry));
    if (!matchesTags) {
      continue;
    }
    if (rule.sourceType == CareerTournamentSlotSourceType.careerTag) {
      return rule.entryRound > 1
          ? 'Qualifiziert ab Runde ${rule.entryRound}'
          : 'Qualifiziert';
    }
    final rank = rule.rankingId == null ? null : rankings[rule.rankingId!];
    if (rank == null) {
      continue;
    }
    final inRange = rank >= rule.fromRank && rank <= rule.toRank;
    final relativeRank = rank - rule.fromRank + 1;
    if (inRange && relativeRank <= rule.slotCount) {
      return rule.entryRound > 1
          ? 'Qualifiziert ab Runde ${rule.entryRound}'
          : 'Qualifiziert';
    }
  }

  for (final rule in item.effectiveFillRules) {
    final matchesTags = rule.requiredCareerTags.every(myTags.contains) &&
        rule.excludedCareerTags.every((entry) => !myTags.contains(entry));
    if (!matchesTags) {
      continue;
    }
    if (rule.sourceType == CareerTournamentFillSourceType.average) {
      return 'Im Auffuellpool';
    }
    final rank = rule.rankingId == null ? null : rankings[rule.rankingId!];
    if (rank != null) {
      return 'Im Auffuellpool';
    }
  }

  return 'Nicht qualifiziert';
}

class _CareerRankingsScreen extends StatelessWidget {
  const _CareerRankingsScreen();

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final career = repository.activeCareer;
        if (career == null) {
          return const Scaffold(
            body: Center(child: Text('Keine aktive Karriere geladen.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Komplette Ranglisten'),
          ),
          body: SafeArea(
            child: career.rankings.isEmpty
                ? const Center(
                    child: Text('Noch keine Ranglisten angelegt.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: career.rankings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final ranking = career.rankings[index];
                      return Card(
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          title: Text(
                            ranking.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          subtitle: Text(
                            'Gueltig ueber ${ranking.validSeasons} Saison(en)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF5D7285),
                                ),
                          ),
                          children: <Widget>[
                            _SimpleStandingsTable(
                              leaders: repository.standingsForRanking(ranking.id),
                              onPlayerTap: (playerId) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CareerPlayerDetailScreen(
                                      playerId: playerId,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _CareerCompletedSeasonsScreen extends StatelessWidget {
  const _CareerCompletedSeasonsScreen();

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final career = repository.activeCareer;
        if (career == null) {
          return const Scaffold(
            body: Center(child: Text('Keine aktive Karriere geladen.')),
          );
        }

        final seasons = career.completedSeasons.reversed.toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Vergangene Saisons'),
          ),
          body: SafeArea(
            child: seasons.isEmpty
                ? const Center(
                    child: Text('Noch keine abgeschlossene Saison.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: seasons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final season = seasons[index];
                      final snapshot = _CompletedSeasonSnapshot.fromCareer(
                        career,
                        seasonNumber: season.seasonNumber,
                      );
                      return _SectionCard(
                        title: 'Saison ${season.seasonNumber}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (snapshot != null) ...<Widget>[
                              _SeasonSummaryLine(
                                label: 'Champion',
                                value: snapshot.championName,
                              ),
                              const SizedBox(height: 8),
                              _SeasonSummaryLine(
                                label: 'Wichtigste Veraenderung',
                                value: snapshot.keyChange,
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              '${season.calendar.length} Turniere im Kalender',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF5D7285),
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ...season.calendar.asMap().entries.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      entry.key == season.calendar.length - 1 ? 0 : 8,
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(entry.value.name),
                                  subtitle: Text(
                                    '${entry.value.fieldSize} Spieler | Preisgeld ${entry.value.prizePool}',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _CareerStatisticsScreen extends StatelessWidget {
  const _CareerStatisticsScreen();

  @override
  Widget build(BuildContext context) {
    final repository = CareerRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final career = repository.activeCareer;
        final summary = repository.statisticsSummary();
        if (career == null || summary == null) {
          return const Scaffold(
            body: Center(child: Text('Noch keine Statistik verfuegbar.')),
          );
        }

        final bestAverageLeaders = _bestAverageLeaders(career);
        final topAverageRows = bestAverageLeaders.take(12).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Karriere-Statistiken'),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: <Widget>[
                _SectionCard(
                  title: 'Meiste Titel',
                  child: _StatsTable(
                    title: 'Karriereweit',
                    leaders: summary.overallTitles,
                    valueLabel: 'Titel',
                    onPlayerTap: (playerId) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CareerPlayerDetailScreen(playerId: playerId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Meistes Preisgeld',
                  child: _StatsTable(
                    title: 'Karriereweit',
                    leaders: summary.overallMoney,
                    valueLabel: 'Geld',
                    onPlayerTap: (playerId) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CareerPlayerDetailScreen(playerId: playerId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Bester Average',
                  child: topAverageRows.isEmpty
                      ? const Text('Noch keine Average-Daten vorhanden.')
                      : Column(
                          children: topAverageRows
                              .map(
                                (entry) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: entry == topAverageRows.last
                                        ? 0
                                        : 8,
                                  ),
                                  child: _AverageLeaderRow(entry: entry),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CompletedSeasonSnapshot {
  const _CompletedSeasonSnapshot({
    required this.seasonNumber,
    required this.championName,
    required this.keyChange,
  });

  final int seasonNumber;
  final String championName;
  final String keyChange;

  static _CompletedSeasonSnapshot? fromCareer(
    CareerDefinition career, {
    int? seasonNumber,
  }) {
    if (career.completedSeasons.isEmpty) {
      return null;
    }
    final targetSeasonNumber =
        seasonNumber ?? career.completedSeasons.last.seasonNumber;
    final tournaments = career.completedTournaments
        .where((entry) => entry.seasonNumber == targetSeasonNumber)
        .toList();
    if (tournaments.isEmpty) {
      return _CompletedSeasonSnapshot(
        seasonNumber: targetSeasonNumber,
        championName: 'Noch offen',
        keyChange: 'Keine abgeschlossenen Turniere gespeichert.',
      );
    }

    final moneyByPlayer = <String, int>{};
    final titleByPlayer = <String, int>{};
    final nameByPlayer = <String, String>{};

    for (final tournament in tournaments) {
      nameByPlayer[tournament.winnerId] = tournament.winnerName;
      titleByPlayer[tournament.winnerId] =
          (titleByPlayer[tournament.winnerId] ?? 0) + 1;
      tournament.playerPayouts.forEach((playerId, payout) {
        moneyByPlayer[playerId] = (moneyByPlayer[playerId] ?? 0) + payout;
      });
    }

    String championName = tournaments.last.winnerName;
    if (moneyByPlayer.isNotEmpty) {
      final championId = moneyByPlayer.entries
          .reduce((best, entry) => entry.value > best.value ? entry : best)
          .key;
      championName = nameByPlayer[championId] ?? championName;
    }

    String keyChange = '${tournaments.length} Turniere abgeschlossen';
    if (titleByPlayer.isNotEmpty) {
      final titleLeader = titleByPlayer.entries
          .reduce((best, entry) => entry.value > best.value ? entry : best);
      final leaderName = nameByPlayer[titleLeader.key] ?? championName;
      keyChange = '$leaderName holte ${titleLeader.value} Titel';
    } else if (moneyByPlayer.isNotEmpty) {
      final moneyLeader = moneyByPlayer.entries
          .reduce((best, entry) => entry.value > best.value ? entry : best);
      final leaderName = nameByPlayer[moneyLeader.key] ?? championName;
      keyChange = '$leaderName fuehrte beim Preisgeld';
    }

    return _CompletedSeasonSnapshot(
      seasonNumber: targetSeasonNumber,
      championName: championName,
      keyChange: keyChange,
    );
  }
}

class _MyCareerStatusCard extends StatelessWidget {
  const _MyCareerStatusCard({
    required this.status,
  });

  final _MyCareerStatusData status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Mein Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              status.playerName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 150,
                  child: _StatsHighlightCard(
                    label: 'Karriere-Geld',
                    title: status.moneyLabel,
                    value: status.averageLabel,
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: _StatsHighlightCard(
                    label: 'Naechste Chance',
                    title: status.nextChanceLabel,
                    value: status.comparisonLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (status.rankingPositions.isNotEmpty) ...<Widget>[
              Text(
                'Ranglisten',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF5D7285),
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: status.rankingPositions
                    .map(
                      (entry) => _InfoPill(
                        label: '${entry.rankingName}: #${entry.rank}',
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            _SeasonSummaryLine(
              label: 'Form',
              value: status.formLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _AverageLeader {
  const _AverageLeader({
    required this.playerId,
    required this.playerName,
    required this.average,
  });

  final String playerId;
  final String playerName;
  final double average;

  String get averageLabel => average.toStringAsFixed(1);
}

class _AverageLeaderRow extends StatelessWidget {
  const _AverageLeaderRow({
    required this.entry,
  });

  final _AverageLeader entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              entry.playerName,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Text(
            entry.averageLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _MyCareerStatusData {
  const _MyCareerStatusData({
    required this.playerId,
    required this.playerName,
    required this.moneyLabel,
    required this.averageLabel,
    required this.formLabel,
    required this.nextChanceLabel,
    required this.comparisonLabel,
    required this.rankingPositions,
  });

  final String playerId;
  final String playerName;
  final String moneyLabel;
  final String averageLabel;
  final String formLabel;
  final String nextChanceLabel;
  final String comparisonLabel;
  final List<_RankingPosition> rankingPositions;

  static _MyCareerStatusData? fromCareer(
    CareerDefinition career, {
    required CareerRepository repository,
    required CareerCalendarItem? nextItem,
  }) {
    if (career.participantMode != CareerParticipantMode.withHuman) {
      return null;
    }
    final player = career.playerProfileId == null
        ? PlayerRepository.instance.activePlayer
        : PlayerRepository.instance.playerById(career.playerProfileId!);
    if (player == null) {
      return null;
    }
    final history = repository.playerHistory(player.id);
    final rankingPositions = <_RankingPosition>[];
    for (final ranking in career.rankings.take(3)) {
      final standings = repository.standingsForRanking(ranking.id);
      for (final standing in standings) {
        if (standing.id == player.id) {
          rankingPositions.add(
            _RankingPosition(
              rankingName: ranking.name,
              rank: standing.rank,
            ),
          );
          break;
        }
      }
    }

    final recentEntries = history?.entries.take(4).toList() ?? const [];
    final formLabel = recentEntries.isEmpty
        ? 'Noch keine Turniere gespielt'
        : recentEntries.map((entry) => entry.resultLabel).join(' • ');
    final nextChanceLabel = nextItem == null
        ? 'Keine offenen Events mehr'
        : _qualificationStatusLabel(career, nextItem, player.id, repository);

    final comparisonLabel = rankingPositions.isEmpty
        ? 'Noch ohne Ranking'
        : rankingPositions
            .take(2)
            .map((entry) => '${entry.rankingName} #${entry.rank}')
            .join(' • ');

    return _MyCareerStatusData(
      playerId: player.id,
      playerName: player.name,
      moneyLabel: history == null ? '0' : '${history.totalMoney}',
      averageLabel: history == null
          ? '0.0 Avg'
          : '${history.x01Stats.average.toStringAsFixed(1)} Avg',
      formLabel: formLabel,
      nextChanceLabel: nextChanceLabel,
      comparisonLabel: comparisonLabel,
      rankingPositions: rankingPositions,
    );
  }
}

class _RankingPosition {
  const _RankingPosition({
    required this.rankingName,
    required this.rank,
  });

  final String rankingName;
  final int rank;
}

class _CareerEventSnapshot {
  const _CareerEventSnapshot({
    required this.metaLine,
    required this.detailPills,
  });

  final String metaLine;
  final List<String> detailPills;

  static _CareerEventSnapshot fromCareer(
    CareerDefinition career, {
    required CareerCalendarItem? nextItem,
    required CareerRepository repository,
    required _MyCareerStatusData? myStatus,
  }) {
    if (nextItem == null) {
      return const _CareerEventSnapshot(
        metaLine: 'Aktuell gibt es kein offenes Event mehr.',
        detailPills: <String>[],
      );
    }

    final rankingNames = career.rankings
        .where((entry) => nextItem.countsForRankingIds.contains(entry.id))
        .map((entry) => entry.name)
        .toList();
    final detailPills = <String>[
      _calendarItemMeta(nextItem),
      '${nextItem.fieldSize} Spieler',
      'Preisgeld ${nextItem.prizePool}',
      _qualificationStatusLabel(
        career,
        nextItem,
        myStatus?.playerId,
        repository,
      ),
      if (rankingNames.isNotEmpty) rankingNames.join(', '),
    ];

    return _CareerEventSnapshot(
      metaLine: 'Format, Quali-Status und Wertung auf einen Blick.',
      detailPills: detailPills,
    );
  }
}

class _CompletedSeasonPreview extends StatelessWidget {
  const _CompletedSeasonPreview({
    required this.snapshot,
    required this.onOpenAll,
  });

  final _CompletedSeasonSnapshot? snapshot;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    if (data == null) {
      return const Text('Noch keine abgeschlossene Saison.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Letzte abgeschlossene Saison',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Saison ${data.seasonNumber}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _SeasonSummaryLine(
                label: 'Champion',
                value: data.championName,
              ),
              const SizedBox(height: 8),
              _SeasonSummaryLine(
                label: 'Wichtigste Veraenderung',
                value: data.keyChange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenAll,
          icon: const Icon(Icons.history_rounded),
          label: const Text('Alle Saisons ansehen'),
        ),
      ],
    );
  }
}

class _SeasonSummaryLine extends StatelessWidget {
  const _SeasonSummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFF5D7285),
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  const _DashboardStatTile({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ScreenLevelLabel extends StatelessWidget {
  const _ScreenLevelLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF5D7285),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.totalCount,
    required this.completedCount,
  });

  final int totalCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Fortschritt $completedCount/$totalCount'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: progress, minHeight: 10),
        ),
      ],
    );
  }
}

class _SimulationProgressCard extends StatelessWidget {
  const _SimulationProgressCard({
    this.title,
    required this.label,
    required this.progress,
  });

  final String? title;
  final String? label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final details = _SimulationVisualState.from(
      title: title,
      label: label,
      progress: progress,
    );
    final hasDeterminateProgress = progress != null;
    final percentLabel = hasDeterminateProgress
        ? '${((progress! * 100).clamp(0, 100)).round()} %'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(details.icon, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      details.phaseTitle,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (percentLabel != null)
                Text(
                  percentLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
            ],
          ),
          if (details.headline != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              details.headline!,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          Row(
            children: <Widget>[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  details.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (details.helper != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              details.helper!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimulationProgressOverlay extends StatelessWidget {
  const _SimulationProgressOverlay({
    required this.title,
    required this.label,
    required this.progress,
    required this.onHide,
  });

  final String title;
  final String? label;
  final double? progress;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: ColoredBox(
          color: Colors.black.withOpacity(0.18),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'Simulation laeuft',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF5D7285),
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: onHide,
                              tooltip: 'Anzeige ausblenden',
                              icon: const Icon(Icons.visibility_off_outlined),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _SimulationProgressCard(
                          title: title,
                          label: label,
                          progress: progress,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Die Berechnung laeuft im Hintergrund weiter. Je nach erstem Turnier und Warmup kann dieser Schritt etwas dauern.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF5D7285),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationProgressHandle extends StatelessWidget {
  const _SimulationProgressHandle({
    required this.label,
    required this.progress,
    required this.onOpen,
  });

  final String? label;
  final double? progress;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final percentLabel = progress == null
        ? null
        : '${((progress! * 100).clamp(0, 100)).round()} %';
    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.sync_rounded, size: 18),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      label == null || label!.trim().isEmpty
                          ? 'Simulation laeuft'
                          : label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  if (percentLabel != null) ...<Widget>[
                    const SizedBox(width: 10),
                    Text(
                      percentLabel,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationVisualState {
  const _SimulationVisualState({
    required this.phaseTitle,
    required this.icon,
    required this.body,
    this.headline,
    this.helper,
  });

  final String phaseTitle;
  final IconData icon;
  final String body;
  final String? headline;
  final String? helper;

  static _SimulationVisualState from({
    required String? title,
    required String? label,
    required double? progress,
  }) {
    final normalizedTitle = _cleanSimulationText(title);
    final normalizedLabel = _cleanSimulationText(label);
    final source = normalizedLabel.isNotEmpty ? normalizedLabel : normalizedTitle;

    if (source.contains('vorbereitet') || source.contains('vorwaerm')) {
      return _SimulationVisualState(
        phaseTitle: 'Vorbereitung',
        icon: Icons.auto_awesome_rounded,
        headline: normalizedTitle.isEmpty ? null : normalizedTitle,
        body: normalizedLabel.isEmpty ? 'Simulationsdaten werden vorbereitet.' : normalizedLabel,
        helper: 'Lookup-Tabellen und der Simulationspfad werden fuer den ersten Lauf warm gemacht.',
      );
    }
    if (source.contains('baue ') ||
        source.contains('aufbau') ||
        source.contains('turnier wird vorbereitet')) {
      return _SimulationVisualState(
        phaseTitle: 'Turnieraufbau',
        icon: Icons.construction_rounded,
        headline: normalizedTitle.isEmpty ? null : normalizedTitle,
        body: normalizedLabel.isEmpty ? 'Teilnehmer, Feld und Struktur werden aufgebaut.' : normalizedLabel,
        helper: 'Hier werden Qualifikation, Feldgroesse, Setzliste und Bracket vorbereitet.',
      );
    }
    if (source.contains('simuliert') || source.contains('simulation')) {
      return _SimulationVisualState(
        phaseTitle: 'Matchsimulation',
        icon: Icons.sports_score_rounded,
        headline: normalizedTitle.isEmpty ? null : normalizedTitle,
        body: normalizedLabel.isEmpty ? 'Die Matches werden gerade simuliert.' : normalizedLabel,
        helper: progress == null
            ? 'Der Fortschritt wird fortlaufend aktualisiert, sobald neue Matchbloecke abgeschlossen sind.'
            : 'Die App verarbeitet Matchbloecke und aktualisiert danach den Fortschritt.',
      );
    }
    if (source.contains('uebernommen') ||
        source.contains('commit') ||
        source.contains('abgeschlossen')) {
      return _SimulationVisualState(
        phaseTitle: 'Uebernahme',
        icon: Icons.save_rounded,
        headline: normalizedTitle.isEmpty ? null : normalizedTitle,
        body: normalizedLabel.isEmpty ? 'Das Ergebnis wird in die Karriere uebernommen.' : normalizedLabel,
        helper: 'Stats, Historie und Saisonfortschritt werden jetzt gespeichert.',
      );
    }
    return _SimulationVisualState(
      phaseTitle: 'Simulation',
      icon: Icons.sync_rounded,
      headline: normalizedTitle.isEmpty ? null : normalizedTitle,
      body: normalizedLabel.isEmpty ? 'Die Berechnung laeuft...' : normalizedLabel,
      helper: 'Die App arbeitet weiter. Der Fortschritt springt nach abgeschlossenen Schritten sichtbar weiter.',
    );
  }
}

String _cleanSimulationText(String? value) {
  if (value == null) {
    return '';
  }
  return value.trim();
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

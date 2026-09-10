import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/debug/app_debug.dart';
import '../data/debug/simulation_debug_state.dart';

class AppDebugOverlay extends StatefulWidget {
  const AppDebugOverlay({super.key});

  @override
  State<AppDebugOverlay> createState() => _AppDebugOverlayState();
}

class _AppDebugOverlayState extends State<AppDebugOverlay> {
  bool _expanded = false;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((_) {
      if (_expanded && mounted) {
        setState(() {});
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.topCenter,
            child: AnimatedBuilder(
              animation: Listenable.merge(
                <Listenable>[
                  AppDebug.instance,
                  SimulationDebugState.instance,
                ],
              ),
              builder: (context, _) {
                final entries =
                    AppDebug.instance.entries.reversed.take(60).toList();
                final activeActions = AppDebug.instance.activeActions;
                final sim = SimulationDebugState.instance.snapshot;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          setState(() {
                            _expanded = !_expanded;
                          });
                        },
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E2630),
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.bug_report_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                              if (activeActions.isNotEmpty)
                                Positioned(
                                  top: 5,
                                  right: 5,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE08E00),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_expanded) ...<Widget>[
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 680,
                          maxHeight: 360,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2630),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const <BoxShadow>[
                                BoxShadow(
                                  color: Color(0x44000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: <Widget>[
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 150,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: <Widget>[
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            14,
                                            8,
                                            10,
                                          ),
                                          child: Row(
                                            children: <Widget>[
                                              const Icon(
                                                Icons.bug_report_outlined,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Debug Konsole (${entries.length})',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: AppDebug.instance.clear,
                                                child: const Text('Leeren'),
                                              ),
                                              IconButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _expanded = false;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.expand_less,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (activeActions.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              10,
                                            ),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: activeActions.map((action) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFE08E00),
                                                      borderRadius:
                                                          BorderRadius.circular(999),
                                                    ),
                                                    child: Text(
                                                      '${action.source}: ${action.label} (${action.elapsedMilliseconds} ms)',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        if (sim.scope != 'idle')
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              16,
                                              0,
                                              16,
                                              12,
                                            ),
                                            child:
                                                _SimulationDebugCard(snapshot: sim),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  color: Color(0x334B5563),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: entries.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = entries[index];
                                      final levelColor = switch (entry.level) {
                                        AppDebugLevel.info =>
                                          const Color(0xFF9FB3C8),
                                        AppDebugLevel.warning =>
                                          const Color(0xFFFFC857),
                                        AppDebugLevel.error =>
                                          const Color(0xFFFF6B6B),
                                      };
                                      final timeText = entry.timestamp
                                          .toIso8601String()
                                          .substring(11, 19);
                                      return Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF273241),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0x334B5563),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Row(
                                              children: <Widget>[
                                                Text(
                                                  '#${entry.sequence}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF9FB3C8),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  '[$timeText]',
                                                  style: const TextStyle(
                                                    color: Color(0xFF9FB3C8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: levelColor.withValues(
                                                      alpha: 0.18,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      999,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    entry.source,
                                                    style: TextStyle(
                                                      color: levelColor,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              entry.message,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulationDebugCard extends StatelessWidget {
  const _SimulationDebugCard({
    required this.snapshot,
  });

  final SimulationDebugSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final phaseAge = snapshot.phaseStartedAt == null
        ? null
        : DateTime.now().difference(snapshot.phaseStartedAt!).inMilliseconds;
    final updateAge = snapshot.updatedAt == null
        ? null
        : DateTime.now().difference(snapshot.updatedAt!).inMilliseconds;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF273241),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0x334B5563),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Live Simulation',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _debugChip('Scope', snapshot.scope),
              _debugChip('Phase', snapshot.phase),
              if (snapshot.seasonCompleted != null && snapshot.seasonTotal != null)
                _debugChip(
                  'Saison',
                  '${snapshot.seasonCompleted}/${snapshot.seasonTotal}',
                ),
              if (snapshot.matchCompleted != null && snapshot.matchTotal != null)
                _debugChip(
                  'Matches',
                  '${snapshot.matchCompleted}/${snapshot.matchTotal}',
                ),
              if (snapshot.progress != null)
                _debugChip(
                  'Fortschritt',
                  '${(snapshot.progress! * 100).toStringAsFixed(1)}%',
                ),
              if (phaseAge != null)
                _debugChip('Phase seit', '$phaseAge ms'),
              if (updateAge != null)
                _debugChip('Letztes Update', '$updateAge ms'),
              if (snapshot.lastDurationMs != null)
                _debugChip('Letzte Dauer', '${snapshot.lastDurationMs} ms'),
            ],
          ),
          if (snapshot.careerName != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Karriere: $snapshot.careerName',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (snapshot.tournamentName != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              'Turnier: $snapshot.tournamentName',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          if (snapshot.statusLabel != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              snapshot.statusLabel!,
              style: const TextStyle(color: Colors.white),
            ),
          ],
          if (snapshot.lastEvent != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Letztes Event: ${snapshot.lastEvent}',
              style: const TextStyle(
                color: Color(0xFF9FB3C8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _debugChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2630),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

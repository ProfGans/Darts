import 'package:flutter/material.dart';

import '../data/debug/app_debug.dart';

class AppDebugOverlay extends StatefulWidget {
  const AppDebugOverlay({super.key});

  @override
  State<AppDebugOverlay> createState() => _AppDebugOverlayState();
}

class _AppDebugOverlayState extends State<AppDebugOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedBuilder(
              animation: AppDebug.instance,
              builder: (context, _) {
                final entries =
                    AppDebug.instance.entries.reversed.take(60).toList();
                final activeActions = AppDebug.instance.activeActions;

                if (!_expanded) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        setState(() {
                          _expanded = true;
                        });
                      },
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2630),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.bug_report_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Debug ${entries.length} Eintraege',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (activeActions.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE08E00),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${activeActions.length} aktiv',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.bug_report_outlined,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Debug Konsole',
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
                                    Icons.expand_more,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (activeActions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: activeActions.map((action) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE08E00),
                                        borderRadius: BorderRadius.circular(999),
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
                          const Divider(height: 1, color: Color(0x334B5563)),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final levelColor = switch (entry.level) {
                                  AppDebugLevel.info => const Color(0xFF9FB3C8),
                                  AppDebugLevel.warning => const Color(0xFFFFC857),
                                  AppDebugLevel.error => const Color(0xFFFF6B6B),
                                };
                                final timeText = entry.timestamp
                                    .toIso8601String()
                                    .substring(11, 19);
                                return Container(
                                  padding: const EdgeInsets.all(10),
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: levelColor.withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              entry.source,
                                              style: TextStyle(
                                                color: levelColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

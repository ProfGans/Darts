import 'package:flutter/material.dart';

import '../data/debug/app_debug.dart';

class AppDebugOverlay extends StatelessWidget {
  const AppDebugOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppDebug.instance,
      builder: (context, _) {
        final debug = AppDebug.instance;
        final height = debug.expanded ? 260.0 : 44.0;
        return Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xEE11181F),
                border: Border.all(color: const Color(0xFF2F4254)),
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 44,
                    child: InkWell(
                      onTap: debug.toggleExpanded,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              debug.expanded
                                  ? Icons.expand_more
                                  : Icons.bug_report_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Debug',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${debug.entries.length} Eintraege',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: const Color(0xFFB6C4D1)),
                            ),
                            const Spacer(),
                            if (debug.expanded)
                              TextButton(
                                onPressed: debug.clear,
                                child: const Text('Leeren'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (debug.expanded)
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: debug.entries.length,
                        itemBuilder: (context, index) {
                          final entry =
                              debug.entries[debug.entries.length - 1 - index];
                          final color = entry.level == AppDebugLevel.error
                              ? const Color(0xFFFF8A80)
                              : const Color(0xFFD7E3EE);
                          final level = entry.level == AppDebugLevel.error
                              ? 'ERROR'
                              : 'INFO';
                          final hh = entry.timestamp.hour
                              .toString()
                              .padLeft(2, '0');
                          final mm = entry.timestamp.minute
                              .toString()
                              .padLeft(2, '0');
                          final ss = entry.timestamp.second
                              .toString()
                              .padLeft(2, '0');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '[$hh:$mm:$ss] [$level] [${entry.source}] ${entry.message}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: color,
                                    fontFamily: 'Consolas',
                                  ),
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
    );
  }
}

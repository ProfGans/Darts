import 'package:flutter/material.dart';

import 'career_editor_section_card.dart';

enum CareerEditorIssueSeverity {
  error,
  warning,
  info,
}

class CareerEditorIssue {
  const CareerEditorIssue({
    required this.severity,
    required this.title,
    required this.message,
  });

  final CareerEditorIssueSeverity severity;
  final String title;
  final String message;
}

class CareerTournamentPreview {
  const CareerTournamentPreview({
    required this.name,
    required this.fieldSize,
    required this.estimatedEligiblePlayers,
    required this.fixedSlotCount,
    required this.fillRuleCount,
    required this.statusLabel,
    required this.statusColor,
    required this.humanStatus,
    required this.seedTarget,
    required this.seededCount,
    required this.seededPlayers,
  });

  final String name;
  final int fieldSize;
  final int estimatedEligiblePlayers;
  final int fixedSlotCount;
  final int fillRuleCount;
  final String statusLabel;
  final Color statusColor;
  final String humanStatus;
  final int seedTarget;
  final int seededCount;
  final List<String> seededPlayers;
}

class CareerValidationPanel extends StatelessWidget {
  const CareerValidationPanel({
    super.key,
    required this.issues,
    required this.previews,
  });

  final List<CareerEditorIssue> issues;
  final List<CareerTournamentPreview> previews;

  @override
  Widget build(BuildContext context) {
    final errorCount = issues
        .where((issue) => issue.severity == CareerEditorIssueSeverity.error)
        .length;
    final warningCount = issues
        .where((issue) => issue.severity == CareerEditorIssueSeverity.warning)
        .length;
    final infoCount = issues
        .where((issue) => issue.severity == CareerEditorIssueSeverity.info)
        .length;

    return CareerEditorSectionCard(
      title: 'Validierung & Vorschau',
      subtitle: issues.isEmpty
          ? 'Keine offensichtlichen Probleme'
          : '$errorCount Fehler | $warningCount Warnungen | $infoCount Hinweise',
      initiallyExpanded: true,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _ValidationChip(
              label: '$errorCount Fehler',
              color: Colors.red.shade100,
              icon: Icons.error_outline,
            ),
            _ValidationChip(
              label: '$warningCount Warnungen',
              color: Colors.orange.shade100,
              icon: Icons.warning_amber_rounded,
            ),
            _ValidationChip(
              label: '$infoCount Hinweise',
              color: Colors.blue.shade100,
              icon: Icons.info_outline,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Editor-Checks',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (issues.isEmpty)
          const Text(
            'Die Karriere sieht im aktuellen Stand konsistent aus.',
          )
        else
          ...issues.map(
            (issue) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (issue.severity) {
                  CareerEditorIssueSeverity.error => Icons.error_outline,
                  CareerEditorIssueSeverity.warning =>
                    Icons.warning_amber_rounded,
                  CareerEditorIssueSeverity.info => Icons.info_outline,
                },
                color: switch (issue.severity) {
                  CareerEditorIssueSeverity.error => Colors.red.shade700,
                  CareerEditorIssueSeverity.warning =>
                    Colors.orange.shade700,
                  CareerEditorIssueSeverity.info => Colors.blue.shade700,
                },
              ),
              title: Text(issue.title),
              subtitle: Text(issue.message),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Turnier-Vorschau',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (previews.isEmpty)
          const Text('Noch keine Turniere im Saisonkalender.')
        else
          ...previews.map(
            (preview) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            preview.name,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: preview.statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(preview.statusLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Schaetzung: ${preview.estimatedEligiblePlayers}/${preview.fieldSize} moegliche Spieler | '
                      '${preview.fixedSlotCount} feste Slots | ${preview.fillRuleCount} Fill-Regeln',
                    ),
                    if (preview.seedTarget > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        preview.seededCount >= preview.seedTarget
                            ? 'Setzliste: ${preview.seededCount}/${preview.seedTarget} gesetzt'
                            : 'Setzliste: nur ${preview.seededCount}/${preview.seedTarget} gesetzt',
                      ),
                      if (preview.seededPlayers.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: preview.seededPlayers
                              .map(
                                (entry) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F6FA),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(entry),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                    const SizedBox(height: 4),
                    Text(preview.humanStatus),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ValidationChip extends StatelessWidget {
  const _ValidationChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

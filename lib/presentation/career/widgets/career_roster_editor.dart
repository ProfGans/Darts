import 'package:flutter/material.dart';

import 'career_editor_section_card.dart';

class CareerRosterEditor extends StatelessWidget {
  const CareerRosterEditor({
    super.key,
    required this.rosterCount,
    required this.summarySection,
    required this.trainingSection,
    required this.addPlayersSection,
    required this.rosterSection,
  });

  final int rosterCount;
  final Widget summarySection;
  final Widget trainingSection;
  final Widget addPlayersSection;
  final Widget rosterSection;

  @override
  Widget build(BuildContext context) {
    return CareerEditorSectionCard(
      title: 'Karriere-Spieler aus Datenbank',
      subtitle: '$rosterCount im Karriere-Kader',
      children: <Widget>[
        summarySection,
        const SizedBox(height: 12),
        trainingSection,
        const SizedBox(height: 16),
        addPlayersSection,
        const SizedBox(height: 16),
        rosterSection,
      ],
    );
  }
}

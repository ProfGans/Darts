import 'package:flutter/material.dart';

import '../../tournament/tournament_basics_form.dart';
import '../../tournament/tournament_form_models.dart';
import 'career_editor_section_card.dart';

class CareerTournamentEditor extends StatelessWidget {
  const CareerTournamentEditor({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.formData,
    required this.onFormChanged,
    required this.prizeSection,
    required this.seriesSection,
    required this.seedingSection,
    required this.slotRuleSection,
    required this.fillRuleSection,
    required this.tagGateSection,
    required this.rankingsSection,
    required this.actionsSection,
  });

  final bool isEditing;
  final TextEditingController nameController;
  final TournamentFormData formData;
  final ValueChanged<TournamentFormData> onFormChanged;
  final Widget prizeSection;
  final Widget seriesSection;
  final Widget seedingSection;
  final Widget slotRuleSection;
  final Widget fillRuleSection;
  final Widget tagGateSection;
  final Widget rankingsSection;
  final Widget actionsSection;

  @override
  Widget build(BuildContext context) {
    return CareerEditorSectionCard(
      title: isEditing ? 'Turnier bearbeiten' : 'Turnier anlegen',
      subtitle: isEditing
          ? 'Aktuelles Turnier wird bearbeitet'
          : 'Neues Karriere-Turnier konfigurieren',
      initiallyExpanded: true,
      children: <Widget>[
        TournamentBasicsForm(
          nameController: nameController,
          formData: formData,
          onChanged: onFormChanged,
        ),
        const SizedBox(height: 12),
        prizeSection,
        const SizedBox(height: 12),
        seriesSection,
        const SizedBox(height: 12),
        seedingSection,
        const SizedBox(height: 16),
        slotRuleSection,
        const SizedBox(height: 16),
        fillRuleSection,
        const SizedBox(height: 16),
        tagGateSection,
        const SizedBox(height: 16),
        rankingsSection,
        const SizedBox(height: 16),
        actionsSection,
      ],
    );
  }
}

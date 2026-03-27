import 'package:flutter/material.dart';

import '../../../domain/career/career_models.dart';
import 'career_editor_section_card.dart';

class CareerRankingsEditor extends StatelessWidget {
  const CareerRankingsEditor({
    super.key,
    required this.rankings,
    required this.rankingNameController,
    required this.rankingValidSeasons,
    required this.rankingResetAtSeasonEnd,
    required this.editingRankingId,
    required this.onValidSeasonsChanged,
    required this.onResetAtSeasonEndChanged,
    required this.onSave,
    required this.onCancelEdit,
    required this.onEditRanking,
    required this.onDeleteRanking,
  });

  final List<CareerRankingDefinition> rankings;
  final TextEditingController rankingNameController;
  final int rankingValidSeasons;
  final bool rankingResetAtSeasonEnd;
  final String? editingRankingId;
  final ValueChanged<int> onValidSeasonsChanged;
  final ValueChanged<bool> onResetAtSeasonEndChanged;
  final VoidCallback onSave;
  final VoidCallback onCancelEdit;
  final ValueChanged<CareerRankingDefinition> onEditRanking;
  final ValueChanged<String> onDeleteRanking;

  @override
  Widget build(BuildContext context) {
    return CareerEditorSectionCard(
      title: 'Ranglisten',
      subtitle: '${rankings.length} angelegt',
      children: <Widget>[
        Text(
          editingRankingId == null ? 'Neue Rangliste' : 'Rangliste bearbeiten',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: rankingNameController,
          decoration: const InputDecoration(labelText: 'Name der Rangliste'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey<int>(rankingValidSeasons),
          initialValue: rankingValidSeasons,
          decoration: const InputDecoration(
            labelText: 'Gueltig ueber Saisons',
          ),
          items: List<DropdownMenuItem<int>>.generate(
            5,
            (index) => DropdownMenuItem<int>(
              value: index + 1,
              child: Text('${index + 1}'),
            ),
          ),
          onChanged: (value) {
            if (value != null) {
              onValidSeasonsChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: rankingResetAtSeasonEnd,
          onChanged: onResetAtSeasonEndChanged,
          title: const Text('Am Saisonende zuruecksetzen'),
          subtitle: Text(
            rankingResetAtSeasonEnd
                ? 'Diese Rangliste startet jede neue Saison wieder bei null.'
                : 'Wenn ausgeschaltet, bleibt die normale Saison-Gaeltigkeit aktiv.',
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onSave,
          icon: const Icon(Icons.add_chart),
          label: Text(
            editingRankingId == null
                ? 'Rangliste hinzufuegen'
                : 'Rangliste speichern',
          ),
        ),
        if (editingRankingId != null) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onCancelEdit,
            child: const Text('Bearbeitung abbrechen'),
          ),
        ],
        const SizedBox(height: 12),
        ...rankings.map(
          (ranking) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(ranking.name),
            subtitle: Text(
              ranking.resetAtSeasonEnd
                  ? 'Setzt sich am Saisonende zurueck'
                  : 'Gueltig ueber ${ranking.validSeasons} Saison(en)',
            ),
            trailing: Wrap(
              spacing: 4,
              children: <Widget>[
                IconButton(
                  onPressed: () => onEditRanking(ranking),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: () => onDeleteRanking(ranking.id),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

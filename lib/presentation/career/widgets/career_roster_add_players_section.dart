import 'package:flutter/material.dart';

import '../../../data/models/computer_player.dart';
import '../../../domain/career/career_models.dart';

class CareerRosterAddPlayersSection extends StatelessWidget {
  const CareerRosterAddPlayersSection({
    super.key,
    required this.career,
    required this.availableTags,
    required this.addablePlayers,
    required this.selectedDatabaseTagFilters,
    required this.selectedDatabasePlayerIds,
    required this.databasePlayerTagsController,
    required this.assignedTagNames,
    required this.tagUsageLabelBuilder,
    required this.onToggleAssignmentCareerTag,
    required this.onClearFilters,
    required this.onToggleDatabaseTagFilter,
    required this.onToggleSelectAll,
    required this.onTogglePlayerSelection,
    required this.onAddSelectedPlayers,
  });

  final CareerDefinition career;
  final List<String> availableTags;
  final List<ComputerPlayer> addablePlayers;
  final Set<String> selectedDatabaseTagFilters;
  final Set<String> selectedDatabasePlayerIds;
  final TextEditingController databasePlayerTagsController;
  final Set<String> assignedTagNames;
  final String Function(String tagName) tagUsageLabelBuilder;
  final ValueChanged<String> onToggleAssignmentCareerTag;
  final VoidCallback onClearFilters;
  final ValueChanged<String> onToggleDatabaseTagFilter;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<String> onTogglePlayerSelection;
  final VoidCallback onAddSelectedPlayers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Spieler hinzufuegen',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (career.careerTagDefinitions.isNotEmpty) ...<Widget>[
          const Text('Karriere-Tags fuer neue Spieler'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: career.careerTagDefinitions.map((definition) {
              return FilterChip(
                label: Text(tagUsageLabelBuilder(definition.name)),
                selected: assignedTagNames.contains(definition.name),
                onSelected: (_) => onToggleAssignmentCareerTag(definition.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (availableTags.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  selectedDatabaseTagFilters.isEmpty
                      ? 'Kein Datenbank-Tag-Filter aktiv'
                      : 'Filter: ${selectedDatabaseTagFilters.join(', ')}',
                ),
              ),
              if (selectedDatabaseTagFilters.isNotEmpty)
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Filter loeschen'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags
                .map(
                  (tag) => FilterChip(
                    label: Text(tag),
                    selected: selectedDatabaseTagFilters.contains(tag),
                    onSelected: (_) => onToggleDatabaseTagFilter(tag),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (addablePlayers.isEmpty)
          Text(
            selectedDatabaseTagFilters.isEmpty
                ? 'Alle Datenbankspieler sind bereits im Karriere-Kader.'
                : 'Kein addierbarer Datenbankspieler passt zum aktiven Tag-Filter.',
          )
        else ...<Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${selectedDatabasePlayerIds.length} Spieler ausgewaehlt',
                ),
              ),
              TextButton(
                onPressed: onToggleSelectAll,
                child: Text(
                  selectedDatabasePlayerIds.length == addablePlayers.length
                      ? 'Auswahl leeren'
                      : 'Alle waehlen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: SingleChildScrollView(
              child: Column(
                children: addablePlayers
                    .map(
                      (player) => CheckboxListTile(
                        value: selectedDatabasePlayerIds.contains(player.id),
                        onChanged: (_) => onTogglePlayerSelection(player.id),
                        title: Text(player.name),
                        subtitle: Text(
                          '${player.theoreticalAverage.toStringAsFixed(1)} Avg'
                          '${player.tags.isEmpty ? '' : ' | ${player.tags.join(', ')}'}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: databasePlayerTagsController,
            decoration: InputDecoration(
              labelText: 'Karriere-Tags',
              helperText: career.careerTagDefinitions.isEmpty
                  ? 'Kommagetrennt, z. B. Premier League, Europa'
                  : 'Kommagetrennt oder ueber die Karriere-Tag-Chips oben auswaehlen',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed:
                selectedDatabasePlayerIds.isEmpty ? null : onAddSelectedPlayers,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Auswahl zur Karriere hinzufuegen'),
          ),
        ],
      ],
    );
  }
}

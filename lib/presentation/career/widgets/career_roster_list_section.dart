import 'package:flutter/material.dart';

import '../../../domain/career/career_models.dart';

class CareerRosterListSection extends StatelessWidget {
  const CareerRosterListSection({
    super.key,
    required this.players,
    required this.selectedPlayerIds,
    required this.careerRosterTagsController,
    required this.tagLabelBuilder,
    required this.onToggleSelectAll,
    required this.onTogglePlayerSelection,
    required this.onApplyTags,
    required this.onRemoveTags,
    required this.onClearTags,
    required this.onRemovePlayers,
    required this.onEditPlayer,
    required this.onDeletePlayer,
    required this.onRemoveSingleTag,
  });

  final List<CareerDatabasePlayer> players;
  final Set<String> selectedPlayerIds;
  final TextEditingController careerRosterTagsController;
  final String Function(CareerPlayerTag tag) tagLabelBuilder;
  final VoidCallback onToggleSelectAll;
  final ValueChanged<String> onTogglePlayerSelection;
  final VoidCallback onApplyTags;
  final VoidCallback onRemoveTags;
  final VoidCallback onClearTags;
  final VoidCallback onRemovePlayers;
  final ValueChanged<CareerDatabasePlayer> onEditPlayer;
  final ValueChanged<String> onDeletePlayer;
  final void Function(CareerDatabasePlayer player, String tagName)
      onRemoveSingleTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Karriere-Kader',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (players.isEmpty)
          const Text(
            'Noch kein eigener Karriere-Kader angelegt. Solange leer, nutzt die Karriere weiter die komplette Computerdatenbank.',
          )
        else ...<Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '${selectedPlayerIds.length} Karriere-Spieler ausgewaehlt',
              ),
              OutlinedButton.icon(
                onPressed: onToggleSelectAll,
                icon: Icon(
                  selectedPlayerIds.length == players.length
                      ? Icons.deselect
                      : Icons.select_all,
                ),
                label: Text(
                  selectedPlayerIds.length == players.length
                      ? 'Auswahl leeren'
                      : 'Alle auswaehlen',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: careerRosterTagsController,
            decoration: const InputDecoration(
              labelText: 'Karriere-Tags fuer Auswahl',
              helperText:
                  'Tags fuer Sammelaktionen: hinzufuegen oder entfernen',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: selectedPlayerIds.isEmpty ? null : onApplyTags,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Tags zu Auswahl hinzufuegen'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPlayerIds.isEmpty ? null : onRemoveTags,
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text('Tags aus Auswahl entfernen'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPlayerIds.isEmpty ? null : onClearTags,
                icon: const Icon(Icons.layers_clear),
                label: const Text('Alle Tags der Auswahl entfernen'),
              ),
              OutlinedButton.icon(
                onPressed: selectedPlayerIds.isEmpty ? null : onRemovePlayers,
                icon: const Icon(Icons.person_remove_alt_1),
                label: const Text('Spieler aus Auswahl entfernen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...players.map(
            (player) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Checkbox(
                          value:
                              selectedPlayerIds.contains(player.databasePlayerId),
                          onChanged: (_) =>
                              onTogglePlayerSelection(player.databasePlayerId),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                player.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('${player.average.toStringAsFixed(1)} Avg'),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onEditPlayer(player),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => onDeletePlayer(player.databasePlayerId),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (player.careerTags.isEmpty)
                      const Text('Keine Karriere-Tags')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: player.careerTags
                            .map(
                              (tag) => InputChip(
                                label: Text(tagLabelBuilder(tag)),
                                onDeleted: () =>
                                    onRemoveSingleTag(player, tag.tagName),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../domain/career/career_models.dart';

class CareerTagDefinitionsList extends StatelessWidget {
  const CareerTagDefinitionsList({
    super.key,
    required this.definitions,
    required this.describeDefinition,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CareerTagDefinition> definitions;
  final String Function(CareerTagDefinition definition) describeDefinition;
  final ValueChanged<CareerTagDefinition> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Bestehende Karriere-Tags',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (definitions.isEmpty)
          const Text('Noch keine Karriere-Tags definiert.')
        else
          ...definitions.map(
            (definition) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(definition.name),
                subtitle: Text(describeDefinition(definition)),
                trailing: Wrap(
                  spacing: 4,
                  children: <Widget>[
                    IconButton(
                      onPressed: () => onEdit(definition),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      onPressed: () => onDelete(definition.id),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

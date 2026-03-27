import 'package:flutter/material.dart';

class CareerTagDefinitionEditor extends StatelessWidget {
  const CareerTagDefinitionEditor({
    super.key,
    required this.isEditing,
    required this.nameController,
    required this.attributesController,
    required this.limitController,
    required this.initialValidityController,
    required this.extensionValidityController,
    required this.addOnExpiryController,
    required this.removeOnInitialController,
    required this.removeOnExtensionController,
    required this.onSave,
    required this.onCancel,
  });

  final bool isEditing;
  final TextEditingController nameController;
  final TextEditingController attributesController;
  final TextEditingController limitController;
  final TextEditingController initialValidityController;
  final TextEditingController extensionValidityController;
  final TextEditingController addOnExpiryController;
  final TextEditingController removeOnInitialController;
  final TextEditingController removeOnExtensionController;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isEditing ? 'Karriere-Tag bearbeiten' : 'Neuen Karriere-Tag anlegen',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Lege Karriere-Tags mit Attributen, Laufzeiten und optionalem Limit an. Diese Regeln gelten nur in dieser Karriere.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Tag-Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: attributesController,
          decoration: const InputDecoration(
            labelText: 'Attribute',
            helperText:
                'Kommagetrennt als key=value, z. B. tour=major, region=europe',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: limitController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Limit',
            helperText: 'Maximale Anzahl Spieler mit diesem Tag.',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: initialValidityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gueltig bei Erstvergabe',
                  helperText: 'In Saisons, leer = dauerhaft',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: extensionValidityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Gueltig bei Verlaengerung',
                  helperText: 'Setzt bei erneuter Vergabe neu',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: addOnExpiryController,
          decoration: const InputDecoration(
            labelText: 'Beim Ablauf hinzufuegen',
            helperText:
                'Kommagetrennte Karriere-Tags, die nach Ablauf dieses Tags gesetzt werden.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: removeOnInitialController,
          decoration: const InputDecoration(
            labelText: 'Bei Erstvergabe entfernen',
            helperText:
                'Kommagetrennte Karriere-Tags, die bei der ersten Vergabe entfernt werden.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: removeOnExtensionController,
          decoration: const InputDecoration(
            labelText: 'Bei Verlaengerung entfernen',
            helperText:
                'Kommagetrennte Karriere-Tags, die bei erneuter Vergabe entfernt werden.',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: onSave,
              icon: const Icon(Icons.label_outline),
              label: Text(
                isEditing ? 'Karriere-Tag speichern' : 'Karriere-Tag anlegen',
              ),
            ),
            if (isEditing)
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Bearbeitung abbrechen'),
              ),
          ],
        ),
      ],
    );
  }
}

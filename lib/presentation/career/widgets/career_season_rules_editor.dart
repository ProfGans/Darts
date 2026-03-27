import 'package:flutter/material.dart';

import '../../../domain/career/career_models.dart';

class CareerSeasonRulesEditor extends StatelessWidget {
  const CareerSeasonRulesEditor({
    super.key,
    required this.career,
    required this.isEditing,
    required this.selectedTagName,
    required this.selectedRankingId,
    required this.action,
    required this.rankMode,
    required this.fromController,
    required this.toController,
    required this.referenceRankController,
    required this.checkMode,
    required this.selectedCheckTagName,
    required this.checkRemainingController,
    required this.onTagChanged,
    required this.onRankingChanged,
    required this.onActionChanged,
    required this.onRankModeChanged,
    required this.onCheckModeChanged,
    required this.onCheckTagChanged,
    required this.onSave,
    required this.onCancel,
    required this.onEdit,
    required this.onDelete,
    required this.describeRule,
  });

  final CareerDefinition career;
  final bool isEditing;
  final String? selectedTagName;
  final String? selectedRankingId;
  final CareerSeasonTagRuleAction action;
  final CareerSeasonTagRuleRankMode rankMode;
  final TextEditingController fromController;
  final TextEditingController toController;
  final TextEditingController referenceRankController;
  final CareerSeasonTagRuleCheckMode checkMode;
  final String? selectedCheckTagName;
  final TextEditingController checkRemainingController;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onRankingChanged;
  final ValueChanged<CareerSeasonTagRuleAction> onActionChanged;
  final ValueChanged<CareerSeasonTagRuleRankMode> onRankModeChanged;
  final ValueChanged<CareerSeasonTagRuleCheckMode> onCheckModeChanged;
  final ValueChanged<String?> onCheckTagChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final ValueChanged<CareerSeasonTagRule> onEdit;
  final ValueChanged<String> onDelete;
  final String Function(CareerSeasonTagRule rule) describeRule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isEditing
              ? 'Saisonabschluss-Regel bearbeiten'
              : 'Saisonabschluss-Regeln',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(selectedTagName ?? 'season-tag-empty'),
          initialValue: selectedTagName,
          decoration: const InputDecoration(labelText: 'Karriere-Tag'),
          items: career.careerTagDefinitions
              .map(
                (definition) => DropdownMenuItem<String>(
                  value: definition.name,
                  child: Text(definition.name),
                ),
              )
              .toList(),
          onChanged:
              career.careerTagDefinitions.isEmpty ? null : onTagChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(selectedRankingId ?? 'season-ranking-empty'),
          initialValue: selectedRankingId,
          decoration: const InputDecoration(labelText: 'Rangliste'),
          items: career.rankings
              .map(
                (ranking) => DropdownMenuItem<String>(
                  value: ranking.id,
                  child: Text(ranking.name),
                ),
              )
              .toList(),
          onChanged: career.rankings.isEmpty ? null : onRankingChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CareerSeasonTagRuleAction>(
          key: ValueKey<CareerSeasonTagRuleAction>(action),
          initialValue: action,
          decoration: const InputDecoration(labelText: 'Aktion'),
          items: const <DropdownMenuItem<CareerSeasonTagRuleAction>>[
            DropdownMenuItem(
              value: CareerSeasonTagRuleAction.add,
              child: Text('Tag hinzufuegen'),
            ),
            DropdownMenuItem(
              value: CareerSeasonTagRuleAction.remove,
              child: Text('Tag entfernen'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onActionChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CareerSeasonTagRuleRankMode>(
          key: ValueKey<CareerSeasonTagRuleRankMode>(rankMode),
          initialValue: rankMode,
          decoration: const InputDecoration(labelText: 'Rang-Bedingung'),
          items: const <DropdownMenuItem<CareerSeasonTagRuleRankMode>>[
            DropdownMenuItem(
              value: CareerSeasonTagRuleRankMode.range,
              child: Text('Rangbereich'),
            ),
            DropdownMenuItem(
              value: CareerSeasonTagRuleRankMode.greaterThanRank,
              child: Text('Groesser als Platz'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onRankModeChanged(value);
            }
          },
        ),
        const SizedBox(height: 12),
        if (rankMode == CareerSeasonTagRuleRankMode.range)
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: fromController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Von Rang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: toController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bis Rang'),
                ),
              ),
            ],
          )
        else
          TextField(
            controller: referenceRankController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Groesser als Platz'),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CareerSeasonTagRuleCheckMode>(
          key: ValueKey<CareerSeasonTagRuleCheckMode>(checkMode),
          initialValue: checkMode,
          decoration: const InputDecoration(labelText: 'Pruefkriterium'),
          items: const <DropdownMenuItem<CareerSeasonTagRuleCheckMode>>[
            DropdownMenuItem(
              value: CareerSeasonTagRuleCheckMode.none,
              child: Text('Kein Zusatzkriterium'),
            ),
            DropdownMenuItem(
              value: CareerSeasonTagRuleCheckMode.tagValidityAtMost,
              child: Text('Tag gueltig hoechstens X Saisons'),
            ),
            DropdownMenuItem(
              value: CareerSeasonTagRuleCheckMode.tagValidityAtLeast,
              child: Text('Tag gueltig mindestens X Saisons'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onCheckModeChanged(value);
            }
          },
        ),
        if (checkMode != CareerSeasonTagRuleCheckMode.none) ...<Widget>[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              selectedCheckTagName ?? 'season-check-tag-empty',
            ),
            initialValue: selectedCheckTagName,
            decoration: const InputDecoration(labelText: 'Pruefe Tag'),
            items: career.careerTagDefinitions
                .map(
                  (definition) => DropdownMenuItem<String>(
                    value: definition.name,
                    child: Text(definition.name),
                  ),
                )
                .toList(),
            onChanged: onCheckTagChanged,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: checkRemainingController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Saisons',
              helperText: 'Restlaufzeit des geprueften Tags',
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: onSave,
              icon: const Icon(Icons.rule),
              label: Text(isEditing ? 'Regel speichern' : 'Regel anlegen'),
            ),
            if (isEditing)
              OutlinedButton(
                onPressed: onCancel,
                child: const Text('Bearbeitung abbrechen'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (career.seasonTagRules.isEmpty)
          const Text('Noch keine Saisonabschluss-Regeln angelegt.')
        else
          ...career.seasonTagRules.map(
            (rule) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${rule.action == CareerSeasonTagRuleAction.add ? 'Hinzufuegen' : 'Entfernen'}: ${rule.tagName}',
              ),
              subtitle: Text(describeRule(rule)),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  IconButton(
                    onPressed: () => onEdit(rule),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    onPressed: () => onDelete(rule.id),
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

import 'package:flutter/material.dart';

enum CareerTournamentPrizeSplitPreset {
  proTour,
  major,
  development,
}

extension CareerTournamentPrizeSplitPresetLabel
    on CareerTournamentPrizeSplitPreset {
  String get label {
    switch (this) {
      case CareerTournamentPrizeSplitPreset.proTour:
        return 'Pro Tour';
      case CareerTournamentPrizeSplitPreset.major:
        return 'Major / TV';
      case CareerTournamentPrizeSplitPreset.development:
        return 'Development';
    }
  }

  String get helperText {
    switch (this) {
      case CareerTournamentPrizeSplitPreset.proTour:
        return 'Angelehnt an typische Floor-Events wie Players Championships.';
      case CareerTournamentPrizeSplitPreset.major:
        return 'Top-lastiger Split wie bei TV-Majors.';
      case CareerTournamentPrizeSplitPreset.development:
        return 'Flacherer Split fuer kleinere Tour-Events.';
    }
  }
}

class CareerTournamentPrizeEditor extends StatelessWidget {
  const CareerTournamentPrizeEditor({
    super.key,
    required this.usesKnockoutPrizeSetup,
    required this.usesLeaguePositionPrizeSetup,
    required this.knockoutPrizeValues,
    required this.knockoutPrizeLabel,
    required this.onKnockoutPrizeChanged,
    required this.calculatedKnockoutPrizePool,
    required this.leaguePositionPrizeValues,
    required this.onLeaguePositionPrizeChanged,
    required this.calculatedLeaguePrizePool,
    required this.prizePoolController,
    required this.calculatedPrizePool,
    required this.selectedSplitPreset,
    required this.onSplitPresetChanged,
    required this.onApplyKnockoutSplit,
    this.totalPrizeHelperText,
  });

  final bool usesKnockoutPrizeSetup;
  final bool usesLeaguePositionPrizeSetup;
  final List<int> knockoutPrizeValues;
  final String Function(int index) knockoutPrizeLabel;
  final void Function(int index, String value) onKnockoutPrizeChanged;
  final int calculatedKnockoutPrizePool;
  final List<int> leaguePositionPrizeValues;
  final void Function(int index, String value) onLeaguePositionPrizeChanged;
  final int calculatedLeaguePrizePool;
  final TextEditingController prizePoolController;
  final int calculatedPrizePool;
  final CareerTournamentPrizeSplitPreset selectedSplitPreset;
  final ValueChanged<CareerTournamentPrizeSplitPreset> onSplitPresetChanged;
  final VoidCallback onApplyKnockoutSplit;
  final String? totalPrizeHelperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (usesKnockoutPrizeSetup) ...<Widget>[
          TextField(
            controller: prizePoolController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Gesamtpreisgeld fuer Auto-Split',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CareerTournamentPrizeSplitPreset>(
            initialValue: selectedSplitPreset,
            decoration: const InputDecoration(
              labelText: 'Typischer Split',
            ),
            items: CareerTournamentPrizeSplitPreset.values
                .map(
                  (preset) => DropdownMenuItem<CareerTournamentPrizeSplitPreset>(
                    value: preset,
                    child: Text(preset.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onSplitPresetChanged(value);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            selectedSplitPreset.helperText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onApplyKnockoutSplit,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Typischen Split anwenden'),
          ),
          const SizedBox(height: 16),
          Text(
            'Preisgeld pro Runde',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...knockoutPrizeValues.asMap().entries.map((entry) {
            final index = entry.key;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == knockoutPrizeValues.length - 1 ? 0 : 12,
              ),
              child: TextFormField(
                initialValue: '${entry.value}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: knockoutPrizeLabel(index),
                ),
                onChanged: (value) => onKnockoutPrizeChanged(index, value),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'KO-Preisgeld $calculatedKnockoutPrizePool',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (usesLeaguePositionPrizeSetup) ...<Widget>[
          if (usesKnockoutPrizeSetup) const SizedBox(height: 12),
          Text(
            'Preisgeld nach Ligaposition',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...leaguePositionPrizeValues.asMap().entries.map((entry) {
            final index = entry.key;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == leaguePositionPrizeValues.length - 1 ? 0 : 12,
              ),
              child: TextFormField(
                initialValue: '${entry.value}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Platz ${index + 1}',
                ),
                onChanged: (value) => onLeaguePositionPrizeChanged(index, value),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Liga-Preisgeld $calculatedLeaguePrizePool',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (!usesKnockoutPrizeSetup && !usesLeaguePositionPrizeSetup)
          TextField(
            controller: prizePoolController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Gesamtpreisgeld'),
          )
        else ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Gesamtpreisgeld $calculatedPrizePool',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (totalPrizeHelperText != null &&
              totalPrizeHelperText!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              totalPrizeHelperText!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/settings_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = SettingsRepository.instance;

    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final settings = repository.settings;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Computer Geschwindigkeit',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: settings.computerSpeedIndex,
                          items: const <DropdownMenuItem<int>>[
                            DropdownMenuItem(value: 0, child: Text('Langsam')),
                            DropdownMenuItem(value: 1, child: Text('Normal')),
                            DropdownMenuItem(value: 2, child: Text('Schnell')),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            repository.update(
                              settings.copyWith(
                                computerSpeedIndex: value,
                              ),
                            );
                            unawaited(
                              ComputerRepository.instance
                                  .refreshTheoreticalAverages(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  context,
                  title: 'Radius Kalibrierung',
                  value: settings.radiusCalibrationPercent
                      .clamp(
                        SettingsRepository.minRadiusCalibrationPercent,
                        SettingsRepository.maxRadiusCalibrationPercent,
                      )
                      .toDouble(),
                  min: SettingsRepository.minRadiusCalibrationPercent.toDouble(),
                  max: SettingsRepository.maxRadiusCalibrationPercent.toDouble(),
                  label:
                      '${settings.radiusCalibrationPercent}% (100% entspricht deinem bisherigen 97%-Punkt)',
                  onChanged: (value) {
                    repository.update(
                      settings.copyWith(
                        radiusCalibrationPercent: value.round(),
                      ),
                    );
                  },
                  onChangeEnd: (_) {
                    unawaited(
                      ComputerRepository.instance.refreshTheoreticalAverages(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  context,
                  title: 'Simulations Spreizung',
                  value: settings.simulationSpreadPercent
                      .clamp(
                        SettingsRepository.minSimulationSpreadPercent,
                        SettingsRepository.maxSimulationSpreadPercent,
                      )
                      .toDouble(),
                  min:
                      SettingsRepository.minSimulationSpreadPercent.toDouble(),
                  max:
                      SettingsRepository.maxSimulationSpreadPercent.toDouble(),
                  label: '${settings.simulationSpreadPercent}% vom alten Standard',
                  onChanged: (value) {
                    repository.update(
                      settings.copyWith(
                        simulationSpreadPercent: value.round(),
                      ),
                    );
                  },
                  onChangeEnd: (_) {
                    unawaited(
                      ComputerRepository.instance.refreshTheoreticalAverages(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'X01 Schnellwerte',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Diese vier Hotkeys erscheinen links und rechts neben dem Eingabewert im X01-Matchscreen.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List<Widget>.generate(4, (index) {
                            return SizedBox(
                              width: 140,
                              child: TextFormField(
                                key: ValueKey<String>(
                                  'x01-quick-score-$index-${settings.x01QuickScores[index]}',
                                ),
                                initialValue: '${settings.x01QuickScores[index]}',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: switch (index) {
                                    0 => 'Links oben',
                                    1 => 'Links unten',
                                    2 => 'Rechts oben',
                                    _ => 'Rechts unten',
                                  },
                                ),
                                onChanged: (value) {
                                  final parsed = int.tryParse(value.trim());
                                  if (parsed == null) {
                                    return;
                                  }
                                  final nextQuickScores =
                                      List<int>.from(settings.x01QuickScores);
                                  nextQuickScores[index] = parsed.clamp(0, 180);
                                  repository.update(
                                    settings.copyWith(
                                      x01QuickScores: nextQuickScores,
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    repository.reset();
                    unawaited(
                      ComputerRepository.instance.refreshTheoreticalAverages(),
                    );
                  },
                  child: const Text('Auf Standard zuruecksetzen'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSliderCard(
    BuildContext context, {
    required String title,
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(label),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
  }
}

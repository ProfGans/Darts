import 'package:flutter/material.dart';

import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/settings_repository.dart';

Future<void> _runBlockingRefresh(
  BuildContext context, {
  required Future<void> Function() action,
  required String message,
  String? successMessage,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  final repository = ComputerRepository.instance;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AnimatedBuilder(
        animation: repository,
        builder: (context, _) {
          final progress = repository.theoreticalRefreshProgress;
          final label = repository.theoreticalRefreshLabel.isNotEmpty
              ? repository.theoreticalRefreshLabel
              : message;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(label),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress > 0 && progress < 1 ? progress : null,
                ),
                if (progress > 0) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ],
            ),
          );
        },
      );
    },
  );
  await Future<void>.delayed(Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 16));
  try {
    await action();
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
  if (context.mounted && successMessage != null && successMessage.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(successMessage),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const List<String> _x01QuickScoreLabels = <String>[
    'Links oben',
    'Links mitte',
    'Links unten',
    'Rechts oben',
    'Rechts mitte',
    'Rechts unten',
  ];

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
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Debug',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Blendet das Debug-Panel in der App ein oder aus. Die Debug-Ausgabe in PowerShell bleibt weiter aktiv.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.debugOverlayEnabled,
                          onChanged: (value) {
                            repository.update(
                              settings.copyWith(debugOverlayEnabled: value),
                            );
                          },
                          title: const Text('Debug-Panel in App anzeigen'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  context,
                  title: 'Radius Kalibrierung',
                  description:
                      'Steuert die grundsaetzliche Zielgenauigkeit der Bots. Hoehere Werte machen die Streuung groesser, niedrigere Werte praeziser.',
                  value: settings.radiusCalibrationPercent
                      .clamp(
                        SettingsRepository.minRadiusCalibrationPercent,
                        SettingsRepository.maxRadiusCalibrationPercent,
                      )
                      .toDouble(),
                  min: SettingsRepository.minRadiusCalibrationPercent.toDouble(),
                  max: SettingsRepository.maxRadiusCalibrationPercent.toDouble(),
                  label: '${settings.radiusCalibrationPercent}%',
                  onChanged: (value) {
                    repository.update(
                      settings.copyWith(
                        radiusCalibrationPercent: value.round(),
                      ),
                    );
                  },
                  onChangeEnd: (_) {
                  },
                ),
                const SizedBox(height: 16),
                _buildSliderCard(
                  context,
                  title: 'Simulations Spreizung',
                  description:
                      'Beeinflusst, wie stark gute und schwache Phasen in der Simulation auseinanderlaufen. Hoehere Werte sorgen fuer mehr Varianz, niedrigere fuer gleichmaessigere Leistungen.',
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
                          'Diese sechs Hotkeys erscheinen links und rechts im X01-Scoring-Pad.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List<Widget>.generate(
                            _x01QuickScoreLabels.length,
                            (index) {
                              return SizedBox(
                                width: 170,
                                child: TextFormField(
                                  key: ValueKey<String>(
                                    'x01-quick-score-$index-${settings.x01QuickScores[index]}',
                                  ),
                                  initialValue:
                                      '${settings.x01QuickScores[index]}',
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: _x01QuickScoreLabels[index],
                                  ),
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value.trim());
                                    if (parsed == null) {
                                      return;
                                    }
                                    final nextQuickScores =
                                        List<int>.from(settings.x01QuickScores);
                                    nextQuickScores[index] =
                                        parsed.clamp(0, 180);
                                    repository.update(
                                      settings.copyWith(
                                        x01QuickScores: nextQuickScores,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Theo Averages',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Berechnet die theoretischen Averages aller vorhandenen Computer-Spieler mit der aktuellen Bot- und Settings-Logik neu.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hinweis: Der Theo Average liegt in der Regel ein paar Punkte ueber dem echten Match-Average.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () async {
                            await _runBlockingRefresh(
                              context,
                              message:
                                  'Theoretische Averages werden neu berechnet...',
                              successMessage:
                                  'Theoretische Averages wurden neu berechnet.',
                              action: () {
                                return ComputerRepository.instance
                                    .refreshTheoreticalAverages();
                              },
                            );
                          },
                          child: const Text(
                            'Theo Averages neu berechnen',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    repository.reset();
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
    required String description,
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
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
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

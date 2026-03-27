import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import 'tournament_form_models.dart';

class TournamentBasicsForm extends StatelessWidget {
  const TournamentBasicsForm({
    super.key,
    required this.nameController,
    required this.formData,
    required this.onChanged,
    this.nameLabel = 'Turniername',
  });

  final TextEditingController nameController;
  final TournamentFormData formData;
  final ValueChanged<TournamentFormData> onChanged;
  final String nameLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: nameLabel),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TournamentGame>(
          key: ValueKey<String>('game-${formData.game.name}'),
          initialValue: formData.game,
          decoration: const InputDecoration(labelText: 'Spiel'),
          items: const <DropdownMenuItem<TournamentGame>>[
            DropdownMenuItem(
              value: TournamentGame.x01,
              child: Text('X01'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(formData.copyWith(game: value));
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TournamentFormat>(
          key: ValueKey<String>('format-${formData.format.name}'),
          initialValue: formData.format,
          decoration: const InputDecoration(labelText: 'Turniermodus'),
          items: const <DropdownMenuItem<TournamentFormat>>[
            DropdownMenuItem(
              value: TournamentFormat.knockout,
              child: Text('KO Modus'),
            ),
            DropdownMenuItem(
              value: TournamentFormat.league,
              child: Text('Liga'),
            ),
            DropdownMenuItem(
              value: TournamentFormat.leaguePlayoff,
              child: Text('Liga + Playoff'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(formData.copyWith(format: value));
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: formData.fieldSizeInput,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Feldgroesse',
            helperText: 'Beliebige Teilnehmerzahl, Freilose werden automatisch vergeben.',
          ),
          onChanged: (value) {
            onChanged(formData.copyWith(fieldSizeInput: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MatchMode>(
          key: ValueKey<String>('mode-${formData.matchMode.name}'),
          initialValue: formData.matchMode,
          decoration: const InputDecoration(labelText: 'Modus'),
          items: const <DropdownMenuItem<MatchMode>>[
            DropdownMenuItem(value: MatchMode.legs, child: Text('Legs')),
            DropdownMenuItem(value: MatchMode.sets, child: Text('Sets')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(formData.copyWith(matchMode: value));
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '${formData.legsValue}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: formData.matchMode == MatchMode.legs
                ? 'Distanz (First to)'
                : 'Legs pro Satz (Best of)',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed != null && parsed > 0) {
              onChanged(formData.copyWith(legsValue: parsed));
            }
          },
        ),
        if (formData.matchMode == MatchMode.sets) ...<Widget>[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${formData.setsToWin}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sets zum Sieg (First to)',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) {
                onChanged(formData.copyWith(setsToWin: parsed));
              }
            },
          ),
        ],
        if ((formData.format == TournamentFormat.knockout ||
                formData.format == TournamentFormat.leaguePlayoff) &&
            formData.roundCount > 0) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Rundendistanzen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          ...formData.effectiveRoundDistanceValues.asMap().entries.map((entry) {
            final index = entry.key;
            final roundNumber = index + 1;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == formData.effectiveRoundDistanceValues.length - 1
                    ? 0
                    : 12,
              ),
              child: TextFormField(
                initialValue: '${entry.value}',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${_roundLabel(roundNumber, formData.roundCount)}${formData.matchMode == MatchMode.legs ? ' (Legs zum Sieg)' : ' (Sets zum Sieg)'}',
                ),
                onChanged: (value) {
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return;
                  }
                  final updated = List<int>.from(
                    formData.effectiveRoundDistanceValues,
                  );
                  updated[index] = parsed;
                  onChanged(formData.copyWith(roundDistanceValues: updated));
                },
              ),
            );
          }),
        ],
        if (formData.format == TournamentFormat.league ||
            formData.format == TournamentFormat.leaguePlayoff) ...<Widget>[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ligaeinstellungen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: '${formData.pointsForWin}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Punkte fuer Sieg'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                onChanged(formData.copyWith(pointsForWin: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${formData.pointsForDraw}',
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Punkte fuer Unentschieden'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                onChanged(formData.copyWith(pointsForDraw: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${formData.roundRobinRepeats}',
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Jeder gegen jeden'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) {
                onChanged(formData.copyWith(roundRobinRepeats: parsed));
              }
            },
          ),
          if (formData.format == TournamentFormat.leaguePlayoff) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '${formData.playoffQualifierCount}',
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(
                    labelText: 'Top X fuer Playoffs',
                    helperText: 'Freie Zahl, sinnvoll sind Werte ab 2.',
                  ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null && parsed >= 2) {
                  onChanged(
                    formData.copyWith(
                      playoffQualifierCount: parsed,
                      roundDistanceValues: List<int>.from(
                        formData.effectiveRoundDistanceValues.take(
                          _playoffRoundCount(parsed),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
        const SizedBox(height: 12),
        TextFormField(
          initialValue: formData.startScoreInput,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Startscore'),
          onChanged: (value) {
            onChanged(formData.copyWith(startScoreInput: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<StartRequirement>(
          key: ValueKey<String>(
            'start-${formData.startRequirement.name}',
          ),
          initialValue: formData.startRequirement,
          decoration: const InputDecoration(labelText: 'In'),
          items: const <DropdownMenuItem<StartRequirement>>[
            DropdownMenuItem(
              value: StartRequirement.straightIn,
              child: Text('Straight In'),
            ),
            DropdownMenuItem(
              value: StartRequirement.doubleIn,
              child: Text('Double In'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(formData.copyWith(startRequirement: value));
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CheckoutRequirement>(
          key: ValueKey<String>(
            'checkout-${formData.checkoutRequirement.name}',
          ),
          initialValue: formData.checkoutRequirement,
          decoration: const InputDecoration(labelText: 'Checkout'),
          items: const <DropdownMenuItem<CheckoutRequirement>>[
            DropdownMenuItem(
              value: CheckoutRequirement.singleOut,
              child: Text('Single Out'),
            ),
            DropdownMenuItem(
              value: CheckoutRequirement.doubleOut,
              child: Text('Double Out'),
            ),
            DropdownMenuItem(
              value: CheckoutRequirement.masterOut,
              child: Text('Master Out'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(formData.copyWith(checkoutRequirement: value));
            }
          },
        ),
      ],
    );
  }

  int _playoffRoundCount(int qualifierCount) {
    var bracketSize = 2;
    var rounds = 1;
    while (bracketSize < qualifierCount) {
      bracketSize *= 2;
      rounds += 1;
    }
    return rounds;
  }

  String _roundLabel(int roundNumber, int roundCount) {
    final matchesInRound = math.pow(2, roundCount - roundNumber).toInt();
    if (matchesInRound <= 1) {
      return 'Finale';
    }
    if (matchesInRound == 2) {
      return 'Halbfinale';
    }
    if (matchesInRound == 4) {
      return 'Viertelfinale';
    }
    if (matchesInRound == 8) {
      return 'Achtelfinale';
    }
    return 'Runde $roundNumber';
  }
}

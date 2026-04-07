import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import 'tournament_form_models.dart';

class TournamentBasicsForm extends StatefulWidget {
  const TournamentBasicsForm({
    super.key,
    required this.nameController,
    required this.formData,
    required this.onChanged,
    this.nameLabel = 'Turniername',
    this.roundDistancesCollapsible = false,
    this.roundDistancesInitiallyExpanded = true,
  });

  final TextEditingController nameController;
  final TournamentFormData formData;
  final ValueChanged<TournamentFormData> onChanged;
  final String nameLabel;
  final bool roundDistancesCollapsible;
  final bool roundDistancesInitiallyExpanded;

  @override
  State<TournamentBasicsForm> createState() => _TournamentBasicsFormState();
}

class _TournamentBasicsFormState extends State<TournamentBasicsForm> {
  late bool _roundDistancesExpanded;

  @override
  void initState() {
    super.initState();
    _roundDistancesExpanded =
        !widget.roundDistancesCollapsible || widget.roundDistancesInitiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant TournamentBasicsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.roundDistancesCollapsible) {
      _roundDistancesExpanded = true;
    } else if (!oldWidget.roundDistancesCollapsible &&
        widget.roundDistancesCollapsible) {
      _roundDistancesExpanded = widget.roundDistancesInitiallyExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TextField(
          controller: widget.nameController,
          decoration: InputDecoration(labelText: widget.nameLabel),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TournamentGame>(
          key: ValueKey<String>('game-${widget.formData.game.name}'),
          initialValue: widget.formData.game,
          decoration: const InputDecoration(labelText: 'Spiel'),
          items: const <DropdownMenuItem<TournamentGame>>[
            DropdownMenuItem(
              value: TournamentGame.x01,
              child: Text('X01'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(widget.formData.copyWith(game: value));
            }
          },
        ),
        const SizedBox(height: 12),
          DropdownButtonFormField<TournamentFormat>(
            key: ValueKey<String>('format-${widget.formData.format.name}'),
            initialValue: widget.formData.format,
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
              widget.onChanged(widget.formData.copyWith(format: value));
            }
          },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widget.formData.tierInput,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tier',
              helperText: 'Freie Tier-Zahl. 1 ist die hoechste Turnier-Stufe.',
            ),
            onChanged: (value) {
              widget.onChanged(widget.formData.copyWith(tierInput: value));
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: widget.formData.fieldSizeInput,
            keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Feldgroesse',
            helperText: 'Beliebige Teilnehmerzahl, Freilose werden automatisch vergeben.',
          ),
          onChanged: (value) {
            widget.onChanged(widget.formData.copyWith(fieldSizeInput: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<MatchMode>(
          key: ValueKey<String>('mode-${widget.formData.matchMode.name}'),
          initialValue: widget.formData.matchMode,
          decoration: const InputDecoration(labelText: 'Modus'),
          items: const <DropdownMenuItem<MatchMode>>[
            DropdownMenuItem(value: MatchMode.legs, child: Text('Legs')),
            DropdownMenuItem(value: MatchMode.sets, child: Text('Sets')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(widget.formData.copyWith(matchMode: value));
            }
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: '${widget.formData.legsValue}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: widget.formData.matchMode == MatchMode.legs
                ? 'Distanz (First to)'
                : 'Legs pro Satz (Best of)',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed != null && parsed > 0) {
              widget.onChanged(widget.formData.copyWith(legsValue: parsed));
            }
          },
        ),
        if (widget.formData.matchMode == MatchMode.sets) ...<Widget>[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${widget.formData.setsToWin}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sets zum Sieg (First to)',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) {
                widget.onChanged(widget.formData.copyWith(setsToWin: parsed));
              }
            },
          ),
        ],
        if ((widget.formData.format == TournamentFormat.knockout ||
                widget.formData.format == TournamentFormat.leaguePlayoff) &&
            widget.formData.roundCount > 0) ...<Widget>[
          const SizedBox(height: 16),
          if (widget.roundDistancesCollapsible)
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      'Rundendistanzen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _roundDistancesExpanded
                          ? 'Distanz pro KO-Runde bearbeiten'
                          : '${widget.formData.roundCount} Runden konfigurierbar',
                    ),
                    trailing: Icon(
                      _roundDistancesExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    onTap: () {
                      setState(() {
                        _roundDistancesExpanded = !_roundDistancesExpanded;
                      });
                    },
                  ),
                  if (_roundDistancesExpanded) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        children: _buildRoundDistanceFields(),
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Rundendistanzen',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ..._buildRoundDistanceFields(),
          ],
        ],
        if (widget.formData.format == TournamentFormat.league ||
            widget.formData.format == TournamentFormat.leaguePlayoff) ...<Widget>[
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
            initialValue: '${widget.formData.pointsForWin}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Punkte fuer Sieg'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                widget.onChanged(widget.formData.copyWith(pointsForWin: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${widget.formData.pointsForDraw}',
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Punkte fuer Unentschieden'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                widget.onChanged(widget.formData.copyWith(pointsForDraw: parsed));
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${widget.formData.roundRobinRepeats}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jeder gegen jeden'),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) {
                widget.onChanged(
                  widget.formData.copyWith(roundRobinRepeats: parsed),
                );
              }
            },
          ),
          if (widget.formData.format == TournamentFormat.leaguePlayoff) ...<Widget>[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: '${widget.formData.playoffQualifierCount}',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Top X fuer Playoffs',
                helperText: 'Freie Zahl, sinnvoll sind Werte ab 2.',
              ),
              onChanged: (value) {
                final parsed = int.tryParse(value.trim());
                if (parsed != null && parsed >= 2) {
                  widget.onChanged(
                    widget.formData.copyWith(
                      playoffQualifierCount: parsed,
                      roundDistanceValues: List<int>.from(
                        widget.formData.effectiveRoundDistanceValues.take(
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
          initialValue: widget.formData.startScoreInput,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Startscore'),
          onChanged: (value) {
            widget.onChanged(widget.formData.copyWith(startScoreInput: value));
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<StartRequirement>(
          key: ValueKey<String>('start-${widget.formData.startRequirement.name}'),
          initialValue: widget.formData.startRequirement,
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
              widget.onChanged(widget.formData.copyWith(startRequirement: value));
            }
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<CheckoutRequirement>(
          key: ValueKey<String>(
            'checkout-${widget.formData.checkoutRequirement.name}',
          ),
          initialValue: widget.formData.checkoutRequirement,
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
              widget.onChanged(
                widget.formData.copyWith(checkoutRequirement: value),
              );
            }
          },
        ),
      ],
    );
  }

  List<Widget> _buildRoundDistanceFields() {
    return widget.formData.effectiveRoundDistanceValues.asMap().entries.map((
      entry,
    ) {
      final index = entry.key;
      final roundNumber = index + 1;
      return Padding(
        padding: EdgeInsets.only(
          bottom: index == widget.formData.effectiveRoundDistanceValues.length - 1
              ? 0
              : 12,
        ),
        child: TextFormField(
          initialValue: '${entry.value}',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText:
                '${_roundLabel(roundNumber, widget.formData.roundCount)}${widget.formData.matchMode == MatchMode.legs ? ' (Legs zum Sieg)' : ' (Sets zum Sieg)'}',
          ),
          onChanged: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return;
            }
            final updated = List<int>.from(
              widget.formData.effectiveRoundDistanceValues,
            );
            updated[index] = parsed;
            widget.onChanged(
              widget.formData.copyWith(roundDistanceValues: updated),
            );
          },
        ),
      );
    }).toList();
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

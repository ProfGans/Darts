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
    _roundDistancesExpanded = !widget.roundDistancesCollapsible ||
        widget.roundDistancesInitiallyExpanded;
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
    final leagueMatchCount = _leagueMatchCountEstimate();
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
        DropdownButtonFormField<TournamentCreationMode>(
          key: ValueKey<String>('creation-mode-${widget.formData.creationMode.name}'),
          initialValue: widget.formData.creationMode,
          decoration: const InputDecoration(labelText: 'Erstellung'),
          items: const <DropdownMenuItem<TournamentCreationMode>>[
            DropdownMenuItem(
              value: TournamentCreationMode.singleTournament,
              child: Text('Einzelturnier'),
            ),
            DropdownMenuItem(
              value: TournamentCreationMode.tournamentSeries,
              child: Text('Turnierphasen'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(widget.formData.copyWith(creationMode: value));
            }
          },
        ),
        const SizedBox(height: 12),
        if (!widget.formData.isSeriesMode) ...<Widget>[
          DropdownButtonFormField<TournamentFormat>(
            key: ValueKey<String>('format-${widget.formData.primaryFormat.name}'),
            initialValue: widget.formData.primaryFormat,
            decoration: const InputDecoration(labelText: 'Format'),
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
            DropdownMenuItem(
              value: TournamentFormat.groupStage,
              child: Text('Gruppenphase'),
            ),
          ],
            onChanged: (value) {
              if (value != null) {
                widget.onChanged(widget.formData.copyWith(format: value));
              }
            },
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          DropdownButtonFormField<int>(
          key: ValueKey<int>(widget.formData.phaseCount),
          initialValue: widget.formData.phaseCount,
          decoration: const InputDecoration(labelText: 'Phasen in der Serie'),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem(value: 1, child: Text('1 Phase')),
            DropdownMenuItem(value: 2, child: Text('2 Phasen')),
            DropdownMenuItem(value: 3, child: Text('3 Phasen')),
            DropdownMenuItem(value: 4, child: Text('4 Phasen')),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.onChanged(widget.formData.copyWith(phaseCount: value));
            }
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Turnierphasen',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildPhaseFields(),
        const SizedBox(height: 8),
        Text(
          'Lege hier die Phasen und Teilturniere fest und bestimme, welche Platzierungen in die naechste Phase weiterziehen.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5D7285),
              ),
        ),
        const SizedBox(height: 12),
        ],
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
        if (widget.formData.primaryFormat != TournamentFormat.groupStage) ...<Widget>[
          TextFormField(
            initialValue: widget.formData.fieldSizeInput,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Feldgroesse',
              helperText:
                  'Beliebige Teilnehmerzahl, Freilose werden automatisch vergeben.',
            ),
            onChanged: (value) {
              widget.onChanged(widget.formData.copyWith(fieldSizeInput: value));
            },
          ),
          const SizedBox(height: 12),
        ] else ...<Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Gruppenphase',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.formData.groupCount}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gruppen',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      widget.onChanged(widget.formData.copyWith(groupCount: parsed));
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: '${widget.formData.playersPerGroup}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Spieler pro Gruppe',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed != null && parsed > 1) {
                      widget.onChanged(
                        widget.formData.copyWith(playersPerGroup: parsed),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Automatische Feldgroesse: ${widget.formData.configuredGroupFieldSize} Teilnehmer',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        if ((widget.formData.primaryFormat == TournamentFormat.knockout ||
                widget.formData.primaryFormat ==
                    TournamentFormat.leaguePlayoff) &&
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
        if (widget.formData.primaryFormat == TournamentFormat.league ||
            widget.formData.primaryFormat == TournamentFormat.groupStage ||
            widget.formData.primaryFormat ==
                TournamentFormat.leaguePlayoff) ...<Widget>[
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
            decoration: const InputDecoration(
              labelText: 'Punkte fuer Unentschieden',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                widget.onChanged(
                  widget.formData.copyWith(pointsForDraw: parsed),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: '${widget.formData.roundRobinRepeats}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Spiele pro Paarung',
              helperText:
                  '1 = jeder spielt einmal gegen jeden, 2 = Hin- und Rueckrunde'
                  '${leagueMatchCount == null ? '' : ' | ca. $leagueMatchCount Liga-Spiele gesamt'}',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed > 0) {
                widget.onChanged(
                  widget.formData.copyWith(roundRobinRepeats: parsed),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue:
                '${widget.formData.maxLeagueMatchesPerParticipant}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maximale Liga-Spiele pro Spieler',
              helperText:
                  '0 = komplette Liga. Bei 5 werden nur die ersten 5 Spieltage angesetzt.',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value.trim());
              if (parsed != null && parsed >= 0) {
                widget.onChanged(
                  widget.formData.copyWith(
                    maxLeagueMatchesPerParticipant: parsed,
                  ),
                );
              }
            },
          ),
          if (widget.formData.primaryFormat ==
              TournamentFormat.leaguePlayoff) ...<Widget>[
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
              widget.onChanged(
                widget.formData.copyWith(startRequirement: value),
              );
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

  List<Widget> _buildPhaseFields() {
    final counts = widget.formData.effectivePhaseTournamentCounts;
    final phaseEntries = widget.formData.effectivePhaseTournaments;
    final widgets = <Widget>[];
    for (var phaseIndex = 0; phaseIndex < phaseEntries.length; phaseIndex += 1) {
      widgets.add(
        Card(
          margin: EdgeInsets.only(
            bottom: phaseIndex == phaseEntries.length - 1 ? 0 : 12,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Phase ${phaseIndex + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey<String>(
                    'phase-count-${phaseIndex + 1}-${counts[phaseIndex]}',
                  ),
                  initialValue: counts[phaseIndex],
                  decoration: const InputDecoration(
                    labelText: 'Turniere in dieser Phase',
                  ),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem(value: 1, child: Text('1 Turnier')),
                    DropdownMenuItem(value: 2, child: Text('2 Turniere')),
                    DropdownMenuItem(value: 3, child: Text('3 Turniere')),
                    DropdownMenuItem(value: 4, child: Text('4 Turniere')),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    final updatedCounts = List<int>.from(counts);
                    updatedCounts[phaseIndex] = value;
                    widget.onChanged(
                      widget.formData.copyWith(
                        phaseTournamentCounts: updatedCounts,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                ...phaseEntries[phaseIndex].asMap().entries.map((entry) {
                  final tournamentIndex = entry.key;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: tournamentIndex ==
                              phaseEntries[phaseIndex].length - 1
                          ? 0
                          : 12,
                    ),
                    child: Column(
                      children: <Widget>[
                        DropdownButtonFormField<TournamentFormat>(
                          key: ValueKey<String>(
                            'phase-${phaseIndex + 1}-tournament-${tournamentIndex + 1}-${entry.value.format.name}',
                          ),
                          initialValue: entry.value.format,
                          decoration: InputDecoration(
                            labelText:
                                'Teilturnier ${tournamentIndex + 1} in Phase ${phaseIndex + 1}',
                          ),
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
                            DropdownMenuItem(
                              value: TournamentFormat.groupStage,
                              child: Text('Gruppenphase'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            final updatedPhaseEntries = _clonePhaseEntries(
                              phaseEntries,
                            );
                            updatedPhaseEntries[phaseIndex][tournamentIndex] =
                                updatedPhaseEntries[phaseIndex][tournamentIndex]
                                    .copyWith(format: value);
                            widget.onChanged(
                              widget.formData.copyWith(
                                phaseTournaments: updatedPhaseEntries,
                                format: updatedPhaseEntries.first.first.format,
                              ),
                            );
                          },
                        ),
                        if (phaseIndex < phaseEntries.length - 1) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        'Qualifikation fuer Turnier ${phaseIndex + 2}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: () {
                                        final updatedPhaseEntries =
                                            _clonePhaseEntries(phaseEntries);
                                        final currentRules =
                                            List<TournamentQualificationRuleFormData>.from(
                                              updatedPhaseEntries[phaseIndex]
                                                      [tournamentIndex]
                                                  .qualificationRules,
                                            );
                                        currentRules.add(
                                          TournamentQualificationRuleFormData(
                                            startPlacement:
                                                currentRules.isEmpty ? 1 : 2,
                                            endPlacement:
                                                currentRules.isEmpty ? 1 : 2,
                                            targetPhaseNumber: phaseIndex + 2,
                                            targetTournamentNumber: 1,
                                          ),
                                        );
                                        updatedPhaseEntries[phaseIndex]
                                            [tournamentIndex] = updatedPhaseEntries[
                                                phaseIndex][tournamentIndex]
                                            .copyWith(
                                          qualificationRules: currentRules,
                                        );
                                        widget.onChanged(
                                          widget.formData.copyWith(
                                            phaseTournaments:
                                                updatedPhaseEntries,
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('Regel hinzufuegen'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Lege fest, welche Plaetze aus diesem Turnier ins naechste Serien-Turnier wechseln.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF5D7285),
                                      ),
                                ),
                                if (entry.value.qualificationRules.isEmpty) ...<Widget>[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Noch keine Quali-Bedingung hinterlegt.',
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (entry.value.qualificationRules.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            ...entry.value.qualificationRules.asMap().entries.map(
                              (ruleEntry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: ruleEntry.key ==
                                          entry.value.qualificationRules.length - 1
                                      ? 0
                                      : 12,
                                ),
                                child: _QualificationRuleEditor(
                                  phaseIndex: phaseIndex,
                                  counts: counts,
                                  ruleIndex: ruleEntry.key,
                                  rule: ruleEntry.value,
                                  onRemove: () {
                                    final updatedPhaseEntries = _clonePhaseEntries(
                                      phaseEntries,
                                    );
                                    final rules = List<TournamentQualificationRuleFormData>.from(
                                      updatedPhaseEntries[phaseIndex][tournamentIndex]
                                          .qualificationRules,
                                    );
                                    rules.removeAt(ruleEntry.key);
                                    updatedPhaseEntries[phaseIndex][tournamentIndex] =
                                        updatedPhaseEntries[phaseIndex][tournamentIndex]
                                            .copyWith(qualificationRules: rules);
                                    widget.onChanged(
                                      widget.formData.copyWith(
                                        phaseTournaments: updatedPhaseEntries,
                                      ),
                                    );
                                  },
                                  onChanged: (nextRule) {
                                    final updatedPhaseEntries = _clonePhaseEntries(
                                      phaseEntries,
                                    );
                                    final rules = List<TournamentQualificationRuleFormData>.from(
                                      updatedPhaseEntries[phaseIndex][tournamentIndex]
                                          .qualificationRules,
                                    );
                                    rules[ruleEntry.key] = nextRule;
                                    updatedPhaseEntries[phaseIndex][tournamentIndex] =
                                        updatedPhaseEntries[phaseIndex][tournamentIndex]
                                            .copyWith(qualificationRules: rules);
                                    widget.onChanged(
                                      widget.formData.copyWith(
                                        phaseTournaments: updatedPhaseEntries,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  List<List<TournamentPhaseTournamentFormData>> _clonePhaseEntries(
    List<List<TournamentPhaseTournamentFormData>> source,
  ) {
    return source
        .map(
          (entries) => List<TournamentPhaseTournamentFormData>.from(entries),
        )
        .toList();
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

  int? _leagueMatchCountEstimate() {
    if (widget.formData.primaryFormat != TournamentFormat.league &&
        widget.formData.primaryFormat != TournamentFormat.groupStage &&
        widget.formData.primaryFormat != TournamentFormat.leaguePlayoff) {
      return null;
    }
    final entrants = widget.formData.primaryFormat == TournamentFormat.groupStage
        ? widget.formData.playersPerGroup
        : widget.formData.parsedFieldSize;
    if (entrants == null || entrants < 2) {
      return null;
    }
    final groupMultiplier = widget.formData.primaryFormat == TournamentFormat.groupStage
        ? widget.formData.groupCount
        : 1;
    final totalMatches =
        (((entrants * (entrants - 1)) ~/ 2) * widget.formData.roundRobinRepeats) *
            groupMultiplier;
    final maxMatches = widget.formData.maxLeagueMatchesPerParticipant;
    if (maxMatches <= 0) {
      return totalMatches;
    }
    final matchesPerRound = (entrants ~/ 2) * groupMultiplier;
    final limitedTotal = matchesPerRound * maxMatches;
    return limitedTotal < totalMatches ? limitedTotal : totalMatches;
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

class _QualificationRuleEditor extends StatelessWidget {
  const _QualificationRuleEditor({
    required this.phaseIndex,
    required this.counts,
    required this.ruleIndex,
    required this.rule,
    required this.onRemove,
    required this.onChanged,
  });

  final int phaseIndex;
  final List<int> counts;
  final int ruleIndex;
  final TournamentQualificationRuleFormData rule;
  final VoidCallback onRemove;
  final ValueChanged<TournamentQualificationRuleFormData> onChanged;

  @override
  Widget build(BuildContext context) {
    final targetPhaseNumber = phaseIndex + 2;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Regel ${ruleIndex + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Regel loeschen',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  initialValue: '${rule.startPlacement}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Von Platz',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed < 1) {
                      return;
                    }
                    onChanged(rule.copyWith(startPlacement: parsed));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: '${rule.endPlacement}',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bis Platz',
                  ),
                  onChanged: (value) {
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed < 1) {
                      return;
                    }
                    onChanged(rule.copyWith(endPlacement: parsed));
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: rule.targetTournamentNumber == null
                ? null
                : '$targetPhaseNumber:${rule.targetTournamentNumber}',
            decoration: InputDecoration(
              labelText: 'Zielturnier in Phase $targetPhaseNumber',
            ),
            items: List<DropdownMenuItem<String>>.generate(
              counts[phaseIndex + 1],
              (index) => DropdownMenuItem<String>(
                value: '$targetPhaseNumber:${index + 1}',
                child: Text('Phase $targetPhaseNumber | Turnier ${index + 1}'),
              ),
            ),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              final parts = value.split(':');
              final nextPhase = int.tryParse(parts.first);
              final nextTournament =
                  parts.length < 2 ? null : int.tryParse(parts.last);
              if (nextPhase == null || nextTournament == null) {
                return;
              }
              onChanged(
                rule.copyWith(
                  targetPhaseNumber: nextPhase,
                  targetTournamentNumber: nextTournament,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

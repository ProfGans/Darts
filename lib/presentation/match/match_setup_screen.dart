import 'package:flutter/material.dart';

import '../../data/repositories/computer_repository.dart';
import '../../data/repositories/player_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/x01/x01_models.dart';
import 'bob27_match_screen.dart';
import 'cricket_match_screen.dart';
import 'game_mode_models.dart';
import 'match_screen.dart';
import 'match_session_config.dart';

class MatchSetupScreen extends StatefulWidget {
  const MatchSetupScreen({
    required this.gameMode,
    super.key,
  });

  final GameMode gameMode;

  @override
  State<MatchSetupScreen> createState() => _MatchSetupScreenState();
}

class _MatchSetupScreenState extends State<MatchSetupScreen> {
  final TextEditingController _legsToWinController =
      TextEditingController(text: '3');
  final TextEditingController _setsToWinController =
      TextEditingController(text: '3');
  final Map<String, TextEditingController> _startScoreControllers =
      <String, TextEditingController>{};
  final List<TextEditingController> _customComputerAverageControllers =
      <TextEditingController>[];

  int _humanOpponents = 0;
  int _computerOpponents = 0;
  bool _useBullOff = true;
  String? _selectedStartingParticipantId;
  MatchMode _matchMode = MatchMode.legs;
  StartRequirement _startRequirement = StartRequirement.straightIn;
  CheckoutRequirement _checkoutRequirement = CheckoutRequirement.doubleOut;
  bool _bob27AllowNegativeScores = false;
  bool _bob27BonusMode = false;
  bool _bob27ReverseOrder = false;
  final List<String?> _selectedHumanIds = <String?>[];
  final List<String?> _selectedComputerIds = <String?>[];

  @override
  void initState() {
    super.initState();
    _syncSelections();
  }

  @override
  void dispose() {
    _legsToWinController.dispose();
    _setsToWinController.dispose();
    for (final controller in _startScoreControllers.values) {
      controller.dispose();
    }
    for (final controller in _customComputerAverageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _scoreControllerFor(String id, {int initialValue = 501}) {
    return _startScoreControllers.putIfAbsent(
      id,
      () => TextEditingController(text: '$initialValue'),
    );
  }

  void _syncSelections() {
    while (_selectedHumanIds.length < _humanOpponents) {
      _selectedHumanIds.add(null);
    }
    while (_selectedHumanIds.length > _humanOpponents) {
      _selectedHumanIds.removeLast();
    }

    while (_selectedComputerIds.length < _computerOpponents) {
      _selectedComputerIds.add(null);
    }
    while (_selectedComputerIds.length > _computerOpponents) {
      _selectedComputerIds.removeLast();
    }

    while (_customComputerAverageControllers.length < _computerOpponents) {
      _customComputerAverageControllers.add(
        TextEditingController(text: '60'),
      );
    }
    while (_customComputerAverageControllers.length > _computerOpponents) {
      _customComputerAverageControllers.removeLast().dispose();
    }

    for (var index = 0; index < _selectedComputerIds.length; index += 1) {
      final selectedValue = _selectedComputerIds[index];
      if (selectedValue != null &&
          selectedValue.startsWith('__custom_computer__')) {
        _selectedComputerIds[index] = _customComputerValue(index);
      }
    }
  }

  String _customComputerValue(int index) => '__custom_computer__$index';

  void _addOpponent({
    required bool isHuman,
  }) {
    setState(() {
      if (isHuman) {
        _humanOpponents += 1;
      } else {
        _computerOpponents += 1;
      }
      _syncSelections();
      if (!isHuman) {
        final newIndex = _computerOpponents - 1;
        _selectedComputerIds[newIndex] = _customComputerValue(newIndex);
      }
    });
  }

  void _removeHumanOpponent(int index) {
    if (index < 0 || index >= _selectedHumanIds.length) {
      return;
    }
    setState(() {
      _humanOpponents -= 1;
      _selectedHumanIds.removeAt(index);
    });
  }

  void _removeComputerOpponent(int index) {
    if (index < 0 || index >= _selectedComputerIds.length) {
      return;
    }
    setState(() {
      _computerOpponents -= 1;
      _selectedComputerIds.removeAt(index);
      _customComputerAverageControllers.removeAt(index).dispose();
    });
  }

  Future<void> _showAddOpponentSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Gegner hinzufuegen',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Waehle aus, ob du ein Spielerprofil oder einen Computergegner hinzufuegen moechtest.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B6A79),
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _addOpponent(isHuman: true);
                    },
                    icon: const Icon(Icons.people_alt_rounded),
                    label: const Text('Menschlicher Gegner'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _addOpponent(isHuman: false);
                    },
                    icon: const Icon(Icons.smart_toy_rounded),
                    label: const Text('Computergegner'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _startMatch() {
    final playerRepository = PlayerRepository.instance;
    final computerRepository = ComputerRepository.instance;
    final activePlayer = playerRepository.activePlayer;
    final legsToWin = int.tryParse(_legsToWinController.text.trim());
    final setsToWin = int.tryParse(_setsToWinController.text.trim());
    final isX01 = widget.gameMode == GameMode.x01;

    if (activePlayer == null ||
        (isX01 &&
            (legsToWin == null ||
                legsToWin <= 0 ||
                (_matchMode == MatchMode.sets &&
                    (setsToWin == null || setsToWin <= 0))))) {
      _showInfo('Bitte alle Werte gueltig eingeben.');
      return;
    }

    final participants = <MatchParticipantConfig>[
        MatchParticipantConfig(
          id: activePlayer.id,
          name: activePlayer.name,
          isHuman: true,
          startingScore: isX01
              ? int.tryParse(_scoreControllerFor(activePlayer.id).text.trim())
              : null,
        ),
      ];

    for (final playerId in _selectedHumanIds) {
      if (playerId == null) {
        _showInfo('Bitte fuer alle menschlichen Gegner ein Profil auswaehlen.');
        return;
      }
      final player = playerRepository.players
          .where((entry) => entry.id == playerId)
          .firstOrNull;
      if (player == null) {
        _showInfo('Ein ausgewaehltes Spielerprofil wurde nicht gefunden.');
        return;
      }
      participants.add(
        MatchParticipantConfig(
          id: player.id,
          name: player.name,
          isHuman: true,
          startingScore:
              isX01 ? int.tryParse(_scoreControllerFor(player.id).text.trim()) : null,
        ),
      );
    }

    for (final computerEntry in _selectedComputerIds.asMap().entries) {
      final computerIndex = computerEntry.key;
      final computerId = computerEntry.value;
      if (computerId == null) {
        _showInfo('Bitte fuer alle Computergegner einen Gegner auswaehlen.');
        return;
      }
      if (computerId == _customComputerValue(computerIndex)) {
        final customAverage = double.tryParse(
          _customComputerAverageControllers[computerIndex].text.trim(),
        );
        if (customAverage == null || customAverage <= 0 || customAverage > 180) {
          _showInfo('Bitte fuer jeden freien Computer einen gueltigen Average eingeben.');
          return;
        }
        final resolution = computerRepository.resolveSkillsForTheoreticalAverage(
          customAverage,
        );
        final customId = 'custom-computer-$computerIndex';
        participants.add(
          MatchParticipantConfig(
            id: customId,
            name: 'Build Your Opponent ${computerIndex + 1}',
            isHuman: false,
            startingScore:
                isX01 ? int.tryParse(_scoreControllerFor(customId).text.trim()) : null,
            botProfile: SettingsRepository.instance.createBotProfile(
              skill: resolution.skill,
              finishingSkill: resolution.finishingSkill,
            ),
          ),
        );
      } else {
        final computer = computerRepository.players
            .where((entry) => entry.id == computerId)
            .firstOrNull;
        if (computer == null) {
          _showInfo('Ein ausgewaehlter Computergegner wurde nicht gefunden.');
          return;
        }
        participants.add(
          MatchParticipantConfig(
            id: computer.id,
            name: computer.name,
            isHuman: false,
            startingScore: isX01
                ? int.tryParse(_scoreControllerFor(computer.id).text.trim())
                : null,
            botProfile: SettingsRepository.instance.createBotProfile(
              skill: computer.skill,
              finishingSkill: computer.finishingSkill,
            ),
          ),
        );
      }
    }

    if (isX01 &&
        participants.any(
          (entry) => entry.startingScore == null || entry.startingScore! <= 1,
        )) {
      _showInfo('Bitte fuer jeden Spieler einen gueltigen Startscore eingeben.');
      return;
    }

    final availableStarterIds = participants.map((entry) => entry.id).toSet();
    final startingParticipantId =
        availableStarterIds.contains(_selectedStartingParticipantId)
            ? _selectedStartingParticipantId
            : participants.first.id;

    final session = MatchSessionConfig(
      gameMode: widget.gameMode,
      participants: participants,
      matchConfig: MatchConfig(
        startScore: isX01 ? participants.first.startingScore! : 0,
        mode: isX01 ? _matchMode : MatchMode.legs,
        startRequirement:
            isX01 ? _startRequirement : StartRequirement.straightIn,
        checkoutRequirement:
            isX01 ? _checkoutRequirement : CheckoutRequirement.singleOut,
        legsToWin: isX01 ? legsToWin! : 1,
        setsToWin: isX01 && _matchMode == MatchMode.sets ? setsToWin! : 1,
        legsPerSet: isX01 && _matchMode == MatchMode.sets ? legsToWin! : 1,
      ),
      useBullOff: _useBullOff && participants.length > 1,
      startingParticipantId: _useBullOff ? null : startingParticipantId,
      bob27AllowNegativeScores: _bob27AllowNegativeScores,
      bob27BonusMode: _bob27BonusMode,
      bob27ReverseOrder: _bob27ReverseOrder,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => switch (widget.gameMode) {
          GameMode.x01 => MatchScreen(session: session),
          GameMode.cricket => CricketMatchScreen(session: session),
          GameMode.bob27 => Bob27MatchScreen(session: session),
        },
      ),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerRepository = PlayerRepository.instance;
    final computerRepository = ComputerRepository.instance;
    final activePlayer = playerRepository.activePlayer;
    final availableHumans = playerRepository.players
        .where((entry) => entry.id != activePlayer?.id)
        .toList();
    final availableComputers = computerRepository.players;
    final isX01 = widget.gameMode == GameMode.x01;
    final isBob27 = widget.gameMode == GameMode.bob27;
    final previewParticipants = <({String id, String name})>[
      if (activePlayer != null) (id: activePlayer.id, name: activePlayer.name),
      ..._selectedHumanIds
          .whereType<String>()
          .map(
            (id) => playerRepository.players
                .where((entry) => entry.id == id)
                .map((entry) => (id: entry.id, name: entry.name))
                .firstOrNull,
          )
          .whereType<({String id, String name})>(),
      ..._selectedComputerIds
          .asMap()
          .entries
          .map((entry) {
            final id = entry.value;
            if (id == null) {
              return null;
            }
            if (id == _customComputerValue(entry.key)) {
              return (
                id: 'custom-computer-${entry.key}',
                name: 'Build Your Opponent ${entry.key + 1}',
              );
            }
            return computerRepository.players
                .where((player) => player.id == id)
                .map((player) => (id: player.id, name: player.name))
                .firstOrNull;
          })
          .whereType<({String id, String name})>(),
    ];
    final effectiveStartingParticipantId = previewParticipants.any(
      (entry) => entry.id == _selectedStartingParticipantId,
    )
        ? _selectedStartingParticipantId
        : previewParticipants.isNotEmpty
            ? previewParticipants.first.id
            : null;
    for (final participant in previewParticipants) {
      if (isX01) {
        _scoreControllerFor(participant.id);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Setup'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: <Widget>[
            Text(
              '${widget.gameMode.title} konfigurieren',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Weniger Schritte, klarer Ablauf: Teilnehmer, Format, Start und los.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5B6A79),
                  ),
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Startspieler',
              child: activePlayer == null
                  ? const Text('Kein aktives Spielerprofil vorhanden.')
                  : Column(
                      children: <Widget>[
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Ausbullen vor dem Match'),
                          subtitle: Text(
                            _useBullOff
                                ? 'Startspieler wird vor dem Match per Bull und Single Bull bestimmt.'
                                : 'Startspieler wird vor dem Match fest ausgewaehlt.',
                          ),
                          value: _useBullOff,
                          onChanged: (value) {
                            setState(() {
                              _useBullOff = value;
                            });
                          },
                        ),
                        if (!_useBullOff) ...<Widget>[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: effectiveStartingParticipantId,
                            decoration: const InputDecoration(
                              labelText: 'Wer beginnt',
                            ),
                            items: previewParticipants
                                .map(
                                  (participant) => DropdownMenuItem<String>(
                                    value: participant.id,
                                    child: Text(participant.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStartingParticipantId = value;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Gegnerauswahl',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _showAddOpponentSheet,
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('Gegner hinzufuegen'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F8FB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Du spielst mit ${1 + _humanOpponents + _computerOpponents} Teilnehmern: '
                      '1 aktives Profil, $_humanOpponents menschlich, $_computerOpponents Computer.'
                      '${1 + _humanOpponents + _computerOpponents == 1 ? ' Solo-Spiel ist moeglich.' : ''}'
                      '${isBob27 ? ' Alle Teilnehmer spielen pro Runde auf dasselbe Zielfeld.' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4F5E6C),
                          ),
                    ),
                  ),
                  if (_humanOpponents > 0) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Spielerprofile auswaehlen',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...List<Widget>.generate(_humanOpponents, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedHumanIds[index],
                                decoration: InputDecoration(
                                  labelText: 'Spieler ${index + 2}',
                                ),
                                items: availableHumans
                                    .map(
                                      (player) => DropdownMenuItem<String>(
                                        value: player.id,
                                        child: Text(player.name),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedHumanIds[index] = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: () => _removeHumanOpponent(index),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Gegner entfernen',
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  if (_computerOpponents > 0) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      'Computergegner auswaehlen',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...List<Widget>.generate(_computerOpponents, (index) {
                      final customValue = _customComputerValue(index);
                      final isCustomComputer =
                          _selectedComputerIds[index] == customValue;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          children: <Widget>[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _selectedComputerIds[index],
                                    decoration: InputDecoration(
                                      labelText: 'Computer ${index + 1}',
                                    ),
                                    items: <DropdownMenuItem<String>>[
                                      ...availableComputers.map(
                                        (computer) => DropdownMenuItem<String>(
                                          value: computer.id,
                                          child: Text(
                                            '${computer.name} (${computer.theoreticalAverage.toStringAsFixed(1)})',
                                          ),
                                        ),
                                      ),
                                      DropdownMenuItem<String>(
                                        value: customValue,
                                        child: const Text(
                                          'Build Your Opponent',
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedComputerIds[index] = value;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  onPressed: () => _removeComputerOpponent(index),
                                  icon: const Icon(Icons.close_rounded),
                                  tooltip: 'Gegner entfernen',
                                ),
                              ],
                            ),
                            if (isCustomComputer) ...<Widget>[
                              const SizedBox(height: 10),
                              TextField(
                                controller: _customComputerAverageControllers[index],
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Theoretischer Average',
                                  suffixText: 'Avg',
                                  helperText:
                                      'Gib den theoretischen 3-Dart-Average ein.',
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SetupCard(
              title: 'Format',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (isX01) ...<Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ModeChip(
                          label: 'Legs',
                          icon: Icons.flag_rounded,
                          selected: _matchMode == MatchMode.legs,
                          onTap: () {
                            setState(() {
                              _matchMode = MatchMode.legs;
                            });
                          },
                        ),
                        _ModeChip(
                          label: 'Sets',
                          icon: Icons.layers_rounded,
                          selected: _matchMode == MatchMode.sets,
                          onTap: () {
                            setState(() {
                              _matchMode = MatchMode.sets;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<StartRequirement>(
                      initialValue: _startRequirement,
                      decoration: const InputDecoration(
                        labelText: 'In',
                      ),
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
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _startRequirement = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CheckoutRequirement>(
                      initialValue: _checkoutRequirement,
                      decoration: const InputDecoration(
                        labelText: 'Checkout',
                      ),
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
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _checkoutRequirement = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _legsToWinController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _matchMode == MatchMode.legs
                            ? 'Legs zum Sieg'
                            : 'Legs pro Satz',
                          ),
                    ),
                    if (_matchMode == MatchMode.sets) ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _setsToWinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Saetze zum Sieg',
                        ),
                      ),
                    ],
                  ] else if (isBob27) ...<Widget>[
                    Text(
                      'Varianten',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Negativscore erlauben'),
                      subtitle: const Text(
                        'Easy-Variante: Jeder Teilnehmer spielt bis Bull weiter, auch wenn der Score 0 oder darunter faellt.',
                      ),
                      value: _bob27AllowNegativeScores,
                      onChanged: (value) {
                        setState(() {
                          _bob27AllowNegativeScores = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bonus fuer 2 oder 3 Treffer'),
                      subtitle: const Text(
                        'Variante mit zusaetzlichen +10 Punkten, wenn in einer Runde mindestens 2 Treffer auf dem Zielfeld gelingen.',
                      ),
                      value: _bob27BonusMode,
                      onChanged: (value) {
                        setState(() {
                          _bob27BonusMode = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reverse'),
                      subtitle: const Text(
                        'Spielt die Reihenfolge umgekehrt: Bull, D20 bis D1.',
                      ),
                      value: _bob27ReverseOrder,
                      onChanged: (value) {
                        setState(() {
                          _bob27ReverseOrder = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Klassisch startest du mit 27 Punkten und spielst D1 bis Bull. '
                        'Jeder Treffer auf das Ziel bringt den Double-Wert, jeder Fehldart zieht denselben Wert ab. '
                        'Ohne Easy-Variante scheidet ein Teilnehmer aus, sobald sein Score 0 oder darunter erreicht.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4F5E6C),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ] else ...<Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Standard Cricket: Ziele sind 20, 19, 18, 17, 16, 15 und Bull. '
                        'Jedes Ziel braucht 3 Marks. Ueberzaehlige Treffer zaehlen als Punkte, '
                        'solange Gegner das Feld noch offen haben.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF4F5E6C),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isX01) ...<Widget>[
              const SizedBox(height: 16),
              _SetupCard(
                title: 'Startscores',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Jeder Teilnehmer kann mit einem eigenen X01-Startscore beginnen.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5B6A79),
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...previewParticipants.map(
                      (participant) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _scoreControllerFor(participant.id),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: participant.name,
                            suffixText: 'Startscore',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startMatch,
              child: const Text('Match starten'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF17324D) : const Color(0xFFF5F8FB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF5B6A79),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : const Color(0xFF324354),
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

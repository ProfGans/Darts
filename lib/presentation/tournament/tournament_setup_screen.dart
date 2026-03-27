import 'package:flutter/material.dart';

import '../../data/repositories/tournament_repository.dart';
import 'tournament_basics_form.dart';
import 'tournament_bracket_screen.dart';
import 'tournament_form_models.dart';

class TournamentSetupScreen extends StatefulWidget {
  const TournamentSetupScreen({super.key});

  @override
  State<TournamentSetupScreen> createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Players Championship');
  final TextEditingController _computerCountController =
      TextEditingController(text: '7');
  final TextEditingController _minimumAverageController =
      TextEditingController(text: '0');
  final TextEditingController _maximumAverageController =
      TextEditingController(text: '180');

  TournamentFormData _formData = const TournamentFormData(
    fieldSizeInput: '8',
    legsValue: 3,
  );
  bool _includeHumanPlayer = true;

  @override
  void dispose() {
    _nameController.dispose();
    _computerCountController.dispose();
    _minimumAverageController.dispose();
    _maximumAverageController.dispose();
    super.dispose();
  }

  void _startTournament() {
    final fieldSize = _formData.parsedFieldSize;
    final startScore = _formData.parsedStartScore;
    if (fieldSize == null || fieldSize < 2 || startScore == null || startScore <= 1) {
      return;
    }
    final humanSlots = _includeHumanPlayer ? 1 : 0;
    final requestedComputerCount =
        int.tryParse(_computerCountController.text.trim()) ?? 0;
    final computerOpponentCount = requestedComputerCount.clamp(
      0,
      fieldSize > humanSlots ? fieldSize - humanSlots : 0,
    );
    final minimumAverage =
        _tryParseAverage(_minimumAverageController.text) ?? 0;
    final maximumAverage =
        _tryParseAverage(_maximumAverageController.text) ?? 180;
    final averageFloor =
        minimumAverage <= maximumAverage ? minimumAverage : maximumAverage;
    final averageCeiling =
        minimumAverage <= maximumAverage ? maximumAverage : minimumAverage;

    TournamentRepository.instance.createTournament(
      name: _nameController.text.trim().isEmpty
          ? 'Turnier'
          : _nameController.text.trim(),
      game: _formData.game,
      format: _formData.format,
      fieldSize: fieldSize,
      matchMode: _formData.matchMode,
      legsToWin: _formData.effectiveLegsToWin,
      startScore: startScore,
      startRequirement: _formData.startRequirement,
      checkoutRequirement: _formData.checkoutRequirement,
      setsToWin: _formData.effectiveSetsToWin,
      legsPerSet: _formData.effectiveLegsPerSet,
      roundDistanceValues: _formData.effectiveRoundDistanceValues,
      pointsForWin: _formData.pointsForWin,
      pointsForDraw: _formData.pointsForDraw,
      roundRobinRepeats: _formData.roundRobinRepeats,
      playoffQualifierCount: _formData.playoffQualifierCount,
      includeHumanPlayer: _includeHumanPlayer,
      computerOpponentCount: computerOpponentCount,
      minimumComputerAverage: averageFloor,
      maximumComputerAverage: averageCeiling,
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TournamentBracketScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Turnier Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Turnier erstellen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TournamentBasicsForm(
                      nameController: _nameController,
                      formData: _formData,
                      onChanged: (value) {
                        setState(() {
                          _formData = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _includeHumanPlayer,
                      onChanged: (value) {
                        setState(() {
                          _includeHumanPlayer = value;
                        });
                      },
                      title: const Text('Aktiven Spieler aufnehmen'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Teilnehmerfeld',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _computerCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Computergegner',
                        helperText:
                            'Wenn weniger Gegner verfuegbar sind, entstehen automatisch Freilose.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _minimumAverageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Min. Average',
                              helperText: 'Standard ist offen.',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _maximumAverageController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Max. Average',
                              helperText: 'Standard ist offen.',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _startTournament,
                      child: const Text('Turnier starten'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double? _tryParseAverage(String input) {
    final normalized = input.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}

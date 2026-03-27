import 'package:flutter/material.dart';

import '../../data/repositories/settings_repository.dart';
import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_match_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import '../../domain/x01/x01_models.dart';

class BotMatchSimulatorScreen extends StatefulWidget {
  const BotMatchSimulatorScreen({super.key});

  @override
  State<BotMatchSimulatorScreen> createState() => _BotMatchSimulatorScreenState();
}

class _BotMatchSimulatorScreenState extends State<BotMatchSimulatorScreen> {
  final TextEditingController _playerANameController =
      TextEditingController(text: 'Bot A');
  final TextEditingController _playerBNameController =
      TextEditingController(text: 'Bot B');
  final TextEditingController _playerASkillController =
      TextEditingController(text: '750');
  final TextEditingController _playerAFinishingController =
      TextEditingController(text: '750');
  final TextEditingController _playerBSkillController =
      TextEditingController(text: '650');
  final TextEditingController _playerBFinishingController =
      TextEditingController(text: '650');

  SimulatedMatchResult? _result;
  String? _errorMessage;
  bool _isRunning = false;

  @override
  void dispose() {
    _playerANameController.dispose();
    _playerBNameController.dispose();
    _playerASkillController.dispose();
    _playerAFinishingController.dispose();
    _playerBSkillController.dispose();
    _playerBFinishingController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final botEngine = BotEngine();
      final matchEngine = X01MatchEngine();
      final simulator = X01MatchSimulator(
        matchEngine: matchEngine,
        botEngine: botEngine,
      );

      final playerA = SimulatedPlayer(
        name: _playerANameController.text.trim().isEmpty
            ? 'Bot A'
            : _playerANameController.text.trim(),
        profile: SettingsRepository.instance.createBotProfile(
          skill: _readSkill(_playerASkillController.text),
          finishingSkill: _readSkill(_playerAFinishingController.text),
        ),
      );
      final playerB = SimulatedPlayer(
        name: _playerBNameController.text.trim().isEmpty
            ? 'Bot B'
            : _playerBNameController.text.trim(),
        profile: SettingsRepository.instance.createBotProfile(
          skill: _readSkill(_playerBSkillController.text),
          finishingSkill: _readSkill(_playerBFinishingController.text),
        ),
      );

      final result = simulator.simulateAutoMatch(
        playerA: playerA,
        playerB: playerB,
        config: const MatchConfig(
          startScore: 501,
          mode: MatchMode.legs,
          checkoutRequirement: CheckoutRequirement.doubleOut,
          legsToWin: 6,
        ),
      );

      setState(() {
        _result = result;
      });
    } on FormatException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  int _readSkill(String rawValue) {
    final parsed = int.tryParse(rawValue.trim());
    if (parsed == null) {
      throw const FormatException('Bitte nur gueltige Ganzzahlen fuer Skill eingeben.');
    }
    return parsed.clamp(1, 1000);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Match Simulator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: <Widget>[
                _buildPlayerCard(
                  title: 'Spieler A',
                  nameController: _playerANameController,
                  skillController: _playerASkillController,
                  finishingController: _playerAFinishingController,
                ),
                _buildPlayerCard(
                  title: 'Spieler B',
                  nameController: _playerBNameController,
                  skillController: _playerBSkillController,
                  finishingController: _playerBFinishingController,
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isRunning ? null : _runSimulation,
              child: Text(_isRunning ? 'Simuliere...' : 'Match simulieren'),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_result != null) ...<Widget>[
              const SizedBox(height: 24),
              _buildResultCard(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required String title,
    required TextEditingController nameController,
    required TextEditingController skillController,
    required TextEditingController finishingController,
  }) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: skillController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Skill',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: finishingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Finishing Skill',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(SimulatedMatchResult result) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Ergebnis',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Sieger: ${result.winner.name}'),
            Text('Score: ${result.scoreText}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: <Widget>[
                _buildStatsColumn(
                  title: 'Spieler A',
                  average: result.averageA,
                  first9Average: result.first9AverageA,
                  checkoutRate: result.checkoutRateA,
                  doubleAttempts: result.doubleAttemptsA,
                  successfulChecks: result.successfulChecksA,
                  scores100Plus: result.scores100PlusA,
                  scores140Plus: result.scores140PlusA,
                  scores180: result.scores180A,
                  legDartsDistribution: result.legDartsDistributionA,
                ),
                _buildStatsColumn(
                  title: 'Spieler B',
                  average: result.averageB,
                  first9Average: result.first9AverageB,
                  checkoutRate: result.checkoutRateB,
                  doubleAttempts: result.doubleAttemptsB,
                  successfulChecks: result.successfulChecksB,
                  scores100Plus: result.scores100PlusB,
                  scores140Plus: result.scores140PlusB,
                  scores180: result.scores180B,
                  legDartsDistribution: result.legDartsDistributionB,
                ),
              ],
            ),
            const SizedBox(height: 24),
             Text(
               'Leg fuer Leg',
               style: Theme.of(context).textTheme.titleMedium,
             ),
             const SizedBox(height: 12),
             _buildLegSummaryTable(_result!),
             const SizedBox(height: 24),
             Text(
               'Bot Ziel-Debug',
               style: Theme.of(context).textTheme.titleMedium,
             ),
             const SizedBox(height: 12),
             _buildVisitDebugSections(_result!),
           ],
         ),
       ),
     );
  }

  Widget _buildStatsColumn({
    required String title,
    required double average,
    required double first9Average,
    required double checkoutRate,
    required int doubleAttempts,
    required int successfulChecks,
    required int scores100Plus,
    required int scores140Plus,
    required int scores180,
    required Map<int, int> legDartsDistribution,
  }) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text('Average: ${average.toStringAsFixed(1)}'),
          Text('First 9: ${first9Average.toStringAsFixed(1)}'),
          Text('Checkout: ${checkoutRate.toStringAsFixed(1)}%'),
          Text('Checks: $successfulChecks / $doubleAttempts'),
          Text('100+: $scores100Plus'),
          Text('140+: $scores140Plus'),
          Text('180er: $scores180'),
          const SizedBox(height: 12),
          Text(
            'Leg-Darts',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _buildLegDartsTable(legDartsDistribution),
        ],
      ),
    );
  }

  Widget _buildLegDartsTable(Map<int, int> distribution) {
    if (distribution.isEmpty) {
      return const Text('Noch keine gewonnenen Legs.');
    }

    final rows = distribution.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1),
      },
      border: TableBorder.symmetric(
        inside: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            _buildTableCell(
              'Darts',
              isHeader: true,
            ),
            _buildTableCell(
              'Anzahl',
              isHeader: true,
            ),
          ],
        ),
        ...rows.map(
          (entry) => TableRow(
            children: <Widget>[
              _buildTableCell('${entry.key}'),
              _buildTableCell('${entry.value}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text, {
    bool isHeader = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        text,
        style: isHeader
            ? Theme.of(context).textTheme.labelLarge
            : Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildLegSummaryTable(SimulatedMatchResult result) {
    if (result.legSummaries.isEmpty) {
      return const Text('Noch keine Leg-Daten vorhanden.');
    }

    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(0.9),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1.2),
        6: FlexColumnWidth(1),
      },
      border: TableBorder.all(
        color: Theme.of(context).dividerColor,
      ),
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            _buildTableCell('Leg', isHeader: true),
            _buildTableCell('3DA A', isHeader: true),
            _buildTableCell('Rest A', isHeader: true),
            _buildTableCell('Sieger', isHeader: true),
            _buildTableCell('Rest B', isHeader: true),
            _buildTableCell('3DA B', isHeader: true),
            _buildTableCell('Darts', isHeader: true),
          ],
        ),
        ...result.legSummaries.map(
          (summary) => TableRow(
            children: <Widget>[
              _buildTableCell('${summary.legNumber}'),
              _buildTableCell(summary.legAverageA.toStringAsFixed(1)),
              _buildTableCell('${summary.remainingScoreA}'),
              _buildTableCell(
                summary.winnerKey == 'A' ? 'A' : 'B',
              ),
              _buildTableCell('${summary.remainingScoreB}'),
              _buildTableCell(summary.legAverageB.toStringAsFixed(1)),
              _buildTableCell(
                summary.winnerKey == 'A'
                    ? '${summary.legDartsA}'
                    : '${summary.legDartsB}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisitDebugSections(SimulatedMatchResult result) {
    if (result.legSummaries.isEmpty) {
      return const Text('Keine Debug-Daten vorhanden.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: result.legSummaries.map((summary) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Leg ${summary.legNumber}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (summary.visitDebugs.isEmpty)
                    const Text('Keine Visit-Debugs gespeichert.')
                  else
                    ...summary.visitDebugs.map(_buildVisitDebugTile),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVisitDebugTile(SimulatedVisitDebug debug) {
    final targetText = _formatThrowList(debug.targets);
    final hitText = _formatThrowList(debug.throws);
    final routeText = debug.plannedRoutes.isEmpty
        ? ''
        : debug.plannedRoutes
            .map(_formatThrowList)
            .where((entry) => entry.isNotEmpty)
            .join(' | ');
    final reasonText = debug.targetReasons.where((entry) => entry.isNotEmpty).join(' | ');
    final outcome = debug.checkedOut
        ? 'Checkout'
        : debug.busted
            ? 'Bust'
            : 'Rest ${debug.endScore}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${debug.playerName}: ${debug.startScore} -> $outcome'),
            const SizedBox(height: 4),
            Text('Ziele: $targetText'),
            Text('Treffer: $hitText'),
            if (reasonText.isNotEmpty) Text('Grund: $reasonText'),
            if (routeText.isNotEmpty) Text('Planroute: $routeText'),
            Text('Gescoret: ${debug.scoredPoints}'),
          ],
        ),
      ),
    );
  }

  String _formatThrowList(List<DartThrowResult> throws) {
    if (throws.isEmpty) {
      return '-';
    }
    return throws.map((entry) => entry.label).join(' - ');
  }
}

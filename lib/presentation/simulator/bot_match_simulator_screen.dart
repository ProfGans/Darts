import 'package:flutter/material.dart';

import '../../data/background/simulation_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_match_simulator.dart';

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
  String _statusLabel = '';

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
      _statusLabel = 'Bot-Match wird vorbereitet';
    });

    try {
      final playerAName = _playerANameController.text.trim().isEmpty
          ? 'Bot A'
          : _playerANameController.text.trim();
      final playerBName = _playerBNameController.text.trim().isEmpty
          ? 'Bot B'
          : _playerBNameController.text.trim();
      final playerAProfile = SettingsRepository.instance.createBotProfile(
        skill: _readSkill(_playerASkillController.text),
        finishingSkill: _readSkill(_playerAFinishingController.text),
      );
      final playerBProfile = SettingsRepository.instance.createBotProfile(
        skill: _readSkill(_playerBSkillController.text),
        finishingSkill: _readSkill(_playerBFinishingController.text),
      );

      await Future<void>.delayed(Duration.zero);
      final handle = SimulationService.instance.startJob<Map<String, Object?>>(
        taskType: 'simulate_bot_match',
        initialLabel: 'Bot-Match wird simuliert',
        payload: <String, Object?>{
          'playerAName': playerAName,
          'playerASkill': playerAProfile.skill,
          'playerAFinishingSkill': playerAProfile.finishingSkill,
          'playerBName': playerBName,
          'playerBSkill': playerBProfile.skill,
          'playerBFinishingSkill': playerBProfile.finishingSkill,
          'radiusCalibrationPercent': playerAProfile.radiusCalibrationPercent,
          'simulationSpreadPercent': playerAProfile.simulationSpreadPercent,
        },
      );
      void updateStatus() {
        if (!mounted) {
          return;
        }
        setState(() {
          _statusLabel = handle.label;
        });
      }

      handle.addListener(updateStatus);
      late final Map<String, Object?> resultMap;
      try {
        resultMap = await handle.result;
      } finally {
        handle.removeListener(updateStatus);
      }
      final result = _matchResultFromMap(resultMap);

      if (!mounted) {
        return;
      }
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
          _statusLabel = '';
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
            if (_isRunning) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 6,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: 8),
              Text(
                _statusLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF556372),
                    ),
              ),
            ],
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

  SimulatedMatchResult _matchResultFromMap(Map<String, Object?> map) {
    final winnerProfile = _botProfileFromMap(
      (map['winnerProfile'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
    return SimulatedMatchResult(
      winner: SimulatedPlayer(
        name: (map['winnerName'] as String?) ?? 'Sieger',
        profile: winnerProfile,
      ),
      scoreText: (map['scoreText'] as String?) ?? '',
      averageA: ((map['averageA'] as num?) ?? 0).toDouble(),
      averageB: ((map['averageB'] as num?) ?? 0).toDouble(),
      first9AverageA: ((map['first9AverageA'] as num?) ?? 0).toDouble(),
      first9AverageB: ((map['first9AverageB'] as num?) ?? 0).toDouble(),
      checkoutRateA: ((map['checkoutRateA'] as num?) ?? 0).toDouble(),
      checkoutRateB: ((map['checkoutRateB'] as num?) ?? 0).toDouble(),
      doubleAttemptsA: (map['doubleAttemptsA'] as num?)?.toInt() ?? 0,
      doubleAttemptsB: (map['doubleAttemptsB'] as num?)?.toInt() ?? 0,
      successfulChecksA: (map['successfulChecksA'] as num?)?.toInt() ?? 0,
      successfulChecksB: (map['successfulChecksB'] as num?)?.toInt() ?? 0,
      scores100PlusA: (map['scores100PlusA'] as num?)?.toInt() ?? 0,
      scores100PlusB: (map['scores100PlusB'] as num?)?.toInt() ?? 0,
      scores140PlusA: (map['scores140PlusA'] as num?)?.toInt() ?? 0,
      scores140PlusB: (map['scores140PlusB'] as num?)?.toInt() ?? 0,
      scores180A: (map['scores180A'] as num?)?.toInt() ?? 0,
      scores180B: (map['scores180B'] as num?)?.toInt() ?? 0,
      legDartsDistributionA: _distributionFromMap(
        (map['legDartsDistributionA'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      legDartsDistributionB: _distributionFromMap(
        (map['legDartsDistributionB'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      legSummaries: ((map['legSummaries'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map(
            (entry) => _legSummaryFromMap(entry.cast<String, Object?>()),
          )
          .toList(growable: false),
      playerStatsA: _playerStatsFromMap(
        (map['playerStatsA'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      playerStatsB: _playerStatsFromMap(
        (map['playerStatsB'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      legsA: (map['legsA'] as num?)?.toInt() ?? 0,
      legsB: (map['legsB'] as num?)?.toInt() ?? 0,
      setsA: (map['setsA'] as num?)?.toInt() ?? 0,
      setsB: (map['setsB'] as num?)?.toInt() ?? 0,
    );
  }

  BotProfile _botProfileFromMap(Map<String, Object?> map) {
    return BotProfile(
      skill: (map['skill'] as num?)?.toInt() ?? 1,
      finishingSkill: (map['finishingSkill'] as num?)?.toInt() ?? 1,
      radiusCalibrationPercent:
          (map['radiusCalibrationPercent'] as num?)?.toInt() ?? 92,
      simulationSpreadPercent:
          (map['simulationSpreadPercent'] as num?)?.toInt() ?? 115,
    );
  }

  Map<int, int> _distributionFromMap(Map<String, Object?> map) {
    return map.map(
      (key, value) => MapEntry(
        int.tryParse(key) ?? 0,
        (value as num?)?.toInt() ?? 0,
      ),
    )..remove(0);
  }

  SimulatedLegSummary _legSummaryFromMap(Map<String, Object?> map) {
    return SimulatedLegSummary(
      legNumber: (map['legNumber'] as num?)?.toInt() ?? 0,
      starterKey: (map['starterKey'] as String?) ?? 'A',
      winnerKey: (map['winnerKey'] as String?) ?? 'A',
      decidingLeg: (map['decidingLeg'] as bool?) ?? false,
      scoreBeforeStartA: (map['scoreBeforeStartA'] as num?)?.toInt() ?? 501,
      scoreBeforeStartB: (map['scoreBeforeStartB'] as num?)?.toInt() ?? 501,
      legDartsA: (map['legDartsA'] as num?)?.toInt() ?? 0,
      legDartsB: (map['legDartsB'] as num?)?.toInt() ?? 0,
      legAverageA: ((map['legAverageA'] as num?) ?? 0).toDouble(),
      legAverageB: ((map['legAverageB'] as num?) ?? 0).toDouble(),
      remainingScoreA: (map['remainingScoreA'] as num?)?.toInt() ?? 0,
      remainingScoreB: (map['remainingScoreB'] as num?)?.toInt() ?? 0,
      visitDebugs: ((map['visitDebugs'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _visitDebugFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
    );
  }

  SimulatedVisitDebug _visitDebugFromMap(Map<String, Object?> map) {
    return SimulatedVisitDebug(
      playerName: (map['playerName'] as String?) ?? '',
      startScore: (map['startScore'] as num?)?.toInt() ?? 0,
      endScore: (map['endScore'] as num?)?.toInt() ?? 0,
      scoredPoints: (map['scoredPoints'] as num?)?.toInt() ?? 0,
      checkedOut: (map['checkedOut'] as bool?) ?? false,
      busted: (map['busted'] as bool?) ?? false,
      targets: ((map['targets'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      throws: ((map['throws'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      targetReasons: ((map['targetReasons'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      plannedRoutes: ((map['plannedRoutes'] as List?) ?? const <Object?>[])
          .whereType<List>()
          .map(
            (route) => route
                .whereType<Map>()
                .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  SimulatedPlayerStats _playerStatsFromMap(Map<String, Object?> map) {
    return SimulatedPlayerStats(
      pointsScored: (map['pointsScored'] as num?)?.toInt() ?? 0,
      dartsThrown: (map['dartsThrown'] as num?)?.toInt() ?? 0,
      visits: (map['visits'] as num?)?.toInt() ?? 0,
      legsWon: (map['legsWon'] as num?)?.toInt() ?? 0,
      legsPlayed: (map['legsPlayed'] as num?)?.toInt() ?? 0,
      legsStarted: (map['legsStarted'] as num?)?.toInt() ?? 0,
      legsWonAsStarter: (map['legsWonAsStarter'] as num?)?.toInt() ?? 0,
      legsWonWithoutStarter: (map['legsWonWithoutStarter'] as num?)?.toInt() ?? 0,
      scores0To40: (map['scores0To40'] as num?)?.toInt() ?? 0,
      scores41To59: (map['scores41To59'] as num?)?.toInt() ?? 0,
      scores60Plus: (map['scores60Plus'] as num?)?.toInt() ?? 0,
      scores100Plus: (map['scores100Plus'] as num?)?.toInt() ?? 0,
      scores140Plus: (map['scores140Plus'] as num?)?.toInt() ?? 0,
      scores171Plus: (map['scores171Plus'] as num?)?.toInt() ?? 0,
      scores180: (map['scores180'] as num?)?.toInt() ?? 0,
      checkoutAttempts: (map['checkoutAttempts'] as num?)?.toInt() ?? 0,
      successfulCheckouts: (map['successfulCheckouts'] as num?)?.toInt() ?? 0,
      checkoutAttempts1Dart:
          (map['checkoutAttempts1Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts2Dart:
          (map['checkoutAttempts2Dart'] as num?)?.toInt() ?? 0,
      checkoutAttempts3Dart:
          (map['checkoutAttempts3Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts1Dart:
          (map['successfulCheckouts1Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts2Dart:
          (map['successfulCheckouts2Dart'] as num?)?.toInt() ?? 0,
      successfulCheckouts3Dart:
          (map['successfulCheckouts3Dart'] as num?)?.toInt() ?? 0,
      thirdDartCheckoutAttempts:
          (map['thirdDartCheckoutAttempts'] as num?)?.toInt() ?? 0,
      thirdDartCheckouts:
          (map['thirdDartCheckouts'] as num?)?.toInt() ?? 0,
      bullCheckoutAttempts:
          (map['bullCheckoutAttempts'] as num?)?.toInt() ?? 0,
      bullCheckouts: (map['bullCheckouts'] as num?)?.toInt() ?? 0,
      functionalDoubleAttempts:
          (map['functionalDoubleAttempts'] as num?)?.toInt() ?? 0,
      functionalDoubleSuccesses:
          (map['functionalDoubleSuccesses'] as num?)?.toInt() ?? 0,
      firstNinePoints: ((map['firstNinePoints'] as num?) ?? 0).toDouble(),
      firstNineDarts: (map['firstNineDarts'] as num?)?.toInt() ?? 0,
      highestFinish: (map['highestFinish'] as num?)?.toInt() ?? 0,
      bestLegDarts: (map['bestLegDarts'] as num?)?.toInt() ?? 0,
      totalFinishValue: (map['totalFinishValue'] as num?)?.toInt() ?? 0,
      withThrowPoints: (map['withThrowPoints'] as num?)?.toInt() ?? 0,
      withThrowDarts: (map['withThrowDarts'] as num?)?.toInt() ?? 0,
      againstThrowPoints: (map['againstThrowPoints'] as num?)?.toInt() ?? 0,
      againstThrowDarts: (map['againstThrowDarts'] as num?)?.toInt() ?? 0,
      decidingLegPoints: (map['decidingLegPoints'] as num?)?.toInt() ?? 0,
      decidingLegDarts: (map['decidingLegDarts'] as num?)?.toInt() ?? 0,
      decidingLegsPlayed: (map['decidingLegsPlayed'] as num?)?.toInt() ?? 0,
      decidingLegsWon: (map['decidingLegsWon'] as num?)?.toInt() ?? 0,
      won9Darters: (map['won9Darters'] as num?)?.toInt() ?? 0,
      won12Darters: (map['won12Darters'] as num?)?.toInt() ?? 0,
      won15Darters: (map['won15Darters'] as num?)?.toInt() ?? 0,
      won18Darters: (map['won18Darters'] as num?)?.toInt() ?? 0,
    );
  }

  DartThrowResult _throwFromMap(Map<String, Object?> map) {
    return DartThrowResult(
      label: (map['label'] as String?) ?? '',
      baseValue: (map['baseValue'] as num?)?.toInt() ?? 0,
      scoredPoints: (map['scoredPoints'] as num?)?.toInt() ?? 0,
      isDouble: (map['isDouble'] as bool?) ?? false,
      isTriple: (map['isTriple'] as bool?) ?? false,
      isBull: (map['isBull'] as bool?) ?? false,
      isMiss: (map['isMiss'] as bool?) ?? false,
    );
  }
}

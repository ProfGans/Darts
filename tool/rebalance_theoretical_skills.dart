import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_flutter_app/domain/bot/bot_engine.dart';
import 'package:dart_flutter_app/domain/x01/x01_models.dart';

const int _legacyRadiusBaselinePercent = 92;
const int _legacySimulationSpreadBaselinePercent = 115;
const int _radiusDisplayNeutralPercent = 95;

class _SettingsSnapshot {
  const _SettingsSnapshot({
    required this.radiusCalibrationPercent,
    required this.simulationSpreadPercent,
  });

  final int radiusCalibrationPercent;
  final int simulationSpreadPercent;
}

class _SkillResolutionCandidate {
  const _SkillResolutionCandidate({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
    required this.error,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
  final double error;

  int get gap => (skill - finishingSkill).abs();
  int get finishingLead => max(0, finishingSkill - skill);
}

Future<void> main() async {
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) {
    stderr.writeln('APPDATA is not available.');
    exitCode = 1;
    return;
  }

  final baseDir = Directory('$appData${Platform.pathSeparator}DartFlutterApp');
  final playersFile =
      File('${baseDir.path}${Platform.pathSeparator}computer_players.json');
  final settingsFile =
      File('${baseDir.path}${Platform.pathSeparator}app_settings.json');

  if (!playersFile.existsSync()) {
    stderr.writeln('computer_players.json not found in ${baseDir.path}.');
    exitCode = 1;
    return;
  }

  final settings = _loadSettings(settingsFile);
  final botEngine = BotEngine();

  final rawPlayers = jsonDecode(playersFile.readAsStringSync()) as Map<String, dynamic>;
  final players = (rawPlayers['players'] as List<dynamic>? ?? const <dynamic>[])
      .map((entry) => (entry as Map).cast<String, dynamic>())
      .toList();

  var changed = 0;
  final now = DateTime.now().toIso8601String();

  for (final player in players) {
    final targetAverage = (player['theoreticalAverage'] as num?)?.toDouble() ?? 0.0;
    final resolution = _resolveSkillsForTheoreticalAverage(
      targetAverage: targetAverage,
      botEngine: botEngine,
      settings: settings,
    );
    final changedHere = player['skill'] != resolution.skill ||
        player['finishingSkill'] != resolution.finishingSkill ||
        ((player['theoreticalAverage'] as num?)?.toDouble() ?? 0.0) !=
            resolution.theoreticalAverage;
    if (changedHere) {
      changed += 1;
      player['skill'] = resolution.skill;
      player['finishingSkill'] = resolution.finishingSkill;
      player['theoreticalAverage'] = resolution.theoreticalAverage;
      player['updatedAt'] = now;
      player['lastModifiedReason'] = 'theoretical_skill_rebalance';
    }
  }

  rawPlayers['players'] = players;
  playersFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(rawPlayers),
    flush: true,
  );

  stdout.writeln('players=${players.length}');
  stdout.writeln('changed=$changed');
}

_SettingsSnapshot _loadSettings(File settingsFile) {
  if (!settingsFile.existsSync()) {
    return const _SettingsSnapshot(
      radiusCalibrationPercent: 100,
      simulationSpreadPercent: 100,
    );
  }

  final map = jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
  return _SettingsSnapshot(
    radiusCalibrationPercent:
        (map['radiusCalibrationPercent'] as num?)?.toInt() ?? 100,
    simulationSpreadPercent:
        (map['simulationSpreadPercent'] as num?)?.toInt() ?? 100,
  );
}

_SkillResolutionCandidate _resolveSkillsForTheoreticalAverage({
  required double targetAverage,
  required BotEngine botEngine,
  required _SettingsSnapshot settings,
}) {
  final target = targetAverage.clamp(0, 180).toDouble();
  final bestEqual = _findBestEqualCandidate(
    target: target,
    botEngine: botEngine,
    settings: settings,
  );
  final bestSplit = _findBestSplitCandidate(
    target: target,
    fallback: bestEqual,
    botEngine: botEngine,
    settings: settings,
  );
  const improvementEpsilon = 0.01;
  if (bestSplit.error + improvementEpsilon < bestEqual.error) {
    return bestSplit;
  }
  return bestEqual;
}

_SkillResolutionCandidate _findBestEqualCandidate({
  required double target,
  required BotEngine botEngine,
  required _SettingsSnapshot settings,
}) {
  return _searchCandidate(
    target: target,
    minimumValue: 1,
    maximumValue: 1000,
    buildCandidate: (value) => _buildCandidate(
      target: target,
      skill: value,
      finishingSkill: value,
      botEngine: botEngine,
      settings: settings,
    ),
  );
}

_SkillResolutionCandidate _findBestSplitCandidate({
  required double target,
  required _SkillResolutionCandidate fallback,
  required BotEngine botEngine,
  required _SettingsSnapshot settings,
}) {
  final moveUp = target >= fallback.theoreticalAverage;
  final minimumValue = moveUp ? fallback.skill : 1;
  final maximumValue = moveUp ? 1000 : fallback.skill;

  final skillDriven = _searchCandidate(
    target: target,
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    buildCandidate: (value) => _buildCandidate(
      target: target,
      skill: value,
      finishingSkill: fallback.finishingSkill,
      botEngine: botEngine,
      settings: settings,
    ),
  );
  final finishingDriven = _searchCandidate(
    target: target,
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    buildCandidate: (value) => _buildCandidate(
      target: target,
      skill: fallback.skill,
      finishingSkill: value,
      botEngine: botEngine,
      settings: settings,
    ),
  );

  return _pickBetterCandidate(
        current: skillDriven,
        next: finishingDriven,
      ) ??
      fallback;
}

_SkillResolutionCandidate _searchCandidate({
  required double target,
  required int minimumValue,
  required int maximumValue,
  required _SkillResolutionCandidate Function(int value) buildCandidate,
}) {
  var low = minimumValue;
  var high = maximumValue;
  _SkillResolutionCandidate? best;

  while (low <= high) {
    final middle = (low + high) ~/ 2;
    final candidate = buildCandidate(middle);
    best = _pickBetterCandidate(current: best, next: candidate);

    if (candidate.theoreticalAverage < target) {
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }

  for (final value in <int>{low, high, low - 1, high + 1}) {
    if (value < minimumValue || value > maximumValue) {
      continue;
    }
    best = _pickBetterCandidate(current: best, next: buildCandidate(value));
  }

  return best!;
}

_SkillResolutionCandidate _buildCandidate({
  required double target,
  required int skill,
  required int finishingSkill,
  required BotEngine botEngine,
  required _SettingsSnapshot settings,
}) {
  final average = botEngine.estimateThreeDartAverage(
    _createBotProfile(
      settings: settings,
      skill: skill,
      finishingSkill: finishingSkill,
    ),
  );
  return _SkillResolutionCandidate(
    skill: skill,
    finishingSkill: finishingSkill,
    theoreticalAverage: average,
    error: (average - target).abs(),
  );
}

_SkillResolutionCandidate? _pickBetterCandidate({
  required _SkillResolutionCandidate? current,
  required _SkillResolutionCandidate next,
}) {
  if (current == null) {
    return next;
  }

  const errorEpsilon = 0.0001;
  if (next.error + errorEpsilon < current.error) {
    return next;
  }
  if (current.error + errorEpsilon < next.error) {
    return current;
  }

  if (next.finishingLead != current.finishingLead) {
    return next.finishingLead < current.finishingLead ? next : current;
  }

  if (next.gap != current.gap) {
    return next.gap < current.gap ? next : current;
  }

  if (next.skill != current.skill) {
    return next.skill > current.skill ? next : current;
  }

  if (next.finishingSkill != current.finishingSkill) {
    return next.finishingSkill < current.finishingSkill ? next : current;
  }

  return current;
}

BotProfile _createBotProfile({
  required _SettingsSnapshot settings,
  required int skill,
  required int finishingSkill,
}) {
  final effectiveRadius = (settings.radiusCalibrationPercent *
          _radiusDisplayNeutralPercent *
          _legacyRadiusBaselinePercent /
          10000)
      .round();
  final effectiveSpread = (settings.simulationSpreadPercent *
          _legacySimulationSpreadBaselinePercent /
          100)
      .round();

  return BotProfile(
    skill: skill,
    finishingSkill: finishingSkill,
    radiusCalibrationPercent: effectiveRadius,
    simulationSpreadPercent: effectiveSpread,
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:dart_flutter_app/domain/bot/bot_engine.dart';
import 'package:dart_flutter_app/domain/x01/x01_models.dart';

class ImportedPlayer {
  const ImportedPlayer({
    required this.pid,
    required this.name,
    required this.nationality,
    required this.age,
    required this.average2026,
  });

  final String pid;
  final String name;
  final String nationality;
  final int? age;
  final double average2026;
}

class SkillResolution {
  const SkillResolution({
    required this.skill,
    required this.finishingSkill,
    required this.theoreticalAverage,
  });

  final int skill;
  final int finishingSkill;
  final double theoreticalAverage;
}

class _SkillCandidate {
  const _SkillCandidate({
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

  SkillResolution toResolution() {
    return SkillResolution(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: theoreticalAverage,
    );
  }
}

class _Importer {
  _Importer({
    required this.settings,
  });

  final _ImportSettings settings;
  final BotEngine _botEngine = BotEngine();

  Future<void> run() async {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      throw StateError('APPDATA is not available.');
    }

    final dataDir = Directory('$appData${Platform.pathSeparator}DartFlutterApp');
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }

    final outputFile = File(
      '${dataDir.path}${Platform.pathSeparator}computer_players.json',
    );
    if (outputFile.existsSync()) {
      final backupFile = File(
        '${dataDir.path}${Platform.pathSeparator}'
        'computer_players.backup.${DateTime.now().millisecondsSinceEpoch}.json',
      );
      backupFile.writeAsStringSync(outputFile.readAsStringSync());
      stdout.writeln('Backup created: ${backupFile.path}');
    }

    final players = await _fetchTourCardHolders();
    final nationalities = <String>{};
    final playerMaps = <Map<String, dynamic>>[];

    for (var index = 0; index < players.length; index += 1) {
      final player = players[index];
      nationalities.add(player.nationality);
      final resolution = resolveSkillsForAverage(player.average2026);
      final now = DateTime.now();
      playerMaps.add(
        <String, dynamic>{
          'id': 'db-player-${player.pid}',
          'name': player.name,
          'skill': resolution.skill,
          'finishingSkill': resolution.finishingSkill,
          'theoreticalAverage': resolution.theoreticalAverage,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'lastModifiedReason': 'tour_card_import',
          'source': 'imported',
          'isFavorite': false,
          'isProtected': false,
          'age': player.age,
          'nationality': player.nationality,
          'tags': const <String>[],
          'matchesPlayed': 0,
          'matchesWon': 0,
          'average': 0,
          'history': const <dynamic>[],
        },
      );
      stdout.writeln(
        '[${index + 1}/${players.length}] ${player.name} -> '
        '${player.average2026.toStringAsFixed(2)} '
        '(skill ${resolution.skill}/${resolution.finishingSkill})',
      );
    }

    playerMaps.sort(
      (left, right) => (right['theoreticalAverage'] as double).compareTo(
        left['theoreticalAverage'] as double,
      ),
    );

    final payload = <String, dynamic>{
      'tagDefinitions': const <String>[],
      'nationalityDefinitions': nationalities.toList()..sort(),
      'players': playerMaps,
    };

    outputFile.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    stdout.writeln(
      'Imported ${playerMaps.length} players into ${outputFile.path}',
    );
  }

  Future<List<ImportedPlayer>> _fetchTourCardHolders() async {
    final listHtml = await _fetchHtml(
      'https://www.dartsdatabase.co.uk/tour_card_holders.php',
    );
    final linkPattern = RegExp(
      r'''<a[^>]+href=['"]player-profile-live\.php\?pid=(\d+)['"][^>]*>([^<]+)</a>''',
      caseSensitive: false,
    );

    final players = <ImportedPlayer>[];
    final seenPids = <String>{};
    for (final match in linkPattern.allMatches(listHtml)) {
      final pid = match.group(1)!;
      final name = _decodeHtml(match.group(2)!);
      if (!seenPids.add(pid)) {
        continue;
      }
      final profile = await _fetchPlayerProfile(pid, fallbackName: name);
      players.add(profile);
    }

    if (players.length != 128) {
      throw StateError(
        'Expected 128 tour card holders, found ${players.length}.',
      );
    }

    return players;
  }

  Future<ImportedPlayer> _fetchPlayerProfile(
    String pid, {
    required String fallbackName,
  }) async {
    final html = await _fetchHtml(
      'https://www.dartsdatabase.co.uk/player-profile-live.php?pid=$pid',
    );

    final nameMatch = RegExp(
      r'<h4 class="card-title mt-2">([^<]+)</h4>',
      caseSensitive: false,
    ).firstMatch(html);
    final nationalityMatch = RegExp(
      r'<h6 class="card-subtitle">([^<]+)</h6>',
      caseSensitive: false,
    ).firstMatch(html);
    final ageMatch = RegExp(
      r'Age</small><h6 class="no-top-space">(\d+)</h6>',
      caseSensitive: false,
    ).firstMatch(html);

    final currentStatsStart = html.indexOf('Current Years Statistics');
    final currentStatsEnd = html.indexOf('This Years Results', currentStatsStart);
    if (currentStatsStart < 0 || currentStatsEnd < 0) {
      throw StateError('Could not find 2026 stats for $fallbackName ($pid).');
    }
    final currentStats = html.substring(currentStatsStart, currentStatsEnd);
    final averageMatch = RegExp(
      r'<h6 class="card-title">Average</h6>.*?<h3 class="mb-0">([0-9]+\.[0-9]+)</h3>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(currentStats);

    if (averageMatch == null) {
      throw StateError('Could not parse average for $fallbackName ($pid).');
    }

    return ImportedPlayer(
      pid: pid,
      name: _decodeHtml(nameMatch?.group(1) ?? fallbackName),
      nationality: _decodeHtml(nationalityMatch?.group(1) ?? 'Unknown'),
      age: int.tryParse(ageMatch?.group(1) ?? ''),
      average2026: double.parse(averageMatch.group(1)!),
    );
  }

  Future<String> _fetchHtml(String url) async {
    final client = HttpClient();
    client.userAgent = 'Mozilla/5.0 (compatible; DartConnectImporter/1.0)';
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);

    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    return body;
  }

  BotProfile _createBotProfile({
    required int skill,
    required int finishingSkill,
  }) {
    final effectiveRadius =
        (settings.radiusCalibrationPercent * 97 * 92 / 10000).round();
    final effectiveSpread =
        (settings.simulationSpreadPercent * 115 / 100).round();
    return BotProfile(
      skill: skill,
      finishingSkill: finishingSkill,
      radiusCalibrationPercent: effectiveRadius,
      simulationSpreadPercent: effectiveSpread,
    );
  }

  double _estimateTheoreticalAverage({
    required int skill,
    required int finishingSkill,
  }) {
    return _botEngine.estimateThreeDartAverage(
      _createBotProfile(
        skill: skill,
        finishingSkill: finishingSkill,
      ),
    );
  }

  SkillResolution resolveSkillsForAverage(double targetAverage) {
    final target = targetAverage.clamp(0, 180).toDouble();
    final bestEqual = _findBestEqualCandidate(target);
    final bestSplit = _findBestSplitCandidate(target, fallback: bestEqual);
    const improvementEpsilon = 0.01;

    if (bestSplit.error + improvementEpsilon < bestEqual.error) {
      return bestSplit.toResolution();
    }
    return bestEqual.toResolution();
  }

  _SkillCandidate _findBestEqualCandidate(double target) {
    return _searchCandidate(
      target: target,
      minimumValue: 1,
      maximumValue: 1000,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: value,
          finishingSkill: value,
        );
      },
    );
  }

  _SkillCandidate _findBestSplitCandidate(
    double target, {
    required _SkillCandidate fallback,
  }) {
    final moveUp = target >= fallback.theoreticalAverage;
    final minimumValue = moveUp ? fallback.skill : 1;
    final maximumValue = moveUp ? 1000 : fallback.skill;

    final skillDriven = _searchCandidate(
      target: target,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: value,
          finishingSkill: fallback.finishingSkill,
        );
      },
    );
    final finishingDriven = _searchCandidate(
      target: target,
      minimumValue: minimumValue,
      maximumValue: maximumValue,
      buildCandidate: (value) {
        return _buildCandidate(
          target: target,
          skill: fallback.skill,
          finishingSkill: value,
        );
      },
    );

    return _pickBetterCandidate(
          current: skillDriven,
          next: finishingDriven,
        ) ??
        fallback;
  }

  _SkillCandidate _searchCandidate({
    required double target,
    required int minimumValue,
    required int maximumValue,
    required _SkillCandidate Function(int value) buildCandidate,
  }) {
    var low = minimumValue;
    var high = maximumValue;
    _SkillCandidate? best;

    while (low <= high) {
      final middle = (low + high) ~/ 2;
      final middleCandidate = buildCandidate(middle);
      best = _pickBetterCandidate(current: best, next: middleCandidate);

      if (middleCandidate.theoreticalAverage < target) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }

    for (final value in <int>{low, high, low - 1, high + 1}) {
      if (value < minimumValue || value > maximumValue) {
        continue;
      }
      best = _pickBetterCandidate(
        current: best,
        next: buildCandidate(value),
      );
    }

    return best!;
  }

  _SkillCandidate _buildCandidate({
    required double target,
    required int skill,
    required int finishingSkill,
  }) {
    final average = _estimateTheoreticalAverage(
      skill: skill,
      finishingSkill: finishingSkill,
    );
    return _SkillCandidate(
      skill: skill,
      finishingSkill: finishingSkill,
      theoreticalAverage: average,
      error: (average - target).abs(),
    );
  }

  _SkillCandidate? _pickBetterCandidate({
    required _SkillCandidate? current,
    required _SkillCandidate next,
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
    if (next.gap != current.gap) {
      return next.gap < current.gap ? next : current;
    }
    if (next.skill != current.skill) {
      return next.skill < current.skill ? next : current;
    }
    if (next.finishingSkill != current.finishingSkill) {
      return next.finishingSkill < current.finishingSkill ? next : current;
    }
    return current;
  }

  String _decodeHtml(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}

class _ImportSettings {
  const _ImportSettings({
    required this.radiusCalibrationPercent,
    required this.simulationSpreadPercent,
  });

  final int radiusCalibrationPercent;
  final int simulationSpreadPercent;

  static _ImportSettings load() {
    final appData = Platform.environment['APPDATA'];
    if (appData == null || appData.isEmpty) {
      return const _ImportSettings(
        radiusCalibrationPercent: 100,
        simulationSpreadPercent: 100,
      );
    }

    final file = File(
      '$appData${Platform.pathSeparator}DartFlutterApp'
      '${Platform.pathSeparator}app_settings.json',
    );
    if (!file.existsSync()) {
      return const _ImportSettings(
        radiusCalibrationPercent: 100,
        simulationSpreadPercent: 100,
      );
    }

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return _ImportSettings(
      radiusCalibrationPercent:
          (json['radiusCalibrationPercent'] as num?)?.toInt() ?? 100,
      simulationSpreadPercent:
          (json['simulationSpreadPercent'] as num?)?.toInt() ?? 100,
    );
  }
}

Future<void> main() async {
  final importer = _Importer(settings: _ImportSettings.load());
  await importer.run();
}

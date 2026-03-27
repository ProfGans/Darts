import 'dart:convert';
import 'dart:io';

import '../../domain/career/career_models.dart';
import '../../domain/career/career_template.dart';
import '../../domain/x01/x01_models.dart';
import '../models/computer_player.dart';
import '../repositories/career_template_repository.dart';
import '../repositories/computer_repository.dart';
import 'electron_import_service.dart';

class IoElectronImportService implements ElectronImportService {
  static const Set<String> _defaultComputerNames = <String>{
    'Luke Humphries',
    'Luke Littler',
    'Michael van Gerwen',
    'Gerwyn Price',
    'Gary Anderson',
    'Nathan Aspinall',
  };

  @override
  Future<ElectronImportReport> importElectronData({
    bool replaceExisting = false,
    bool importOnlyIfEmpty = false,
  }) async {
    final workspaceRoot = _findWorkspaceRoot();
    if (workspaceRoot == null) {
      return const ElectronImportReport(
        foundWorkspace: false,
        message: 'Kein Electron-Arbeitsordner mit Importdaten gefunden.',
      );
    }

    final shouldImportComputers = !importOnlyIfEmpty || _canAutoImportComputers();
    final shouldImportTemplates =
        !importOnlyIfEmpty || CareerTemplateRepository.instance.templates.isEmpty;

    var importedComputers = 0;
    var importedCareers = 0;

    if (shouldImportComputers) {
      final players = _loadComputerPlayers(workspaceRoot);
      if (players.isNotEmpty) {
        await ComputerRepository.instance.importPlayers(
          players,
          replaceExisting: replaceExisting || _canAutoImportComputers(),
        );
        importedComputers = players.length;
      }
    }

    if (shouldImportTemplates) {
      final templates = _loadCareerPresetsAsTemplates(workspaceRoot);
      if (templates.isNotEmpty) {
        await CareerTemplateRepository.instance.importTemplates(
          templates,
          replaceExisting:
              replaceExisting && CareerTemplateRepository.instance.templates.isEmpty,
        );
        importedCareers = templates.length;
      }
    }

    return ElectronImportReport(
      foundWorkspace: true,
      computersImported: importedComputers,
      careersImported: importedCareers,
      message: importedComputers == 0 && importedCareers == 0
          ? 'Keine neuen Electron-Daten importiert.'
          : 'Electron-Daten importiert.',
    );
  }

  bool _canAutoImportComputers() {
    final players = ComputerRepository.instance.players;
    if (players.length != _defaultComputerNames.length) {
      return false;
    }
    final currentNames = players.map((entry) => entry.name).toSet();
    return currentNames.length == _defaultComputerNames.length &&
        currentNames.containsAll(_defaultComputerNames);
  }

  Directory? _findWorkspaceRoot() {
    final candidates = <Directory>[];
    var current = Directory.current;
    for (var depth = 0; depth < 5; depth += 1) {
      candidates.add(current);
      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    final executableDir = File(Platform.resolvedExecutable).parent;
    current = executableDir;
    for (var depth = 0; depth < 6; depth += 1) {
      candidates.add(current);
      final parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }

    for (final candidate in candidates) {
      final computerDir = Directory(
        '${candidate.path}${Platform.pathSeparator}computer_players',
      );
      final presetDir = Directory(
        '${candidate.path}${Platform.pathSeparator}career_presets',
      );
      if (computerDir.existsSync() || presetDir.existsSync()) {
        return candidate;
      }
    }
    return null;
  }

  List<ComputerPlayer> _loadComputerPlayers(Directory workspaceRoot) {
    final directory = Directory(
      '${workspaceRoot.path}${Platform.pathSeparator}computer_players',
    );
    if (!directory.existsSync()) {
      return const <ComputerPlayer>[];
    }

    final players = <ComputerPlayer>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (name.toLowerCase() == 'readme.txt') {
        continue;
      }

      try {
        final raw = entity.readAsStringSync();
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final map = decoded.cast<String, dynamic>();
        final statistics =
            (map['statistics'] as Map?)?.cast<String, dynamic>() ??
                const <String, dynamic>{};
        final matchesWon = (statistics['matchesWon'] as num?)?.toInt() ?? 0;
        final matchesLost = (statistics['matchesLost'] as num?)?.toInt() ?? 0;
        final totalScored = (statistics['totalScored'] as num?)?.toInt() ?? 0;
        final dartsThrown = (statistics['dartsThrown'] as num?)?.toInt() ?? 0;
        final realAverage =
            dartsThrown > 0 ? (totalScored / dartsThrown) * 3 : 0.0;
        final now = DateTime.now();

        players.add(
          ComputerPlayer(
            id: map['id'] as String? ?? 'computer-import-${players.length}',
            name: map['name'] as String? ?? 'Computer',
            skill: (map['skill'] as num?)?.toInt() ?? 700,
            finishingSkill:
                (map['finishingSkill'] as num?)?.toInt() ?? 700,
            theoreticalAverage:
                (map['theoreticalAverage'] as num?)?.toDouble() ?? 60.0,
            createdAt: now,
            updatedAt: now,
            lastModifiedReason: 'electron_import',
            matchesPlayed: matchesWon + matchesLost,
            matchesWon: matchesWon,
            average: realAverage,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    players.sort(
      (left, right) =>
          right.theoreticalAverage.compareTo(left.theoreticalAverage),
    );
    return players;
  }

  List<CareerTemplate> _loadCareerPresetsAsTemplates(Directory workspaceRoot) {
    final directory = Directory(
      '${workspaceRoot.path}${Platform.pathSeparator}career_presets',
    );
    if (!directory.existsSync()) {
      return const <CareerTemplate>[];
    }

    final templates = <CareerTemplate>[];
    for (final entity in directory.listSync()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      final fileName = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (fileName.toLowerCase() == 'readme.txt') {
        continue;
      }

      try {
        final raw = entity.readAsStringSync();
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final map = decoded.cast<String, dynamic>();
        final rankingsRaw =
            (map['rankings'] as List<dynamic>? ?? const <dynamic>[]);
        final itemsRaw = (map['items'] as List<dynamic>? ?? const <dynamic>[]);

        final rankings = rankingsRaw
            .map(
              (entry) => CareerRankingDefinition(
                id: (entry as Map)['id'] as String,
                name: entry['name'] as String? ?? 'Rangliste',
                validSeasons:
                    (entry['validSeasons'] as num?)?.toInt() ?? 1,
              ),
            )
            .toList();

        final knownRankingIds = rankings.map((entry) => entry.id).toSet();
        final fallbackRankingId =
            rankings.isEmpty ? null : rankings.first.id;

        final calendar = <CareerCalendarItem>[];
        for (final rawItem in itemsRaw) {
          if (rawItem is! Map) {
            continue;
          }
          final item = rawItem.cast<String, dynamic>();
          final roundConfigs =
              (item['roundConfigs'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<Map>()
                  .map((entry) => entry.cast<String, dynamic>())
                  .toList();
          final firstRound =
              roundConfigs.isEmpty ? const <String, dynamic>{} : roundConfigs.first;

          final qualificationConditions =
              (item['qualificationConditions'] as List<dynamic>? ??
                      const <dynamic>[])
                  .whereType<Map>()
                  .map((entry) {
                    final rankingId = entry['rankingId'] as String?;
                    return CareerQualificationCondition(
                      rankingId: knownRankingIds.contains(rankingId)
                          ? rankingId!
                          : (fallbackRankingId ?? rankingId ?? 'ranking-import'),
                      fromRank: (entry['fromRank'] as num?)?.toInt() ?? 1,
                      toRank: (entry['toRank'] as num?)?.toInt() ?? 1,
                    );
                  })
                  .toList();

          final prizeRankingIds =
              (item['prizeRankingIds'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<String>()
                  .map(
                    (rankingId) => knownRankingIds.contains(rankingId)
                        ? rankingId
                        : (fallbackRankingId ?? rankingId),
                  )
                  .toSet()
                  .toList();

          calendar.add(
            CareerCalendarItem(
              id: item['id'] as String? ??
                  'calendar-import-${calendar.length}',
              name: item['name'] as String? ?? 'Importiertes Turnier',
              fieldSize: (item['fieldSize'] as num?)?.toInt() ?? 32,
              matchMode: (firstRound['mode'] as String?) == 'sets'
                  ? MatchMode.sets
                  : MatchMode.legs,
              legsToWin: (firstRound['legsToWin'] as num?)?.toInt() ?? 6,
              startScore: 501,
              prizePool: _estimatePrizePool(
                fieldSize: (item['fieldSize'] as num?)?.toInt() ?? 32,
                roundConfigs: roundConfigs,
              ),
              setsToWin: (firstRound['setsToWin'] as num?)?.toInt() ?? 1,
              legsPerSet: (firstRound['legsPerSet'] as num?)?.toInt() ?? 1,
              countsForRankingIds: prizeRankingIds,
              seedingRankingId: knownRankingIds.contains(
                item['seedingRankingId'] as String?,
              )
                  ? item['seedingRankingId'] as String?
                  : fallbackRankingId,
              seedCount: (item['seedCount'] as num?)?.toInt() ?? 0,
              qualificationConditions: qualificationConditions,
            ),
          );
        }

        final includesPlayer = itemsRaw.whereType<Map>().any(
              (entry) => entry['includesPlayer'] == true,
            );

        templates.add(
          CareerTemplate(
            id: 'imported-preset-$fileName',
            name: map['name'] as String? ?? fileName,
            participantMode: includesPlayer
                ? CareerParticipantMode.withHuman
                : CareerParticipantMode.cpuOnly,
            rankings: rankings.isEmpty
                ? const <CareerRankingDefinition>[
                    CareerRankingDefinition(
                      id: 'ranking-order-of-merit',
                      name: 'Order of Merit',
                      validSeasons: 1,
                    ),
                  ]
                : rankings,
            calendar: calendar,
          ),
        );
      } catch (_) {
        continue;
      }
    }

    return templates;
  }

  int _estimatePrizePool({
    required int fieldSize,
    required List<Map<String, dynamic>> roundConfigs,
  }) {
    if (roundConfigs.isEmpty) {
      return 12500;
    }

    var entrants = fieldSize;
    var total = 0;
    for (var index = 0; index < roundConfigs.length; index += 1) {
      final round = roundConfigs[index];
      final prizeMoney = (round['prizeMoney'] as num?)?.toInt() ?? 0;
      final runnerUpPrize = (round['runnerUpPrize'] as num?)?.toInt() ?? 0;
      final isFinal = index == roundConfigs.length - 1 || entrants <= 2;

      if (isFinal) {
        total += prizeMoney + runnerUpPrize;
      } else {
        final losers = entrants ~/ 2;
        total += losers * prizeMoney;
        entrants = losers;
      }
    }

    return total > 0 ? total : 12500;
  }
}

ElectronImportService createElectronImportService() =>
    IoElectronImportService();

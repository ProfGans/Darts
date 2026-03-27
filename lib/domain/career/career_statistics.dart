import 'career_models.dart';

enum CareerHistoryFilterMode {
  career,
  currentSeason,
  specificSeason,
}

class CareerStatLeader {
  const CareerStatLeader({
    required this.playerId,
    required this.playerName,
    required this.value,
  });

  final String playerId;
  final String playerName;
  final int value;
}

class CareerTournamentTypeRecord {
  const CareerTournamentTypeRecord({
    required this.typeName,
    required this.leaders,
  });

  final String typeName;
  final List<CareerStatLeader> leaders;
}

class CareerPlayerHistoryEntry {
  const CareerPlayerHistoryEntry({
    required this.seasonNumber,
    required this.tournamentName,
    required this.resultLabel,
    required this.money,
  });

  final int seasonNumber;
  final String tournamentName;
  final String resultLabel;
  final int money;
}

class CareerPlayerHistorySummary {
  const CareerPlayerHistorySummary({
    required this.playerId,
    required this.playerName,
    required this.totalTitles,
    required this.totalFinals,
    required this.totalSemiFinals,
    required this.totalQuarterFinals,
    required this.totalAppearances,
    required this.totalMoney,
    required this.seasonTitles,
    required this.seasonFinals,
    required this.seasonSemiFinals,
    required this.seasonQuarterFinals,
    required this.seasonAppearances,
    required this.seasonMoney,
    required this.entries,
    required this.typeTitleCounts,
    required this.x01Stats,
    required this.availableSeasons,
    required this.selectedSeasonNumber,
  });

  final String playerId;
  final String playerName;
  final int totalTitles;
  final int totalFinals;
  final int totalSemiFinals;
  final int totalQuarterFinals;
  final int totalAppearances;
  final int totalMoney;
  final int seasonTitles;
  final int seasonFinals;
  final int seasonSemiFinals;
  final int seasonQuarterFinals;
  final int seasonAppearances;
  final int seasonMoney;
  final List<CareerPlayerHistoryEntry> entries;
  final Map<String, int> typeTitleCounts;
  final CareerX01PlayerStats x01Stats;
  final List<int> availableSeasons;
  final int? selectedSeasonNumber;
}

class CareerStatisticsSummary {
  const CareerStatisticsSummary({
    required this.overallTitles,
    required this.overallMoney,
    required this.seasonTitles,
    required this.seasonMoney,
    required this.typeRecords,
  });

  final List<CareerStatLeader> overallTitles;
  final List<CareerStatLeader> overallMoney;
  final List<CareerStatLeader> seasonTitles;
  final List<CareerStatLeader> seasonMoney;
  final List<CareerTournamentTypeRecord> typeRecords;
}

class CareerStatisticsEngine {
  const CareerStatisticsEngine();

  CareerStatisticsSummary buildSummary({
    required int currentSeasonNumber,
    required List<CareerCompletedTournament> completedTournaments,
    required Map<String, String> participants,
  }) {
    final overallTitles = <String, _Accumulator>{};
    final overallMoney = <String, _Accumulator>{};
    final seasonTitles = <String, _Accumulator>{};
    final seasonMoney = <String, _Accumulator>{};
    final typeBuckets = <String, Map<String, _Accumulator>>{};

    for (final tournament in completedTournaments) {
      final winnerName =
          participants[tournament.winnerId] ?? tournament.winnerName;
      _bump(overallTitles, tournament.winnerId, winnerName, 1);
      for (final entry in tournament.playerPayouts.entries) {
        final playerName = participants[entry.key] ?? entry.key;
        _bump(overallMoney, entry.key, playerName, entry.value);
        if (tournament.seasonNumber == currentSeasonNumber) {
          _bump(seasonMoney, entry.key, playerName, entry.value);
        }
      }

      if (tournament.seasonNumber == currentSeasonNumber) {
        _bump(seasonTitles, tournament.winnerId, winnerName, 1);
      }

      final typeName = _tournamentTypeName(tournament.name);
      final typeMap = typeBuckets.putIfAbsent(
        typeName,
        () => <String, _Accumulator>{},
      );
      _bump(typeMap, tournament.winnerId, winnerName, 1);
    }

    final typeRecords = typeBuckets.entries.map((entry) {
      return CareerTournamentTypeRecord(
        typeName: entry.key,
        leaders: _sort(entry.value).take(10).toList(),
      );
    }).toList()
      ..sort((left, right) => left.typeName.compareTo(right.typeName));

    return CareerStatisticsSummary(
      overallTitles: _sort(overallTitles).take(10).toList(),
      overallMoney: _sort(overallMoney).take(10).toList(),
      seasonTitles: _sort(seasonTitles).take(10).toList(),
      seasonMoney: _sort(seasonMoney).take(10).toList(),
      typeRecords: typeRecords,
    );
  }

  CareerPlayerHistorySummary buildPlayerHistory({
    required String playerId,
    required String playerName,
    required int currentSeasonNumber,
    required List<CareerCompletedTournament> completedTournaments,
    CareerHistoryFilterMode filterMode = CareerHistoryFilterMode.career,
    int? seasonNumber,
  }) {
    var totalTitles = 0;
    var totalFinals = 0;
    var totalSemiFinals = 0;
    var totalQuarterFinals = 0;
    var totalAppearances = 0;
    var totalMoney = 0;
    var seasonTitles = 0;
    var seasonFinals = 0;
    var seasonSemiFinals = 0;
    var seasonQuarterFinals = 0;
    var seasonAppearances = 0;
    var seasonMoney = 0;
    final entries = <CareerPlayerHistoryEntry>[];
    final typeTitleCounts = <String, int>{};
    var x01Stats = const CareerX01PlayerStats();
    final availableSeasons = completedTournaments
        .map((entry) => entry.seasonNumber)
        .toSet()
        .toList()
      ..sort();

    for (final tournament in completedTournaments) {
      final includeTournament = switch (filterMode) {
        CareerHistoryFilterMode.career => true,
        CareerHistoryFilterMode.currentSeason =>
          tournament.seasonNumber == currentSeasonNumber,
        CareerHistoryFilterMode.specificSeason =>
          tournament.seasonNumber == seasonNumber,
      };
      final exactMoney = tournament.playerPayouts[playerId];
      final exactLabel = tournament.playerResultLabels[playerId];
      final tournamentX01Stats = tournament.playerX01Stats[playerId];

      if (includeTournament && tournamentX01Stats != null) {
        x01Stats = x01Stats.add(tournamentX01Stats);
      }

      if (tournament.winnerId == playerId) {
        if (includeTournament) {
          totalAppearances += 1;
          totalTitles += 1;
          totalFinals += 1;
          totalMoney += exactMoney ?? tournament.prizePool;
          final typeName = _tournamentTypeName(tournament.name);
          typeTitleCounts[typeName] = (typeTitleCounts[typeName] ?? 0) + 1;
          entries.add(
            CareerPlayerHistoryEntry(
              seasonNumber: tournament.seasonNumber,
              tournamentName: tournament.name,
              resultLabel: exactLabel ?? 'Sieger',
              money: exactMoney ?? tournament.prizePool,
            ),
          );
        }
        if (tournament.seasonNumber == currentSeasonNumber) {
          seasonAppearances += 1;
          seasonTitles += 1;
          seasonFinals += 1;
          seasonMoney += exactMoney ?? tournament.prizePool;
        }
        continue;
      }

      if (exactMoney != null || exactLabel != null) {
        final payoutValue = exactMoney ?? 0;
        if (includeTournament) {
          totalAppearances += 1;
          totalMoney += payoutValue;
          if (exactLabel == 'Finalist') {
            totalFinals += 1;
          } else if (exactLabel == 'Halbfinale') {
            totalSemiFinals += 1;
          } else if (exactLabel == 'Viertelfinale') {
            totalQuarterFinals += 1;
          }
          entries.add(
            CareerPlayerHistoryEntry(
              seasonNumber: tournament.seasonNumber,
              tournamentName: tournament.name,
              resultLabel: exactLabel ?? 'Teilnahme',
              money: payoutValue,
            ),
          );
        }
        if (tournament.seasonNumber == currentSeasonNumber) {
          seasonAppearances += 1;
          seasonMoney += payoutValue;
          if (exactLabel == 'Finalist') {
            seasonFinals += 1;
          } else if (exactLabel == 'Halbfinale') {
            seasonSemiFinals += 1;
          } else if (exactLabel == 'Viertelfinale') {
            seasonQuarterFinals += 1;
          }
        }
        continue;
      }

      if (tournament.runnerUpId == playerId) {
        if (includeTournament) {
          totalAppearances += 1;
          totalFinals += 1;
          entries.add(
            CareerPlayerHistoryEntry(
              seasonNumber: tournament.seasonNumber,
              tournamentName: tournament.name,
              resultLabel: 'Finalist',
              money: 0,
            ),
          );
        }
        if (tournament.seasonNumber == currentSeasonNumber) {
          seasonAppearances += 1;
          seasonFinals += 1;
        }
        continue;
      }

      if (tournament.semiFinalistIds.contains(playerId)) {
        if (includeTournament) {
          totalAppearances += 1;
          totalSemiFinals += 1;
          entries.add(
            CareerPlayerHistoryEntry(
              seasonNumber: tournament.seasonNumber,
              tournamentName: tournament.name,
              resultLabel: 'Halbfinale',
              money: 0,
            ),
          );
        }
        if (tournament.seasonNumber == currentSeasonNumber) {
          seasonAppearances += 1;
          seasonSemiFinals += 1;
        }
        continue;
      }

      if (tournament.quarterFinalistIds.contains(playerId)) {
        if (includeTournament) {
          totalAppearances += 1;
          totalQuarterFinals += 1;
          entries.add(
            CareerPlayerHistoryEntry(
              seasonNumber: tournament.seasonNumber,
              tournamentName: tournament.name,
              resultLabel: 'Viertelfinale',
              money: 0,
            ),
          );
        }
        if (tournament.seasonNumber == currentSeasonNumber) {
          seasonAppearances += 1;
          seasonQuarterFinals += 1;
        }
      }
    }

    entries.sort((left, right) {
      final seasonCompare = right.seasonNumber.compareTo(left.seasonNumber);
      if (seasonCompare != 0) {
        return seasonCompare;
      }
      return left.tournamentName.compareTo(right.tournamentName);
    });

    return CareerPlayerHistorySummary(
      playerId: playerId,
      playerName: playerName,
      totalTitles: totalTitles,
      totalFinals: totalFinals,
      totalSemiFinals: totalSemiFinals,
      totalQuarterFinals: totalQuarterFinals,
      totalAppearances: totalAppearances,
      totalMoney: totalMoney,
      seasonTitles: seasonTitles,
      seasonFinals: seasonFinals,
      seasonSemiFinals: seasonSemiFinals,
      seasonQuarterFinals: seasonQuarterFinals,
      seasonAppearances: seasonAppearances,
      seasonMoney: seasonMoney,
      entries: entries,
      typeTitleCounts: typeTitleCounts,
      x01Stats: x01Stats,
      availableSeasons: availableSeasons.reversed.toList(),
      selectedSeasonNumber: filterMode == CareerHistoryFilterMode.specificSeason
          ? seasonNumber
          : null,
    );
  }

  void _bump(
    Map<String, _Accumulator> bucket,
    String playerId,
    String playerName,
    int delta,
  ) {
    final current = bucket.putIfAbsent(
      playerId,
      () => _Accumulator(playerId: playerId, playerName: playerName),
    );
    current.value += delta;
  }

  List<CareerStatLeader> _sort(Map<String, _Accumulator> bucket) {
    final values = bucket.values.toList()
      ..sort((left, right) {
        final valueCompare = right.value.compareTo(left.value);
        if (valueCompare != 0) {
          return valueCompare;
        }
        return left.playerName.compareTo(right.playerName);
      });
    return values
        .map(
          (entry) => CareerStatLeader(
            playerId: entry.playerId,
            playerName: entry.playerName,
            value: entry.value,
          ),
        )
        .toList();
  }

  String _tournamentTypeName(String name) {
    final normalized = name.trim();
    final digits = RegExp(r'\s+\d+$');
    if (digits.hasMatch(normalized)) {
      return normalized.replaceFirst(digits, '');
    }
    return normalized;
  }
}

class _Accumulator {
  _Accumulator({
    required this.playerId,
    required this.playerName,
  });

  final String playerId;
  final String playerName;
  int value = 0;
}

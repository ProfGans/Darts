import '../career/career_models.dart';

class RankingStanding {
  const RankingStanding({
    required this.rank,
    required this.id,
    required this.name,
    required this.money,
    required this.titles,
    this.metricLabel = 'Geld',
  });

  final int rank;
  final String id;
  final String name;
  final int money;
  final int titles;
  final String metricLabel;
}

class RankingEngine {
  const RankingEngine();

  List<RankingStanding> buildInitialStandings({
    required CareerRankingDefinition ranking,
    required List<String> participantNames,
  }) {
    final sorted = List<String>.from(participantNames)..sort();
    return List<RankingStanding>.generate(
      sorted.length,
        (index) => RankingStanding(
          rank: index + 1,
          id: 'initial-$index',
          name: sorted[index],
          money: 0,
          titles: 0,
        ),
      );
  }

  List<RankingStanding> buildCareerStandings({
    required CareerRankingDefinition ranking,
    required int currentSeasonNumber,
    required List<CareerCompletedTournament> completedTournaments,
    required Map<String, String> participants,
  }) {
    final totals = <String, _StandingAccumulator>{};
    final normalizedTournaments =
        _normalizeCalendarIndices(completedTournaments);
    final currentSeasonCompletedSlots = normalizedTournaments
        .where((tournament) => tournament.seasonNumber == currentSeasonNumber)
        .map((tournament) => tournament.calendarIndex)
        .where((index) => index >= 0)
        .toSet();
    final rollingSeason = currentSeasonNumber - ranking.validSeasons;

    for (final entry in participants.entries) {
      totals[entry.key] = _StandingAccumulator(
        id: entry.key,
        name: entry.value,
      );
    }

    for (final tournament in normalizedTournaments) {
      if (!_countsForRankingWindow(
            tournament: tournament,
            rankingId: ranking.id,
            currentSeasonNumber: currentSeasonNumber,
            rollingSeason: rollingSeason,
            currentSeasonCompletedSlots: currentSeasonCompletedSlots,
            ranking: ranking,
          )) {
        continue;
      }
      final payout = _buildPrizeDistribution(
        prizePool: tournament.prizePool,
        fieldSizeHint: tournament.fieldSize,
      );
      final scores = _scoresForTournament(
        tournament: tournament,
        ranking: ranking,
        fallbackPayout: payout,
        participants: participants,
      );
      for (final score in scores.entries) {
        _applyScore(
          totals: totals,
          participantId: score.key,
          fallbackName: participants[score.key] ?? score.key,
          amount: score.value,
          titleIncrement: score.key == tournament.winnerId ? 1 : 0,
        );
      }
      if (ranking.seasonBonus > 0 &&
          tournament.seasonNumber == currentSeasonNumber) {
        _applyScore(
          totals: totals,
          participantId: tournament.winnerId,
          fallbackName: tournament.winnerName,
          amount: ranking.seasonBonus,
        );
      }
      if (ranking.playoffBonus > 0 &&
          tournament.categoryName.toLowerCase().contains('playoff')) {
        _applyScore(
          totals: totals,
          participantId: tournament.winnerId,
          fallbackName: tournament.winnerName,
          amount: ranking.playoffBonus,
        );
      }
    }

    final sorted = totals.values.toList()
      ..sort((left, right) {
        final moneyCompare = right.total.compareTo(left.total);
        if (moneyCompare != 0) {
          return moneyCompare;
        }
        final titleCompare = right.titles.compareTo(left.titles);
        if (titleCompare != 0) {
          return titleCompare;
        }
        return left.name.compareTo(right.name);
      });

    return List<RankingStanding>.generate(
      sorted.length,
      (index) => RankingStanding(
        rank: index + 1,
        id: sorted[index].id,
        name: sorted[index].name,
        money: sorted[index].displayTotal,
        titles: sorted[index].titles,
        metricLabel: ranking.metric == CareerRankingMetric.points ? 'Punkte' : 'Geld',
      ),
    );
  }

  Map<String, int> _scoresForTournament({
    required CareerCompletedTournament tournament,
    required CareerRankingDefinition ranking,
    required _PrizeDistribution fallbackPayout,
    required Map<String, String> participants,
  }) {
    final scores = <String, int>{};
    final hasRecordedPayouts = tournament.playerPayouts.values.any(
      (amount) => amount > 0,
    );
    if (hasRecordedPayouts) {
      for (final entry in tournament.playerPayouts.entries) {
        scores[entry.key] = entry.value;
      }
    } else {
      scores[tournament.winnerId] = fallbackPayout.winner;
      if (tournament.runnerUpId != null) {
        scores[tournament.runnerUpId!] = fallbackPayout.runnerUp;
      }
      for (final participantId in tournament.semiFinalistIds) {
        scores[participantId] = fallbackPayout.semiFinal;
      }
      for (final participantId in tournament.quarterFinalistIds) {
        scores[participantId] = fallbackPayout.quarterFinal;
      }
    }

    if (ranking.metric == CareerRankingMetric.points) {
      return scores;
    }
    return scores;
  }

  void _applyScore({
    required Map<String, _StandingAccumulator> totals,
    required String participantId,
    required String fallbackName,
    required int amount,
    int titleIncrement = 0,
  }) {
    final accumulator = totals.putIfAbsent(
      participantId,
      () => _StandingAccumulator(
        id: participantId,
        name: fallbackName,
      ),
    );
    accumulator.add(amount);
    accumulator.titles += titleIncrement;
  }

  bool _countsForRankingWindow({
    required CareerCompletedTournament tournament,
    required String rankingId,
    required int currentSeasonNumber,
    required int rollingSeason,
    required Set<int> currentSeasonCompletedSlots,
    required CareerRankingDefinition ranking,
  }) {
    if (!tournament.countsForRankingIds.contains(rankingId)) {
      return false;
    }

    if (ranking.countedCategories.isNotEmpty &&
        !ranking.countedCategories.contains(tournament.categoryName)) {
      return false;
    }

    if (ranking.resetAtSeasonEnd) {
      return tournament.seasonNumber == currentSeasonNumber;
    }

    if (tournament.seasonNumber > currentSeasonNumber) {
      return false;
    }

    if (tournament.seasonNumber == currentSeasonNumber) {
      return true;
    }

    if (tournament.seasonNumber < rollingSeason) {
      return false;
    }

    if (tournament.seasonNumber > rollingSeason) {
      return true;
    }

    if (tournament.calendarIndex < 0) {
      return true;
    }

    return !currentSeasonCompletedSlots.contains(tournament.calendarIndex);
  }

  List<CareerCompletedTournament> _normalizeCalendarIndices(
    List<CareerCompletedTournament> completedTournaments,
  ) {
    final nextIndexBySeason = <int, int>{};
    return completedTournaments.map((tournament) {
      if (tournament.calendarIndex >= 0) {
        final nextIndex = tournament.calendarIndex + 1;
        final previous = nextIndexBySeason[tournament.seasonNumber] ?? 0;
        if (nextIndex > previous) {
          nextIndexBySeason[tournament.seasonNumber] = nextIndex;
        }
        return tournament;
      }

      final fallbackIndex = nextIndexBySeason[tournament.seasonNumber] ?? 0;
      nextIndexBySeason[tournament.seasonNumber] = fallbackIndex + 1;
      return CareerCompletedTournament(
        seasonNumber: tournament.seasonNumber,
        calendarItemId: tournament.calendarItemId,
        calendarIndex: fallbackIndex,
        name: tournament.name,
        categoryName: tournament.categoryName,
        fieldSize: tournament.fieldSize,
        winnerId: tournament.winnerId,
        winnerName: tournament.winnerName,
        runnerUpId: tournament.runnerUpId,
        runnerUpName: tournament.runnerUpName,
        semiFinalistIds: tournament.semiFinalistIds,
        quarterFinalistIds: tournament.quarterFinalistIds,
        prizePool: tournament.prizePool,
        playerPayouts: tournament.playerPayouts,
        playerResultLabels: tournament.playerResultLabels,
        countsForRankingIds: tournament.countsForRankingIds,
      );
    }).toList();
  }

  _PrizeDistribution _buildPrizeDistribution({
    required int prizePool,
    required int fieldSizeHint,
  }) {
    if (fieldSizeHint >= 16) {
      final winner = (prizePool * 0.24).round();
      final runnerUp = (prizePool * 0.12).round();
      final semiFinal = (prizePool * 0.07).round();
      final quarterFinal = (prizePool * 0.04).round();
      return _PrizeDistribution(
        winner: winner,
        runnerUp: runnerUp,
        semiFinal: semiFinal,
        quarterFinal: quarterFinal,
      );
    }

    final winner = (prizePool * 0.38).round();
    final runnerUp = (prizePool * 0.18).round();
    final semiFinal = (prizePool * 0.09).round();
    return _PrizeDistribution(
      winner: winner,
      runnerUp: runnerUp,
      semiFinal: semiFinal,
      quarterFinal: 0,
    );
  }
}

class _StandingAccumulator {
  _StandingAccumulator({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
  final List<int> scores = <int>[];
  int titles = 0;

  void add(int value) {
    scores.add(value);
  }

  int totalFor(CareerRankingDefinition ranking) {
    final ordered = List<int>.from(scores)..sort();
    var trimmed = ordered;
    if (ranking.discardWorstCount > 0 && trimmed.isNotEmpty) {
      trimmed = trimmed.skip(ranking.discardWorstCount).toList();
    }
    if (ranking.bestOfCount != null && ranking.bestOfCount! > 0) {
      trimmed = (List<int>.from(trimmed)..sort((a, b) => b.compareTo(a)))
          .take(ranking.bestOfCount!)
          .toList();
    }
    return trimmed.fold<int>(0, (sum, entry) => sum + entry);
  }

  int get displayTotal => total;
  int total = 0;
}

class _PrizeDistribution {
  const _PrizeDistribution({
    required this.winner,
    required this.runnerUp,
    required this.semiFinal,
    required this.quarterFinal,
  });

  final int winner;
  final int runnerUp;
  final int semiFinal;
  final int quarterFinal;
}

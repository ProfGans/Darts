import 'career_models.dart';

class CareerEngine {
  const CareerEngine();

  CareerDefinition initializeCareer({
    required String name,
    required CareerParticipantMode participantMode,
    String? playerProfileId,
    bool replaceWeakestPlayerWithHuman = false,
  }) {
      return CareerDefinition(
        id: 'career-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        participantMode: participantMode,
        playerProfileId: playerProfileId,
        replaceWeakestPlayerWithHuman: replaceWeakestPlayerWithHuman,
        databasePlayers: const <CareerDatabasePlayer>[],
        careerTagDefinitions: const <CareerTagDefinition>[],
        seasonTagRules: const <CareerSeasonTagRule>[],
        rankings: const <CareerRankingDefinition>[],
        currentSeason: const CareerSeason(
          seasonNumber: 1,
          calendar: <CareerCalendarItem>[],
        ),
      completedSeasons: const <CareerSeason>[],
      isStarted: false,
    );
  }

  CareerDefinition addRanking({
    required CareerDefinition career,
    required String name,
    required int validSeasons,
    bool resetAtSeasonEnd = false,
  }) {
    final ranking = CareerRankingDefinition(
      id: 'ranking-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      validSeasons: validSeasons,
      resetAtSeasonEnd: resetAtSeasonEnd,
    );
    return career.copyWith(
      rankings: <CareerRankingDefinition>[...career.rankings, ranking],
    );
  }

  CareerDefinition updateRanking({
    required CareerDefinition career,
    required String rankingId,
    required String name,
    required int validSeasons,
    bool resetAtSeasonEnd = false,
  }) {
    return career.copyWith(
      rankings: career.rankings
          .map(
            (ranking) => ranking.id == rankingId
                ? ranking.copyWith(
                    name: name,
                    validSeasons: validSeasons,
                    resetAtSeasonEnd: resetAtSeasonEnd,
                  )
                : ranking,
          )
          .toList(),
    );
  }

  CareerDefinition removeRanking({
    required CareerDefinition career,
    required String rankingId,
  }) {
    final nextRankings = career.rankings
        .where((ranking) => ranking.id != rankingId)
        .toList();
    final nextCalendar = career.currentSeason.calendar
        .map(
          (item) => item.copyWith(
            countsForRankingIds: item.countsForRankingIds
                .where((id) => id != rankingId)
                .toList(),
            seedingRankingId: item.seedingRankingId == rankingId
                ? null
                : item.seedingRankingId,
            clearSeedingRankingId: item.seedingRankingId == rankingId,
            fillRankingId: item.fillRankingId == rankingId
                ? null
                : item.fillRankingId,
            clearFillRankingId: item.fillRankingId == rankingId,
            qualificationConditions: item.qualificationConditions
                .where((condition) => condition.rankingId != rankingId)
                .toList(),
          ),
        )
        .toList();
    return career.copyWith(
      rankings: nextRankings,
      currentSeason: career.currentSeason.copyWith(
        calendar: nextCalendar,
      ),
    );
  }

  CareerDefinition addCalendarItem({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        calendar: <CareerCalendarItem>[
          ...career.currentSeason.calendar,
          item,
        ],
      ),
    );
  }

  CareerDefinition addDatabasePlayer({
    required CareerDefinition career,
    required CareerDatabasePlayer player,
  }) {
    final alreadyExists = career.databasePlayers.any(
      (entry) => entry.databasePlayerId == player.databasePlayerId,
    );
    if (alreadyExists) {
      return career;
    }
    return career.copyWith(
      databasePlayers: <CareerDatabasePlayer>[
        ...career.databasePlayers,
        player,
      ],
    );
  }

  CareerDefinition updateDatabasePlayer({
    required CareerDefinition career,
    required CareerDatabasePlayer player,
  }) {
    return career.copyWith(
      databasePlayers: career.databasePlayers
          .map(
            (entry) => entry.databasePlayerId == player.databasePlayerId
                ? player
                : entry,
          )
          .toList(),
    );
  }

  CareerDefinition removeDatabasePlayer({
    required CareerDefinition career,
    required String databasePlayerId,
  }) {
    return career.copyWith(
      databasePlayers: career.databasePlayers
          .where((entry) => entry.databasePlayerId != databasePlayerId)
          .toList(),
    );
  }

  CareerDefinition addCareerTagDefinition({
    required CareerDefinition career,
    required CareerTagDefinition tagDefinition,
  }) {
    final alreadyExists = career.careerTagDefinitions.any(
      (entry) => entry.name.toLowerCase() == tagDefinition.name.toLowerCase(),
    );
    if (alreadyExists) {
      return career;
    }
    return career.copyWith(
      careerTagDefinitions: <CareerTagDefinition>[
        ...career.careerTagDefinitions,
        tagDefinition,
      ],
    );
  }

  CareerDefinition updateCareerTagDefinition({
    required CareerDefinition career,
    required CareerTagDefinition tagDefinition,
  }) {
    return career.copyWith(
      careerTagDefinitions: career.careerTagDefinitions
          .map((entry) => entry.id == tagDefinition.id ? tagDefinition : entry)
          .toList(),
    );
  }

  CareerDefinition removeCareerTagDefinition({
    required CareerDefinition career,
    required String tagDefinitionId,
  }) {
    CareerTagDefinition? removedDefinition;
    for (final definition in career.careerTagDefinitions) {
      if (definition.id == tagDefinitionId) {
        removedDefinition = definition;
        break;
      }
    }
    if (removedDefinition == null) {
      return career;
    }
    return career.copyWith(
      careerTagDefinitions: career.careerTagDefinitions
          .where((entry) => entry.id != tagDefinitionId)
          .map(
            (entry) => entry.copyWith(
              tagsToAddOnExpiry: entry.tagsToAddOnExpiry
                  .where((tagName) => tagName != removedDefinition!.name)
                  .toList(),
              tagsToRemoveOnInitialAssignment: entry
                  .tagsToRemoveOnInitialAssignment
                  .where((tagName) => tagName != removedDefinition!.name)
                  .toList(),
              tagsToRemoveOnExtension: entry.tagsToRemoveOnExtension
                  .where((tagName) => tagName != removedDefinition!.name)
                  .toList(),
              fillUpRequiredCareerTags: entry.fillUpRequiredCareerTags
                  .where((tagName) => tagName != removedDefinition!.name)
                  .toList(),
              fillUpExcludedCareerTags: entry.fillUpExcludedCareerTags
                  .where((tagName) => tagName != removedDefinition!.name)
                  .toList(),
            ),
          )
          .toList(),
      seasonTagRules: career.seasonTagRules
          .where((entry) => entry.tagName != removedDefinition!.name)
          .toList(),
      databasePlayers: career.databasePlayers
          .map(
            (player) => player.copyWith(
              careerTags: player.careerTags
                  .where((tag) => tag.tagName != removedDefinition!.name)
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  CareerDefinition addSeasonTagRule({
    required CareerDefinition career,
    required CareerSeasonTagRule rule,
  }) {
    return career.copyWith(
      seasonTagRules: <CareerSeasonTagRule>[
        ...career.seasonTagRules,
        rule,
      ],
    );
  }

  CareerDefinition updateSeasonTagRule({
    required CareerDefinition career,
    required CareerSeasonTagRule rule,
  }) {
    return career.copyWith(
      seasonTagRules: career.seasonTagRules
          .map((entry) => entry.id == rule.id ? rule : entry)
          .toList(),
    );
  }

  CareerDefinition removeSeasonTagRule({
    required CareerDefinition career,
    required String ruleId,
  }) {
    return career.copyWith(
      seasonTagRules:
          career.seasonTagRules.where((entry) => entry.id != ruleId).toList(),
    );
  }

  CareerDefinition updateCalendarItem({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        calendar: career.currentSeason.calendar
            .map((entry) => entry.id == item.id ? item : entry)
            .toList(),
      ),
    );
  }

  CareerDefinition removeCalendarItem({
    required CareerDefinition career,
    required String itemId,
  }) {
    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        calendar: career.currentSeason.calendar
            .where((item) => item.id != itemId)
            .toList(),
      ),
    );
  }

  CareerDefinition reorderCalendar({
    required CareerDefinition career,
    required int oldIndex,
    required int newIndex,
  }) {
    final nextCalendar = List<CareerCalendarItem>.from(career.currentSeason.calendar);
    if (oldIndex < 0 ||
        oldIndex >= nextCalendar.length ||
        newIndex < 0 ||
        newIndex >= nextCalendar.length) {
      return career;
    }

    final item = nextCalendar.removeAt(oldIndex);
    nextCalendar.insert(newIndex, item);
    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(calendar: nextCalendar),
    );
  }

  CareerDefinition startCareer(CareerDefinition career) {
    return career.copyWith(isStarted: true);
  }

  CareerDefinition finishCurrentSeason(CareerDefinition career) {
    final completedSeason = career.currentSeason.copyWith(
      calendar: List<CareerCalendarItem>.from(career.currentSeason.calendar),
      isCompleted: true,
      completedItemIds: List<String>.from(career.currentSeason.completedItemIds),
    );
    final nextSeason = career.currentSeason.copyWith(
      seasonNumber: career.currentSeason.seasonNumber + 1,
      calendar: List<CareerCalendarItem>.from(career.currentSeason.calendar),
      isCompleted: false,
      completedItemIds: const <String>[],
    );

    return career.copyWith(
      completedSeasons: <CareerSeason>[
        ...career.completedSeasons,
        completedSeason,
      ],
      currentSeason: nextSeason,
    );
  }

  CareerDefinition completeTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
    required String winnerId,
    required String winnerName,
    String? runnerUpId,
    String? runnerUpName,
    List<String> semiFinalistIds = const <String>[],
    List<String> quarterFinalistIds = const <String>[],
    Map<String, int> playerPayouts = const <String, int>{},
    Map<String, String> playerResultLabels = const <String, String>{},
    Map<String, CareerX01PlayerStats> playerX01Stats =
        const <String, CareerX01PlayerStats>{},
  }) {
    if (career.currentSeason.completedItemIds.contains(item.id)) {
      return career;
    }
    final calendarIndex = career.currentSeason.calendar.indexWhere(
      (entry) => entry.id == item.id,
    );

    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        completedItemIds: <String>[
          ...career.currentSeason.completedItemIds,
          item.id,
        ],
      ),
      completedTournaments: <CareerCompletedTournament>[
        ...career.completedTournaments,
        CareerCompletedTournament(
          seasonNumber: career.currentSeason.seasonNumber,
          calendarItemId: item.id,
          calendarIndex: calendarIndex,
          name: item.name,
          fieldSize: item.fieldSize,
          winnerId: winnerId,
          winnerName: winnerName,
          runnerUpId: runnerUpId,
          runnerUpName: runnerUpName,
          semiFinalistIds: semiFinalistIds,
          quarterFinalistIds: quarterFinalistIds,
          prizePool: item.prizePool,
          playerPayouts: playerPayouts,
          playerResultLabels: playerResultLabels,
          playerX01Stats: playerX01Stats,
          countsForRankingIds: item.countsForRankingIds,
        ),
      ],
    );
  }

  CareerDefinition skipTournament({
    required CareerDefinition career,
    required CareerCalendarItem item,
  }) {
    if (career.currentSeason.completedItemIds.contains(item.id)) {
      return career;
    }
    return career.copyWith(
      currentSeason: career.currentSeason.copyWith(
        completedItemIds: <String>[
          ...career.currentSeason.completedItemIds,
          item.id,
        ],
      ),
    );
  }
}

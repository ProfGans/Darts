import 'package:flutter_test/flutter_test.dart';

import 'package:DartCore/domain/tournament/tournament_engine.dart';
import 'package:DartCore/domain/tournament/tournament_models.dart';
import 'package:DartCore/domain/x01/x01_models.dart';

void main() {
  group('TournamentEngine', () {
    test('league playoff supports non power of two qualifier counts', () {
      final engine = TournamentEngine();
      const definition = TournamentDefinition(
        name: 'League Playoff',
        format: TournamentFormat.leaguePlayoff,
        fieldSize: 6,
        matchMode: MatchMode.legs,
        legsToWin: 4,
        startScore: 501,
        playoffQualifierCount: 6,
        includeHumanPlayer: false,
      );
      final participants = List<TournamentParticipant>.generate(
        6,
        (index) => TournamentParticipant(
          id: 'p$index',
          name: 'P$index',
          type: TournamentParticipantType.computer,
          average: 90 - index.toDouble(),
          seedNumber: index + 1,
        ),
      );

      var bracket = engine.buildBracket(
        definition: definition,
        participants: participants,
      );

      for (final round in List<TournamentRound>.from(bracket.leagueRounds)) {
        for (final match in round.matches) {
          bracket = engine.applyResult(
            bracket: bracket,
            matchId: match.id,
            result: TournamentMatchResult(
              winnerId: match.playerA!.id,
              winnerName: match.playerA!.name,
              scoreText: '4:0 Legs',
            ),
          );
        }
      }

      bracket = engine.ensureLeaguePlayoffRounds(bracket);

      final playoffRounds = bracket.playoffRounds;
      expect(playoffRounds, hasLength(3));
      expect(playoffRounds.first.matches, hasLength(4));
      expect(
        playoffRounds.first.matches.where(
          (match) => match.status == TournamentMatchStatus.completed,
        ),
        isNotEmpty,
      );
      expect(
        playoffRounds[1].matches.any((match) => match.playerA != null || match.playerB != null),
        isTrue,
      );
    });
  });

  group('Tournament standings', () {
    test('use leg difference as a league tie breaker', () {
      final bracket = TournamentBracket(
        definition: const TournamentDefinition(
          name: 'Leg League',
          format: TournamentFormat.league,
          fieldSize: 3,
          matchMode: MatchMode.legs,
          legsToWin: 4,
          startScore: 501,
          includeHumanPlayer: false,
        ),
        participants: <TournamentParticipant>[
          _participant('a', 'A', 80),
          _participant('b', 'B', 79),
          _participant('c', 'C', 78),
        ],
        rounds: <TournamentRound>[
          _completedRound(
            1,
            _completedMatch(
              'r1-m1',
              1,
              'a',
              'A',
              'b',
              'B',
              winnerId: 'a',
              winnerName: 'A',
              scoreText: '4:0 Legs',
            ),
          ),
          _completedRound(
            2,
            _completedMatch(
              'r2-m1',
              2,
              'b',
              'B',
              'c',
              'C',
              winnerId: 'b',
              winnerName: 'B',
              scoreText: '4:0 Legs',
            ),
          ),
          _completedRound(
            3,
            _completedMatch(
              'r3-m1',
              3,
              'c',
              'C',
              'a',
              'A',
              winnerId: 'c',
              winnerName: 'C',
              scoreText: '4:3 Legs',
            ),
          ),
        ],
      );

      expect(
        bracket.standings.map((entry) => entry.participant.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });

    test('use set difference in sets leagues', () {
      final bracket = TournamentBracket(
        definition: const TournamentDefinition(
          name: 'Set League',
          format: TournamentFormat.league,
          fieldSize: 3,
          matchMode: MatchMode.sets,
          legsToWin: 3,
          setsToWin: 2,
          startScore: 501,
          includeHumanPlayer: false,
        ),
        participants: <TournamentParticipant>[
          _participant('a', 'A', 80),
          _participant('b', 'B', 79),
          _participant('c', 'C', 78),
        ],
        rounds: <TournamentRound>[
          _completedRound(
            1,
            _completedMatch(
              'r1-m1',
              1,
              'a',
              'A',
              'b',
              'B',
              winnerId: 'a',
              winnerName: 'A',
              scoreText: '2:0 Sets',
            ),
          ),
          _completedRound(
            2,
            _completedMatch(
              'r2-m1',
              2,
              'b',
              'B',
              'c',
              'C',
              winnerId: 'b',
              winnerName: 'B',
              scoreText: '2:0 Sets',
            ),
          ),
          _completedRound(
            3,
            _completedMatch(
              'r3-m1',
              3,
              'c',
              'C',
              'a',
              'A',
              winnerId: 'c',
              winnerName: 'C',
              scoreText: '2:1 Sets',
            ),
          ),
        ],
      );

      expect(
        bracket.standings.map((entry) => entry.participant.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });

    test('build grouped standings for group stage', () {
      final engine = TournamentEngine();
      final participants = List<TournamentParticipant>.generate(
        8,
        (index) => TournamentParticipant(
          id: 'p$index',
          name: 'P$index',
          type: TournamentParticipantType.computer,
          average: 90 - index.toDouble(),
          seedNumber: index + 1,
        ),
      );
      final bracket = engine.buildBracket(
        definition: const TournamentDefinition(
          name: 'Groups',
          format: TournamentFormat.groupStage,
          fieldSize: 8,
          matchMode: MatchMode.legs,
          legsToWin: 4,
          startScore: 501,
          roundRobinRepeats: 1,
          groupCount: 2,
          playersPerGroup: 4,
          includeHumanPlayer: false,
        ),
        participants: participants,
      );

      expect(bracket.groupRounds, hasLength(6));
      expect(bracket.groupedStandings, hasLength(2));
      expect(bracket.groupedStandings.first.groupName, 'Gruppe A');
      expect(bracket.groupedStandings.last.groupName, 'Gruppe B');
      expect(
        bracket.groupedStandings
            .map((section) => section.standings.length)
            .toList(),
        <int>[4, 4],
      );
      expect(bracket.champion, isNull);
      expect(bracket.runnerUp, isNull);
    });

    test('limit league schedule to configured maximum matchdays', () {
      final engine = TournamentEngine();
      final participants = List<TournamentParticipant>.generate(
        10,
        (index) => TournamentParticipant(
          id: 'p$index',
          name: 'P$index',
          type: TournamentParticipantType.computer,
          average: 90 - index.toDouble(),
        ),
      );
      final bracket = engine.buildBracket(
        definition: const TournamentDefinition(
          name: 'Limited League',
          format: TournamentFormat.league,
          fieldSize: 10,
          matchMode: MatchMode.legs,
          legsToWin: 4,
          startScore: 501,
          roundRobinRepeats: 1,
          maxLeagueMatchesPerParticipant: 5,
          includeHumanPlayer: false,
        ),
        participants: participants,
      );

      expect(bracket.leagueRounds, hasLength(5));
      expect(bracket.totalMatchCount, 25);
    });

    test('single-group group stage exposes champion and runner up from table', () {
      final bracket = TournamentBracket(
        definition: const TournamentDefinition(
          name: 'Single Group',
          format: TournamentFormat.groupStage,
          fieldSize: 3,
          matchMode: MatchMode.legs,
          legsToWin: 4,
          startScore: 501,
          groupCount: 1,
          playersPerGroup: 3,
          includeHumanPlayer: false,
        ),
        participants: <TournamentParticipant>[
          _participant('a', 'A', 80),
          _participant('b', 'B', 79),
          _participant('c', 'C', 78),
        ],
        rounds: <TournamentRound>[
          _completedGroupRound(
            1,
            1,
            'Gruppe A',
            _completedMatch(
              'g1-m1',
              1,
              'a',
              'A',
              'b',
              'B',
              winnerId: 'a',
              winnerName: 'A',
              scoreText: '4:0 Legs',
            ),
          ),
          _completedGroupRound(
            2,
            1,
            'Gruppe A',
            _completedMatch(
              'g2-m1',
              2,
              'b',
              'B',
              'c',
              'C',
              winnerId: 'b',
              winnerName: 'B',
              scoreText: '4:0 Legs',
            ),
          ),
          _completedGroupRound(
            3,
            1,
            'Gruppe A',
            _completedMatch(
              'g3-m1',
              3,
              'a',
              'A',
              'c',
              'C',
              winnerId: 'a',
              winnerName: 'A',
              scoreText: '4:1 Legs',
            ),
          ),
        ],
      );

      expect(bracket.groupedStandings, hasLength(1));
      expect(bracket.champion?.id, 'a');
      expect(bracket.runnerUp?.id, 'b');
    });
  });
}

TournamentParticipant _participant(String id, String name, double average) {
  return TournamentParticipant(
    id: id,
    name: name,
    type: TournamentParticipantType.computer,
    average: average,
  );
}

TournamentRound _completedRound(int roundNumber, TournamentMatch match) {
  return TournamentRound(
    roundNumber: roundNumber,
    title: 'Round $roundNumber',
    stage: TournamentRoundStage.league,
    matches: <TournamentMatch>[match],
  );
}

TournamentRound _completedGroupRound(
  int roundNumber,
  int groupNumber,
  String groupName,
  TournamentMatch match,
) {
  return TournamentRound(
    roundNumber: roundNumber,
    title: '$groupName - Spieltag $roundNumber',
    stage: TournamentRoundStage.group,
    groupNumber: groupNumber,
    groupName: groupName,
    matches: <TournamentMatch>[match],
  );
}

TournamentMatch _completedMatch(
  String id,
  int roundNumber,
  String playerAId,
  String playerAName,
  String playerBId,
  String playerBName, {
  required String winnerId,
  required String winnerName,
  required String scoreText,
}) {
  return TournamentMatch(
    id: id,
    roundNumber: roundNumber,
    matchNumber: 1,
    playerA: _participant(playerAId, playerAName, 0),
    playerB: _participant(playerBId, playerBName, 0),
    status: TournamentMatchStatus.completed,
    result: TournamentMatchResult(
      winnerId: winnerId,
      winnerName: winnerName,
      scoreText: scoreText,
    ),
  );
}

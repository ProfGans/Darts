import 'package:flutter/material.dart';

import '../../data/repositories/tournament_repository.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';
import '../match/game_mode_models.dart';
import '../match/match_screen.dart';
import '../match/match_session_config.dart';

class TournamentBracketScreen extends StatelessWidget {
  const TournamentBracketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = TournamentRepository.instance;
    return AnimatedBuilder(
      animation: repository,
      builder: (context, _) {
        final bracket = repository.currentBracket;
        if (bracket == null) {
          return const Scaffold(
            body: Center(child: Text('Kein Turnier vorhanden.')),
          );
        }
        final seededParticipants = bracket.participants
            .where((participant) => participant.seedNumber != null)
            .toList()
          ..sort((left, right) =>
              (left.seedNumber ?? 1 << 20).compareTo(right.seedNumber ?? 1 << 20));
        final knockoutRounds = bracket.rounds
            .where((round) => round.stage == TournamentRoundStage.knockout)
            .toList();
        final playoffRounds = bracket.playoffRounds;
        final focus = _findFocusMatch(bracket);
        final nextRoundNumber = _nextPendingRoundNumber(bracket);
        final pendingHumanInNextRound = nextRoundNumber == null
            ? false
            : _hasPendingHumanMatchInRound(bracket, nextRoundNumber);

        return Scaffold(
          appBar: AppBar(title: Text(bracket.definition.name)),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: <Widget>[
                _SummaryCard(
                  bracket: bracket,
                  seededParticipants: seededParticipants,
                ),
                if (focus != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Card(
                    color: const Color(0xFFEFF6FF),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _MatchTile(
                        match: focus.$1,
                        roundStage: focus.$2,
                        emphasize: true,
                        onWinnerPicked: (winnerId) {
                          repository.resolveHumanMatch(
                            matchId: focus.$1.id,
                            winnerId: winnerId,
                          );
                        },
                      ),
                    ),
                  ),
                ],
                if (seededParticipants.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _SeedsCard(participants: seededParticipants),
                ],
                const SizedBox(height: 12),
                _ActionsCard(
                  bracket: bracket,
                  nextPendingRoundNumber: nextRoundNumber,
                  pendingHumanInNextRound: pendingHumanInNextRound,
                ),
                if (bracket.definition.format == TournamentFormat.knockout &&
                    knockoutRounds.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  _BracketStageCard(title: 'Turnierbaum', rounds: knockoutRounds),
                ],
                if (bracket.definition.format == TournamentFormat.leaguePlayoff)
                  ...<Widget>[
                    const SizedBox(height: 12),
                    playoffRounds.isEmpty
                        ? const _InfoCard(
                            title: 'Playoff-Baum',
                            body:
                                'Die Playoffs werden automatisch erzeugt, sobald alle Ligaspieltage abgeschlossen sind.',
                          )
                        : _BracketStageCard(
                            title: 'Playoff-Baum',
                            rounds: playoffRounds,
                          ),
                  ],
                if (bracket.definition.format == TournamentFormat.league ||
                    bracket.definition.format ==
                        TournamentFormat.leaguePlayoff) ...<Widget>[
                  const SizedBox(height: 12),
                  _StandingsCard(
                    bracket: bracket,
                    showSetDifference:
                        bracket.definition.matchMode == MatchMode.sets,
                  ),
                ],
                const SizedBox(height: 12),
                _RoundsCard(
                  bracket: bracket,
                  hiddenMatchId: focus?.$1.id,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

(TournamentMatch, TournamentRoundStage)? _findFocusMatch(TournamentBracket bracket) {
  TournamentMatch? focusMatch;
  TournamentRoundStage focusRoundStage = TournamentRoundStage.knockout;
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (!match.isHumanMatch) {
        continue;
      }
      focusMatch ??= match;
      focusRoundStage = round.stage;
      if (match.status == TournamentMatchStatus.pending) {
        return (match, round.stage);
      }
    }
  }
  if (focusMatch == null) {
    return null;
  }
  return (focusMatch, focusRoundStage);
}

int? _nextPendingRoundNumber(TournamentBracket bracket) {
  for (final round in bracket.rounds) {
    for (final match in round.matches) {
      if (match.status == TournamentMatchStatus.pending && match.isReady) {
        return round.roundNumber;
      }
    }
  }
  return null;
}

bool _hasPendingHumanMatchInRound(TournamentBracket bracket, int roundNumber) {
  for (final round in bracket.rounds) {
    if (round.roundNumber != roundNumber) {
      continue;
    }
    return round.matches.any(
      (match) =>
          match.status == TournamentMatchStatus.pending &&
          match.isReady &&
          match.isHumanMatch,
    );
  }
  return false;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.bracket,
    required this.seededParticipants,
  });

  final TournamentBracket bracket;
  final List<TournamentParticipant> seededParticipants;

  @override
  Widget build(BuildContext context) {
    final bracketSize = bracket.rounds.isEmpty
        ? bracket.definition.fieldSize
        : bracket.rounds.first.matches.length * 2;
    final byeCount = bracketSize - bracket.participants.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              bracket.definition.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              bracket.definition.format == TournamentFormat.knockout
                  ? 'Turnierbaum'
                  : bracket.definition.format == TournamentFormat.leaguePlayoff
                      ? 'Liga und Playoff-Baum'
                      : 'Ligaansicht',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _CompactInfoChip(label: '${bracket.participants.length} Teilnehmer'),
                if (bracket.definition.format == TournamentFormat.knockout &&
                    byeCount > 0)
                  _CompactInfoChip(label: '$byeCount Freilose'),
                _CompactInfoChip(
                  label: switch (bracket.definition.format) {
                    TournamentFormat.league =>
                      'Liga ${bracket.definition.roundRobinRepeats}x',
                    TournamentFormat.leaguePlayoff =>
                      'Liga+Playoff Top ${bracket.definition.playoffQualifierCount}',
                    TournamentFormat.knockout =>
                      bracket.definition.matchMode == MatchMode.legs
                          ? 'Legs ${bracket.definition.legsToWin}'
                          : 'Sets ${bracket.definition.setsToWin}',
                  },
                ),
                if (bracket.definition.format != TournamentFormat.knockout)
                  _CompactInfoChip(
                    label:
                        '${bracket.definition.pointsForWin}/${bracket.definition.pointsForDraw} Punkte',
                  ),
                if (bracket.champion != null)
                  _CompactInfoChip(label: 'Sieger ${bracket.champion!.name}'),
                if (seededParticipants.isNotEmpty)
                  _CompactInfoChip(label: '${seededParticipants.length} gesetzt'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeedsCard extends StatelessWidget {
  const _SeedsCard({required this.participants});

  final List<TournamentParticipant> participants;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text('Setzliste', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${participants.length} Spieler gesetzt'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: participants
                  .map(
                    (participant) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('S${participant.seedNumber} ${participant.name}'),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.bracket,
    required this.nextPendingRoundNumber,
    required this.pendingHumanInNextRound,
  });

  final TournamentBracket bracket;
  final int? nextPendingRoundNumber;
  final bool pendingHumanInNextRound;

  @override
  Widget build(BuildContext context) {
    final repository = TournamentRepository.instance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Aktionen', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: repository.simulateNextCpuMatch,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Naechstes CPU Match'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed:
                  nextPendingRoundNumber == null ? null : repository.simulateNextRound,
              icon: const Icon(Icons.skip_next_outlined),
              label: Text(
                pendingHumanInNextRound
                    ? 'Aktuelle Runde simulieren'
                    : 'Naechste Runde simulieren',
              ),
            ),
            if (pendingHumanInNextRound) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Dein Match ist in der aktuellen offenen Runde noch nicht gespielt. Darum wird nur diese Runde simuliert.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF5D7285),
                    ),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: repository.simulateRemainingCpuMatches,
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Rest simulieren'),
            ),
            if (repository.isCareerTournament) ...<Widget>[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: bracket.isCompleted
                    ? () {
                        repository.commitCurrentCareerTournament();
                        Navigator.of(context).pop();
                      }
                    : null,
                icon: const Icon(Icons.task_alt_rounded),
                label: const Text('In Karriere uebernehmen'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BracketStageCard extends StatelessWidget {
  const _BracketStageCard({
    required this.title,
    required this.rounds,
  });

  final String title;
  final List<TournamentRound> rounds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '${rounds.length} Runden',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: rounds.asMap().entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: entry.key == rounds.length - 1 ? 0 : 14,
                    ),
                    child: _BracketColumn(
                      round: entry.value,
                      roundIndex: entry.key,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketColumn extends StatelessWidget {
  const _BracketColumn({
    required this.round,
    required this.roundIndex,
  });

  final TournamentRound round;
  final int roundIndex;

  @override
  Widget build(BuildContext context) {
    final topPadding = roundIndex == 0 ? 0.0 : 16.0 * roundIndex;
    final gap = 12.0 + (roundIndex * 18.0);
    return SizedBox(
      width: 248,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            round.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: topPadding),
          ...round.matches.asMap().entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(
                bottom: entry.key == round.matches.length - 1 ? 0 : gap,
              ),
              child: _BracketMatchCard(
                match: entry.value,
                roundStage: round.stage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BracketMatchCard extends StatelessWidget {
  const _BracketMatchCard({
    required this.match,
    required this.roundStage,
  });

  final TournamentMatch match;
  final TournamentRoundStage roundStage;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (match.status) {
      TournamentMatchStatus.completed => const Color(0xFFD9F2E4),
      TournamentMatchStatus.pending => match.isReady
          ? const Color(0xFFFFF0C7)
          : const Color(0xFFE8EEF4),
    };
    final statusText = switch (match.status) {
      TournamentMatchStatus.completed => match.result?.scoreText ?? 'Fertig',
      TournamentMatchStatus.pending => match.isReady ? 'Offen' : 'Wartet',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (context) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _MatchTile(
                  match: match,
                  roundStage: roundStage,
                  onWinnerPicked: (winnerId) {
                    TournamentRepository.instance.resolveHumanMatch(
                      matchId: match.id,
                      winnerId: winnerId,
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E8EF)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: Text('Match ${match.matchNumber}')),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _BracketPlayerRow(
                name: match.playerA?.name ?? 'Offen',
                isWinner: match.result?.winnerId == match.playerA?.id,
                isHuman: match.playerA?.isHuman ?? false,
              ),
              const SizedBox(height: 6),
              _BracketPlayerRow(
                name: match.playerB?.name ?? 'Offen',
                isWinner: match.result?.winnerId == match.playerB?.id,
                isHuman: match.playerB?.isHuman ?? false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BracketPlayerRow extends StatelessWidget {
  const _BracketPlayerRow({
    required this.name,
    required this.isWinner,
    required this.isHuman,
  });

  final String name;
  final bool isWinner;
  final bool isHuman;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
        if (isHuman) const Icon(Icons.person, size: 16),
        if (isWinner) const Padding(
          padding: EdgeInsets.only(left: 6),
          child: Icon(Icons.emoji_events_outlined, size: 16),
        ),
      ],
    );
  }
}

class _StandingsCard extends StatelessWidget {
  const _StandingsCard({
    required this.bracket,
    required this.showSetDifference,
  });

  final TournamentBracket bracket;
  final bool showSetDifference;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text('Tabelle', style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${bracket.standings.length} Spieler'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: bracket.standings.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == bracket.standings.length - 1 ? 0 : 8,
            ),
            child: _StandingTile(
              rank: entry.key + 1,
              standing: entry.value,
              showSetDifference: showSetDifference,
            ),
          ),
        ).toList(),
      ),
    );
  }
}

class _RoundsCard extends StatelessWidget {
  const _RoundsCard({
    required this.bracket,
    required this.hiddenMatchId,
  });

  final TournamentBracket bracket;
  final String? hiddenMatchId;

  @override
  Widget build(BuildContext context) {
    final repository = TournamentRepository.instance;
    return Card(
      child: ExpansionTile(
        initiallyExpanded:
            bracket.definition.format == TournamentFormat.league,
        title: Text(
          'Runden und Matches',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('${bracket.rounds.length} Abschnitte'),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: bracket.rounds.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == bracket.rounds.length - 1 ? 0 : 12,
            ),
            child: _RoundSection(
              round: entry.value,
              initiallyExpanded: !entry.value.isCompleted || entry.key == 0,
              hiddenMatchId: hiddenMatchId,
              onWinnerPicked: (matchId, winnerId) {
                repository.resolveHumanMatch(
                  matchId: matchId,
                  winnerId: winnerId,
                );
              },
            ),
          ),
        ).toList(),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({
    required this.match,
    required this.roundStage,
    required this.onWinnerPicked,
    this.emphasize = false,
  });

  final TournamentMatch match;
  final TournamentRoundStage roundStage;
  final ValueChanged<String> onWinnerPicked;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (match.status) {
      TournamentMatchStatus.completed => match.result?.scoreText ?? 'Fertig',
      TournamentMatchStatus.pending => match.isReady ? 'Offen' : 'Wartet auf Gegner',
    };
    final repository = TournamentRepository.instance;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFFFFF) : const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: emphasize ? Border.all(color: const Color(0xFFBEDBFF)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  '${match.playerA?.name ?? 'Offen'} vs ${match.playerB?.name ?? 'Offen'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _CompactInfoChip(label: statusText),
            ],
          ),
          if (match.playerA != null || match.playerB != null) ...<Widget>[
            const SizedBox(height: 8),
            if (match.playerA != null) _ParticipantBadge(player: match.playerA!),
            if (match.playerA != null && match.playerB != null)
              const SizedBox(height: 8),
            if (match.playerB != null) _ParticipantBadge(player: match.playerB!),
          ],
          if (match.isHumanMatch &&
              match.isReady &&
              match.status == TournamentMatchStatus.pending) ...<Widget>[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                repository.simulateRemainingCpuMatchesInRound(match.roundNumber);
                _playMatch(context);
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Mein Match spielen'),
            ),
            if (match.playerA != null) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onWinnerPicked(match.playerA!.id),
                child: Text('${match.playerA!.name} gewinnt'),
              ),
            ],
            if (match.playerB != null) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onWinnerPicked(match.playerB!.id),
                child: Text('${match.playerB!.name} gewinnt'),
              ),
            ],
            if (roundStage == TournamentRoundStage.league) ...<Widget>[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  repository.resolveMatchAsDraw(matchId: match.id);
                },
                child: const Text('Unentschieden'),
              ),
            ],
          ] else if (match.status == TournamentMatchStatus.completed &&
              match.result != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              match.result!.isDraw
                  ? 'Ergebnis: Unentschieden'
                  : 'Gewinner: ${match.result!.winnerName}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF44576A),
                  ),
            ),
          ],
        ],
      ),
    );
  }

  void _playMatch(BuildContext context) {
    if (!match.isReady || !match.isHumanMatch) {
      return;
    }
    final human = match.playerA?.isHuman ?? false ? match.playerA! : match.playerB!;
    final bot = match.playerA?.isHuman ?? false ? match.playerB! : match.playerA!;
    final bracket = TournamentRepository.instance.currentBracket!;
    final definition = bracket.definition;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(
          session: MatchSessionConfig(
            gameMode: GameMode.x01,
            participants: <MatchParticipantConfig>[
              MatchParticipantConfig(id: human.id, name: human.name, isHuman: true),
              MatchParticipantConfig(
                id: bot.id,
                name: bot.name,
                isHuman: false,
                botProfile: TournamentRepository.instance.profileForParticipant(bot.id),
              ),
            ],
            matchConfig: MatchConfig(
              startScore: definition.startScore,
              mode: definition.matchMode,
              startRequirement: definition.startRequirement,
              checkoutRequirement: definition.checkoutRequirement,
              legsToWin: _legsToWinForMatch(bracket, definition),
              setsToWin: _setsToWinForMatch(bracket, definition),
              legsPerSet: definition.legsPerSet,
            ),
            tournamentMatchId: match.id,
            playerParticipantId: human.id,
            botParticipantId: bot.id,
            useBullOff: true,
            returnButtonLabel: 'Zum Turnier',
          ),
        ),
      ),
    );
  }

  int _legsToWinForMatch(TournamentBracket bracket, TournamentDefinition definition) {
    if (definition.matchMode != MatchMode.legs) {
      return definition.legsToWin;
    }
    if (definition.format == TournamentFormat.leaguePlayoff &&
        roundStage == TournamentRoundStage.playoff) {
      return definition.distanceForRound(bracket.stageRoundIndex(match.roundNumber));
    }
    return definition.distanceForRound(match.roundNumber);
  }

  int _setsToWinForMatch(TournamentBracket bracket, TournamentDefinition definition) {
    if (definition.matchMode != MatchMode.sets) {
      return definition.setsToWin;
    }
    if (definition.format == TournamentFormat.leaguePlayoff &&
        roundStage == TournamentRoundStage.playoff) {
      return definition.distanceForRound(bracket.stageRoundIndex(match.roundNumber));
    }
    return definition.distanceForRound(match.roundNumber);
  }
}

class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.round,
    required this.initiallyExpanded,
    required this.onWinnerPicked,
    this.hiddenMatchId,
  });

  final TournamentRound round;
  final bool initiallyExpanded;
  final String? hiddenMatchId;
  final void Function(String matchId, String winnerId) onWinnerPicked;

  @override
  Widget build(BuildContext context) {
    final visibleMatches = hiddenMatchId == null
        ? round.matches
        : round.matches.where((match) => match.id != hiddenMatchId).toList();
    if (visibleMatches.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(round.title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${visibleMatches.length} Matches${round.isCompleted ? ' | abgeschlossen' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: visibleMatches.asMap().entries.map(
          (matchEntry) => Padding(
            padding: EdgeInsets.only(
              bottom: matchEntry.key == visibleMatches.length - 1 ? 0 : 10,
            ),
            child: _MatchTile(
              match: matchEntry.value,
              roundStage: round.stage,
              onWinnerPicked: (winnerId) {
                onWinnerPicked(matchEntry.value.id, winnerId);
              },
            ),
          ),
        ).toList(),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({
    required this.rank,
    required this.standing,
    required this.showSetDifference,
  });

  final int rank;
  final TournamentStanding standing;
  final bool showSetDifference;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$rank'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  standing.participant.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text('${standing.points} P'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CompactInfoChip(
                label: '${standing.wins}-${standing.draws}-${standing.losses}',
              ),
              _CompactInfoChip(label: '${standing.played} Spiele'),
              _CompactInfoChip(
                label: 'Legs ${standing.legsFor}:${standing.legsAgainst}'
                    ' (${standing.legDifference >= 0 ? '+' : ''}${standing.legDifference})',
              ),
              if (showSetDifference)
                _CompactInfoChip(
                  label: 'Sets ${standing.setsFor}:${standing.setsAgainst}'
                      ' (${standing.setDifference >= 0 ? '+' : ''}${standing.setDifference})',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantBadge extends StatelessWidget {
  const _ParticipantBadge({required this.player});

  final TournamentParticipant player;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            player.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (player.seedNumber != null)
                _CompactInfoChip(label: 'S${player.seedNumber}'),
              _CompactInfoChip(label: '${player.average.toStringAsFixed(1)} Avg'),
            ],
          ),
          if ((player.qualificationReason ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              player.qualificationReason!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5D7285),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactInfoChip extends StatelessWidget {
  const _CompactInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

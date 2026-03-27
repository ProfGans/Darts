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
            body: Center(
              child: Text('Kein Turnier vorhanden.'),
            ),
          );
        }
        final bracketSize = bracket.rounds.isEmpty
            ? bracket.definition.fieldSize
            : bracket.rounds.first.matches.length * 2;
        final byeCount = bracketSize - bracket.participants.length;
        final seededParticipants = bracket.participants
            .where((participant) => participant.seedNumber != null)
            .toList()
          ..sort((left, right) {
            final seedCompare =
                (left.seedNumber ?? 1 << 20).compareTo(right.seedNumber ?? 1 << 20);
            if (seedCompare != 0) {
              return seedCompare;
            }
            return left.name.compareTo(right.name);
          });
        TournamentMatch? focusMatch;
        TournamentRoundStage focusRoundStage = TournamentRoundStage.knockout;
        for (final round in bracket.rounds) {
          for (final match in round.matches) {
            if (match.isHumanMatch) {
              focusMatch ??= match;
              focusRoundStage = round.stage;
              if (match.status == TournamentMatchStatus.pending) {
                focusMatch = match;
                focusRoundStage = round.stage;
                break;
              }
            }
          }
          if (focusMatch != null &&
              focusMatch.status == TournamentMatchStatus.pending) {
            break;
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(bracket.definition.name),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: <Widget>[
                Card(
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
                              ? 'Turnieransicht'
                              : bracket.definition.format ==
                                      TournamentFormat.leaguePlayoff
                                  ? 'Liga und Playoffs'
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
                            _CompactInfoChip(
                              label: '${bracket.participants.length} Teilnehmer',
                            ),
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
                            if (bracket.definition.format == TournamentFormat.league ||
                                bracket.definition.format ==
                                    TournamentFormat.leaguePlayoff)
                              _CompactInfoChip(
                                label:
                                    '${bracket.definition.pointsForWin}/${bracket.definition.pointsForDraw} Punkte',
                              ),
                            if (bracket.champion != null)
                              _CompactInfoChip(
                                label: 'Sieger ${bracket.champion!.name}',
                              ),
                            if (seededParticipants.isNotEmpty)
                              _CompactInfoChip(
                                label: '${seededParticipants.length} gesetzt',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (focusMatch != null) ...<Widget>[
                  Card(
                    color: const Color(0xFFEFF6FF),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Dein Match',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            focusMatch.status == TournamentMatchStatus.pending
                                ? 'Das ist dein aktueller Fokus in diesem Turnier.'
                                : 'Dein letztes oder kommendes Match auf einen Blick.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF5D7285),
                                ),
                          ),
                          const SizedBox(height: 12),
                          _MatchTile(
                            match: focusMatch,
                            roundStage: focusRoundStage,
                            emphasize: true,
                            onWinnerPicked: (winnerId) {
                              repository.resolveHumanMatch(
                                matchId: focusMatch!.id,
                                winnerId: winnerId,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (seededParticipants.isNotEmpty) ...<Widget>[
                  Card(
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      title: Text(
                        'Setzliste',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text('${seededParticipants.length} Spieler gesetzt'),
                      children: <Widget>[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: seededParticipants
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
                                    child: Text(
                                      'S${participant.seedNumber} ${participant.name}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Aktionen',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: repository.simulateNextCpuMatch,
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Naechstes CPU Match'),
                        ),
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
                ),
                const SizedBox(height: 12),
                if (bracket.definition.format == TournamentFormat.league ||
                    bracket.definition.format ==
                        TournamentFormat.leaguePlayoff) ...<Widget>[
                  Card(
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      title: Text(
                        'Tabelle',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text('${bracket.standings.length} Spieler'),
                      children: <Widget>[
                        ...bracket.standings.asMap().entries.map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(
                              bottom: entry.key == bracket.standings.length - 1
                                  ? 0
                                  : 8,
                            ),
                            child: _StandingTile(
                              rank: entry.key + 1,
                              standing: entry.value,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                ...bracket.rounds.asMap().entries.map(
                  (entry) => Padding(
                    padding: EdgeInsets.only(
                      bottom: entry.key == bracket.rounds.length - 1 ? 0 : 12,
                    ),
                    child: _RoundSection(
                      round: entry.value,
                      initiallyExpanded: !entry.value.isCompleted || entry.key == 0,
                      hiddenMatchId: focusMatch?.id,
                      onWinnerPicked: (matchId, winnerId) {
                        repository.resolveHumanMatch(
                          matchId: matchId,
                          winnerId: winnerId,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final isByeMatch =
        match.result?.scoreText == 'Freilos' &&
        ((match.playerA != null) != (match.playerB != null));
    final statusText = switch (match.status) {
      TournamentMatchStatus.completed => match.result?.scoreText ?? 'Fertig',
      TournamentMatchStatus.pending => match.isReady ? 'Offen' : 'Wartet auf Gegner',
    };
    final repository = TournamentRepository.instance;
    final participantNames = isByeMatch
        ? '${match.playerA?.name ?? match.playerB?.name ?? 'Spieler'} hat ein Freilos'
        : '${match.playerA?.name ?? 'Offen'} vs ${match.playerB?.name ?? 'Offen'}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFFFFF) : const Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(14),
        border: emphasize
            ? Border.all(
                color: const Color(0xFFBEDBFF),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  participantNames,
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
            Column(
              children: <Widget>[
                if (match.playerA != null)
                  _ParticipantBadge(player: match.playerA!),
                if (match.playerA != null && match.playerB != null)
                  const SizedBox(height: 8),
                if (match.playerB != null)
                  _ParticipantBadge(player: match.playerB!),
              ],
            ),
          ],
          if (match.playerA != null || match.playerB != null) ...<Widget>[
            const SizedBox(height: 12),
            if (match.isHumanMatch &&
                match.isReady &&
                match.status == TournamentMatchStatus.pending)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () {
                      repository.simulateRemainingCpuMatchesInRound(
                        match.roundNumber,
                      );
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
                ],
              )
            else if (match.status == TournamentMatchStatus.completed &&
                match.result != null)
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
    final TournamentParticipant human =
        match.playerA?.isHuman ?? false ? match.playerA! : match.playerB!;
    final TournamentParticipant bot =
        match.playerA?.isHuman ?? false ? match.playerB! : match.playerA!;

    final definition = TournamentRepository.instance.currentBracket!.definition;
    final bracket = TournamentRepository.instance.currentBracket!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MatchScreen(
          session: MatchSessionConfig(
            gameMode: GameMode.x01,
            participants: <MatchParticipantConfig>[
              MatchParticipantConfig(
                id: human.id,
                name: human.name,
                isHuman: true,
              ),
              MatchParticipantConfig(
                id: bot.id,
                name: bot.name,
                isHuman: false,
                botProfile: TournamentRepository.instance.profileForParticipant(
                  bot.id,
                ),
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

  int _legsToWinForMatch(
    TournamentBracket bracket,
    TournamentDefinition definition,
  ) {
    if (definition.matchMode != MatchMode.legs) {
      return definition.legsToWin;
    }
    if (definition.format == TournamentFormat.leaguePlayoff &&
        roundStage == TournamentRoundStage.playoff) {
      return definition.distanceForRound(bracket.stageRoundIndex(match.roundNumber));
    }
    return definition.distanceForRound(match.roundNumber);
  }

  int _setsToWinForMatch(
    TournamentBracket bracket,
    TournamentDefinition definition,
  ) {
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
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          round.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${visibleMatches.length} Matches'
          '${round.isCompleted ? ' | abgeschlossen' : ''}',
        ),
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
  });

  final int rank;
  final TournamentStanding standing;

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
                child: Text(
                  '$rank',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
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
              Text(
                '${standing.points} P',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
            ],
          ),
        ],
      ),
    );
  }
}

class _ParticipantBadge extends StatelessWidget {
  const _ParticipantBadge({
    required this.player,
  });

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
  const _CompactInfoChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

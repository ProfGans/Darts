import '../../domain/x01/x01_models.dart';
import 'game_mode_models.dart';

class MatchParticipantConfig {
  const MatchParticipantConfig({
    required this.id,
    required this.name,
    required this.isHuman,
    this.startingScore,
    this.botProfile,
  });

  final String id;
  final String name;
  final bool isHuman;
  final int? startingScore;
  final BotProfile? botProfile;
}

class MatchSessionConfig {
  const MatchSessionConfig({
    required this.gameMode,
    required this.participants,
    required this.matchConfig,
    this.useBullOff = false,
    this.startingParticipantId,
    this.bob27AllowNegativeScores = false,
    this.bob27BonusMode = false,
    this.bob27ReverseOrder = false,
    this.tournamentMatchId,
    this.playerParticipantId,
    this.botParticipantId,
    this.returnButtonLabel,
  });

  final GameMode gameMode;
  final List<MatchParticipantConfig> participants;
  final MatchConfig matchConfig;
  final bool useBullOff;
  final String? startingParticipantId;
  final bool bob27AllowNegativeScores;
  final bool bob27BonusMode;
  final bool bob27ReverseOrder;
  final String? tournamentMatchId;
  final String? playerParticipantId;
  final String? botParticipantId;
  final String? returnButtonLabel;

  MatchParticipantConfig get firstParticipant => participants.first;

  MatchParticipantConfig? get firstBot {
    for (final participant in participants) {
      if (!participant.isHuman) {
        return participant;
      }
    }
    return null;
  }
}

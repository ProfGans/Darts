enum VoiceSessionPhase {
  idle,
  listeningForCommand,
  confirmingCommand,
  applyingCommand,
  paused,
  error,
}

enum SpokenVisitKind {
  score,
  bust,
  noScore,
}

enum SpokenConfirmation {
  yes,
  no,
  retry,
  cancel,
}

enum SpokenParseStatus {
  matched,
  ambiguous,
  unrecognized,
}

class SpokenParseResult<T> {
  const SpokenParseResult._({
    required this.status,
    this.value,
    this.alternatives = const [],
    this.normalizedInput = '',
  });

  const SpokenParseResult.matched(
    T this.value, {
    this.normalizedInput = '',
  })  : status = SpokenParseStatus.matched,
        alternatives = const [];

  const SpokenParseResult.ambiguous({
    required this.alternatives,
    this.normalizedInput = '',
  })  : status = SpokenParseStatus.ambiguous,
        value = null;

  const SpokenParseResult.unrecognized({
    this.normalizedInput = '',
  })  : status = SpokenParseStatus.unrecognized,
        value = null,
        alternatives = const [];

  final SpokenParseStatus status;
  final T? value;
  final List<T> alternatives;
  final String normalizedInput;

  bool get isMatched => status == SpokenParseStatus.matched && value != null;

  bool get isAmbiguous => status == SpokenParseStatus.ambiguous;
}

sealed class SpokenMatchCommand {
  const SpokenMatchCommand();

  String get summaryLabel;

  String get confirmationPrompt;
}

enum SpokenBullOffKind {
  bull,
  singleBull,
  outside,
}

class SpokenVisitCommand extends SpokenMatchCommand {
  const SpokenVisitCommand.score(this.score) : kind = SpokenVisitKind.score;

  const SpokenVisitCommand.bust()
      : kind = SpokenVisitKind.bust,
        score = null;

  const SpokenVisitCommand.noScore()
      : kind = SpokenVisitKind.noScore,
        score = 0;

  final SpokenVisitKind kind;
  final int? score;

  @override
  String get summaryLabel {
    return switch (kind) {
      SpokenVisitKind.score => '${score ?? 0}',
      SpokenVisitKind.bust => 'Bust',
      SpokenVisitKind.noScore => 'Kein Score',
    };
  }

  @override
  String get confirmationPrompt {
    return switch (kind) {
      SpokenVisitKind.score => '${score ?? 0} Punkte, stimmt das?',
      SpokenVisitKind.bust => 'Bust, stimmt das?',
      SpokenVisitKind.noScore => 'Kein Score, stimmt das?',
    };
  }
}

class SpokenCheckoutCommand extends SpokenMatchCommand {
  const SpokenCheckoutCommand();

  @override
  String get summaryLabel => 'Check';

  @override
  String get confirmationPrompt => 'Check, stimmt das?';
}

class SpokenBullOffCommand extends SpokenMatchCommand {
  const SpokenBullOffCommand(this.kind);

  final SpokenBullOffKind kind;

  @override
  String get summaryLabel {
    return switch (kind) {
      SpokenBullOffKind.bull => 'Bull',
      SpokenBullOffKind.singleBull => 'Single Bull',
      SpokenBullOffKind.outside => 'Outside',
    };
  }

  @override
  String get confirmationPrompt {
    return switch (kind) {
      SpokenBullOffKind.bull => 'Bull, stimmt das?',
      SpokenBullOffKind.singleBull => 'Single Bull, stimmt das?',
      SpokenBullOffKind.outside => 'Outside, stimmt das?',
    };
  }
}

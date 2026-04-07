import 'dart:math';

import '../../domain/career/career_models.dart';
import '../../domain/tournament/tournament_models.dart';
import '../../domain/x01/x01_models.dart';

class TournamentFormData {
  const TournamentFormData({
    this.game = TournamentGame.x01,
    this.format = TournamentFormat.knockout,
    this.tierInput = '1',
    this.fieldSizeInput = '16',
    this.matchMode = MatchMode.legs,
    this.legsValue = 6,
    this.setsToWin = 3,
    this.startScoreInput = '501',
    this.startRequirement = StartRequirement.straightIn,
    this.checkoutRequirement = CheckoutRequirement.doubleOut,
    this.roundDistanceValues = const <int>[],
    this.pointsForWin = 2,
    this.pointsForDraw = 1,
    this.roundRobinRepeats = 1,
    this.playoffQualifierCount = 4,
  });

  final TournamentGame game;
  final TournamentFormat format;
  final String tierInput;
  final String fieldSizeInput;
  final MatchMode matchMode;
  final int legsValue;
  final int setsToWin;
  final String startScoreInput;
  final StartRequirement startRequirement;
  final CheckoutRequirement checkoutRequirement;
  final List<int> roundDistanceValues;
  final int pointsForWin;
  final int pointsForDraw;
  final int roundRobinRepeats;
  final int playoffQualifierCount;

  int get effectiveLegsToWin => matchMode == MatchMode.legs ? legsValue : 3;
  int get effectiveSetsToWin => matchMode == MatchMode.legs ? 1 : setsToWin;
  int get effectiveLegsPerSet => matchMode == MatchMode.legs ? 1 : legsValue;
  int? get parsedTier => int.tryParse(tierInput.trim());
  int? get parsedFieldSize => int.tryParse(fieldSizeInput.trim());
  int? get parsedStartScore => int.tryParse(startScoreInput.trim());
  int get roundCount {
    final entrants = parsedFieldSize;
    if (format == TournamentFormat.league) {
      return 0;
    }
    final int playoffEntrants = format == TournamentFormat.leaguePlayoff
        ? playoffQualifierCount
        : (entrants ?? 0);
    if (playoffEntrants < 2) {
      return 0;
    }
    var bracketSize = 2;
    while (bracketSize < playoffEntrants) {
      bracketSize *= 2;
    }
    return (log(bracketSize) / log(2)).round();
  }

  List<int> get effectiveRoundDistanceValues {
    final rounds = roundCount;
    if (rounds <= 0) {
      return const <int>[];
    }
    final fallbackValue =
        matchMode == MatchMode.legs ? effectiveLegsToWin : effectiveSetsToWin;
    return List<int>.generate(rounds, (index) {
      if (index < roundDistanceValues.length) {
        return max(1, roundDistanceValues[index]);
      }
      return fallbackValue;
    });
  }

  TournamentFormData copyWith({
    TournamentGame? game,
    TournamentFormat? format,
    String? tierInput,
    String? fieldSizeInput,
    MatchMode? matchMode,
    int? legsValue,
    int? setsToWin,
    String? startScoreInput,
    StartRequirement? startRequirement,
    CheckoutRequirement? checkoutRequirement,
    List<int>? roundDistanceValues,
    int? pointsForWin,
    int? pointsForDraw,
    int? roundRobinRepeats,
    int? playoffQualifierCount,
  }) {
    return TournamentFormData(
      game: game ?? this.game,
      format: format ?? this.format,
      tierInput: tierInput ?? this.tierInput,
      fieldSizeInput: fieldSizeInput ?? this.fieldSizeInput,
      matchMode: matchMode ?? this.matchMode,
      legsValue: legsValue ?? this.legsValue,
      setsToWin: setsToWin ?? this.setsToWin,
      startScoreInput: startScoreInput ?? this.startScoreInput,
      startRequirement: startRequirement ?? this.startRequirement,
      checkoutRequirement: checkoutRequirement ?? this.checkoutRequirement,
      roundDistanceValues: roundDistanceValues ?? this.roundDistanceValues,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      roundRobinRepeats: roundRobinRepeats ?? this.roundRobinRepeats,
      playoffQualifierCount:
          playoffQualifierCount ?? this.playoffQualifierCount,
    );
  }

  static TournamentFormData fromCareerItem(CareerCalendarItem item) {
    return TournamentFormData(
      game: item.game,
      format: item.format,
      tierInput: '${item.tier}',
      fieldSizeInput: '${item.fieldSize}',
      matchMode: item.matchMode,
      legsValue:
          item.matchMode == MatchMode.legs ? item.legsToWin : item.legsPerSet,
      setsToWin: item.setsToWin,
      startScoreInput: '${item.startScore}',
      startRequirement: StartRequirement.straightIn,
      checkoutRequirement: item.checkoutRequirement,
      roundDistanceValues: item.roundDistanceValues,
      pointsForWin: item.pointsForWin,
      pointsForDraw: item.pointsForDraw,
      roundRobinRepeats: item.roundRobinRepeats,
      playoffQualifierCount: item.playoffQualifierCount,
    );
  }
}

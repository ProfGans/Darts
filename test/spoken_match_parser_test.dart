import 'package:flutter_test/flutter_test.dart';

import 'package:DartCore/domain/voice/spoken_match_command.dart';
import 'package:DartCore/domain/voice/spoken_match_parser.dart';

void main() {
  const parser = SpokenMatchParser();

  group('SpokenMatchParser commands', () {
    test('parses numeric visit scores', () {
      final command = parser.parseCommand('140');

      expect(command, isA<SpokenVisitCommand>());
      expect((command as SpokenVisitCommand).score, 140);
      expect(command.kind, SpokenVisitKind.score);
    });

    test('parses german number words', () {
      final command = parser.parseCommand('hundertvierzig');
      final spaced = parser.parseCommand('hundert vierzig');
      final withAnd = parser.parseCommand('ein hundert vierzig');
      final withHundertUnd = parser.parseCommand('hundert und vierzig');
      final oneEighty = parser.parseCommand('hundert achtzig');
      final sixty = parser.parseCommand('sechzig');
      final fortyOne = parser.parseCommand('einundvierzig');
      final fortyOneSpaced = parser.parseCommand('ein und vierzig');
      final fortyFive = parser.parseCommand('fuenfundvierzig');
      final twentyFiveSpaced = parser.parseCommand('fuenf und zwanzig');

      expect(command, isA<SpokenVisitCommand>());
      expect((command as SpokenVisitCommand).score, 140);
      expect(spaced, isA<SpokenVisitCommand>());
      expect((spaced as SpokenVisitCommand).score, 140);
      expect(withAnd, isA<SpokenVisitCommand>());
      expect((withAnd as SpokenVisitCommand).score, 140);
      expect(withHundertUnd, isA<SpokenVisitCommand>());
      expect((withHundertUnd as SpokenVisitCommand).score, 140);
      expect(oneEighty, isA<SpokenVisitCommand>());
      expect((oneEighty as SpokenVisitCommand).score, 180);
      expect(sixty, isA<SpokenVisitCommand>());
      expect((sixty as SpokenVisitCommand).score, 60);
      expect(fortyOne, isA<SpokenVisitCommand>());
      expect((fortyOne as SpokenVisitCommand).score, 41);
      expect(fortyOneSpaced, isA<SpokenVisitCommand>());
      expect((fortyOneSpaced as SpokenVisitCommand).score, 41);
      expect(fortyFive, isA<SpokenVisitCommand>());
      expect((fortyFive as SpokenVisitCommand).score, 45);
      expect(twentyFiveSpaced, isA<SpokenVisitCommand>());
      expect((twentyFiveSpaced as SpokenVisitCommand).score, 25);
    });

    test('parses english number words', () {
      final oneForty = parser.parseCommand('one forty');
      final oneHundredForty = parser.parseCommand('one hundred forty');
      final oneHundredAndForty = parser.parseCommand('one hundred and forty');

      expect(oneForty, isA<SpokenVisitCommand>());
      expect((oneForty as SpokenVisitCommand).score, 140);
      expect(oneHundredForty, isA<SpokenVisitCommand>());
      expect((oneHundredForty as SpokenVisitCommand).score, 140);
      expect(oneHundredAndForty, isA<SpokenVisitCommand>());
      expect((oneHundredAndForty as SpokenVisitCommand).score, 140);
    });

    test('parses bust and no score aliases', () {
      final bust = parser.parseCommand('bust');
      final noScore = parser.parseCommand('kein score');
      final overthrown = parser.parseCommand('ueberworfen');
      final zero = parser.parseCommand('zero');

      expect(bust, isA<SpokenVisitCommand>());
      expect((bust as SpokenVisitCommand).kind, SpokenVisitKind.bust);
      expect(noScore, isA<SpokenVisitCommand>());
      expect((noScore as SpokenVisitCommand).kind, SpokenVisitKind.noScore);
      expect(overthrown, isA<SpokenVisitCommand>());
      expect((overthrown as SpokenVisitCommand).kind, SpokenVisitKind.bust);
      expect(zero, isA<SpokenVisitCommand>());
      expect((zero as SpokenVisitCommand).kind, SpokenVisitKind.noScore);
    });

    test('parses simple checkout call', () {
      final command = parser.parseCommand('check');
      final aus = parser.parseCommand('aus');
      final checked = parser.parseCommand('gecheckt');

      expect(command, isA<SpokenCheckoutCommand>());
      expect(aus, isA<SpokenCheckoutCommand>());
      expect(checked, isA<SpokenCheckoutCommand>());
    });

    test('rejects unsupported scores', () {
      expect(parser.parseCommand('181'), isNull);
    });

    test('uses alternatives to resolve a command', () {
      final result = parser.parseCommandResult(
        'for tea',
        alternatives: const <String>['forty'],
      );

      expect(result.status, SpokenParseStatus.matched);
      expect(result.value, isA<SpokenVisitCommand>());
      expect((result.value as SpokenVisitCommand).score, 40);
    });

    test('marks conflicting alternatives as ambiguous', () {
      final result = parser.parseCommandResult(
        'for tea',
        alternatives: const <String>['forty', 'hundertvierzig'],
      );

      expect(result.status, SpokenParseStatus.ambiguous);
      expect(result.alternatives.length, 2);
    });
  });

  group('SpokenMatchParser bull off', () {
    test('parses bull off commands', () {
      final bull = parser.parseBullOffCommand('bull');
      final singleBull = parser.parseBullOffCommand('single bull');
      final outside = parser.parseBullOffCommand('outside');

      expect(bull, isA<SpokenBullOffCommand>());
      expect(bull!.kind, SpokenBullOffKind.bull);
      expect(singleBull, isA<SpokenBullOffCommand>());
      expect(singleBull!.kind, SpokenBullOffKind.singleBull);
      expect(outside, isA<SpokenBullOffCommand>());
      expect(outside!.kind, SpokenBullOffKind.outside);
    });

    test('parses 25 as single bull during bull off', () {
      final command = parser.parseBullOffCommand('25');

      expect(command, isA<SpokenBullOffCommand>());
      expect(command!.kind, SpokenBullOffKind.singleBull);
    });

    test('accepts common bull off synonyms', () {
      expect(
        parser.parseBullOffCommand('outer bull')!.kind,
        SpokenBullOffKind.singleBull,
      );
      expect(
        parser.parseBullOffCommand('daneben')!.kind,
        SpokenBullOffKind.outside,
      );
      expect(
        parser.parseBullOffCommand('bullseye')!.kind,
        SpokenBullOffKind.bull,
      );
    });
  });

  group('SpokenMatchParser confirmations', () {
    test('parses yes intents', () {
      expect(parser.parseConfirmation('ja'), SpokenConfirmation.yes);
      expect(parser.parseConfirmation('korrekt'), SpokenConfirmation.yes);
    });

    test('parses no and retry intents', () {
      expect(parser.parseConfirmation('nein'), SpokenConfirmation.no);
      expect(parser.parseConfirmation('nochmal'), SpokenConfirmation.retry);
      expect(parser.parseConfirmation('abbrechen'), SpokenConfirmation.cancel);
    });

    test('keeps confirmation grammar strict', () {
      final result = parser.parseConfirmationResult(
        'ja nein',
        alternatives: const <String>['ja', 'nein'],
      );

      expect(result.status, SpokenParseStatus.ambiguous);
    });
  });
}

import 'spoken_match_command.dart';

class SpokenMatchParser {
  const SpokenMatchParser();

  SpokenMatchCommand? parseCommand(String rawText) =>
      parseCommandResult(rawText).value;

  SpokenParseResult<SpokenMatchCommand> parseCommandResult(
    String rawText, {
    List<String> alternatives = const <String>[],
  }) {
    return _resolveMatches<SpokenMatchCommand>(
      rawText,
      alternatives: alternatives,
      parseSingle: _parseSingleCommand,
      identity: (command) => '${command.runtimeType}:${command.summaryLabel}',
    );
  }

  SpokenBullOffCommand? parseBullOffCommand(String rawText) =>
      parseBullOffCommandResult(rawText).value;

  SpokenParseResult<SpokenBullOffCommand> parseBullOffCommandResult(
    String rawText, {
    List<String> alternatives = const <String>[],
  }) {
    return _resolveMatches<SpokenBullOffCommand>(
      rawText,
      alternatives: alternatives,
      parseSingle: _parseSingleBullOffCommand,
      identity: (command) => command.kind.name,
    );
  }

  SpokenConfirmation? parseConfirmation(String rawText) =>
      parseConfirmationResult(rawText).value;

  SpokenParseResult<SpokenConfirmation> parseConfirmationResult(
    String rawText, {
    List<String> alternatives = const <String>[],
  }) {
    return _resolveMatches<SpokenConfirmation>(
      rawText,
      alternatives: alternatives,
      parseSingle: _parseSingleConfirmation,
      identity: (confirmation) => confirmation.name,
    );
  }

  SpokenParseResult<T> _resolveMatches<T>(
    String rawText, {
    required T? Function(String normalized) parseSingle,
    required String Function(T value) identity,
    List<String> alternatives = const <String>[],
  }) {
    final normalizedInput = _normalize(rawText);
    if (normalizedInput.isEmpty) {
      return SpokenParseResult<T>.unrecognized(
        normalizedInput: normalizedInput,
      );
    }

    final candidates = <String>[normalizedInput];
    for (final alternative in alternatives) {
      final normalizedAlternative = _normalize(alternative);
      if (normalizedAlternative.isNotEmpty &&
          !candidates.contains(normalizedAlternative)) {
        candidates.add(normalizedAlternative);
      }
    }

    final matchesById = <String, T>{};
    for (final candidate in candidates) {
      final match = parseSingle(candidate);
      if (match == null) {
        continue;
      }
      matchesById.putIfAbsent(identity(match), () => match);
    }

    if (matchesById.isEmpty) {
      return SpokenParseResult<T>.unrecognized(
        normalizedInput: normalizedInput,
      );
    }
    if (matchesById.length == 1) {
      return SpokenParseResult<T>.matched(
        matchesById.values.first,
        normalizedInput: normalizedInput,
      );
    }
    return SpokenParseResult<T>.ambiguous(
      alternatives: matchesById.values.toList(growable: false),
      normalizedInput: normalizedInput,
    );
  }

  SpokenMatchCommand? _parseSingleCommand(String normalized) {
    final checkoutMatch = _matchExact(normalized, _checkoutKeywords);
    final bustMatch = _matchExact(normalized, _bustKeywords);
    final noScoreMatch = _matchExact(normalized, _noScoreKeywords);

    final keywordHits = <SpokenMatchCommand>[
      if (checkoutMatch) const SpokenCheckoutCommand(),
      if (bustMatch) const SpokenVisitCommand.bust(),
      if (noScoreMatch) const SpokenVisitCommand.noScore(),
    ];
    if (keywordHits.length > 1) {
      return null;
    }
    if (keywordHits.isNotEmpty) {
      return keywordHits.first;
    }

    final numeric = _parseScore(normalized);
    if (numeric == null || numeric < 0 || numeric > 180) {
      return null;
    }
    return SpokenVisitCommand.score(numeric);
  }

  SpokenBullOffCommand? _parseSingleBullOffCommand(String normalized) {
    final bull = _matchExact(normalized, _bullKeywords);
    final singleBull = _matchExact(normalized, _singleBullKeywords);
    final outside = _matchExact(normalized, _outsideKeywords);
    final hitCount = <bool>[bull, singleBull, outside].where((value) => value).length;
    if (hitCount != 1) {
      return null;
    }
    if (bull) {
      return const SpokenBullOffCommand(SpokenBullOffKind.bull);
    }
    if (singleBull) {
      return const SpokenBullOffCommand(SpokenBullOffKind.singleBull);
    }
    return const SpokenBullOffCommand(SpokenBullOffKind.outside);
  }

  SpokenConfirmation? _parseSingleConfirmation(String normalized) {
    final yes = _matchExact(normalized, _yesKeywords);
    final no = _matchExact(normalized, _noKeywords);
    final retry = _matchExact(normalized, _retryKeywords);
    final cancel = _matchExact(normalized, _cancelKeywords);
    final hitCount = <bool>[yes, no, retry, cancel].where((value) => value).length;
    if (hitCount != 1) {
      return null;
    }
    if (yes) {
      return SpokenConfirmation.yes;
    }
    if (no) {
      return SpokenConfirmation.no;
    }
    if (retry) {
      return SpokenConfirmation.retry;
    }
    return SpokenConfirmation.cancel;
  }

  int? _parseScore(String normalized) {
    final stripped = _stripScoreWrappers(normalized);
    final direct = int.tryParse(stripped);
    if (direct != null) {
      return direct;
    }

    final compact = stripped.replaceAll(' ', '');
    return _parseGermanNumber(compact) ?? _parseEnglishNumber(stripped);
  }

  String _stripScoreWrappers(String normalized) {
    var value = normalized;
    for (final wrapper in _scoreWrappers) {
      if (value.startsWith('$wrapper ')) {
        value = value.substring(wrapper.length + 1);
      }
      if (value.endsWith(' $wrapper')) {
        value = value.substring(0, value.length - wrapper.length - 1);
      }
    }
    return value.trim();
  }

  int? _parseGermanNumber(String normalized) {
    if (normalized.isEmpty) {
      return null;
    }
    final softened = normalized
        .replaceAll(' und ', ' ')
        .replaceAll('hundertund', 'hundert')
        .replaceAll('einshundert', 'einhundert');
    if (softened != normalized) {
      final retried = _parseGermanNumber(softened);
      if (retried != null) {
        return retried;
      }
    }
    final direct = _germanExactNumbers[normalized];
    if (direct != null) {
      return direct;
    }
    if (normalized == 'null') {
      return 0;
    }
    if (normalized.startsWith('einhundert')) {
      final remainder = normalized.substring('einhundert'.length);
      if (remainder.isEmpty) {
        return 100;
      }
      final belowHundred = _parseGermanBelowHundred(remainder);
      return belowHundred == null ? null : 100 + belowHundred;
    }
    if (normalized.startsWith('hundert')) {
      final remainder = normalized.substring('hundert'.length);
      if (remainder.isEmpty) {
        return 100;
      }
      final belowHundred = _parseGermanBelowHundred(remainder);
      return belowHundred == null ? null : 100 + belowHundred;
    }
    return _parseGermanBelowHundred(normalized);
  }

  int? _parseGermanBelowHundred(String value) {
    final direct = _germanExactNumbers[value];
    if (direct != null) {
      return direct;
    }

    for (final tens in _germanTens.entries) {
      if (!value.endsWith(tens.key)) {
        continue;
      }
      final prefix = value.substring(0, value.length - tens.key.length);
      if (prefix.isEmpty) {
        return tens.value;
      }
      if (!prefix.endsWith('und')) {
        continue;
      }
      final unitToken = prefix.substring(0, prefix.length - 3);
      final unitValue = _germanUnits[unitToken];
      if (unitValue != null) {
        return tens.value + unitValue;
      }
    }
    return null;
  }

  int? _parseEnglishNumber(String normalized) {
    final cleaned = normalized.replaceAll('-', ' ');
    final tokens = cleaned
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return null;
    }
    if (tokens.length == 2 &&
        tokens.first == 'one' &&
        _englishTens.containsKey(tokens.last)) {
      return 100 + _englishTens[tokens.last]!;
    }

    var total = 0;
    var current = 0;
    for (final token in tokens) {
      if (token == 'and') {
        continue;
      }
      final unit = _englishUnits[token];
      if (unit != null) {
        current += unit;
        continue;
      }
      final tens = _englishTens[token];
      if (tens != null) {
        current += tens;
        continue;
      }
      if (token == 'hundred') {
        current = (current == 0 ? 1 : current) * 100;
        continue;
      }
      return null;
    }
    total += current;
    return total;
  }

  bool _matchExact(String normalized, Set<String> keywords) {
    return keywords.contains(normalized) ||
        keywords.contains(normalized.replaceAll(' ', ''));
  }

  String _normalize(String value) {
    var normalized = value
        .toLowerCase()
        .replaceAll('\u00E4', 'ae')
        .replaceAll('\u00F6', 'oe')
        .replaceAll('\u00FC', 'ue')
        .replaceAll('\u00DF', 'ss')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    for (final entry in _normalizationReplacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

const Set<String> _scoreWrappers = <String>{
  'punkte',
  'punkt',
  'score',
};

const Map<String, String> _normalizationReplacements = <String, String>{
  'null komma null': 'null',
  'nuller': 'null',
  'nix': 'gar nichts',
  'nichts': 'gar nichts',
  'kein punkt': 'keine punkte',
  'keinen score': 'kein score',
  'kein sكورe': 'kein score',
  'no scores': 'no score',
  'check out': 'checkout',
  'checkouts': 'checkout',
  'gecheckt': 'check',
  'checkt': 'check',
  'single bull': 'singlebull',
  'single-bull': 'singlebull',
  'outer bull': 'outerbull',
  'inner bull': 'innerbull',
  'game shot': 'gameshot',
  'gameshot': 'gameshot',
  'fuenf und zwanzig': 'fuenfundzwanzig',
  'funf und zwanzig': 'funfundzwanzig',
  'ein und zwanzig': 'einundzwanzig',
  'zwei und zwanzig': 'zweiundzwanzig',
  'drei und zwanzig': 'dreiundzwanzig',
  'vier und zwanzig': 'vierundzwanzig',
  'fuenf und dreissig': 'fuenfunddreissig',
  'funf und dreissig': 'funfunddreissig',
  'ein und dreissig': 'einunddreissig',
  'zwei und dreissig': 'zweiunddreissig',
  'drei und dreissig': 'dreiunddreissig',
  'vier und dreissig': 'vierunddreissig',
  'ein und vierzig': 'einundvierzig',
  'zwei und vierzig': 'zweiundvierzig',
  'drei und vierzig': 'dreiundvierzig',
  'vier und vierzig': 'vierundvierzig',
  'fuenf und vierzig': 'fuenfundvierzig',
  'funf und vierzig': 'funfundvierzig',
  'ein und fuenfzig': 'einundfuenfzig',
  'ein und funfzig': 'einundfunfzig',
  'zwei und fuenfzig': 'zweiundfuenfzig',
  'zwei und funfzig': 'zweiundfunfzig',
  'ein und sechzig': 'einundsechzig',
  'zwei und sechzig': 'zweiundsechzig',
  'ein und siebzig': 'einundsiebzig',
  'zwei und siebzig': 'zweiundsiebzig',
  'ein und achtzig': 'einundachtzig',
  'zwei und achtzig': 'zweiundachtzig',
  'ein und neunzig': 'einundneunzig',
  'zwei und neunzig': 'zweiundneunzig',
};

const Set<String> _checkoutKeywords = <String>{
  'check',
  'checkout',
  'gameshot',
  'aus',
  'ausgemacht',
  'leg aus',
  'fertig',
};

const Set<String> _bullKeywords = <String>{
  'bull',
  'bullseye',
  'innerbull',
  'vollbull',
  'direkt bull',
};

const Set<String> _singleBullKeywords = <String>{
  'singlebull',
  'outerbull',
  'aussen bull',
  'aussenbull',
  'aussenring',
  'outer',
  'fuenfundzwanzig',
  'funfundzwanzig',
  '25',
};

const Set<String> _outsideKeywords = <String>{
  'outside',
  'vorbei',
  'daneben',
  'miss',
  'draussen',
  'aussen vorbei',
  'nicht getroffen',
  'knapp vorbei',
};

const Set<String> _bustKeywords = <String>{
  'bust',
  'gebustet',
  'ueberworfen',
  'drueber',
  'druber',
};

const Set<String> _noScoreKeywords = <String>{
  'null',
  'no score',
  'kein score',
  'keine punkte',
  'null punkte',
  'null score',
  'zero',
  'nullnummer',
  'ohne punkte',
  'gar nichts',
};

const Set<String> _yesKeywords = <String>{
  'ja',
  'korrekt',
  'stimmt',
  'genau',
  'richtig',
  'yes',
};

const Set<String> _noKeywords = <String>{
  'nein',
  'falsch',
  'no',
};

const Set<String> _retryKeywords = <String>{
  'nochmal',
  'wiederholen',
  'erneut',
  'retry',
};

const Set<String> _cancelKeywords = <String>{
  'abbrechen',
  'stop',
  'stopp',
  'cancel',
};

const Map<String, int> _germanUnits = <String, int>{
  'null': 0,
  'ein': 1,
  'eins': 1,
  'eine': 1,
  'einen': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fuenf': 5,
  'funf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
};

const Map<String, int> _germanTens = <String, int>{
  'zwanzig': 20,
  'dreissig': 30,
  'dreisig': 30,
  'vierzig': 40,
  'fuenfzig': 50,
  'funfzig': 50,
  'sechzig': 60,
  'siebzig': 70,
  'achtzig': 80,
  'neunzig': 90,
};

const Map<String, int> _germanExactNumbers = <String, int>{
  'null': 0,
  'eins': 1,
  'ein': 1,
  'zwei': 2,
  'drei': 3,
  'vier': 4,
  'fuenf': 5,
  'funf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwoelf': 12,
  'zwolf': 12,
  'dreizehn': 13,
  'vierzehn': 14,
  'fuenfzehn': 15,
  'funfzehn': 15,
  'sechzehn': 16,
  'siebzehn': 17,
  'achtzehn': 18,
  'neunzehn': 19,
  'zwanzig': 20,
  'einundzwanzig': 21,
  'zweiundzwanzig': 22,
  'dreiundzwanzig': 23,
  'vierundzwanzig': 24,
  'fuenfundzwanzig': 25,
  'funfundzwanzig': 25,
  'sechsundzwanzig': 26,
  'siebenundzwanzig': 27,
  'achtundzwanzig': 28,
  'neunundzwanzig': 29,
  'dreissig': 30,
  'dreisig': 30,
  'einunddreissig': 31,
  'einunddreisig': 31,
  'zweiunddreissig': 32,
  'zweiunddreisig': 32,
  'dreiunddreissig': 33,
  'dreiunddreisig': 33,
  'vierunddreissig': 34,
  'vierunddreisig': 34,
  'fuenfunddreissig': 35,
  'funfunddreissig': 35,
  'fuenfunddreisig': 35,
  'funfunddreisig': 35,
  'sechsunddreissig': 36,
  'sechsunddreisig': 36,
  'siebenunddreissig': 37,
  'siebenunddreisig': 37,
  'achtunddreissig': 38,
  'achtunddreisig': 38,
  'neununddreissig': 39,
  'neununddreisig': 39,
  'vierzig': 40,
  'einundvierzig': 41,
  'zweiundvierzig': 42,
  'dreiundvierzig': 43,
  'vierundvierzig': 44,
  'fuenfundvierzig': 45,
  'funfundvierzig': 45,
  'sechsundvierzig': 46,
  'siebenundvierzig': 47,
  'achtundvierzig': 48,
  'neunundvierzig': 49,
  'fuenfzig': 50,
  'funfzig': 50,
  'einundfuenfzig': 51,
  'einundfunfzig': 51,
  'zweiundfuenfzig': 52,
  'zweiundfunfzig': 52,
  'dreiundfuenfzig': 53,
  'dreiundfunfzig': 53,
  'vierundfuenfzig': 54,
  'vierundfunfzig': 54,
  'fuenfundfuenfzig': 55,
  'funfundfunfzig': 55,
  'sechsundfuenfzig': 56,
  'sechsundfunfzig': 56,
  'siebenundfuenfzig': 57,
  'siebenundfunfzig': 57,
  'achtundfuenfzig': 58,
  'achtundfunfzig': 58,
  'neunundfuenfzig': 59,
  'neunundfunfzig': 59,
  'sechzig': 60,
  'einundsechzig': 61,
  'zweiundsechzig': 62,
  'dreiundsechzig': 63,
  'vierundsechzig': 64,
  'fuenfundsechzig': 65,
  'funfundsechzig': 65,
  'sechsundsechzig': 66,
  'siebenundsechzig': 67,
  'achtundsechzig': 68,
  'neunundsechzig': 69,
  'siebzig': 70,
  'einundsiebzig': 71,
  'zweiundsiebzig': 72,
  'dreiundsiebzig': 73,
  'vierundsiebzig': 74,
  'fuenfundsiebzig': 75,
  'funfundsiebzig': 75,
  'sechsundsiebzig': 76,
  'siebenundsiebzig': 77,
  'achtundsiebzig': 78,
  'neunundsiebzig': 79,
  'achtzig': 80,
  'einundachtzig': 81,
  'zweiundachtzig': 82,
  'dreiundachtzig': 83,
  'vierundachtzig': 84,
  'fuenfundachtzig': 85,
  'funfundachtzig': 85,
  'sechsundachtzig': 86,
  'siebenundachtzig': 87,
  'achtundachtzig': 88,
  'neunundachtzig': 89,
  'neunzig': 90,
  'einundneunzig': 91,
  'zweiundneunzig': 92,
  'dreiundneunzig': 93,
  'vierundneunzig': 94,
  'fuenfundneunzig': 95,
  'funfundneunzig': 95,
  'sechsundneunzig': 96,
  'siebenundneunzig': 97,
  'achtundneunzig': 98,
  'neunundneunzig': 99,
  'hundert': 100,
  'einhundert': 100,
  'einhundertzehn': 110,
  'hundertzehn': 110,
  'hundertzwanzig': 120,
  'hundertdreissig': 130,
  'hundertvierzig': 140,
  'hundertfuenfzig': 150,
  'hundertsechzig': 160,
  'hundertsiebzig': 170,
  'hundertachtzig': 180,
};

const Map<String, int> _englishUnits = <String, int>{
  'zero': 0,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
};

const Map<String, int> _englishTens = <String, int>{
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
};

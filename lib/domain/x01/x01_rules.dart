import 'dart:math';

import 'x01_models.dart';

class X01Rules {
  const X01Rules({Random? random}) : _random = random;

  static const List<int> wheel = <int>[
    20,
    1,
    18,
    4,
    13,
    6,
    10,
    15,
    2,
    17,
    3,
    19,
    7,
    16,
    8,
    11,
    14,
    9,
    12,
    5,
  ];

  final Random? _random;

  DartThrowResult createSingle(int value) {
    return DartThrowResult(
      label: '$value',
      baseValue: value,
      scoredPoints: value,
      isDouble: false,
      isTriple: false,
    );
  }

  DartThrowResult createDouble(int value) {
    return DartThrowResult(
      label: 'D$value',
      baseValue: value,
      scoredPoints: value * 2,
      isDouble: true,
      isTriple: false,
    );
  }

  DartThrowResult createTriple(int value) {
    return DartThrowResult(
      label: 'T$value',
      baseValue: value,
      scoredPoints: value * 3,
      isDouble: false,
      isTriple: true,
    );
  }

  DartThrowResult createOuterBull() {
    return const DartThrowResult(
      label: '25',
      baseValue: 25,
      scoredPoints: 25,
      isDouble: false,
      isTriple: false,
    );
  }

  DartThrowResult createBull() {
    return const DartThrowResult(
      label: 'BULL',
      baseValue: 25,
      scoredPoints: 50,
      isDouble: true,
      isTriple: false,
      isBull: true,
    );
  }

  DartThrowResult createMiss() {
    return const DartThrowResult(
      label: 'MISS',
      baseValue: 0,
      scoredPoints: 0,
      isDouble: false,
      isTriple: false,
      isMiss: true,
    );
  }

  List<DartThrowResult> buildAllThrows() {
    final result = <DartThrowResult>[createBull(), createOuterBull()];

    for (var value = 20; value >= 1; value -= 1) {
      result.add(createTriple(value));
    }

    for (var value = 20; value >= 1; value -= 1) {
      result.add(createDouble(value));
    }

    for (var value = 20; value >= 0; value -= 1) {
      result.add(createSingle(value));
    }

    return result;
  }

  int neighborSegment(int value) {
    final index = wheel.indexOf(value);
    if (index < 0) {
      return 20;
    }

    final random = _random ?? Random();
    final goRight = random.nextBool();
    if (goRight) {
      return wheel[(index + 1) % wheel.length];
    }
    return wheel[(index - 1 + wheel.length) % wheel.length];
  }

  List<int> adjacentSegments(int value) {
    final index = wheel.indexOf(value);
    if (index < 0) {
      return const <int>[1, 5];
    }

    return <int>[
      wheel[(index - 1 + wheel.length) % wheel.length],
      wheel[(index + 1) % wheel.length],
    ];
  }

  DartThrowResult maybeMiss(DartThrowResult target) {
    final random = _random ?? Random();
    final roll = random.nextDouble();

    if (target.isBull) {
      return roll < 0.65 ? target : createOuterBull();
    }

    if (target.isDouble) {
      return roll < 0.6 ? target : createSingle(target.baseValue);
    }

    if (target.isTriple) {
      if (roll < 0.55) {
        return target;
      }
      if (roll < 0.8) {
        return createSingle(target.baseValue);
      }
      return createSingle(neighborSegment(target.baseValue));
    }

    return roll < 0.82
        ? target
        : createSingle(neighborSegment(target.baseValue));
  }

  bool isBust({
    required int currentScore,
    required int scoredPoints,
    required CheckoutRequirement checkoutRequirement,
    DartThrowResult? finishingThrow,
  }) {
    final remaining = currentScore - scoredPoints;
    if (remaining < 0) {
      return true;
    }
    if (remaining == 1 &&
        checkoutRequirement != CheckoutRequirement.singleOut) {
      return true;
    }
    if (remaining == 0) {
      return !(finishingThrow
              ?.matchesCheckoutRequirement(checkoutRequirement) ??
          false);
    }
    return false;
  }

  int remainingAfterVisit(int currentScore, int scoredPoints) {
    return currentScore - scoredPoints;
  }

  CheckoutPlan? findCheckout({
    required int score,
    required int dartsLeft,
    List<DartThrowResult>? allThrows,
  }) {
    final throws = allThrows ?? buildAllThrows();
    final plan = _findCheckout(score, dartsLeft, throws);
    if (plan == null) {
      return null;
    }
    return CheckoutPlan(throws: plan);
  }

  CheckoutPlan? findExactCheckout({
    required int remainingScore,
    required int remainingPoints,
    required int dartsLeft,
    List<DartThrowResult>? allThrows,
  }) {
    final throws = allThrows ?? buildAllThrows();
    final plan = _findExactCheckout(
      remainingScore,
      remainingPoints,
      dartsLeft,
      throws,
    );
    if (plan == null) {
      return null;
    }
    return CheckoutPlan(throws: plan);
  }

  DartThrowResult findSetupThrow(
    int score, {
    List<DartThrowResult>? allThrows,
  }) {
    final preferred = <DartThrowResult>[
      createTriple(20),
      createTriple(19),
      createTriple(18),
      createTriple(17),
      createSingle(20),
      createSingle(19),
      createSingle(18),
    ];
    final throws = allThrows ?? buildAllThrows();

    for (final candidate in preferred) {
      final rest = score - candidate.scoredPoints;
      if (rest > 1 &&
          findCheckout(score: rest, dartsLeft: 2, allThrows: throws) != null) {
        return candidate;
      }
    }

    return createTriple(20);
  }

  DartThrowResult chooseComputerThrow(
    int score, {
    required int dartsLeft,
    List<DartThrowResult>? allThrows,
    bool simulateMiss = true,
  }) {
    final throws = allThrows ?? buildAllThrows();
    final finish =
        findCheckout(score: score, dartsLeft: dartsLeft, allThrows: throws);
    if (finish != null && finish.throws.isNotEmpty) {
      return simulateMiss
          ? maybeMiss(finish.throws.first)
          : finish.throws.first;
    }

    DartThrowResult target;
    if (score > 170) {
      target = createTriple(20);
    } else if (score >= 62 && score <= 170) {
      target = findSetupThrow(score, allThrows: throws);
    } else if (score == 50) {
      target = createBull();
    } else if (score <= 40 && score.isEven) {
      target = createDouble(score ~/ 2);
    } else if (score <= 20) {
      target = createSingle(max(score - 1, 0));
    } else {
      target = createSingle(min(score - 2, 20));
    }

    return simulateMiss ? maybeMiss(target) : target;
  }

  List<DartThrowResult>? _findCheckout(
    int score,
    int dartsLeft,
    List<DartThrowResult> allThrows,
  ) {
    if (dartsLeft <= 0) {
      return score == 0 ? <DartThrowResult>[] : null;
    }

    for (final dartThrow in allThrows) {
      final rest = score - dartThrow.scoredPoints;
      if (rest < 0 || rest == 1) {
        continue;
      }

      if (rest == 0) {
        if (dartThrow.isFinishDouble) {
          return <DartThrowResult>[dartThrow];
        }
        continue;
      }

      final tail = _findCheckout(rest, dartsLeft - 1, allThrows);
      if (tail != null) {
        return <DartThrowResult>[dartThrow, ...tail];
      }
    }

    return null;
  }

  List<DartThrowResult>? _findExactCheckout(
    int remainingScore,
    int remainingPoints,
    int dartsLeft,
    List<DartThrowResult> allThrows,
  ) {
    if (remainingScore < 0 || remainingPoints < 0) {
      return null;
    }

    if (dartsLeft <= 0) {
      return remainingScore == 0 && remainingPoints == 0
          ? <DartThrowResult>[]
          : null;
    }

    for (final dartThrow in allThrows) {
      final nextScore = remainingScore - dartThrow.scoredPoints;
      final nextPoints = remainingPoints - dartThrow.scoredPoints;

      if (nextScore < 0 || nextPoints < 0 || nextScore == 1) {
        continue;
      }

      if (nextScore == 0 && nextPoints == 0) {
        if (dartThrow.isFinishDouble) {
          return <DartThrowResult>[dartThrow];
        }
        continue;
      }

      final tail = _findExactCheckout(
        nextScore,
        nextPoints,
        dartsLeft - 1,
        allThrows,
      );
      if (tail != null) {
        return <DartThrowResult>[dartThrow, ...tail];
      }
    }

    return null;
  }
}

import 'package:dart_flutter_app/domain/x01/checkout_planner.dart';
import 'package:dart_flutter_app/domain/x01/x01_models.dart';
import 'package:dart_flutter_app/domain/x01/x01_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final planner = CheckoutPlanner(rules: const X01Rules());

  List<DartThrowResult> routeFor(
    int score,
    List<String> labels, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    return planner
        .allCheckoutRoutes(
          score: score,
          dartsLeft: 3,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        )
        .firstWhere(
          (route) =>
              route.map((entry) => entry.label).join('|') == labels.join('|'),
        );
  }

  int routeScore(
    int score,
    List<String> labels, {
    CheckoutRequirement checkoutRequirement = CheckoutRequirement.doubleOut,
    CheckoutPlayStyle playStyle = CheckoutPlayStyle.balanced,
  }) {
    final route = routeFor(
      score,
      labels,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
    return planner.scoreRoute(
      route: route,
      startScore: score,
      totalDarts: 3,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );
  }

  List<List<DartThrowResult>> rankedRoutes(int score) {
    final routes =
        planner.allCheckoutRoutes(score: score, dartsLeft: 3).toList();
    routes.sort(
      (a, b) => planner
          .scoreRoute(route: b, startScore: score, totalDarts: 3)
          .compareTo(
            planner.scoreRoute(route: a, startScore: score, totalDarts: 3),
          ),
    );
    return routes;
  }

  group('CheckoutPlanner ranking', () {
    test('prefers simple singles over unnecessary triples on 42', () {
      expect(
        routeScore(42, <String>['10', 'D16']),
        greaterThan(routeScore(42, <String>['T2', 'D18'])),
      );
    });

    test('prefers T20 D10 over the weaker T16 fallback route on 80', () {
      expect(
        routeScore(80, <String>['T20', 'D10']),
        greaterThan(routeScore(80, <String>['T16', 'D16'])),
      );
    });

    test('keeps strong 2-dart finishes ahead of 3-dart alternatives on 90', () {
      final bestThreeDart =
          rankedRoutes(90).firstWhere((route) => route.length == 3);
      final bestThreeDartScore = planner.scoreRoute(
        route: bestThreeDart,
        startScore: 90,
        totalDarts: 3,
      );

      expect(
        routeScore(90, <String>['T18', 'D18']),
        greaterThan(bestThreeDartScore),
      );
      expect(
        routeScore(90, <String>['T20', 'D15']),
        greaterThan(bestThreeDartScore),
      );
      expect(
        routeScore(90, <String>['T20', 'D15']),
        greaterThan(routeScore(90, <String>['T18', 'D18'])),
      );
    });

    test('keeps T19 Bull competitive on 107', () {
      expect(
        routeScore(107, <String>['T19', 'BULL']),
        greaterThan(routeScore(107, <String>['T19', '18', 'D16'])),
      );
      expect(
        routeScore(107, <String>['T19', 'BULL']),
        greaterThan(routeScore(107, <String>['19', 'T16', 'D20'])),
      );
    });

    test('keeps bull routes closer when the leave is strong on 302 setup ideas', () {
      expect(
        routeScore(170, <String>['T20', 'T20', 'BULL']),
        greaterThan(routeScore(170, <String>['T20', '18', 'D16'])),
      );
    });

    test(
        'rewards T20 T11 D14 because the single fallback still leaves bull on 121',
        () {
      expect(
        routeScore(121, <String>['T20', 'T11', 'D14']),
        greaterThan(routeScore(121, <String>['T20', '25', 'D18'])),
      );
      expect(
        routeScore(121, <String>['T20', 'T11', 'D14']),
        greaterThan(routeScore(121, <String>['T18', 'T17', 'D8'])),
      );
    });

    test('avoids early bull routes on 129 when cleaner triple paths exist', () {
      expect(
        routeScore(129, <String>['T20', 'T19', 'D6']),
        greaterThan(routeScore(129, <String>['BULL', 'T13', 'D20'])),
      );
    });

    test('prefers bull bull d16 on 132 because 25 still leaves 107', () {
      expect(
        routeScore(132, <String>['BULL', 'BULL', 'D16']),
        greaterThan(routeScore(132, <String>['T20', '20', 'D16'])),
      );
    });

    test('supports single out finishes', () {
      final best = planner.bestFinishRoute(
        score: 41,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.singleOut,
      );

      expect(best, isNotNull);
      expect(
          best!.last.matchesCheckoutRequirement(CheckoutRequirement.singleOut),
          isTrue);
    });

    test('supports master out finishes', () {
      final best = planner.bestFinishRoute(
        score: 81,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.masterOut,
      );

      expect(best, isNotNull);
      expect(
          best!.last.matchesCheckoutRequirement(CheckoutRequirement.masterOut),
          isTrue);
    });

    test('safe style keeps simple routes ahead of forced narrow setups', () {
      expect(
        routeScore(
          42,
          <String>['10', 'D16'],
          playStyle: CheckoutPlayStyle.safe,
        ),
        greaterThan(
          routeScore(
            42,
            <String>['T2', 'D18'],
            playStyle: CheckoutPlayStyle.safe,
          ),
        ),
      );
    });

    test('aggressive style still values direct 2-dart checkouts', () {
      expect(
        routeScore(
          80,
          <String>['T20', 'D10'],
          playStyle: CheckoutPlayStyle.aggressive,
        ),
        greaterThan(
          routeScore(
            80,
            <String>['20', '20', 'D20'],
            playStyle: CheckoutPlayStyle.aggressive,
          ),
        ),
      );
    });

    test('exposes a readable score breakdown for the UI', () {
      final route = routeFor(42, <String>['10', 'D16']);
      final breakdown = planner.routeScoreBreakdown(
        route: route,
        startScore: 42,
        totalDarts: 3,
      );

      expect(breakdown.comfort, greaterThan(0));
      expect(breakdown.doubleQuality, greaterThan(0));
      expect(breakdown.bullPenalty, 0);
    });

    test('setup calculator prefers the simplest route to the target score', () {
      final best = planner.bestRouteToTargetRemaining(
        startScore: 265,
        targetScore: 170,
        dartsLeft: 3,
      );

      expect(best, isNotNull);
      expect(best!.map((entry) => entry.label).join('|'), '19|19|T19');
    });

    test('can return the best setup leave for an exact narrow-field bucket', () {
      final oneNarrow = planner.bestSetupLeaveForNarrowFieldCount(
        startScore: 265,
        dartsLeft: 3,
        narrowFieldCount: 1,
      );

      expect(oneNarrow, isNotNull);
      expect(oneNarrow!.setupRoute.where(planner.isNarrowField).length, 1);
      expect(oneNarrow.setupRoute.map((entry) => entry.label).join('|'),
          '19|19|T19');
      expect(oneNarrow.remainingScore, 170);
      expect(oneNarrow.finishRoute.map((entry) => entry.label).join('|'),
          'T20|T20|BULL');
    });

    test('can return multiple top setup leaves for one bucket', () {
      final options = planner.topSetupLeavesForNarrowFieldCount(
        startScore: 265,
        dartsLeft: 3,
        narrowFieldCount: 1,
        maxResults: 3,
      );

      expect(options.length, greaterThanOrEqualTo(2));
      expect(options.first.score, greaterThanOrEqualTo(options[1].score));
    });

    test('setup ranking penalizes routes with more critical miss branches', () {
      final safer = planner.scoreSetupLeave(
        setupRoute: <DartThrowResult>[
          const X01Rules().createSingle(19),
          const X01Rules().createTriple(20),
          const X01Rules().createTriple(20),
        ],
        startScore: 309,
        remainingScore: 170,
        finishRoute: planner.bestFinishRoute(score: 170, dartsLeft: 3)!,
        dartsLeft: 3,
      );
      final riskier = planner.scoreSetupLeave(
        setupRoute: <DartThrowResult>[
          const X01Rules().createTriple(20),
          const X01Rules().createTriple(20),
          const X01Rules().createSingle(19),
        ],
        startScore: 309,
        remainingScore: 170,
        finishRoute: planner.bestFinishRoute(score: 170, dartsLeft: 3)!,
        dartsLeft: 3,
      );

      expect(safer, greaterThan(riskier));
    });

    test('prefers the t18 route over a 25-led setup on 302', () {
      final options = planner.topSetupLeavesForNarrowFieldCount(
        startScore: 302,
        dartsLeft: 3,
        narrowFieldCount: 2,
        maxResults: 3,
      );

      expect(options, isNotEmpty);
      expect(
        options.first.setupRoute.map((entry) => entry.label).join('|'),
        'T18|18|T20',
      );
      expect(options.first.remainingScore, 170);
    });

    test('setup leave scoring reacts to leave preference', () {
      final rules = const X01Rules();
      final route = <DartThrowResult>[
        rules.createSingle(19),
        rules.createSingle(19),
        rules.createTriple(19),
      ];
      final finish = planner.bestFinishRoute(score: 170, dartsLeft: 3);

      expect(finish, isNotNull);

      final simpleFocused = planner.scoreSetupLeave(
        setupRoute: route,
        startScore: 265,
        remainingScore: 170,
        finishRoute: finish!,
        dartsLeft: 3,
        leavePreference: 0,
      );
      final finishFocused = planner.scoreSetupLeave(
        setupRoute: route,
        startScore: 265,
        remainingScore: 170,
        finishRoute: finish,
        dartsLeft: 3,
        leavePreference: 100,
      );

      expect(finishFocused, isNot(equals(simpleFocused)));
    });

    test('bull preference changes route scores', () {
      final bullRoute = routeFor(107, <String>['T19', 'BULL']);

      final lowAvoidance = planner.scoreRoute(
        route: bullRoute,
        startScore: 107,
        totalDarts: 3,
        bullPreference: 0,
      );
      final highAvoidance = planner.scoreRoute(
        route: bullRoute,
        startScore: 107,
        totalDarts: 3,
        bullPreference: 100,
      );

      expect(lowAvoidance, greaterThan(highAvoidance));
    });

    test('rules expose deterministic adjacent segments', () {
      expect(const X01Rules().adjacentSegments(20), <int>[5, 1]);
      expect(const X01Rules().adjacentSegments(19), <int>[3, 7]);
    });
  });
}

import 'package:dart_flutter_app/domain/x01/x01_models.dart';
import 'package:dart_flutter_app/domain/x01/x01_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Checkout requirements', () {
    final rules = const X01Rules();

    test('single out accepts any non-miss finishing dart', () {
      expect(
        rules.createSingle(1).matchesCheckoutRequirement(
              CheckoutRequirement.singleOut,
            ),
        isTrue,
      );
      expect(
        rules.createDouble(20).matchesCheckoutRequirement(
              CheckoutRequirement.singleOut,
            ),
        isTrue,
      );
      expect(
        rules.createTriple(20).matchesCheckoutRequirement(
              CheckoutRequirement.singleOut,
            ),
        isTrue,
      );
      expect(
        rules.createBull().matchesCheckoutRequirement(
              CheckoutRequirement.singleOut,
            ),
        isTrue,
      );
    });

    test('master out accepts doubles, triples and bull, but not singles', () {
      expect(
        rules.createSingle(1).matchesCheckoutRequirement(
              CheckoutRequirement.masterOut,
            ),
        isFalse,
      );
      expect(
        rules.createDouble(20).matchesCheckoutRequirement(
              CheckoutRequirement.masterOut,
            ),
        isTrue,
      );
      expect(
        rules.createTriple(20).matchesCheckoutRequirement(
              CheckoutRequirement.masterOut,
            ),
        isTrue,
      );
      expect(
        rules.createBull().matchesCheckoutRequirement(
              CheckoutRequirement.masterOut,
            ),
        isTrue,
      );
    });
  });

  group('Rule search helpers', () {
    final rules = const X01Rules();

    test('findCheckout supports single-out finishes on 41', () {
      final checkout = rules.findCheckout(
        score: 41,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.singleOut,
      );

      expect(checkout, isNotNull);
      expect(
        checkout!.throws.last.matchesCheckoutRequirement(
          CheckoutRequirement.singleOut,
        ),
        isTrue,
      );
    });

    test('findCheckout supports master-out finishes on 81', () {
      final checkout = rules.findCheckout(
        score: 81,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.masterOut,
      );

      expect(checkout, isNotNull);
      expect(
        checkout!.throws.last.matchesCheckoutRequirement(
          CheckoutRequirement.masterOut,
        ),
        isTrue,
      );
    });
  });

  group('Manual visit score validation', () {
    final rules = const X01Rules();

    test('rejects impossible aggregate three-dart scores', () {
      expect(rules.isAchievableVisitScore(179), isFalse);
      expect(rules.isAchievableVisitScore(178), isFalse);
      expect(rules.isAchievableVisitScore(176), isFalse);
      expect(rules.isAchievableVisitScore(173), isFalse);
      expect(rules.isAchievableVisitScore(180), isTrue);
      expect(rules.isAchievableVisitScore(177), isTrue);
    });

    test('double-in validation rejects totals that cannot open the leg', () {
      expect(
        rules.isAchievableVisitScore(1, requireDoubleInStart: true),
        isFalse,
      );
      expect(
        rules.isAchievableVisitScore(40, requireDoubleInStart: true),
        isTrue,
      );
    });
  });
}

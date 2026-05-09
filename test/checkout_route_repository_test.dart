import 'package:flutter_test/flutter_test.dart';

import 'package:DartCore/data/repositories/checkout_route_repository.dart';
import 'package:DartCore/domain/bot/bot_engine.dart';
import 'package:DartCore/domain/x01/x01_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CheckoutRouteRepository', () {
    test('loads bundled double-out finish routes from the precomputed asset', () async {
      await CheckoutRouteRepository.instance.initialize();

      final route = CheckoutRouteRepository.instance.bestFinishRoute(
        score: 170,
        dartsLeft: 3,
        checkoutRequirement: CheckoutRequirement.doubleOut,
      );

      expect(route, isNotNull);
      expect(route!.map((entry) => entry.label).join('|'), 'T20|T20|BULL');
    });

    test('exposes bundled high-score setup routes when present', () async {
      await CheckoutRouteRepository.instance.initialize();

      final route = CheckoutRouteRepository.instance.bestHighScoreSetupRoute(
        score: 350,
        dartsLeft: 3,
        checkoutRequirement: CheckoutRequirement.doubleOut,
      );

      expect(route, isNotNull);
      expect(route, isNotEmpty);
      expect(route!.length, 3);
    });
  });

  group('BotEngine checkout fallback', () {
    final engine = BotEngine(recordPerformanceLogs: false);

    test('keeps single-out checkouts aligned with the live planner', () {
      final route = engine.findPreferredCheckout(
        score: 41,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.singleOut,
      );

      expect(route, isNotNull);
      expect(
        route!.last.matchesCheckoutRequirement(CheckoutRequirement.singleOut),
        isTrue,
      );
    });

    test('keeps master-out checkouts aligned with the live planner', () {
      final route = engine.findPreferredCheckout(
        score: 81,
        dartsLeft: 2,
        checkoutRequirement: CheckoutRequirement.masterOut,
      );

      expect(route, isNotNull);
      expect(
        route!.last.matchesCheckoutRequirement(CheckoutRequirement.masterOut),
        isTrue,
      );
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:DartCore/domain/x01/checkout_planner.dart';
import 'package:DartCore/domain/x01/x01_models.dart';

const int _minScore = 2;
const int _maxScore = 501;
const int _minDarts = 1;
const int _maxDarts = 3;
const int _maxCheckoutScore = 170;
const int _minHighScoreSetup = 350;
const List<CheckoutPlayStyle> _supportedPlayStyles = <CheckoutPlayStyle>[
  CheckoutPlayStyle.balanced,
];

void main(List<String> args) {
  final planner = CheckoutPlanner();
  final minScore = _readIntArg(args, '--min-score') ?? _minScore;
  final maxScore = _readIntArg(args, '--max-score') ?? _maxScore;
  final outputPath =
      _readStringArg(args, '--output') ?? 'assets/data/checkout_routes_v1.json';
  final includeContinuations = args.contains('--include-continuations');
  final routeBundles = <String, Object?>{};
  var totalFinishRoutes = 0;
  var totalSetupRoutes = 0;
  var totalContinuationRoutes = 0;
  var totalHighScoreSetupRoutes = 0;

  for (final checkoutRequirement in CheckoutRequirement.values) {
    for (final playStyle in _supportedPlayStyles) {
      final finishRoutes = <String, List<String>>{};
      final setupRoutes = <String, List<String>>{};
      final continuationRoutes = <String, List<String>>{};
      final highScoreSetupRoutes = <String, List<String>>{};

      for (var score = minScore; score <= maxScore; score += 1) {
        for (var dartsLeft = _minDarts; dartsLeft <= _maxDarts; dartsLeft += 1) {
          final key = '$score|$dartsLeft';

          if (score <= _maxCheckoutScore) {
            final finishRoute = planner.bestFinishRoute(
              score: score,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: 50,
              bullPreference: 50,
            );
            if (finishRoute != null && finishRoute.isNotEmpty) {
              finishRoutes[key] = _serializeRoute(finishRoute);
            }
          }

          if (score <= _maxCheckoutScore && dartsLeft >= 2) {
            final setupOptions = planner.setupLeaveOptions(
              startScore: score,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              leavePreference: 85,
              outerBullPreference: 50,
              bullPreference: 50,
              maxResults: 1,
              maxResultsPerNarrowCount: 20,
            );
            if (setupOptions.isNotEmpty && setupOptions.first.setupRoute.isNotEmpty) {
              setupRoutes[key] = _serializeRoute(setupOptions.first.setupRoute);
            }
          }

          if (score >= _minHighScoreSetup && dartsLeft == 3) {
            final setupOptions = planner.setupLeaveOptions(
              startScore: score,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              leavePreference: 85,
              outerBullPreference: 50,
              bullPreference: 50,
              maxResults: 1,
              maxResultsPerNarrowCount: 20,
            );
            if (setupOptions.isNotEmpty && setupOptions.first.setupRoute.isNotEmpty) {
              highScoreSetupRoutes[key] = _serializeRoute(setupOptions.first.setupRoute);
            }
          }

          if (includeContinuations) {
            final continuation = planner.bestContinuationPlan(
              score: score,
              dartsLeft: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: 50,
              bullPreference: 50,
            );
            if (continuation != null && continuation.throws.isNotEmpty) {
              continuationRoutes[key] = _serializeRoute(continuation.throws);
            }
          }
        }
      }

      totalFinishRoutes += finishRoutes.length;
      totalSetupRoutes += setupRoutes.length;
      totalContinuationRoutes += continuationRoutes.length;
      totalHighScoreSetupRoutes += highScoreSetupRoutes.length;
      routeBundles[_bundleKey(
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      )] = <String, Object?>{
        'checkoutRequirement': checkoutRequirement.name,
        'playStyle': playStyle.name,
        'finishRoutes': finishRoutes,
        'setupRoutes': setupRoutes,
        'continuationRoutes': continuationRoutes,
        'highScoreSetupRoutes': highScoreSetupRoutes,
      };
    }
  }

  final output = <String, Object?>{
    'version': 2,
    'scoreRange': <String, int>{
      'min': _minScore,
      'requestedMin': minScore,
      'max': maxScore,
      'highScoreSetupMin': _minHighScoreSetup,
      'checkoutMax': _maxCheckoutScore,
    },
    'dartsLeftRange': <String, int>{
      'min': _minDarts,
      'max': _maxDarts,
    },
    'routeBundles': routeBundles,
  };

  final targetFile = File(outputPath);
  targetFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  stdout.writeln(
    'Generated ${targetFile.path} with '
    '${routeBundles.length} bundles, '
    '$totalFinishRoutes finish routes, '
    '$totalSetupRoutes setup routes, '
    '$totalHighScoreSetupRoutes high-score setup routes and '
    '$totalContinuationRoutes continuation routes.',
  );
}

List<String> _serializeRoute(List<DartThrowResult> route) =>
    route.map((entry) => entry.label).toList(growable: false);

int? _readIntArg(List<String> args, String name) {
  for (var index = 0; index < args.length - 1; index += 1) {
    if (args[index] == name) {
      return int.tryParse(args[index + 1]);
    }
  }
  return null;
}

String? _readStringArg(List<String> args, String name) {
  for (var index = 0; index < args.length - 1; index += 1) {
    if (args[index] == name) {
      return args[index + 1];
    }
  }
  return null;
}

String _bundleKey({
  required CheckoutRequirement checkoutRequirement,
  required CheckoutPlayStyle playStyle,
}) => '${checkoutRequirement.name}|${playStyle.name}';

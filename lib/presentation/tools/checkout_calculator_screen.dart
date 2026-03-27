import 'package:flutter/material.dart';

import '../../domain/x01/checkout_planner.dart';
import '../../domain/x01/x01_models.dart';
import '../../domain/x01/x01_rules.dart';

class CheckoutCalculatorScreen extends StatefulWidget {
  const CheckoutCalculatorScreen({super.key});

  @override
  State<CheckoutCalculatorScreen> createState() =>
      _CheckoutCalculatorScreenState();
}

class _CheckoutCalculatorScreenState extends State<CheckoutCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _scoreController =
      TextEditingController(text: '121');
  final TextEditingController _setupStartController =
      TextEditingController(text: '121');
  final TextEditingController _preferredDoublesController =
      TextEditingController();
  final TextEditingController _avoidedDoublesController =
      TextEditingController();
  int _dartsLeft = 3;
  CheckoutRequirement _checkoutRequirement = CheckoutRequirement.doubleOut;
  double _leavePreference = 50;
  List<_CheckoutOption> _options = const <_CheckoutOption>[];
  List<_BestFinishBucket> _bestFinishBuckets = const <_BestFinishBucket>[];

  static const CheckoutPlayStyle _standardPlayStyle =
      CheckoutPlayStyle.balanced;
  static const int _standardOuterBullPreference = 50;
  static const int _standardBullPreference = 50;

  final X01Rules _rules = const X01Rules();
  late final CheckoutPlanner _planner;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _planner = CheckoutPlanner(rules: _rules);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
    _recalculate();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    _scoreController.dispose();
    _setupStartController.dispose();
    _preferredDoublesController.dispose();
    _avoidedDoublesController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    _recalculate();
  }

  void _recalculate() {
    final score = int.tryParse(_scoreController.text.trim()) ?? 0;
    final setupStart = int.tryParse(_setupStartController.text.trim()) ?? 0;
    setState(() {
      if (_tabController.index == 0) {
        _options = _buildCheckoutOptions(
          score: score,
          dartsLeft: _dartsLeft,
          checkoutRequirement: _checkoutRequirement,
          playStyle: _standardPlayStyle,
        );
      } else {
        _bestFinishBuckets = _buildBestFinishBuckets(
          startScore: setupStart,
          dartsLeft: _dartsLeft,
          checkoutRequirement: _checkoutRequirement,
          playStyle: _standardPlayStyle,
        );
      }
    });
  }

  List<_CheckoutOption> _buildCheckoutOptions({
    required int score,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    if (score <= 1 || dartsLeft <= 0) {
      return const <_CheckoutOption>[];
    }
    final preferredDoubles = _parsePreferredDoubleValues(
      _preferredDoublesController.text,
    );
    final dislikedDoubles = _parsePreferredDoubleValues(
      _avoidedDoublesController.text,
    );

    final finishes = _planner.allCheckoutRoutes(
      score: score,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    );

    final options = finishes
        .map(
          (route) {
            final baseScore = _planner.scoreRoute(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: _standardOuterBullPreference,
              bullPreference: _standardBullPreference,
            );
            final baseBreakdown = _planner.routeScoreBreakdown(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: _standardOuterBullPreference,
              bullPreference: _standardBullPreference,
            );
            final adjustment = _doublePreferenceAdjustment(
              route.isEmpty ? null : route.last,
              preferredDoubles: preferredDoubles,
              dislikedDoubles: dislikedDoubles,
            );
            return _CheckoutOption(
              throws: route,
              score: baseScore + adjustment,
              breakdown: _applyDoubleAdjustmentToBreakdown(
                baseBreakdown,
                route.isEmpty ? null : route.last,
                adjustment,
              ),
              missScenarios: _buildMissScenarios(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              outerBullPreference: _standardOuterBullPreference,
              bullPreference: _standardBullPreference,
            ),
              fallbackHints: _buildFallbackHints(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              ),
              rationaleHint: _buildRationaleHint(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              ),
              badges: _buildBadges(
              route: route,
              startScore: score,
              totalDarts: dartsLeft,
              checkoutRequirement: checkoutRequirement,
              playStyle: playStyle,
              ),
            );
          },
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return options.take(8).toList();
  }

  List<_BestFinishBucket> _buildBestFinishBuckets({
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    if (startScore <= 1 || dartsLeft <= 0) {
      return const <_BestFinishBucket>[];
    }
    final preferredDoubles = _parsePreferredDoubleValues(
      _preferredDoublesController.text,
    );
    final dislikedDoubles = _parsePreferredDoubleValues(
      _avoidedDoublesController.text,
    );

    return List<_BestFinishBucket>.generate(4, (index) {
      final options = _planner.topSetupLeavesForNarrowFieldCount(
        startScore: startScore,
        dartsLeft: dartsLeft,
        narrowFieldCount: index,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
        leavePreference: _leavePreference.round(),
        outerBullPreference: _standardOuterBullPreference,
        bullPreference: _standardBullPreference,
        maxResults: 3,
      );
      final sortedOptions = options.toList()
        ..sort(
          (a, b) => (_doublePreferenceAdjustment(
                    b.finishRoute.isEmpty ? null : b.finishRoute.last,
                    preferredDoubles: preferredDoubles,
                    dislikedDoubles: dislikedDoubles,
                  ) +
                  b.score)
              .compareTo(
                _doublePreferenceAdjustment(
                      a.finishRoute.isEmpty ? null : a.finishRoute.last,
                      preferredDoubles: preferredDoubles,
                      dislikedDoubles: dislikedDoubles,
                    ) +
                    a.score,
              ),
        );
      return _BestFinishBucket(
        narrowFieldCount: index,
        options: sortedOptions
            .map(
              (option) => _SetupLeavePresentation(
                option: option,
                explanation: _buildSetupLeaveExplanation(
                  option: option,
                  startScore: startScore,
                ),
                missScenarios: _buildMissScenarios(
                  route: option.setupRoute,
                  startScore: startScore,
                  totalDarts: dartsLeft,
                  checkoutRequirement: checkoutRequirement,
                  playStyle: playStyle,
                  outerBullPreference: _standardOuterBullPreference,
                  bullPreference: _standardBullPreference,
                ),
              ),
            )
            .toList(),
      );
    });
  }

  Set<int> _parsePreferredDoubleValues(String text) {
    return text
        .split(',')
        .map((entry) => int.tryParse(entry.trim()))
        .whereType<int>()
        .where((value) => value >= 1 && value <= 20)
        .toSet();
  }

  int _doublePreferenceAdjustment(
    DartThrowResult? finalThrow, {
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
  }) {
    if (finalThrow == null || !finalThrow.isFinishDouble || finalThrow.isBull) {
      return 0;
    }
    if (preferredDoubles.contains(finalThrow.baseValue)) {
      return 150;
    }
    if (dislikedDoubles.contains(finalThrow.baseValue)) {
      return -150;
    }
    return 0;
  }

  CheckoutRouteScoreBreakdown _applyDoubleAdjustmentToBreakdown(
    CheckoutRouteScoreBreakdown breakdown,
    DartThrowResult? finalThrow,
    int adjustment,
  ) {
    if (adjustment == 0 || finalThrow == null) {
      return breakdown;
    }

    return CheckoutRouteScoreBreakdown(
      dartPathScore: breakdown.dartPathScore,
      comfort: breakdown.comfort,
      robustness: breakdown.robustness,
      doubleQuality: breakdown.doubleQuality + adjustment,
      bullPenalty: breakdown.bullPenalty,
      segmentFlow: breakdown.segmentFlow,
      dartPathDetails: breakdown.dartPathDetails,
      comfortDetails: breakdown.comfortDetails,
      robustnessDetails: breakdown.robustnessDetails,
      doubleQualityDetails: <String>[
        ...breakdown.doubleQualityDetails,
        if (adjustment > 0)
          'Persoenliche Doppel-Praeferenz fuer ${finalThrow.label}: +$adjustment',
        if (adjustment < 0)
          'Persoenlicher Malus fuer ${finalThrow.label}: $adjustment',
      ],
      bullPenaltyDetails: breakdown.bullPenaltyDetails,
      segmentFlowDetails: breakdown.segmentFlowDetails,
    );
  }

  List<_MissScenario> _buildMissScenarios({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    final scenarios = <_MissScenario>[];
    var remaining = startScore;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;

      if (dartThrow.isTriple) {
        final singleRemaining = remaining - dartThrow.baseValue;
        final singleText = _describeMissContinuation(
          remainingScore: singleRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (singleText != null) {
          scenarios.add(
            _MissScenario(
              label: 'Single statt ${dartThrow.label}',
              outcome: singleText.text,
              state: singleText.state,
            ),
          );
        }

        for (final neighbor in _rules.adjacentSegments(dartThrow.baseValue)) {
          final neighborRemaining = remaining - neighbor;
          final neighborText = _describeMissContinuation(
            remainingScore: neighborRemaining,
            dartsLeft: dartsAfterThis,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
            outerBullPreference: outerBullPreference,
            bullPreference: bullPreference,
          );
          if (neighborText != null) {
            scenarios.add(
              _MissScenario(
                label: 'Nachbar $neighbor statt ${dartThrow.label}',
                outcome: neighborText.text,
                state: neighborText.state,
              ),
            );
          }
        }
      } else if (dartThrow.isDouble && !dartThrow.isBull) {
        final singleRemaining = remaining - dartThrow.baseValue;
        final fallbackDarts = dartsAfterThis;
        final singleText = _describeMissContinuation(
          remainingScore: singleRemaining,
          dartsLeft: fallbackDarts,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (singleText != null) {
          scenarios.add(
            _MissScenario(
              label: 'Single statt ${dartThrow.label}',
              outcome: singleText.text,
              state: singleText.state,
            ),
          );
        }
      } else if (dartThrow.isBull) {
        final outerBullRemaining = remaining - 25;
        final outerBullText = _describeMissContinuation(
          remainingScore: outerBullRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          outerBullPreference: outerBullPreference,
          bullPreference: bullPreference,
        );
        if (outerBullText != null) {
          scenarios.add(
            _MissScenario(
              label: '25 statt BULL',
              outcome: outerBullText.text,
              state: outerBullText.state,
            ),
          );
        }
      }

      remaining -= dartThrow.scoredPoints;
    }

    return scenarios.take(4).toList();
  }

  _MissContinuation? _describeMissContinuation({
    required int remainingScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    int outerBullPreference = 50,
    int bullPreference = 50,
  }) {
    if (remainingScore <= 1 || dartsLeft <= 0) {
      return null;
    }

    final continuation = _planner.bestContinuationPlan(
      score: remainingScore,
      dartsLeft: dartsLeft,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      outerBullPreference: outerBullPreference,
      bullPreference: bullPreference,
    );
    if (continuation == null || continuation.throws.isEmpty) {
      return _MissContinuation(
        text: '$remainingScore Rest, kein guter Anschluss',
        state: _MissScenarioState.bad,
      );
    }

    final labels = continuation.throws.joinLabels(dartsLeft);
    if (continuation.immediateFinish) {
      return _MissContinuation(
        text: '$remainingScore Rest, Finish ueber $labels',
        state: _MissScenarioState.finish,
      );
    }
    return _MissContinuation(
      text: '$remainingScore Rest, weiter mit $labels',
      state: _MissScenarioState.setup,
    );
  }

  String _buildSetupLeaveExplanation({
    required CheckoutSetupLeaveOption option,
    required int startScore,
  }) {
    final setupNarrow = option.setupRoute.where(_planner.isNarrowField).length;
    final baseFinishBreakdown = _planner.routeScoreBreakdown(
      route: option.finishRoute,
      startScore: option.remainingScore,
      totalDarts: 3,
      checkoutRequirement: _checkoutRequirement,
      playStyle: _standardPlayStyle,
      outerBullPreference: _standardOuterBullPreference,
      bullPreference: _standardBullPreference,
    );
    final finishAdjustment = _doublePreferenceAdjustment(
      option.finishRoute.isEmpty ? null : option.finishRoute.last,
      preferredDoubles: _parsePreferredDoubleValues(
        _preferredDoublesController.text,
      ),
      dislikedDoubles: _parsePreferredDoubleValues(
        _avoidedDoublesController.text,
      ),
    );
    final finishBreakdown = _applyDoubleAdjustmentToBreakdown(
      baseFinishBreakdown,
      option.finishRoute.isEmpty ? null : option.finishRoute.last,
      finishAdjustment,
    );
    final setupLabels = option.setupRoute.map((entry) => entry.label).join(' | ');
    final finishLabels = option.finishRoute.map((entry) => entry.label).join(' | ');

    if (_leavePreference >= 67) {
      return 'Gedanke: $setupLabels stellt bewusst ${option.remainingScore}, '
          'weil danach mit $finishLabels ein starkes Restfinish offen bleibt. '
          'Der Weg nimmt dafuer $setupNarrow schmales Feld in Kauf.';
    }
    if (_leavePreference <= 33) {
      return 'Gedanke: $setupLabels haelt den Stellweg moeglichst einfach und '
          'ruhig. Es bleiben ${option.remainingScore} Rest, die trotzdem mit '
          '$finishLabels sauber auscheckbar sind.';
    }
    return 'Gedanke: Von $startScore aus balanciert $setupLabels einen einfachen '
        'Stellweg mit einem starken Leave. ${option.remainingScore} Rest bleiben, '
        'danach ist $finishLabels offen. Die Finish-Qualitaet profitiert hier von '
        '${finishBreakdown.doubleQuality >= 100 ? 'einem starken Schlussdoppel' : 'einem brauchbaren Abschlussfeld'}.';
  }

  List<String> _buildFallbackHints({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    final hints = <String>[];
    var remaining = startScore;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      final isSingleMissScenario =
          dartThrow.isTriple || (dartThrow.isDouble && !dartThrow.isBull);
      if (isSingleMissScenario) {
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        final fallbackDarts = dartsAfterThis;
        if (singleFallbackRemaining > 1 && fallbackDarts > 0) {
          final fallbackPlan = _planner.bestContinuationPlan(
            score: singleFallbackRemaining,
            dartsLeft: fallbackDarts,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          );
          if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
            final labels = fallbackPlan.throws.joinLabels(fallbackDarts);
            final prefix = 'Bei Single statt ${dartThrow.label}: ';
            final suffix = fallbackPlan.immediateFinish
                ? labels
                : '$labels fuer den naechsten Besuch';
            hints.add('$prefix$suffix');
          }
        }
      }
      remaining -= dartThrow.scoredPoints;
    }
    return hints.take(2).toList();
  }

  bool _hasImmediateMissCheckout({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    var remaining = startScore;
    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      final isSingleMissScenario =
          dartThrow.isTriple || (dartThrow.isDouble && !dartThrow.isBull);
      if (isSingleMissScenario) {
        final singleFallbackRemaining = remaining - dartThrow.baseValue;
        final fallbackDarts = dartsAfterThis;
        if (singleFallbackRemaining > 1 && fallbackDarts > 0) {
          final fallbackPlan = _planner.bestContinuationPlan(
            score: singleFallbackRemaining,
            dartsLeft: fallbackDarts,
            checkoutRequirement: checkoutRequirement,
            playStyle: playStyle,
          );
          if (fallbackPlan != null &&
              fallbackPlan.throws.isNotEmpty &&
              fallbackPlan.immediateFinish) {
            return true;
          }
        }
      }
      remaining -= dartThrow.scoredPoints;
    }
    return false;
  }

  String? _buildRationaleHint({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    if (route.length < 2 || totalDarts < 2) {
      return null;
    }

    final first = route.first;
    final firstRemaining = startScore - first.scoredPoints;
    if (firstRemaining <= 1) {
      return null;
    }

    final second = route.length > 1 ? route[1] : null;
    if (second == null) {
      return null;
    }

    final afterSecond = firstRemaining - second.scoredPoints;
    final singleOnSecondRemaining = firstRemaining - second.baseValue;

    final targetFinish =
        afterSecond == 0 ? second.label : _formatRemaining(afterSecond);

    String? fallbackText;
    if (second.isTriple && totalDarts >= 3 && singleOnSecondRemaining > 1) {
      final fallbackPlan = _planner.bestContinuationPlan(
        score: singleOnSecondRemaining,
        dartsLeft: totalDarts - 2,
        checkoutRequirement: checkoutRequirement,
        playStyle: playStyle,
      );
      if (fallbackPlan != null && fallbackPlan.throws.isNotEmpty) {
        final labels = fallbackPlan.throws.joinLabels(totalDarts - 2);
        fallbackText = fallbackPlan.immediateFinish
            ? labels
            : '$labels fuer den naechsten Besuch';
      }
    }

    if (first.isTriple && totalDarts >= 3) {
      final singleOnFirstRemaining = startScore - first.baseValue;
      if (singleOnFirstRemaining > 1) {
        final firstFallbackPlan = _planner.bestContinuationPlan(
          score: singleOnFirstRemaining,
          dartsLeft: totalDarts - 1,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
        );
        if (firstFallbackPlan != null && firstFallbackPlan.throws.isNotEmpty) {
          final firstFallbackLabels =
              firstFallbackPlan.throws.joinLabels(totalDarts - 1);
          final firstFallbackText = firstFallbackPlan.immediateFinish
              ? firstFallbackLabels
              : '$firstFallbackLabels fuer den naechsten Besuch';
          final firstFallbackLead = firstFallbackPlan.immediateFinish
              ? 'trotzdem ein guter Weg'
              : 'ein brauchbarer Weg fuer den naechsten Besuch';
          if (fallbackText != null) {
            return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
                'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
                '$firstFallbackLead. '
                'Darum geht der 2. Dart auf ${second.label}, weil auch ein Single statt ${second.label} '
                'noch $fallbackText offenlaesst.';
          }
          return 'Gedanke: ${first.label} stellt direkt $targetFinish. '
              'Wenn der erste Dart nur Single wird, bleibt mit $firstFallbackText '
              '$firstFallbackLead.';
        }
      }
    }

    if (fallbackText != null) {
      return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
          'Darum geht der 2. Dart auf ${second.label}, weil dann $targetFinish bleibt '
          'und bei Single statt ${second.label} trotzdem $fallbackText offen ist.';
    }

    return 'Gedanke: Nach ${first.label} bleiben $firstRemaining. '
        'Der 2. Dart geht auf ${second.label}, damit anschliessend $targetFinish bleibt.';
  }

  String _formatRemaining(int remaining) {
    if (remaining == 50) {
      return 'Bull';
    }
    if (remaining > 1 && remaining <= 40 && remaining.isEven) {
      return 'D${remaining ~/ 2}';
    }
    return '$remaining Rest';
  }

  List<String> _buildBadges({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
  }) {
    final badges = <String>[];
    final narrowFields = route.where(_planner.isNarrowField).length;

    if (route.length == 2) {
      badges.add('2-Dart-Weg');
    }
    if (route.isNotEmpty && !route.last.isBull) {
      badges.add(
        route.last.isFinishDouble
            ? 'starkes Schlussdoppel'
            : 'klares Schlussfeld',
      );
    }
    if (narrowFields <= 1) {
      badges.add('wenig schmale Felder');
    }
    if (route.every((entry) => !entry.isBull && entry.label != '25')) {
      badges.add('Bull vermieden');
    }
    if (_hasSameSegmentFlow(route)) {
      badges.add('ruhiger Segmentfluss');
    }
    if (_buildFallbackHints(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    ).isNotEmpty) {
      badges.add('Miss-Fallback');
    }
    if (_hasImmediateMissCheckout(
      route: route,
      startScore: startScore,
      totalDarts: totalDarts,
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
    )) {
      badges.add('robuster Miss-Fallback');
    }
    return badges.take(4).toList();
  }

  bool _hasSameSegmentFlow(List<DartThrowResult> route) {
    for (var index = 1; index < route.length; index += 1) {
      if (route[index - 1].baseValue == route[index].baseValue) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(_scoreController.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout Rechner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Einzeln'),
            Tab(text: 'Bestes Finish'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: <Widget>[
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                _buildSharedControls(includeRangeFields: false),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Vorschlaege',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Beste Variante oben. Wenige schmale Felder, passende Schlussfelder und robuste Triple-Wege bekommen Vorrang.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF556372),
                                  ),
                        ),
                        const SizedBox(height: 12),
                        if (score <= 1)
                          const Text('Bitte eine gueltige Restpunktzahl eingeben.')
                        else if (_options.isEmpty)
                          const Text('Kein Finish mit dieser Dartanzahl moeglich.')
                        else
                          ..._options.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CheckoutResultTile(
                                    rank: entry.key + 1,
                                    option: entry.value,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                _buildSharedControls(includeSetupFields: true),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Bestes Finish',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hier siehst du, welches Finish nach dem Stellweg uebrig bleibt. Pro Kategorie wird der beste Stellweg mit 0, 1, 2 oder 3 schmalen Feldern gezeigt.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF556372),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stelllogik: ${_leavePreference <= 33 ? 'einfacher Stellweg' : _leavePreference >= 67 ? 'starkes Restfinish' : 'ausgewogen'}',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF0E5A52),
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        if (_bestFinishBuckets.isEmpty)
                          const Text('Bitte einen gueltigen Startwert eingeben.')
                        else
                          ..._bestFinishBuckets.map(
                                (bucket) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F5F0),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _labelForNarrowFieldCount(
                                            bucket.narrowFieldCount,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (bucket.options.isEmpty)
                                          const Text('Kein Stellweg')
                                        else
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: bucket.options
                                                .asMap()
                                                .entries
                                                .map(
                                                  (entry) => SizedBox(
                                                    width: 260,
                                                    child: _SetupLeaveCard(
                                                      rank: entry.key + 1,
                                                      presentation: entry.value,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedControls({
    bool includeRangeFields = false,
    bool includeSetupFields = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              includeSetupFields
                  ? 'Bestes Finish und Einstellungen'
                  : includeRangeFields
                      ? 'Bereich und Einstellungen'
                      : 'Restscore und Einstellungen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!includeRangeFields && !includeSetupFields) ...<Widget>[
              TextField(
                controller: _scoreController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Restpunkte',
                ),
                onSubmitted: (_) => _recalculate(),
              ),
              const SizedBox(height: 12),
            ],
            if (includeSetupFields) ...<Widget>[
              TextField(
                controller: _setupStartController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Startwert',
                ),
                onSubmitted: (_) => _recalculate(),
              ),
              const SizedBox(height: 12),
              Text(
                'Einfacher Weg vs. starkes Restfinish',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Slider(
                value: _leavePreference,
                min: 0,
                max: 100,
                divisions: 10,
                label: _leavePreference.round().toString(),
                onChanged: (value) => setState(() => _leavePreference = value),
              ),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'einfacher Stellweg',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    'starkes Restfinish',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<int>(
              initialValue: _dartsLeft,
              decoration: const InputDecoration(
                labelText: 'Darts uebrig',
              ),
              items: const <DropdownMenuItem<int>>[
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _dartsLeft = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<CheckoutRequirement>(
              initialValue: _checkoutRequirement,
              decoration: const InputDecoration(
                labelText: 'Out-Art',
              ),
              items: CheckoutRequirement.values
                  .map(
                    (requirement) => DropdownMenuItem<CheckoutRequirement>(
                      value: requirement,
                      child: Text(_labelForRequirement(requirement)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _checkoutRequirement = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _preferredDoublesController,
              decoration: const InputDecoration(
                labelText: 'Lieblingsdoppel',
                helperText: 'Komma-getrennt, z. B. 16,20,10',
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _recalculate(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _avoidedDoublesController,
              decoration: const InputDecoration(
                labelText: 'Ungern gespielte Doppel',
                helperText: 'Komma-getrennt, z. B. 7,11,19',
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _recalculate(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _recalculate,
                child: const Text('Berechnen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForRequirement(CheckoutRequirement requirement) {
    switch (requirement) {
      case CheckoutRequirement.singleOut:
        return 'Single Out';
      case CheckoutRequirement.doubleOut:
        return 'Double Out';
      case CheckoutRequirement.masterOut:
        return 'Master Out';
    }
  }

  String _labelForNarrowFieldCount(int count) => switch (count) {
        0 => 'Kein schmales Feld',
        1 => '1x schmales Feld',
        2 => '2x schmale Felder',
        _ => '3x schmale Felder',
      };
}

class _CheckoutResultTile extends StatelessWidget {
  const _CheckoutResultTile({
    required this.rank,
    required this.option,
  });

  final int rank;
  final _CheckoutOption option;

  List<_BreakdownExplanation> _buildBreakdownExplanations() {
    final route = option.throws;
    final setupThrows = route.take(route.length > 1 ? route.length - 1 : 0);
    final earlyTriples = setupThrows.where((entry) => entry.isTriple).length;
    final earlyDoubles = setupThrows
        .where((entry) => entry.isDouble && !entry.isBull)
        .length;
    final bigSingles = setupThrows
        .where(
          (entry) =>
              !entry.isTriple &&
              !entry.isDouble &&
              !entry.isBull &&
              entry.label != '25' &&
              entry.baseValue >= 10,
        )
        .length;
    final outerBullCount = route.where((entry) => entry.label == '25').length;
    final bullCount = route.where((entry) => entry.isBull).length;
    final sameSegmentPairs = _sameSegmentPairs(route);
    final finishScenarios = option.missScenarios
        .where((scenario) => scenario.state == _MissScenarioState.finish)
        .length;
    final setupScenarios = option.missScenarios
        .where((scenario) => scenario.state == _MissScenarioState.setup)
        .length;

    final reasons = <_BreakdownExplanation>[
      _BreakdownExplanation(
        label: 'Dart-Weg',
        value: option.breakdown.dartPathScore,
        reason: _dartPathReason(route.length),
        details: option.breakdown.dartPathDetails,
      ),
      _BreakdownExplanation(
        label: 'Komfort',
        value: option.breakdown.comfort,
        reason: _comfortReason(
          bigSingles: bigSingles,
          earlyTriples: earlyTriples,
          earlyDoubles: earlyDoubles,
        ),
        details: option.breakdown.comfortDetails,
      ),
      _BreakdownExplanation(
        label: 'Robustheit',
        value: option.breakdown.robustness,
        reason: _robustnessReason(
          finishScenarios: finishScenarios,
          setupScenarios: setupScenarios,
        ),
        details: option.breakdown.robustnessDetails,
      ),
      _BreakdownExplanation(
        label: 'Doppel',
        value: option.breakdown.doubleQuality,
        reason: _doubleReason(route.last),
        details: option.breakdown.doubleQualityDetails,
      ),
      _BreakdownExplanation(
        label: 'Bull-Malus',
        value: -option.breakdown.bullPenalty,
        reason: _bullReason(
          outerBullCount: outerBullCount,
          bullCount: bullCount,
        ),
        details: option.breakdown.bullPenaltyDetails,
      ),
      _BreakdownExplanation(
        label: 'Segmentfluss',
        value: option.breakdown.segmentFlow,
        reason: _flowReason(sameSegmentPairs: sameSegmentPairs),
        details: option.breakdown.segmentFlowDetails,
      ),
    ];

    return reasons;
  }

  int _sameSegmentPairs(List<DartThrowResult> route) {
    var count = 0;
    for (var index = 1; index < route.length; index += 1) {
      if (route[index - 1].baseValue == route[index].baseValue) {
        count += 1;
      }
    }
    return count;
  }

  String _comfortReason({
    required int bigSingles,
    required int earlyTriples,
    required int earlyDoubles,
  }) {
    if (bigSingles > 0 && earlyTriples == 0 && earlyDoubles == 0) {
      return 'grosse Singles vor dem Schlussdart machen den Weg einfacher.';
    }
    if (earlyTriples > 0) {
      return 'fruehe Triple machen den Weg schmaler und druecken den Komfort.';
    }
    if (earlyDoubles > 0) {
      return 'ein fruehes Doppel ist heikler als ein grosses Single-Feld.';
    }
    return 'der Aufbau ist weder besonders breit noch besonders unbequem.';
  }

  String _dartPathReason(int routeLength) {
    switch (routeLength) {
      case 1:
        return '1-Dart-Weg liegt vorne und bekommt den hoechsten Tempobonus.';
      case 2:
        return '2-Dart-Weg wird in der Regel vor 3 Darts bevorzugt und bekommt einen klaren Bonus.';
      default:
        return '3-Dart-Weg bleibt spielbar, liegt aber meist etwas hinter kuerzeren Wegen.';
    }
  }

  String _robustnessReason({
    required int finishScenarios,
    required int setupScenarios,
  }) {
    if (finishScenarios > 0) {
      return 'bei Fehlwurf bleibt noch direkt ein Finish offen.';
    }
    if (setupScenarios > 0) {
      return 'bei Fehlwurf bleibt immerhin noch ein brauchbarer Anschluss.';
    }
    return 'Fehlwuerfe fuehren hier eher auf schwache Anschlusswege.';
  }

  String _doubleReason(DartThrowResult finalThrow) {
    if (finalThrow.isBull) {
      return 'Bull zaehlt als Abschluss, ist aber schwaecher als Top-Doppel.';
    }
    if (finalThrow.isFinishDouble) {
      return 'das Schlussdoppel ${finalThrow.label} wird in der Bewertung bevorzugt.';
    }
    return 'kein klassisches Schlussdoppel, daher wenig Bonus.';
  }

  String _bullReason({
    required int outerBullCount,
    required int bullCount,
  }) {
    if (bullCount == 0 && outerBullCount == 0) {
      return 'kein Bull im Weg, deshalb faellt hier kein Malus an.';
    }
    if (bullCount > 0 && outerBullCount == 0) {
      return 'BULL ist bewusst abgewertet, vor allem als Schlussfeld.';
    }
    if (outerBullCount > 0 && bullCount == 0) {
      return '25 zaehlt hier nicht mehr als eigener Malus.';
    }
    return 'Nur BULL kostet hier Punkte; 25 hat keinen eigenen Malus mehr.';
  }

  String _flowReason({required int sameSegmentPairs}) {
    if (sameSegmentPairs > 0) {
      return 'wiederholte Segmente machen den Rhythmus ruhiger.';
    }
    return 'mehr Segmentwechsel geben hier wenig oder keinen Flow-Bonus.';
  }

  @override
  Widget build(BuildContext context) {
    final labels = option.throws.map((entry) => entry.label).join('  |  ');
    final breakdownExplanations = _buildBreakdownExplanations();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rank == 1 ? const Color(0xFFE3F1EC) : const Color(0xFFF7F5F0),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor:
                rank == 1 ? const Color(0xFF0E5A52) : const Color(0xFFCFD8E1),
            foregroundColor: rank == 1 ? Colors.white : const Color(0xFF17324D),
            child: Text('$rank'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  labels,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${option.throws.length} Dart${option.throws.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF556372),
                      ),
                ),
                if (option.badges.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: option.badges
                        .map(
                          (badge) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF0F4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: const Color(0xFF3E5468),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Warum diese Variante?',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17324D),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Endscore: ${option.score}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF0E5A52),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _ScorePill(
                      label: 'Komfort',
                      value: option.breakdown.comfort,
                    ),
                    _ScorePill(
                      label: 'Robustheit',
                      value: option.breakdown.robustness,
                    ),
                    _ScorePill(
                      label: 'Doppel',
                      value: option.breakdown.doubleQuality,
                    ),
                    _ScorePill(
                      label: 'Bull-Malus',
                      value: -option.breakdown.bullPenalty,
                    ),
                    _ScorePill(
                      label: 'Segmentfluss',
                      value: option.breakdown.segmentFlow,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: breakdownExplanations
                      .map(
                        (item) => SizedBox(
                          width: 220,
                          child: _BreakdownDetailsCard(item: item),
                        ),
                      )
                      .toList(),
                ),
                if (option.missScenarios.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _MissScenarioPanel(
                    scenarios: option.missScenarios,
                  ),
                ],
                if (option.fallbackHints.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  ...option.fallbackHints.map(
                    (hint) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        hint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF0E5A52),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
                if (option.rationaleHint != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    option.rationaleHint!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutOption {
  const _CheckoutOption({
    required this.throws,
    required this.score,
    required this.breakdown,
    required this.missScenarios,
    this.fallbackHints = const <String>[],
    this.badges = const <String>[],
    this.rationaleHint,
  });

  final List<DartThrowResult> throws;
  final int score;
  final CheckoutRouteScoreBreakdown breakdown;
  final List<_MissScenario> missScenarios;
  final List<String> fallbackHints;
  final List<String> badges;
  final String? rationaleHint;
}

class _BestFinishBucket {
  const _BestFinishBucket({
    required this.narrowFieldCount,
    required this.options,
  });

  final int narrowFieldCount;
  final List<_SetupLeavePresentation> options;
}

class _SetupLeavePresentation {
  const _SetupLeavePresentation({
    required this.option,
    required this.explanation,
    required this.missScenarios,
  });

  final CheckoutSetupLeaveOption option;
  final String explanation;
  final List<_MissScenario> missScenarios;
}

class _MissScenario {
  const _MissScenario({
    required this.label,
    required this.outcome,
    required this.state,
  });

  final String label;
  final String outcome;
  final _MissScenarioState state;
}

class _MissContinuation {
  const _MissContinuation({
    required this.text,
    required this.state,
  });

  final String text;
  final _MissScenarioState state;
}

enum _MissScenarioState { finish, setup, bad }

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final isPositive = value >= 0;
    final text = '${isPositive ? '+' : ''}$value';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isPositive
            ? const Color(0xFFE6F3ED)
            : const Color(0xFFF6E8E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $text',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  isPositive ? const Color(0xFF0E5A52) : const Color(0xFF8A3A2C),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _BreakdownExplanation {
  const _BreakdownExplanation({
    required this.label,
    required this.value,
    required this.reason,
    required this.details,
  });

  final String label;
  final int value;
  final String reason;
  final List<String> details;
}

class _BreakdownExplanationCard extends StatelessWidget {
  const _BreakdownExplanationCard({
    required this.item,
  });

  final _BreakdownExplanation item;

  @override
  Widget build(BuildContext context) {
    final isPositive = item.value >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17324D),
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFE6F3ED)
                      : const Color(0xFFF6E8E6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${item.value}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isPositive
                            ? const Color(0xFF0E5A52)
                            : const Color(0xFF8A3A2C),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
            Text(
              item.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF556372),
                    height: 1.35,
                  ),
            ),
            if (item.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  title: Text(
                    'Genaue Rechnung',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: const Color(0xFF0E5A52),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  children: item.details
                      .map(
                        (detail) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  '•',
                                  style: TextStyle(
                                    color: Color(0xFF556372),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  detail,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF556372),
                                        height: 1.3,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      );
  }
}

class _BreakdownDetailsCard extends StatelessWidget {
  const _BreakdownDetailsCard({
    required this.item,
  });

  final _BreakdownExplanation item;

  @override
  Widget build(BuildContext context) {
    final isPositive = item.value >= 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17324D),
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFFE6F3ED)
                      : const Color(0xFFF6E8E6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${item.value}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isPositive
                            ? const Color(0xFF0E5A52)
                            : const Color(0xFF8A3A2C),
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.reason,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                  height: 1.35,
                ),
          ),
          if (item.details.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                dense: true,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                title: Text(
                  'Genaue Rechnung',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF0E5A52),
                        fontWeight: FontWeight.w800,
                      ),
                ),
                children: item.details
                    .map(
                      (detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                '-',
                                style: TextStyle(
                                  color: Color(0xFF556372),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                detail,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: const Color(0xFF556372),
                                      height: 1.3,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupLeaveCard extends StatelessWidget {
  const _SetupLeaveCard({
    required this.rank,
    required this.presentation,
  });

  final int rank;
  final _SetupLeavePresentation presentation;

  @override
  Widget build(BuildContext context) {
    final option = presentation.option;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rank == 1 ? const Color(0xFFE3F1EC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Option $rank',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17324D),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            option.setupRoute.map((entry) => entry.label).join(' | '),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Stellt ${option.remainingScore} Rest',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Danach: ${option.finishRoute.map((entry) => entry.label).join(' | ')}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF0E5A52),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            presentation.explanation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                  height: 1.35,
                ),
          ),
          if (presentation.missScenarios.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            _MissScenarioPanel(scenarios: presentation.missScenarios),
          ],
        ],
      ),
    );
  }
}

class _MissScenarioPanel extends StatelessWidget {
  const _MissScenarioPanel({
    required this.scenarios,
  });

  final List<_MissScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Miss-Szenarien',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17324D),
              ),
        ),
        children: scenarios
            .map(
              (scenario) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _backgroundForScenario(scenario.state),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeBackgroundForScenario(scenario.state),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _labelForScenario(scenario.state),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _textForScenario(scenario.state),
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF556372),
                                height: 1.35,
                              ),
                          children: <InlineSpan>[
                            TextSpan(
                              text: '${scenario.label}: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _textForScenario(scenario.state),
                              ),
                            ),
                            TextSpan(text: scenario.outcome),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Color _backgroundForScenario(_MissScenarioState state) {
    switch (state) {
      case _MissScenarioState.finish:
        return const Color(0xFFE6F3ED);
      case _MissScenarioState.setup:
        return const Color(0xFFF4EFD8);
      case _MissScenarioState.bad:
        return const Color(0xFFF6E8E6);
    }
  }

  Color _badgeBackgroundForScenario(_MissScenarioState state) {
    switch (state) {
      case _MissScenarioState.finish:
        return const Color(0xFFD4EBE2);
      case _MissScenarioState.setup:
        return const Color(0xFFE9E1A8);
      case _MissScenarioState.bad:
        return const Color(0xFFF0D3CD);
    }
  }

  String _labelForScenario(_MissScenarioState state) {
    switch (state) {
      case _MissScenarioState.finish:
        return 'Finish';
      case _MissScenarioState.setup:
        return 'Setup';
      case _MissScenarioState.bad:
        return 'kritisch';
    }
  }

  Color _textForScenario(_MissScenarioState state) {
    switch (state) {
      case _MissScenarioState.finish:
        return const Color(0xFF0E5A52);
      case _MissScenarioState.setup:
        return const Color(0xFF857200);
      case _MissScenarioState.bad:
        return const Color(0xFF8A3A2C);
    }
  }
}

extension on List<DartThrowResult> {
  String joinLabels(int maxThrows) {
    return take(maxThrows).map((entry) => entry.label).join(' | ');
  }
}

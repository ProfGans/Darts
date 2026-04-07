import 'package:flutter/material.dart';

import '../../data/background/simulation_service.dart';
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
      TextEditingController(text: '171');
  final TextEditingController _preferredDoublesController =
      TextEditingController();
  final TextEditingController _avoidedDoublesController =
      TextEditingController();
  int _dartsLeft = 3;
  CheckoutRequirement _checkoutRequirement = CheckoutRequirement.doubleOut;
  List<_CheckoutOption> _options = const <_CheckoutOption>[];
  Map<_SetupFinishBand, _SetupLeavePresentation> _setupBandOptions =
      const <_SetupFinishBand, _SetupLeavePresentation>{};
  final Map<String, List<_CheckoutOption>> _checkoutOptionsCache =
      <String, List<_CheckoutOption>>{};
  final Map<String, Map<_SetupFinishBand, _SetupLeavePresentation>>
  _setupBuildResultCache =
      <String, Map<_SetupFinishBand, _SetupLeavePresentation>>{};
  final Map<String, _SetupFallbackNode> _setupFallbackTreeCache =
      <String, _SetupFallbackNode>{};
  bool _isCalculating = false;
  String _calculationLabel = '';
  int _calculationRequestId = 0;

  static const CheckoutPlayStyle _standardPlayStyle =
      CheckoutPlayStyle.balanced;
  static const int _standardSetupPreference = 85;
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

  Future<void> _recalculate() async {
    final requestId = ++_calculationRequestId;
    final score = int.tryParse(_scoreController.text.trim()) ?? 0;
    final setupStart = int.tryParse(_setupStartController.text.trim()) ?? 0;
    final preferredDoubles = _parsePreferredDoubleValues(
      _preferredDoublesController.text,
    );
    final dislikedDoubles = _parsePreferredDoubleValues(
      _avoidedDoublesController.text,
    );

    if (_tabController.index == 0) {
      final cacheKey = <Object>[
        score,
        _dartsLeft,
        _checkoutRequirement,
        _standardPlayStyle,
        _preferredDoublesController.text.trim(),
        _avoidedDoublesController.text.trim(),
      ].join('|');
      final cached = _checkoutOptionsCache[cacheKey];
      if (cached != null) {
        if (!mounted || requestId != _calculationRequestId) {
          return;
        }
        setState(() {
          _isCalculating = false;
          _calculationLabel = '';
          _options = cached;
        });
        return;
      }
    } else {
      final cacheKey = <Object>[
        setupStart,
        _dartsLeft,
        _checkoutRequirement,
        _standardPlayStyle,
        _preferredDoublesController.text.trim(),
        _avoidedDoublesController.text.trim(),
      ].join('|');
      final cached = _setupBuildResultCache[cacheKey];
      if (cached != null) {
        if (!mounted || requestId != _calculationRequestId) {
          return;
        }
        setState(() {
          _isCalculating = false;
          _calculationLabel = '';
          _setupBandOptions = cached;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isCalculating = true;
        _calculationLabel = _tabController.index == 0
            ? 'Checkout-Wege werden berechnet'
            : 'Stellwege werden berechnet';
      });
    }
    await Future<void>.delayed(Duration.zero);

    try {
      final handle = SimulationService.instance.startJob<Map<String, Object?>>(
        taskType: 'checkout_calculator',
        initialLabel: _tabController.index == 0
            ? 'Checkout-Wege werden berechnet'
            : 'Stellwege werden berechnet',
        payload: <String, Object?>{
          'mode': _tabController.index == 0 ? 'checkout' : 'setup',
          'score': score,
          'startScore': setupStart,
          'dartsLeft': _dartsLeft,
          'checkoutRequirement': _checkoutRequirement.name,
          'playStyle': _standardPlayStyle.name,
          'preferredDoubles': preferredDoubles.toList()..sort(),
          'dislikedDoubles': dislikedDoubles.toList()..sort(),
        },
      );
      void updateCalculationLabel() {
          if (!mounted || requestId != _calculationRequestId) {
            return;
          }
          setState(() {
            _calculationLabel = handle.label;
          });
      }
      handle.addListener(updateCalculationLabel);
      late final Map<String, Object?> result;
      try {
        result = await handle.result;
      } finally {
        handle.removeListener(updateCalculationLabel);
      }
      if (!mounted || requestId != _calculationRequestId) {
        return;
      }
      setState(() {
        if (_tabController.index == 0) {
          _options = _checkoutOptionsFromBackgroundResult(result);
        } else {
          _setupBandOptions = _setupBandOptionsFromBackgroundResult(result);
        }
      });
    } finally {
      if (mounted && requestId == _calculationRequestId) {
        setState(() {
          _isCalculating = false;
          _calculationLabel = '';
        });
      }
    }
  }

  _SetupFallbackNode _buildSetupFallbackTree({
    required List<DartThrowResult> route,
    required int startScore,
    required int totalDarts,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
    required _SetupFinishBand? targetBand,
  }) {
    final branches = <_SetupFallbackBranch>[];
    var remaining = startScore;

    for (var index = 0; index < route.length; index += 1) {
      final dartThrow = route[index];
      final dartsAfterThis = totalDarts - index - 1;
      if (dartsAfterThis <= 0) {
        remaining -= dartThrow.scoredPoints;
        continue;
      }

      int? fallbackRemaining;
      String? missLabel;
      if (dartThrow.isTriple) {
        fallbackRemaining = remaining - dartThrow.baseValue;
        missLabel = 'Single statt ${dartThrow.label}';
      } else if (dartThrow.isBull) {
        fallbackRemaining = remaining - 25;
        missLabel = '25 statt BULL';
      }

      if (fallbackRemaining != null &&
          fallbackRemaining > 1 &&
          missLabel != null) {
        final fallbackRoute = _bestSetupFallbackRoute(
          startScore: fallbackRemaining,
          dartsLeft: dartsAfterThis,
          checkoutRequirement: checkoutRequirement,
          playStyle: playStyle,
          preferredDoubles: preferredDoubles,
          dislikedDoubles: dislikedDoubles,
          targetBand: targetBand,
        );

        if (fallbackRoute != null && fallbackRoute.isNotEmpty) {
          branches.add(
            _SetupFallbackBranch(
              dartIndex: index + 1,
              triggerLabel: dartThrow.label,
              missLabel: missLabel,
              remainingScore: fallbackRemaining,
              child: _buildSetupFallbackTree(
                route: fallbackRoute,
                startScore: fallbackRemaining,
                totalDarts: dartsAfterThis,
                checkoutRequirement: checkoutRequirement,
                playStyle: playStyle,
                preferredDoubles: preferredDoubles,
                dislikedDoubles: dislikedDoubles,
                targetBand: targetBand,
              ),
            ),
          );
        }
      }

      remaining -= dartThrow.scoredPoints;
    }

    return _SetupFallbackNode(
      route: route,
      startScore: startScore,
      branches: branches,
    );
  }

  List<DartThrowResult>? _bestSetupFallbackRoute({
    required int startScore,
    required int dartsLeft,
    required CheckoutRequirement checkoutRequirement,
    required CheckoutPlayStyle playStyle,
    required Set<int> preferredDoubles,
    required Set<int> dislikedDoubles,
    required _SetupFinishBand? targetBand,
  }) {
    if (!_planner.isValidSetupStartScore(startScore) || dartsLeft <= 0) {
      return null;
    }

    return _planner.bestSetupFallbackRoute(
      startScore: startScore,
      dartsLeft: dartsLeft,
      targetBand: _toPlannerSetupFinishBand(targetBand),
      checkoutRequirement: checkoutRequirement,
      playStyle: playStyle,
      leavePreference: _standardSetupPreference,
      outerBullPreference: _standardOuterBullPreference,
      bullPreference: _standardBullPreference,
      preferredDoubles: preferredDoubles,
      dislikedDoubles: dislikedDoubles,
    );
  }

  String _setupPresentationKey(_SetupLeavePresentation presentation) {
    final sortedPreferred = presentation.preferredDoubles.toList()..sort();
    final sortedDisliked = presentation.dislikedDoubles.toList()..sort();
    return <Object>[
      presentation.option.setupRoute.map((entry) => entry.label).join('|'),
      presentation.option.remainingScore,
      presentation.option.finishRoute.map((entry) => entry.label).join('|'),
      presentation.option.score,
      presentation.startScore,
      presentation.dartsLeft,
      presentation.checkoutRequirement,
      presentation.playStyle,
      presentation.targetBand?.name ?? 'none',
      sortedPreferred,
      sortedDisliked,
    ].join('|');
  }

  _SetupFallbackNode _resolveSetupFallbackTree(
    _SetupLeavePresentation presentation,
  ) {
    final cacheKey = _setupPresentationKey(presentation);
    final cached = _setupFallbackTreeCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final tree = _buildSetupFallbackTree(
      route: presentation.option.setupRoute,
      startScore: presentation.startScore,
      totalDarts: presentation.dartsLeft,
      checkoutRequirement: presentation.checkoutRequirement,
      playStyle: presentation.playStyle,
      preferredDoubles: presentation.preferredDoubles,
      dislikedDoubles: presentation.dislikedDoubles,
      targetBand: presentation.targetBand,
    );
    _setupFallbackTreeCache[cacheKey] = tree;
    return tree;
  }

  CheckoutSetupFinishBand? _toPlannerSetupFinishBand(_SetupFinishBand? band) {
    switch (band) {
      case _SetupFinishBand.deep:
        return CheckoutSetupFinishBand.deep;
      case _SetupFinishBand.medium:
        return CheckoutSetupFinishBand.medium;
      case _SetupFinishBand.justFinish:
        return CheckoutSetupFinishBand.justFinish;
      case null:
        return null;
    }
  }

  Set<int> _parsePreferredDoubleValues(String text) {
    return text
        .split(',')
        .map((entry) => int.tryParse(entry.trim()))
        .whereType<int>()
        .where((value) => value >= 1 && value <= 20)
        .toSet();
  }

  @override
  Widget build(BuildContext context) {
    final score = int.tryParse(_scoreController.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout-Rechner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(text: 'Checkout-Rechner'),
            Tab(text: 'Stell Rechner'),
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
                        if (_isCalculating && _tabController.index == 0) ...<Widget>[
                          LinearProgressIndicator(
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _calculationLabel,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF556372),
                                ),
                          ),
                        ] else if (score <= 1)
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
                          'Stell Rechner',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hier siehst du die besten Stellwege als Top-Liste. Im Stell Rechner zaehlt vor allem, welcher Weg am staerksten ein garantiertes Finish stehen laesst und dabei mit moeglichst wenigen schmalen Feldern auskommt.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF556372),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stell-Prioritaet: garantiertes Finish-Leave zuerst, dann wenige schmale Felder und ruhiger Segmentfluss.',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: const Color(0xFF0E5A52),
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        if (_isCalculating && _tabController.index == 1) ...<Widget>[
                          LinearProgressIndicator(
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _calculationLabel,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF556372),
                                ),
                          ),
                        ] else if (_setupBandOptions.isNotEmpty) ...<Widget>[
                          Text(
                            'Finish-Bereiche',
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF17324D),
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: _SetupFinishBand.values
                                .map(
                                  (band) => SizedBox(
                                    width: 250,
                                    child: _SetupBandCard(
                                      band: band,
                                      presentation: _setupBandOptions[band],
                                      resolveFallbackTree:
                                          _resolveSetupFallbackTree,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (_setupBandOptions.isEmpty)
                          const Text(
                            'Bitte einen gueltigen Stellwert eingeben. Erlaubt sind 159, 162, 163, 165, 166, 168, 169 oder Werte ab 171.',
                          )
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
                  ? 'Stell Rechner und Einstellungen'
                  : includeRangeFields
                      ? 'Bereich und Einstellungen'
                      : 'Checkout-Rechner und Einstellungen',
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
                  helperText:
                      'Nur fuer Stellwege: 159, 162, 163, 165, 166, 168, 169 oder Werte ab 171',
                ),
                onSubmitted: (_) => _recalculate(),
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
        return 'Triple Out';
    }
  }

  List<_CheckoutOption> _checkoutOptionsFromBackgroundResult(
    Map<String, Object?> result,
  ) {
    final options = ((result['options'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map((entry) => _checkoutOptionFromMap(entry.cast<String, Object?>()))
        .toList(growable: false);
    final cacheKey = <Object>[
      int.tryParse(_scoreController.text.trim()) ?? 0,
      _dartsLeft,
      _checkoutRequirement,
      _standardPlayStyle,
      _preferredDoublesController.text.trim(),
      _avoidedDoublesController.text.trim(),
    ].join('|');
    _checkoutOptionsCache[cacheKey] = options;
    return options;
  }

  Map<_SetupFinishBand, _SetupLeavePresentation>
      _setupBandOptionsFromBackgroundResult(
    Map<String, Object?> result,
  ) {
    final rawBands =
        (result['bands'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{};
    final mapped = <_SetupFinishBand, _SetupLeavePresentation>{};
    for (final entry in rawBands.entries) {
      final band = _setupFinishBandFromName(entry.key);
      final value = entry.value;
      if (band == null || value is! Map) {
        continue;
      }
      mapped[band] = _setupPresentationFromMap(value.cast<String, Object?>());
    }
    final cacheKey = <Object>[
      int.tryParse(_setupStartController.text.trim()) ?? 0,
      _dartsLeft,
      _checkoutRequirement,
      _standardPlayStyle,
      _preferredDoublesController.text.trim(),
      _avoidedDoublesController.text.trim(),
    ].join('|');
    _setupBuildResultCache[cacheKey] = mapped;
    return mapped;
  }

  _CheckoutOption _checkoutOptionFromMap(Map<String, Object?> map) {
    return _CheckoutOption(
      throws: ((map['throws'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      score: (map['score'] as num?)?.toInt() ?? 0,
      breakdown: _routeScoreBreakdownFromMap(
        (map['breakdown'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      missScenarios: ((map['missScenarios'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _missScenarioFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      fallbackHints: ((map['fallbackHints'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      badges: ((map['badges'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      rationaleHint: map['rationaleHint'] as String?,
    );
  }

  _SetupLeavePresentation _setupPresentationFromMap(Map<String, Object?> map) {
    final optionMap =
        (map['option'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{};
    return _SetupLeavePresentation(
      option: _setupLeaveOptionFromMap(optionMap),
      effectiveScore: (map['effectiveScore'] as num?)?.toInt() ?? 0,
      effectiveBreakdown: _setupScoreBreakdownFromMap(
        (map['effectiveBreakdown'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
      explanation: map['explanation'] as String?,
      fallbackTree: null,
      missScenarios: null,
      startScore: (map['startScore'] as num?)?.toInt() ?? 0,
      dartsLeft: (map['dartsLeft'] as num?)?.toInt() ?? 0,
      checkoutRequirement: CheckoutRequirement.values.firstWhere(
        (entry) => entry.name == map['checkoutRequirement'],
        orElse: () => CheckoutRequirement.doubleOut,
      ),
      playStyle: CheckoutPlayStyle.values.firstWhere(
        (entry) => entry.name == map['playStyle'],
        orElse: () => CheckoutPlayStyle.balanced,
      ),
      preferredDoubles: ((map['preferredDoubles'] as List?) ?? const <Object?>[])
          .whereType<num>()
          .map((entry) => entry.toInt())
          .toSet(),
      dislikedDoubles: ((map['dislikedDoubles'] as List?) ?? const <Object?>[])
          .whereType<num>()
          .map((entry) => entry.toInt())
          .toSet(),
      targetBand: _setupFinishBandFromName(map['targetBand'] as String?),
    );
  }

  CheckoutSetupLeaveOption _setupLeaveOptionFromMap(Map<String, Object?> map) {
    return CheckoutSetupLeaveOption(
      setupRoute: ((map['setupRoute'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      remainingScore: (map['remainingScore'] as num?)?.toInt() ?? 0,
      finishRoute: ((map['finishRoute'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((entry) => _throwFromMap(entry.cast<String, Object?>()))
          .toList(growable: false),
      score: (map['score'] as num?)?.toInt() ?? 0,
      breakdown: _setupScoreBreakdownFromMap(
        (map['breakdown'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
      ),
    );
  }

  DartThrowResult _throwFromMap(Map<String, Object?> map) {
    return DartThrowResult(
      label: (map['label'] as String?) ?? '',
      baseValue: (map['baseValue'] as num?)?.toInt() ?? 0,
      scoredPoints: (map['scoredPoints'] as num?)?.toInt() ?? 0,
      isDouble: (map['isDouble'] as bool?) ?? false,
      isTriple: (map['isTriple'] as bool?) ?? false,
      isBull: (map['isBull'] as bool?) ?? false,
      isMiss: (map['isMiss'] as bool?) ?? false,
    );
  }

  CheckoutRouteScoreBreakdown _routeScoreBreakdownFromMap(
    Map<String, Object?> map,
  ) {
    return CheckoutRouteScoreBreakdown(
      dartPathScore: (map['dartPathScore'] as num?)?.toInt() ?? 0,
      comfort: (map['comfort'] as num?)?.toInt() ?? 0,
      robustness: (map['robustness'] as num?)?.toInt() ?? 0,
      doubleQuality: (map['doubleQuality'] as num?)?.toInt() ?? 0,
      narrowFieldPenalty: (map['narrowFieldPenalty'] as num?)?.toInt() ?? 0,
      bullPenalty: (map['bullPenalty'] as num?)?.toInt() ?? 0,
      segmentFlow: (map['segmentFlow'] as num?)?.toInt() ?? 0,
      dartPathDetails: ((map['dartPathDetails'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      comfortDetails: ((map['comfortDetails'] as List?) ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      robustnessDetails:
          ((map['robustnessDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      doubleQualityDetails:
          ((map['doubleQualityDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      narrowFieldDetails:
          ((map['narrowFieldDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      bullPenaltyDetails:
          ((map['bullPenaltyDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      segmentFlowDetails:
          ((map['segmentFlowDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  CheckoutSetupScoreBreakdown _setupScoreBreakdownFromMap(
    Map<String, Object?> map,
  ) {
    return CheckoutSetupScoreBreakdown(
      setupPathScore: (map['setupPathScore'] as num?)?.toInt() ?? 0,
      routeGuidance: (map['routeGuidance'] as num?)?.toInt() ?? 0,
      leaveQuality: (map['leaveQuality'] as num?)?.toInt() ?? 0,
      missPenalty: (map['missPenalty'] as num?)?.toInt() ?? 0,
      totalScore: (map['totalScore'] as num?)?.toInt() ?? 0,
      setupPathDetails:
          ((map['setupPathDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      routeGuidanceDetails:
          ((map['routeGuidanceDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      leaveQualityDetails:
          ((map['leaveQualityDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
      missPenaltyDetails:
          ((map['missPenaltyDetails'] as List?) ?? const <Object?>[])
              .whereType<String>()
              .toList(growable: false),
    );
  }

  _MissScenario _missScenarioFromMap(Map<String, Object?> map) {
    return _MissScenario(
      dartIndex: (map['dartIndex'] as num?)?.toInt() ?? 0,
      targetLabel: (map['targetLabel'] as String?) ?? '',
      label: (map['label'] as String?) ?? '',
      outcome: (map['outcome'] as String?) ?? '',
      state: _missScenarioStateFromName(map['state'] as String?),
    );
  }

  _MissScenarioState _missScenarioStateFromName(String? name) {
    switch (name) {
      case 'finish':
        return _MissScenarioState.finish;
      case 'setup':
        return _MissScenarioState.setup;
      case 'bad':
      default:
        return _MissScenarioState.bad;
    }
  }

  _SetupFinishBand? _setupFinishBandFromName(String? name) {
    switch (name) {
      case 'deep':
        return _SetupFinishBand.deep;
      case 'medium':
        return _SetupFinishBand.medium;
      case 'justFinish':
        return _SetupFinishBand.justFinish;
      default:
        return null;
    }
  }
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
        label: 'Schmale Felder',
        value: -option.breakdown.narrowFieldPenalty,
        reason: _narrowFieldReason(route),
        details: option.breakdown.narrowFieldDetails,
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

  String _narrowFieldReason(List<DartThrowResult> route) {
    final count = route
        .where(
          (entry) =>
              entry.label == '25' ||
              entry.isTriple ||
              entry.isDouble ||
              entry.isBull,
        )
        .length;
    if (count == 0) {
      return 'keine schmalen Felder im Weg, daher kein Zusatzmalus.';
    }
    return '$count schmales Feld${count == 1 ? '' : 'er'} druecken den Gesamtscore.';
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
                _RouteHeader(
                  labels: labels,
                  score: option.score,
                  scoreLabel: 'Endscore',
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
                      label: 'Schmale Felder',
                      value: -option.breakdown.narrowFieldPenalty,
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
                  _TripleSingleFallbackPanel(
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

class _SetupLeavePresentation {
  const _SetupLeavePresentation({
    required this.option,
    required this.effectiveScore,
    required this.effectiveBreakdown,
    required this.explanation,
    required this.fallbackTree,
    required this.missScenarios,
    required this.startScore,
    required this.dartsLeft,
    required this.checkoutRequirement,
    required this.playStyle,
    required this.preferredDoubles,
    required this.dislikedDoubles,
    required this.targetBand,
  });

  final CheckoutSetupLeaveOption option;
  final int effectiveScore;
  final CheckoutSetupScoreBreakdown effectiveBreakdown;
  final String? explanation;
  final _SetupFallbackNode? fallbackTree;
  final List<_MissScenario>? missScenarios;
  final int startScore;
  final int dartsLeft;
  final CheckoutRequirement checkoutRequirement;
  final CheckoutPlayStyle playStyle;
  final Set<int> preferredDoubles;
  final Set<int> dislikedDoubles;
  final _SetupFinishBand? targetBand;
}

class _SetupFallbackNode {
  const _SetupFallbackNode({
    required this.route,
    required this.startScore,
    required this.branches,
  });

  final List<DartThrowResult> route;
  final int startScore;
  final List<_SetupFallbackBranch> branches;
}

class _SetupFallbackBranch {
  const _SetupFallbackBranch({
    required this.dartIndex,
    required this.triggerLabel,
    required this.missLabel,
    required this.remainingScore,
    required this.child,
  });

  final int dartIndex;
  final String triggerLabel;
  final String missLabel;
  final int remainingScore;
  final _SetupFallbackNode child;
}

enum _SetupFinishBand { deep, medium, justFinish }

class _MissScenario {
  const _MissScenario({
    required this.dartIndex,
    required this.targetLabel,
    required this.label,
    required this.outcome,
    required this.state,
  });

  final int dartIndex;
  final String targetLabel;
  final String label;
  final String outcome;
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

class _SetupBandCard extends StatefulWidget {
  const _SetupBandCard({
    required this.band,
    required this.presentation,
    required this.resolveFallbackTree,
  });

  final _SetupFinishBand band;
  final _SetupLeavePresentation? presentation;
  final _SetupFallbackNode Function(_SetupLeavePresentation presentation)
      resolveFallbackTree;

  @override
  State<_SetupBandCard> createState() => _SetupBandCardState();
}

class _SetupBandCardState extends State<_SetupBandCard> {
  bool _showFallbackTree = false;

  String get _title {
    switch (widget.band) {
      case _SetupFinishBand.deep:
        return 'Tiefes Finish';
      case _SetupFinishBand.medium:
        return 'Mittleres Finish';
      case _SetupFinishBand.justFinish:
        return 'Geradeso Finish';
    }
  }

  String get _subtitle {
    switch (widget.band) {
      case _SetupFinishBand.deep:
        return 'Rest bis 79';
      case _SetupFinishBand.medium:
        return 'Rest 100 bis 130';
      case _SetupFinishBand.justFinish:
        return 'Rest 160 bis 170';
    }
  }

  @override
  Widget build(BuildContext context) {
    final option = widget.presentation?.option;
    final fallbackTree =
        widget.presentation == null
            ? null
            : (widget.presentation!.fallbackTree ??
                widget.resolveFallbackTree(widget.presentation!));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E8EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF17324D),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF556372),
                ),
          ),
          const SizedBox(height: 10),
          if (widget.presentation == null)
            Text(
              'Kein passender Stellweg',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF556372),
                  ),
            )
          else ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: const Color(0xFF17324D),
                      height: 1.45,
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Stellt ${option!.remainingScore} Rest',
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
                    const SizedBox(height: 10),
                    _SetupFallbackTreeView(
                      node: fallbackTree!,
                      isRoot: true,
                      showBranches: false,
                    ),
                    if (widget.band == _SetupFinishBand.deep) ...<Widget>[
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            'Fallback-Wege',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: const Color(0xFF0E5A52),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          onExpansionChanged: (expanded) {
                            setState(() {
                              _showFallbackTree = expanded;
                            });
                          },
                          children: _showFallbackTree
                              ? <Widget>[
                                  const SizedBox(height: 6),
                                  _SetupFallbackTreeView(
                                    node: fallbackTree!,
                                    isRoot: true,
                                  ),
                                ]
                              : const <Widget>[],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupFallbackTreeView extends StatelessWidget {
  const _SetupFallbackTreeView({
    required this.node,
    this.isRoot = false,
    this.showBranches = true,
  });

  final _SetupFallbackNode node;
  final bool isRoot;
  final bool showBranches;

  @override
  Widget build(BuildContext context) {
    final routeLabels = node.route.map((entry) => entry.label).join(' | ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRoot ? const Color(0xFFE3F1EC) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRoot ? const Color(0xFFB8D6CB) : const Color(0xFFE3E8EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isRoot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0E5A52),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Originaler Stellweg',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            )
          else
            Text(
              'Fallback-Weg',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF17324D),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          const SizedBox(height: 8),
          Text(
            routeLabels,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF17324D),
                  fontWeight: FontWeight.w900,
                ),
          ),
          if (showBranches && node.branches.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...node.branches.map(
              (branch) => Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(left: 12, top: 4),
                  title: Text(
                    'Dart ${branch.dartIndex}: ${branch.triggerLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF17324D),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  subtitle: Text(
                    '${branch.missLabel} -> ${branch.remainingScore} Rest',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                        ),
                  ),
                  children: <Widget>[
                    _SetupFallbackTreeView(node: branch.child),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteHeader extends StatelessWidget {
  const _RouteHeader({
    required this.labels,
    required this.score,
    required this.scoreLabel,
  });

  final String labels;
  final int score;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final scoreBox = _ScoreRatingBox(
          label: scoreLabel,
          score: score,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                labels,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              scoreBox,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                labels,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            scoreBox,
          ],
        );
      },
    );
  }
}

class _ScoreRatingBox extends StatelessWidget {
  const _ScoreRatingBox({
    required this.label,
    required this.score,
  });

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB8D6CB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF556372),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            '$score',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF0E5A52),
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _TripleSingleFallbackPanel extends StatelessWidget {
  const _TripleSingleFallbackPanel({
    required this.scenarios,
  });

  final List<_MissScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    final tripleSingleScenarios = scenarios
        .where(
          (scenario) =>
              scenario.targetLabel.startsWith('T') &&
              scenario.label.startsWith('Single statt '),
        )
        .toList();

    if (tripleSingleScenarios.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = <int, List<_MissScenario>>{};
    final targets = <int, String>{};
    for (final scenario in tripleSingleScenarios) {
      grouped.putIfAbsent(scenario.dartIndex, () => <_MissScenario>[]).add(scenario);
      targets.putIfAbsent(scenario.dartIndex, () => scenario.targetLabel);
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Single-Fallbacks auf Triple',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF17324D),
              ),
        ),
        children: grouped.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3E8EE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dart ${entry.key}/',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17324D),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '└─ Ziel ${targets[entry.key] ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF556372),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...entry.value.map((scenario) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '└─ ',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF556372),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _backgroundForScenario(scenario.state),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    '${scenario.label}/',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF17324D),
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
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
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: _textForScenario(scenario.state),
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '└─ ${scenario.outcome}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: const Color(0xFF556372),
                                          height: 1.35,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }).toList(),
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

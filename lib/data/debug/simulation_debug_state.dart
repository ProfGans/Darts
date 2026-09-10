import 'package:flutter/foundation.dart';

class SimulationDebugSnapshot {
  const SimulationDebugSnapshot({
    required this.scope,
    required this.phase,
    required this.careerName,
    required this.tournamentName,
    required this.statusLabel,
    required this.lastEvent,
    required this.seasonCompleted,
    required this.seasonTotal,
    required this.matchCompleted,
    required this.matchTotal,
    required this.progress,
    required this.updatedAt,
    required this.phaseStartedAt,
    required this.lastDurationMs,
  });

  final String scope;
  final String phase;
  final String? careerName;
  final String? tournamentName;
  final String? statusLabel;
  final String? lastEvent;
  final int? seasonCompleted;
  final int? seasonTotal;
  final int? matchCompleted;
  final int? matchTotal;
  final double? progress;
  final DateTime? updatedAt;
  final DateTime? phaseStartedAt;
  final int? lastDurationMs;
}

class SimulationDebugState extends ChangeNotifier {
  SimulationDebugState._();

  static final SimulationDebugState instance = SimulationDebugState._();

  String _scope = 'idle';
  String _phase = 'idle';
  String? _careerName;
  String? _tournamentName;
  String? _statusLabel;
  String? _lastEvent;
  int? _seasonCompleted;
  int? _seasonTotal;
  int? _matchCompleted;
  int? _matchTotal;
  double? _progress;
  DateTime? _updatedAt;
  DateTime? _phaseStartedAt;
  int? _lastDurationMs;

  SimulationDebugSnapshot get snapshot => SimulationDebugSnapshot(
        scope: _scope,
        phase: _phase,
        careerName: _careerName,
        tournamentName: _tournamentName,
        statusLabel: _statusLabel,
        lastEvent: _lastEvent,
        seasonCompleted: _seasonCompleted,
        seasonTotal: _seasonTotal,
        matchCompleted: _matchCompleted,
        matchTotal: _matchTotal,
        progress: _progress,
        updatedAt: _updatedAt,
        phaseStartedAt: _phaseStartedAt,
        lastDurationMs: _lastDurationMs,
      );

  void beginSeason({
    required String careerName,
    required int totalTournaments,
  }) {
    _scope = 'season';
    _phase = 'start';
    _careerName = careerName;
    _tournamentName = null;
    _statusLabel = 'Saison-Simulation gestartet';
    _lastEvent = 'Saisonlauf initialisiert';
    _seasonCompleted = 0;
    _seasonTotal = totalTournaments;
    _matchCompleted = null;
    _matchTotal = null;
    _progress = totalTournaments == 0 ? null : 0;
    _touchPhase();
  }

  void updateSeasonStep({
    required int completed,
    required int total,
    required String tournamentName,
    required String phase,
    String? label,
  }) {
    _scope = 'season';
    _phase = phase;
    _tournamentName = tournamentName;
    _seasonCompleted = completed;
    _seasonTotal = total;
    _statusLabel = label;
    _lastEvent = 'Saison $completed/$total | $tournamentName | $phase';
    _progress = total == 0 ? null : (completed / total).clamp(0.0, 1.0);
    _touchPhase();
  }

  void beginTournament({
    required String careerName,
    required String tournamentName,
    required String phase,
    String? label,
  }) {
    _scope = 'tournament';
    _careerName = careerName;
    _tournamentName = tournamentName;
    _phase = phase;
    _statusLabel = label;
    _lastEvent = '$tournamentName | $phase';
    _matchCompleted = null;
    _matchTotal = null;
    _progress = null;
    _touchPhase();
  }

  void updateTournamentProgress({
    required String tournamentName,
    required String phase,
    String? label,
    double? progress,
  }) {
    _scope = 'tournament';
    _tournamentName = tournamentName;
    _phase = phase;
    _statusLabel = label;
    _progress = progress;
    _extractMatchProgress(label);
    _lastEvent = '$tournamentName | $phase';
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  void markCheckpoint(String event, {int? durationMs}) {
    _lastEvent = event;
    _lastDurationMs = durationMs;
    _updatedAt = DateTime.now();
    notifyListeners();
  }

  void clear() {
    _scope = 'idle';
    _phase = 'idle';
    _careerName = null;
    _tournamentName = null;
    _statusLabel = null;
    _lastEvent = null;
    _seasonCompleted = null;
    _seasonTotal = null;
    _matchCompleted = null;
    _matchTotal = null;
    _progress = null;
    _updatedAt = null;
    _phaseStartedAt = null;
    _lastDurationMs = null;
    notifyListeners();
  }

  void _touchPhase() {
    final now = DateTime.now();
    _updatedAt = now;
    _phaseStartedAt = now;
    notifyListeners();
  }

  void _extractMatchProgress(String? label) {
    if (label == null) {
      return;
    }
    final match = RegExp(r'\((\d+)/(\d+)\s+Matches\)').firstMatch(label);
    if (match == null) {
      return;
    }
    _matchCompleted = int.tryParse(match.group(1) ?? '');
    _matchTotal = int.tryParse(match.group(2) ?? '');
  }
}

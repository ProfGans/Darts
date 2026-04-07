import '../../domain/bot/bot_engine.dart';
import '../../domain/x01/x01_match_simulator.dart';
import 'simulation_service.dart';

class SimulationWarmupManager {
  SimulationWarmupManager._();

  static final SimulationWarmupManager instance = SimulationWarmupManager._();

  bool get hasWarmupData => SimulationService.instance.hasWarmupData;
  bool get isWarmupRunning => SimulationService.instance.isWarmupRunning;

  Future<void> initialize() => SimulationService.instance.initialize();

  Future<void> startWarmupIfNeeded() =>
      SimulationService.instance.startWarmupIfNeeded();

  void applyToBotEngine(BotEngine botEngine) {
    SimulationService.instance.applyToBotEngine(botEngine);
  }

  void applyToX01MatchSimulator(X01MatchSimulator simulator) {
    SimulationService.instance.applyToX01MatchSimulator(simulator);
  }
}

import 'dart:async';

import 'background/simulation_service.dart';
import 'repositories/career_repository.dart';
import 'repositories/career_template_repository.dart';
import 'repositories/checkout_route_repository.dart';
import 'repositories/computer_repository.dart';
import 'repositories/player_repository.dart';
import 'repositories/settings_repository.dart';
import 'simulation/theo_resolution_lookup.dart';
import 'repositories/tournament_repository.dart';

class AppBootstrap {
  AppBootstrap._();

  static Future<void> initialize() async {
    await PlayerRepository.instance.initialize();
    await SettingsRepository.instance.initialize();
    await TheoResolutionLookup.initialize();
    await CheckoutRouteRepository.instance.initialize();
    await ComputerRepository.instance.initialize();
    await CareerRepository.instance.initialize();
    await CareerTemplateRepository.instance.initialize();
    await TournamentRepository.instance.initialize();
    await SimulationService.instance.initialize();
    unawaited(TheoResolutionLookup.prewarmCurrentSettingsBucket());
  }
}

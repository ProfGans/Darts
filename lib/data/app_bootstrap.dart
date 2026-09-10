import 'dart:async';

import 'background/simulation_service.dart';
import 'repositories/community_repository.dart';
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
    await Future.wait<void>(<Future<void>>[
      PlayerRepository.instance.initialize(),
      CommunityRepository.instance.initialize(),
      SettingsRepository.instance.initialize(),
      CareerRepository.instance.initialize(),
      CareerTemplateRepository.instance.initialize(),
      SimulationService.instance.initialize(),
    ]);
    await TheoResolutionLookup.initialize();
    await CheckoutRouteRepository.instance.initialize();
    await ComputerRepository.instance.initialize();
    await TournamentRepository.instance.initialize();
    unawaited(TheoResolutionLookup.prewarmCurrentSettingsBucket());
  }
}

import 'package:flutter/material.dart';

import '../presentation/career/career_detail_screen.dart';
import '../presentation/career/career_setup_screen.dart';
import '../presentation/tools/checkout_calculator_screen.dart';
import '../presentation/main_menu/main_menu_screen.dart';
import '../presentation/database/computer_database_screen.dart';
import '../presentation/match/game_mode_selection_screen.dart';
import '../presentation/simulator/bot_match_simulator_screen.dart';
import '../presentation/players/player_profiles_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/tournament/tournament_bracket_screen.dart';
import '../presentation/tournament/tournament_setup_screen.dart';

class AppRoutes {
  static const home = '/';
  static const gameModes = '/match/modes';
  static const checkoutCalculator = '/tools/checkout-calculator';
  static const botSimulator = '/bot-simulator';
  static const playerProfiles = '/players';
  static const computerDatabase = '/database';
  static const settings = '/settings';
  static const tournamentSetup = '/tournament/setup';
  static const tournamentBracket = '/tournament/bracket';
  static const careerSetup = '/career/setup';
  static const careerDetail = '/career/detail';

  static final routes = <String, WidgetBuilder>{
    home: (_) => const MainMenuScreen(),
    gameModes: (_) => const GameModeSelectionScreen(),
    checkoutCalculator: (_) => const CheckoutCalculatorScreen(),
    botSimulator: (_) => const BotMatchSimulatorScreen(),
    playerProfiles: (_) => const PlayerProfilesScreen(),
    computerDatabase: (_) => const ComputerDatabaseScreen(),
    settings: (_) => const SettingsScreen(),
    tournamentSetup: (_) => const TournamentSetupScreen(),
    tournamentBracket: (_) => const TournamentBracketScreen(),
    careerSetup: (_) => const CareerSetupScreen(),
    careerDetail: (_) => const CareerDetailScreen(),
  };
}

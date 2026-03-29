import 'package:flutter_test/flutter_test.dart';

import 'package:dart_flutter_app/data/repositories/computer_repository.dart';
import 'package:dart_flutter_app/data/repositories/settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rebalance current computer players while keeping theoretical averages', () async {
    await SettingsRepository.instance.initialize();
    await ComputerRepository.instance.initialize();
    await ComputerRepository.instance.rebalanceSkillsFromCurrentTheoreticalAverages();

    final importedCount = ComputerRepository.instance.players
        .where((player) => player.source.name == 'imported')
        .length;
    // ignore: avoid_print
    print('rebalanced_players=${ComputerRepository.instance.players.length}');
    // ignore: avoid_print
    print('imported_players=$importedCount');
  });
}

import 'dart:io';

import 'package:dart_flutter_app/data/app_bootstrap.dart';
import 'package:dart_flutter_app/data/import/electron_import_service.dart';

Future<void> main() async {
  await AppBootstrap.initialize();
  final report = await ElectronImportService.instance.importElectronData();
  stdout.writeln(
    'Import abgeschlossen: ${report.computersImported} Computer, '
    '${report.careersImported} Karriere-Vorlagen.',
  );
  if (report.message.isNotEmpty) {
    stdout.writeln(report.message);
  }
}

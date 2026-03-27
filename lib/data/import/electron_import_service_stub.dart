import 'electron_import_service.dart';

class StubElectronImportService implements ElectronImportService {
  @override
  Future<ElectronImportReport> importElectronData({
    bool replaceExisting = false,
    bool importOnlyIfEmpty = false,
  }) async {
    return const ElectronImportReport(
      foundWorkspace: false,
      message: 'Electron-Import ist auf dieser Plattform nicht verfuegbar.',
    );
  }
}

ElectronImportService createElectronImportService() =>
    StubElectronImportService();

import 'electron_import_service_stub.dart'
    if (dart.library.io) 'electron_import_service_io.dart';

class ElectronImportReport {
  const ElectronImportReport({
    this.computersImported = 0,
    this.careersImported = 0,
    this.foundWorkspace = false,
    this.message = '',
  });

  final int computersImported;
  final int careersImported;
  final bool foundWorkspace;
  final String message;

  bool get didImport => computersImported > 0 || careersImported > 0;
}

abstract class ElectronImportService {
  static ElectronImportService get instance => createElectronImportService();

  Future<ElectronImportReport> importElectronData({
    bool replaceExisting = false,
    bool importOnlyIfEmpty = false,
  });
}

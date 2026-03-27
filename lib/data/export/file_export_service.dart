import 'file_export_service_io.dart'
    if (dart.library.html) 'file_export_service_web.dart' as impl;

abstract class FileExportService {
  Future<String?> exportTextFile({
    required String folderName,
    required String fileName,
    required String content,
  });
}

FileExportService createFileExportService() => impl.createFileExportService();

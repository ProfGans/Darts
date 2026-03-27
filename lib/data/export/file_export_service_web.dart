import 'file_export_service.dart';

class WebFileExportService implements FileExportService {
  @override
  Future<String?> exportTextFile({
    required String folderName,
    required String fileName,
    required String content,
  }) async {
    return null;
  }
}

FileExportService createFileExportService() => WebFileExportService();

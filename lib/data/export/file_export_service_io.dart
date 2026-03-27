import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'file_export_service.dart';

class IoFileExportService implements FileExportService {
  Future<Directory> _baseDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final appDirectory =
          Directory('$directory${Platform.pathSeparator}dart_flutter_app');
      if (!appDirectory.existsSync()) {
        appDirectory.createSync(recursive: true);
      }
      return appDirectory;
    }

    final appData = Platform.environment['APPDATA'];
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final separator = Platform.pathSeparator;
    final path = appData != null && appData.isNotEmpty
        ? '$appData${separator}DartFlutterApp'
        : '$home$separator.dart_flutter_app';
    final directory = Directory(path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  @override
  Future<String?> exportTextFile({
    required String folderName,
    required String fileName,
    required String content,
  }) async {
    final baseDirectory = await _baseDirectory();
    final exportDirectory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}$folderName',
    );
    if (!exportDirectory.existsSync()) {
      exportDirectory.createSync(recursive: true);
    }
    final file = File(
      '${exportDirectory.path}${Platform.pathSeparator}$fileName',
    );
    await file.writeAsString(content, flush: true);
    return file.path;
  }
}

FileExportService createFileExportService() => IoFileExportService();

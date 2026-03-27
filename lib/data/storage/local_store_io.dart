// ignore_for_file: unnecessary_brace_in_string_interps

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_store.dart';

class IoLocalStore implements LocalStore {
  Future<Directory> _baseDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final appDirectory =
          Directory('${directory.path}${Platform.pathSeparator}dart_flutter_app');
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
        ? '${appData}${separator}DartFlutterApp'
        : '$home${separator}.dart_flutter_app';
    final directory = Directory(path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  Future<File> _fileFor(String key) async {
    final directory = await _baseDirectory();
    return File('${directory.path}${Platform.pathSeparator}$key.json');
  }

  @override
  Future<void> delete(String key) async {
    final file = await _fileFor(key);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<String?> read(String key) async {
    final file = await _fileFor(key);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) async {
    final file = await _fileFor(key);
    await file.writeAsString(value, flush: true);
  }
}

LocalStore createLocalStore() => IoLocalStore();

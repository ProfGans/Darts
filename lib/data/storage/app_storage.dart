import 'dart:convert';

import 'local_store.dart';

class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();
  final LocalStore _store = createLocalStore();

  Future<Map<String, dynamic>?> readJsonMap(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    return null;
  }

  Future<List<dynamic>?> readJsonList(String key) async {
    final raw = await _store.read(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : null;
  }

  Future<void> writeJson(String key, Object value) async {
    await _store.write(key, jsonEncode(value));
  }

  Future<void> delete(String key) => _store.delete(key);
}

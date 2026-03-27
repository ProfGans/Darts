// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'local_store.dart';

class WebLocalStore implements LocalStore {
  static const _prefix = 'dart_flutter_app.';

  @override
  Future<void> delete(String key) async {
    html.window.localStorage.remove('$_prefix$key');
  }

  @override
  Future<String?> read(String key) async {
    return html.window.localStorage['$_prefix$key'];
  }

  @override
  Future<void> write(String key, String value) async {
    html.window.localStorage['$_prefix$key'] = value;
  }
}

LocalStore createLocalStore() => WebLocalStore();

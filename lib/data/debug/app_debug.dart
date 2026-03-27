import 'package:flutter/foundation.dart';

enum AppDebugLevel {
  info,
  error,
}

class AppDebugEntry {
  const AppDebugEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  final DateTime timestamp;
  final AppDebugLevel level;
  final String source;
  final String message;
}

class AppDebug extends ChangeNotifier {
  AppDebug._();

  static final AppDebug instance = AppDebug._();
  static const int _maxEntries = 300;

  final List<AppDebugEntry> _entries = <AppDebugEntry>[];
  bool _expanded = false;
  bool _notifyScheduled = false;

  List<AppDebugEntry> get entries => List<AppDebugEntry>.unmodifiable(_entries);
  bool get expanded => _expanded;

  void toggleExpanded() {
    _expanded = !_expanded;
    _scheduleNotify();
  }

  void clear() {
    _entries.clear();
    _scheduleNotify();
  }

  void info(String source, String message) {
    _append(
      AppDebugEntry(
        timestamp: DateTime.now(),
        level: AppDebugLevel.info,
        source: source,
        message: message,
      ),
    );
  }

  void error(String source, String message) {
    _append(
      AppDebugEntry(
        timestamp: DateTime.now(),
        level: AppDebugLevel.error,
        source: source,
        message: message,
      ),
    );
  }

  void _append(AppDebugEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    _scheduleNotify();
  }

  void _scheduleNotify() {
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    Future<void>.microtask(() {
      _notifyScheduled = false;
      notifyListeners();
    });
  }
}

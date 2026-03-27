import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

class AppDebugAction {
  AppDebugAction._({
    required AppDebug debug,
    required this.source,
    required this.label,
  })  : _debug = debug,
        _stopwatch = Stopwatch()..start();

  final AppDebug _debug;
  final String source;
  final String label;
  final Stopwatch _stopwatch;
  bool _closed = false;

  void complete([String? message]) {
    if (_closed) {
      return;
    }
    _closed = true;
    _stopwatch.stop();
    final suffix = message == null || message.trim().isEmpty
        ? ''
        : ' - ${message.trim()}';
    _debug.info(
      source,
      '$label abgeschlossen in ${_stopwatch.elapsedMilliseconds} ms$suffix',
    );
  }

  void fail(Object error) {
    if (_closed) {
      return;
    }
    _closed = true;
    _stopwatch.stop();
    _debug.error(
      source,
      '$label fehlgeschlagen nach ${_stopwatch.elapsedMilliseconds} ms: $error',
    );
  }
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

  AppDebugAction startAction(String source, String label) {
    info(source, '$label gestartet');
    return AppDebugAction._(
      debug: this,
      source: source,
      label: label,
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

class AppDebugNavigatorObserver extends NavigatorObserver {
  String _routeName(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    final fallback = route?.runtimeType.toString();
    if (fallback != null && fallback.trim().isNotEmpty) {
      return fallback;
    }
    return 'unknown';
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppDebug.instance.info(
      'Navigation',
      'push ${_routeName(route)} <= ${_routeName(previousRoute)}',
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    AppDebug.instance.info(
      'Navigation',
      'pop ${_routeName(route)} => ${_routeName(previousRoute)}',
    );
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    AppDebug.instance.info(
      'Navigation',
      'replace ${_routeName(oldRoute)} => ${_routeName(newRoute)}',
    );
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

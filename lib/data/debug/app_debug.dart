import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum AppDebugLevel {
  info,
  warning,
  error,
}

class AppDebugEntry {
  const AppDebugEntry({
    required this.sequence,
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
  });

  final int sequence;
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
    required this.id,
  })  : _debug = debug,
        _stopwatch = Stopwatch()..start() {
    _scheduleSlowWarnings();
  }

  final AppDebug _debug;
  final String source;
  final String label;
  final String id;
  final Stopwatch _stopwatch;
  bool _closed = false;
  Timer? _slowWarningTimer;
  Timer? _verySlowWarningTimer;

  int get elapsedMilliseconds => _stopwatch.elapsedMilliseconds;

  void _scheduleSlowWarnings() {
    _slowWarningTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_closed) {
        return;
      }
      _debug.warning(
        source,
        '$label laeuft noch nach ${_stopwatch.elapsedMilliseconds} ms',
      );
    });
    _verySlowWarningTimer = Timer(const Duration(milliseconds: 3500), () {
      if (_closed) {
        return;
      }
      _debug.error(
        source,
        '$label blockiert auffaellig lange (${_stopwatch.elapsedMilliseconds} ms)',
      );
    });
  }

  void complete([String? message]) {
    if (_closed) {
      return;
    }
    _closed = true;
    _slowWarningTimer?.cancel();
    _verySlowWarningTimer?.cancel();
    _stopwatch.stop();
    _debug._unregisterAction(this);
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
    _slowWarningTimer?.cancel();
    _verySlowWarningTimer?.cancel();
    _stopwatch.stop();
    _debug._unregisterAction(this);
    _debug.error(
      source,
      '$label fehlgeschlagen nach ${_stopwatch.elapsedMilliseconds} ms: $error',
    );
  }
}

class AppDebug extends ChangeNotifier {
  AppDebug._();

  static final AppDebug instance = AppDebug._();
  static const int _maxEntries = 200;

  final List<AppDebugEntry> _entries = <AppDebugEntry>[];
  final Map<String, AppDebugAction> _activeActions = <String, AppDebugAction>{};
  int _actionSequence = 0;
  int _entrySequence = 0;
  bool _notifyQueued = false;
  int _lastSlowFrameLogAtEpochMs = -1000;
  int? _lastSlowFrameBuildMilliseconds;
  int? _lastSlowFrameRasterMilliseconds;

  List<AppDebugEntry> get entries => List<AppDebugEntry>.unmodifiable(_entries);
  List<AppDebugAction> get activeActions =>
      List<AppDebugAction>.unmodifiable(_activeActions.values);
  List<String> get activeActionLabels => activeActions
      .map(
        (action) =>
            '${action.source}: ${action.label} (${action.elapsedMilliseconds} ms)',
      )
      .toList(growable: false);

  void clear() {
    _entries.clear();
    _queueNotify();
  }

  void info(String source, String message) {
    _append(
      AppDebugEntry(
        sequence: _entrySequence++,
        timestamp: DateTime.now(),
        level: AppDebugLevel.info,
        source: source,
        message: message,
      ),
    );
  }

  void warning(String source, String message) {
    _append(
      AppDebugEntry(
        sequence: _entrySequence++,
        timestamp: DateTime.now(),
        level: AppDebugLevel.warning,
        source: source,
        message: message,
      ),
    );
  }

  void error(String source, String message) {
    _append(
      AppDebugEntry(
        sequence: _entrySequence++,
        timestamp: DateTime.now(),
        level: AppDebugLevel.error,
        source: source,
        message: message,
      ),
    );
  }

  AppDebugAction startAction(String source, String label) {
    final id = 'action-${_actionSequence++}';
    info(source, '$label gestartet');
    final action = AppDebugAction._(
      debug: this,
      source: source,
      label: label,
      id: id,
    );
    _activeActions[id] = action;
    _queueNotify();
    return action;
  }

  void logSlowFrame({
    required int totalMilliseconds,
    required int buildMilliseconds,
    required int rasterMilliseconds,
  }) {
    final nowEpochMs = DateTime.now().millisecondsSinceEpoch;
    final nearDuplicate = _lastSlowFrameBuildMilliseconds == buildMilliseconds &&
        _lastSlowFrameRasterMilliseconds == rasterMilliseconds &&
        nowEpochMs - _lastSlowFrameLogAtEpochMs < 250;
    final belowNoiseThreshold =
        totalMilliseconds < 55 && buildMilliseconds < 50 && rasterMilliseconds < 8;
    if (nearDuplicate || belowNoiseThreshold) {
      return;
    }
    _lastSlowFrameLogAtEpochMs = nowEpochMs;
    _lastSlowFrameBuildMilliseconds = buildMilliseconds;
    _lastSlowFrameRasterMilliseconds = rasterMilliseconds;
    final activeActionsText = activeActionLabels.isEmpty
        ? 'keine aktive Aktion'
        : activeActionLabels.join(' | ');
    warning(
      'Performance',
      'Langsamer Frame: $totalMilliseconds ms gesamt '
      '(Build $buildMilliseconds ms, Raster $rasterMilliseconds ms) '
      '- aktiv: $activeActionsText',
    );
  }

  void _append(AppDebugEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
    if (_shouldPrintToConsole(entry)) {
      final level = switch (entry.level) {
        AppDebugLevel.info => 'INFO',
        AppDebugLevel.warning => 'WARN',
        AppDebugLevel.error => 'ERROR',
      };
      final timestamp = entry.timestamp.toIso8601String().substring(11, 19);
      debugPrint('[$timestamp] [$level] [${entry.source}] ${entry.message}');
    }
    _queueNotify();
  }

  void _unregisterAction(AppDebugAction action) {
    _activeActions.remove(action.id);
    _queueNotify();
  }

  void _queueNotify() {
    if (_notifyQueued) {
      return;
    }
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      notifyListeners();
    });
  }

  bool _shouldPrintToConsole(AppDebugEntry entry) {
    if (kDebugMode) {
      return true;
    }
    return entry.level != AppDebugLevel.info;
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

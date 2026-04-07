import 'dart:ui';
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/debug/app_debug.dart';
import 'data/app_bootstrap.dart';
import 'data/background/simulation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsBinding.instance.addTimingsCallback((timings) {
    for (final timing in timings) {
      final totalMilliseconds =
          timing.totalSpan.inMilliseconds;
      if (totalMilliseconds < 40) {
        continue;
      }
      AppDebug.instance.logSlowFrame(
        totalMilliseconds: totalMilliseconds,
        buildMilliseconds: timing.buildDuration.inMilliseconds,
        rasterMilliseconds: timing.rasterDuration.inMilliseconds,
      );
    }
  });
  FlutterError.onError = (details) {
    AppDebug.instance.error(
      'Flutter',
      details.exceptionAsString(),
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppDebug.instance.error('Platform', error.toString());
    return false;
  };
  try {
    AppDebug.instance.info('App', 'Bootstrap startet');
    await AppBootstrap.initialize();
    AppDebug.instance.info('App', 'Bootstrap abgeschlossen');
  } catch (error) {
    AppDebug.instance.error('Bootstrap', error.toString());
    rethrow;
  }
  runApp(const DartFlutterApp());
  unawaited(
    SimulationService.instance.startWarmupIfNeeded().catchError((Object error) {
      AppDebug.instance.error('Warmup', error.toString());
    }),
  );
}

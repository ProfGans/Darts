import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/debug/app_debug.dart';
import 'data/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
}

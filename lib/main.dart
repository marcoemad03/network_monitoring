import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'bootstrap.dart';
import 'core/config/environment.dart';
import 'core/utils/logger.dart';

void main() async {
  FlutterError.onError = (details) {
    AppLogger.error(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('Platform error', error: error, stackTrace: stack);
    return true;
  };

  await AppBootstrap.initialize(
    environment: Environment.development,
  );

  await _configureWindow();

  await AppBootstrap.run();
}

Future<void> _configureWindow() async {
  await windowManager.ensureInitialized();
  await windowManager.setTitle('Hospital NMS');
  await windowManager.setMinimumSize(const Size(1024, 680));
  await windowManager.setPreventClose(false);
  await windowManager.show();
  await windowManager.focus();
}

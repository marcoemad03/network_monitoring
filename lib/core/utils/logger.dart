import 'package:logger/logger.dart';
import '../config/build_config.dart';

class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
    level: BuildConfig.enableLogging ? Level.all : Level.warning,
  );

  static void debug(String message, {dynamic data, dynamic error}) {
    if (data != null) {
      _logger.d('$message\nData: $data');
    } else if (error != null) {
      _logger.d('$message\nError: $error');
    } else {
      _logger.d(message);
    }
  }

  static void info(String message, {dynamic data}) {
    if (data != null) {
      _logger.i('$message\nData: $data');
    } else {
      _logger.i(message);
    }
  }

  static void warning(String message, {dynamic data, dynamic error}) {
    if (error != null) {
      _logger.w('$message\nError: $error');
    } else if (data != null) {
      _logger.w('$message\nData: $data');
    } else {
      _logger.w(message);
    }
  }

  static void error(String message, {dynamic error, dynamic stackTrace, dynamic data}) {
    if (error != null && stackTrace != null) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } else if (error != null) {
      _logger.e('$message\nException: $error');
    } else if (data != null) {
      _logger.e('$message\nData: $data');
    } else {
      _logger.e(message);
    }
  }

  static void trace(String message) {
    _logger.t(message);
  }

  static void fatal(String message, {dynamic error, dynamic stackTrace}) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

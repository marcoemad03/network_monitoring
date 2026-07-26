import 'app_config.dart';
import 'environment.dart';

class BuildConfig {
  static late final AppConfig config;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static void initialize({Environment? environment}) {
    if (_initialized) return;
    config = switch (environment) {
      Environment.staging => AppConfig.staging(),
      Environment.production => AppConfig.production(),
      _ => AppConfig.development(),
    };
    _initialized = true;
  }

  static String get apiBaseUrl => config.apiBaseUrl;
  static String get wsBaseUrl => config.wsBaseUrl;
  static String get appName => config.appName;
  static bool get enableLogging => config.enableLogging;
  static Environment get environment => config.environment;
}

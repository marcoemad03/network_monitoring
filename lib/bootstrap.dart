import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/config/build_config.dart';
import 'core/config/environment.dart';
import 'core/di/injection_container.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/utils/logger.dart';
import 'presentation/router/app_router.dart';

class AppBootstrap {
  static Future<void> initialize({
    Environment? environment,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    BuildConfig.initialize(environment: environment);

    AppLogger.info(
      'Starting ${BuildConfig.appName} in ${BuildConfig.environment.name} mode',
    );
  }

  static Future<void> run() async {
    final prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: Builder(
          builder: (context) {
            return _ProvidersInitializer(child: const _AppInitializer());
          },
        ),
      ),
    );
  }
}

class _ProvidersInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const _ProvidersInitializer({required this.child});

  @override
  ConsumerState<_ProvidersInitializer> createState() =>
      _ProvidersInitializerState();
}

class _ProvidersInitializerState
    extends ConsumerState<_ProvidersInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    await Future.wait([
      ref.read(themeProvider.notifier).loadPreference(),
      ref.read(localeProvider.notifier).loadPreference(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AppInitializer extends StatelessWidget {
  const _AppInitializer();

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();
    return NMSApp(appRouter: appRouter);
  }
}

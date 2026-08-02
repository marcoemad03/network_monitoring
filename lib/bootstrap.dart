import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'core/config/backend_config.dart';
import 'core/config/build_config.dart';
import 'core/config/environment.dart';
import 'core/di/injection_container.dart';
import 'core/services/backend_manager.dart';
import 'core/services/marco_state_service.dart';
import 'core/theme/theme_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/utils/logger.dart';
import 'presentation/router/app_router.dart';
import 'presentation/providers/device/device_provider.dart';

enum _StartupStage { loadingConfig, startingBackend, waitingForHealth, backendReady, routesRegistered, databaseConnected, failed, completed }

class AppBootstrap {
  static Future<void> initialize({
    Environment? environment,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    BuildConfig.initialize(environment: environment);

    try {
      final backendConfig = await BackendConfig.load();
      BackendConfig.instance = backendConfig;
      AppLogger.info('Backend config loaded', data: {
        'host': backendConfig.host,
        'port': backendConfig.port,
        'url': backendConfig.baseUrl,
      });
    } catch (e, _) {
      AppLogger.warning('Failed to load backend config, using defaults', error: e);
    }

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
          marcoStateServiceProvider.overrideWith(
            (ref) => MarcoStateService(prefs),
          ),
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

class _AppInitializer extends ConsumerStatefulWidget {
  const _AppInitializer();

  @override
  ConsumerState<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<_AppInitializer> {
  BackendManager? _manager;
  bool _startupComplete = false;
  _StartupStage _stage = _StartupStage.loadingConfig;
  String _message = 'Initializing...';
  String? _errorReason;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();
    _startBackend();
  }

  Future<void> _startBackend() async {
    try {
      _setStage(_StartupStage.loadingConfig, 'Loading configuration...');

      final config = BackendConfig.instance;
      if (config == null) {
        _fail('Backend Configuration Not Found', 'Configuration file could not be loaded.');
        return;
      }

      _manager = BackendManager(config);

      _setStage(_StartupStage.startingBackend, 'Starting backend...');
      AppLogger.info('Backend Starting...');
      AppLogger.info('Listening on ${config.host}:${config.port}');

      final started = await _manager!.ensureBackendRunning();
      if (!started && config.autoStartBackend) {
        final health = await _manager!.checkHealth();
        if (!health.isOk && !health.isDegraded) {
          _fail(
            health.errorReason ?? 'Backend Not Reachable',
            health.errorDetail ?? 'The backend could not be started and is not reachable.',
          );
          return;
        }
      }

      _setStage(_StartupStage.backendReady, 'Backend ready');
      AppLogger.info('Backend Ready');

      _setStage(_StartupStage.waitingForHealth, 'Verifying connectivity...');
      final health = await _manager!.checkHealth();
      if (!health.isOk && !health.isDegraded) {
        _fail(
          health.errorReason ?? 'Health Check Failed',
          health.errorDetail ?? 'The /health endpoint did not respond successfully.',
        );
        return;
      }

      _setStage(_StartupStage.databaseConnected, 'Database connected');
      AppLogger.info('Database Connected');

      _setStage(_StartupStage.routesRegistered, 'Routes registered');
      AppLogger.info('Routes Registered');

      _manager!.startPeriodicHealthChecks();

      AppLogger.info('Backend startup complete', data: {
        'status': health.status.name,
        'database': health.database,
        'version': health.version,
      });

      if (mounted) {
        setState(() {
          _stage = _StartupStage.completed;
          _startupComplete = true;
        });
      }
    } catch (e, stack) {
      AppLogger.error('Startup failed', error: e, stackTrace: stack);
      _fail('Unexpected Error', '$e');
    }
  }

  void _setStage(_StartupStage stage, String message) {
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _message = message;
    });
  }

  void _fail(String reason, String detail) {
    if (!mounted) return;
    AppLogger.error('Startup failed: $reason', data: {'detail': detail});
    setState(() {
      _stage = _StartupStage.failed;
      _errorReason = reason;
      _errorDetail = detail;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_startupComplete) {
      return NMSApp(appRouter: AppRouter());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1565C0),
        brightness: Brightness.dark,
      ),
      home: Builder(
        builder: (context) {
          final theme = Theme.of(context);

          return Scaffold(
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _stage == _StartupStage.failed
                              ? theme.colorScheme.error.withValues(alpha: 0.1)
                              : theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          _stage == _StartupStage.failed ? Icons.error_outline : Icons.network_check,
                          size: 44,
                          color: _stage == _StartupStage.failed ? theme.colorScheme.error : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Hospital NMS', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Network Management System',
                          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 48),
                      if (_stage == _StartupStage.failed) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.error, color: theme.colorScheme.error, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _errorReason ?? 'Startup Failed',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (_errorDetail != null) ...[
                                const SizedBox(height: 12),
                                SelectableText(
                                  _errorDetail!,
                                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _startBackend,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
                        const SizedBox(height: 24),
                        Text(_message,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 24),
                        _buildProgress(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress() {
    const items = [
      (0, 'Config Loaded'),
      (1, 'Backend Start'),
      (2, 'Backend Ready'),
      (3, 'Database'),
      (4, 'Routes'),
    ];
    return Column(
      children: items.map((i) {
        final done = _stage.index >= i.$1;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle : Icons.circle_outlined, size: 16, color: done ? Colors.green : Colors.grey),
              const SizedBox(width: 8),
              Text(i.$2, style: TextStyle(fontSize: 13, color: done ? Colors.green : Colors.grey)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

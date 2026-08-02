import 'dart:io';
import '../config/backend_config.dart';
import '../network/health_check_service.dart';
import '../utils/logger.dart';

class BackendManager {
  final BackendConfig config;
  final HealthCheckService healthCheckService;
  Process? _backendProcess;
  bool _isStarting = false;

  BackendManager(this.config)
      : healthCheckService = HealthCheckService(config);

  bool get isRunning => _backendProcess != null && _backendProcess!.pid > 0;
  bool get isStarting => _isStarting;

  Future<HealthStatus> checkHealth() => healthCheckService.check();

  Future<bool> ensureBackendRunning() async {
    if (_backendProcess != null && isRunning) return true;

    if (!config.autoStartBackend) {
      AppLogger.warning('Backend auto-start is disabled');
      return false;
    }

    // Check if already running by trying a health check
    final health = await healthCheckService.check();
    if (health.isOk || health.isDegraded) {
      AppLogger.info('Backend is already running', data: {'status': health.status.name});
      return true;
    }

    return _startBackend();
  }

  Future<bool> _startBackend() async {
    if (_isStarting) return false;
    _isStarting = true;

    try {
      AppLogger.info('Starting backend process', data: {
        'path': config.backendExecutablePath,
        'workingDir': config.backendWorkingDirectory,
      });

      final workingDir = Directory(config.backendWorkingDirectory);
      if (!await workingDir.exists()) {
        AppLogger.error('Backend working directory not found', error: config.backendWorkingDirectory);
        _isStarting = false;
        return false;
      }

      _backendProcess = await Process.start(
        config.backendExecutablePath,
        [
          '-port',
          config.port.toString(),
        ],
        workingDirectory: workingDir.path,
        runInShell: false,
      );

      _backendProcess!.stdout.listen((data) {
        AppLogger.info('Backend stdout: ${String.fromCharCodes(data)}');
      });

      _backendProcess!.stderr.listen((data) {
        AppLogger.error('Backend stderr: ${String.fromCharCodes(data)}');
      });

      _backendProcess!.exitCode.then((code) {
        AppLogger.warning('Backend process exited', data: {'exitCode': code});
        _backendProcess = null;
      });

      // Wait for the backend to become healthy
      for (var attempt = 0; attempt < 30; attempt++) {
        await Future.delayed(const Duration(seconds: 1));
        final health = await healthCheckService.check();
        if (health.isOk || health.isDegraded) {
          AppLogger.info('Backend started successfully', data: {'attempts': attempt + 1});
          _isStarting = false;
          return true;
        }
        AppLogger.debug('Waiting for backend...', data: {'attempt': attempt + 1});
      }

      AppLogger.error('Backend failed to start within 30 seconds');
      _isStarting = false;
      return false;
    } catch (e, stack) {
      AppLogger.error('Failed to start backend', error: e, stackTrace: stack);
      _isStarting = false;
      return false;
    }
  }

  Future<void> stopBackend() async {
    if (_backendProcess != null) {
      _backendProcess!.kill();
      await _backendProcess!.exitCode;
      _backendProcess = null;
      AppLogger.info('Backend process stopped');
    }
    healthCheckService.stop();
  }

  void startPeriodicHealthChecks() {
    healthCheckService.startPeriodicChecks();
  }

  void dispose() {
    healthCheckService.stop();
    if (_backendProcess != null) {
      _backendProcess!.kill();
      _backendProcess = null;
    }
  }
}
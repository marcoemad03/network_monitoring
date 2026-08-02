import 'dart:async';
import 'package:dio/dio.dart';
import '../config/backend_config.dart';
import '../utils/logger.dart';

enum BackendStatus {
  unknown,
  connected,
  degraded,
  disconnected,
}

class HealthStatus {
  final BackendStatus status;
  final String? server;
  final String? database;
  final String? mikrotik;
  final String? routerIP;
  final String? version;
  final String? uptime;
  final int? responseTimeMs;
  final DateTime lastChecked;
  final String? errorReason;
  final String? errorDetail;

  const HealthStatus({
    this.status = BackendStatus.unknown,
    this.server,
    this.database,
    this.mikrotik,
    this.routerIP,
    this.version,
    this.uptime,
    this.responseTimeMs,
    required this.lastChecked,
    this.errorReason,
    this.errorDetail,
  });

  bool get isOk => status == BackendStatus.connected;
  bool get isDegraded => status == BackendStatus.degraded;
  bool get isDisconnected => status == BackendStatus.disconnected;

  factory HealthStatus.ok({
    String? server,
    String? database,
    String? mikrotik,
    String? routerIP,
    String? version,
    String? uptime,
    int? responseTimeMs,
  }) {
    return HealthStatus(
      status: BackendStatus.connected,
      server: server,
      database: database,
      mikrotik: mikrotik,
      routerIP: routerIP,
      version: version,
      uptime: uptime,
      responseTimeMs: responseTimeMs,
      lastChecked: DateTime.now(),
    );
  }

  factory HealthStatus.error(String reason, {String? detail, int? responseTimeMs}) {
    return HealthStatus(
      status: BackendStatus.disconnected,
      errorReason: reason,
      errorDetail: detail,
      responseTimeMs: responseTimeMs,
      lastChecked: DateTime.now(),
    );
  }

  factory HealthStatus.degraded(String database, {String? mikrotik, String? version, String? uptime, int? responseTimeMs}) {
    return HealthStatus(
      status: BackendStatus.degraded,
      database: database,
      mikrotik: mikrotik,
      version: version,
      uptime: uptime,
      responseTimeMs: responseTimeMs,
      lastChecked: DateTime.now(),
    );
  }
}

class HealthCheckService {
  final BackendConfig _config;
  final Dio _dio;
  Timer? _timer;
  HealthStatus _lastStatus = HealthStatus(lastChecked: DateTime.now());
  StreamController<HealthStatus> _statusController = StreamController<HealthStatus>.broadcast();

  HealthCheckService(this._config)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _config.apiBaseUrl,
            connectTimeout: Duration(milliseconds: _config.healthCheckTimeoutMs),
            receiveTimeout: Duration(milliseconds: _config.healthCheckTimeoutMs),
          ),
        );

  HealthStatus get lastStatus => _lastStatus;
  Stream<HealthStatus> get statusStream => _statusController.stream;

  Future<HealthStatus> check() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get('/api/v1/health');
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final apiStatus = data['status'] as String? ?? 'ok';
        final database = data['database'] as String? ?? 'unknown';
        final mikrotik = data['mikrotik'] as String?;
        final routerIP = data['router'] as String?;
        final version = data['version'] as String?;
        final uptime = data['uptime'] as String?;

        if (apiStatus == 'degraded') {
          _lastStatus = HealthStatus.degraded(
            database,
            mikrotik: mikrotik,
            version: version,
            uptime: uptime,
            responseTimeMs: stopwatch.elapsedMilliseconds,
          );
        } else {
          _lastStatus = HealthStatus.ok(
            server: 'running',
            database: database,
            mikrotik: mikrotik,
            routerIP: routerIP,
            version: version,
            uptime: uptime,
            responseTimeMs: stopwatch.elapsedMilliseconds,
          );
        }
      } else {
        stopwatch.stop();
        _lastStatus = HealthStatus.error(
          'Invalid Backend URL',
          detail: 'Unexpected status code: ${response.statusCode}',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
    } on DioException catch (e) {
      stopwatch.stop();
      _lastStatus = HealthStatus.error(
        _classifyDioError(e),
        detail: '${e.type}: ${e.message}',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e, stack) {
      stopwatch.stop();
      AppLogger.error('Health check failed', error: e, stackTrace: stack);
      _lastStatus = HealthStatus.error(
        e.toString(),
        detail: stack.toString(),
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    _statusController.add(_lastStatus);
    AppLogger.info('Health check completed', data: {
      'status': _lastStatus.status.name,
      if (_lastStatus.errorReason != null) 'reason': _lastStatus.errorReason,
      'responseTimeMs': _lastStatus.responseTimeMs,
    });
    return _lastStatus;
  }

  String _classifyDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Timeout';
      case DioExceptionType.connectionError:
        final message = e.message ?? '';
        if (message.contains('Connection refused')) {
          return 'Backend Process Not Running';
        }
        if (message.contains('No address associated')) {
          return 'Invalid Backend URL';
        }
        if (message.contains('Failed host lookup')) {
          return 'Invalid Backend URL';
        }
        return 'Firewall Blocking Connection';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 503) {
          return 'Backend Process Not Running';
        }
        return 'Invalid Backend URL';
      case DioExceptionType.cancel:
        return 'Request was cancelled';
      case DioExceptionType.badCertificate:
        return 'Bad SSL certificate';
      default:
        return 'Unknown connection error';
    }
  }

  void startPeriodicChecks() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: _config.healthCheckIntervalSeconds),
      (_) => check(),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _statusController.close();
  }
}

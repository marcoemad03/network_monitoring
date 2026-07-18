import 'package:dio/dio.dart';
import '../config/build_config.dart';
import '../utils/logger.dart';
import '../security/jwt_manager.dart';

class AuthInterceptor extends Interceptor {
  final JwtManager _jwtManager;

  AuthInterceptor(this._jwtManager);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _jwtManager.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers['X-Correlation-ID'] = _generateCorrelationId();
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final refreshed = await _jwtManager.refreshToken();
      if (refreshed) {
        final token = await _jwtManager.getAccessToken();
        final retryOptions = err.requestOptions;
        retryOptions.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await Dio().fetch(retryOptions);
          handler.resolve(response);
          return;
        } catch (_) {}
      }
    }
    handler.next(err);
  }

  String _generateCorrelationId() =>
      '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => chars[DateTime.now().microsecond % chars.length],
    ).join();
  }
}

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (BuildConfig.enableLogging) {
      AppLogger.debug(
        '${options.method} ${options.path}',
        data: {
          'headers': options.headers,
          'queryParams': options.queryParameters,
          'body': options.data,
        },
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (BuildConfig.enableLogging) {
      AppLogger.debug(
        '${response.statusCode} ${response.requestOptions.path}',
        data: {'body': response.data},
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.error(
      '${err.response?.statusCode} ${err.requestOptions.path}',
      error: err,
      data: {'response': err.response?.data},
    );
    handler.next(err);
  }
}

class RetryInterceptor extends Interceptor {
  final int maxRetries;

  RetryInterceptor({this.maxRetries = 3});

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err) && _getRetryCount(err) < maxRetries) {
      final retryCount = _getRetryCount(err) + 1;
      final options = err.requestOptions;
      options.extra['retryCount'] = retryCount;
      await Future.delayed(Duration(seconds: retryCount * 2));
      try {
        final response = await Dio().fetch(options);
        handler.resolve(response);
        return;
      } catch (_) {}
    }
    handler.next(err);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.type == DioExceptionType.badResponse &&
            err.response?.statusCode != null &&
            err.response!.statusCode! >= 500);
  }

  int _getRetryCount(DioException err) {
    return err.requestOptions.extra['retryCount'] as int? ?? 0;
  }
}

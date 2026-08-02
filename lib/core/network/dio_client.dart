import 'package:dio/dio.dart';
import '../config/backend_config.dart';
import '../config/build_config.dart';
import '../constants/api_constants.dart';
import 'api_interceptors.dart';
import '../security/jwt_manager.dart';

class DioClient {
  late final Dio _dio;

  DioClient({required JwtManager jwtManager}) {
    _dio = _createDio(jwtManager);
  }

  Dio _createDio(JwtManager jwtManager) {
    final baseUrl = BackendConfig.instance?.apiBaseUrl ?? BuildConfig.apiBaseUrl;
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: Duration(
          milliseconds: BackendConfig.instance?.connectionTimeoutMs ?? BuildConfig.config.connectTimeoutMs,
        ),
        receiveTimeout: Duration(
          milliseconds: BackendConfig.instance?.receiveTimeoutMs ?? BuildConfig.config.receiveTimeoutMs,
        ),
        sendTimeout: Duration(
          milliseconds: BackendConfig.instance?.receiveTimeoutMs ?? BuildConfig.config.sendTimeoutMs,
        ),
        headers: {
          ApiConstants.acceptHeader: ApiConstants.applicationJson,
          ApiConstants.contentTypeHeader: ApiConstants.applicationJson,
        },
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(jwtManager),
      LoggingInterceptor(),
      RetryInterceptor(maxRetries: BuildConfig.config.maxRetries),
    ]);

    return dio;
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

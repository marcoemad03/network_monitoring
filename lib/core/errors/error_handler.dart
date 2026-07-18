import 'package:dio/dio.dart';
import 'failures.dart';
import 'exceptions.dart';

class ErrorHandler {
  static Failure handleException(dynamic error) {
    if (error is Failure) return error;

    if (error is DioException) return _handleDioError(error);

    if (error is ServerException) {
      return ServerFailure(
        message: error.message,
        statusCode: error.statusCode,
        code: error.code,
      );
    }

    if (error is NetworkException) {
      return NetworkFailure(message: error.message);
    }

    if (error is TimeoutException) {
      return TimeoutFailure(message: error.message);
    }

    if (error is AuthException) {
      return AuthFailure(message: error.message, statusCode: error.statusCode);
    }

    if (error is CacheException) {
      return CacheFailure(message: error.message);
    }

    return UnknownFailure(message: error.toString());
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutFailure();

      case DioExceptionType.connectionError:
        return NetworkFailure();

      case DioExceptionType.badResponse:
        return _handleStatusCode(error.response);

      case DioExceptionType.cancel:
        return const NetworkFailure(message: 'Request was cancelled');

      case DioExceptionType.badCertificate:
        return const ServerFailure(
          message: 'Bad SSL certificate',
          code: 'SSL_ERROR',
        );

      default:
        return UnknownFailure(message: error.message ?? 'Unknown error');
    }
  }

  static Failure _handleStatusCode(Response? response) {
    if (response == null) {
      return const ServerFailure(message: 'No response from server');
    }

    final statusCode = response.statusCode;
    if (statusCode == null) {
      return const ServerFailure(message: 'No status code in response');
    }

    final data = response.data;
    final message = data is Map ? data['message'] as String? : null;

    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: message ?? 'Bad request',
          statusCode: statusCode,
          errors: data is Map ? _parseValidationErrors(data) : null,
        );
      case 401:
        return AuthFailure(
          message: message ?? 'Unauthorized',
          statusCode: statusCode,
        );
      case 403:
        return UnauthorizedFailure(
          message: message ?? 'Forbidden',
          statusCode: statusCode,
        );
      case 404:
        return NotFoundFailure(
          message: message ?? 'Not found',
          statusCode: statusCode,
        );
      case 422:
        return ValidationFailure(
          message: message ?? 'Validation failed',
          statusCode: statusCode,
          errors: data is Map ? _parseValidationErrors(data) : null,
        );
      case 429:
        return const ServerFailure(
          message: 'Too many requests',
          statusCode: 429,
          code: 'RATE_LIMIT',
        );
      case >= 500:
        return ServerFailure(
          message: message ?? 'Internal server error',
          statusCode: statusCode,
          code: 'SERVER_ERROR',
        );
      default:
        return ServerFailure(
          message: message ?? 'Unexpected error',
          statusCode: statusCode,
        );
    }
  }

  static Map<String, List<String>>? _parseValidationErrors(Map data) {
    if (data['errors'] is Map) {
      return (data['errors'] as Map).map(
        (key, value) => MapEntry(
          key.toString(),
          value is List ? value.cast<String>() : [value.toString()],
        ),
      );
    }
    return null;
  }
}

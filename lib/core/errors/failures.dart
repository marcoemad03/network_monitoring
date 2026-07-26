import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;
  final String? code;

  const Failure({required this.message, this.statusCode, this.code});

  @override
  List<Object?> get props => [message, statusCode, code];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Hospital NMS server is unreachable on the local network',
    super.code = 'LOCAL_SERVER_UNREACHABLE',
  });
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({
    super.message = 'Request timed out',
    super.code = 'TIMEOUT',
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed',
    super.statusCode = 401,
    super.code = 'AUTH_ERROR',
  });
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Unauthorized access',
    super.statusCode = 403,
    super.code = 'UNAUTHORIZED',
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found',
    super.statusCode = 404,
    super.code = 'NOT_FOUND',
  });
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;

  const ValidationFailure({
    super.message = 'Validation failed',
    super.statusCode = 422,
    super.code = 'VALIDATION_ERROR',
    this.errors,
  });

  @override
  List<Object?> get props => [...super.props, errors];
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Cache error',
    super.code = 'CACHE_ERROR',
  });
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message, super.code = 'DB_ERROR'});
}

class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred',
    super.code = 'UNKNOWN',
  });
}

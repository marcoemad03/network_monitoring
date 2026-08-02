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
  final String? reasonCode;
  final String? reasonDescription;

  const NetworkFailure({
    super.message = 'Hospital NMS server is unreachable on the local network',
    super.code = 'LOCAL_SERVER_UNREACHABLE',
    this.reasonCode,
    this.reasonDescription,
  });

  factory NetworkFailure.backendNotRunning() => const NetworkFailure(
    message: 'Backend process is not running. Start the backend server first.',
    code: 'BACKEND_NOT_RUNNING',
    reasonCode: 'BACKEND_PROCESS_NOT_RUNNING',
    reasonDescription: 'The Go backend process is not running on the configured host and port.',
  );

  factory NetworkFailure.portInUse() => const NetworkFailure(
    message: 'The backend port is already in use by another process.',
    code: 'PORT_IN_USE',
    reasonCode: 'PORT_ALREADY_IN_USE',
    reasonDescription: 'Another process is already listening on the backend port.',
  );

  factory NetworkFailure.databaseConnectionFailed() => const NetworkFailure(
    message: 'Database connection failed. Check if PostgreSQL is running.',
    code: 'DB_CONNECTION_FAILED',
    reasonCode: 'DATABASE_CONNECTION_FAILED',
    reasonDescription: 'The backend cannot connect to the PostgreSQL database.',
  );

  factory NetworkFailure.mikrotikAuthFailed() => const NetworkFailure(
    message: 'MikroTik authentication failed. Check router credentials.',
    code: 'MIKROTIK_AUTH_FAILED',
    reasonCode: 'MIKROTIK_AUTHENTICATION_FAILED',
    reasonDescription: 'The MikroTik router rejected the provided credentials.',
  );

  factory NetworkFailure.mikrotikApiDisabled() => const NetworkFailure(
    message: 'MikroTik API is disabled on the router. Enable the API service.',
    code: 'MIKROTIK_API_DISABLED',
    reasonCode: 'MIKROTIK_API_DISABLED',
    reasonDescription: 'The MikroTik API service is disabled or the API port is blocked.',
  );

  factory NetworkFailure.routerUnreachable() => const NetworkFailure(
    message: 'The router is unreachable. Check network connectivity.',
    code: 'ROUTER_UNREACHABLE',
    reasonCode: 'ROUTER_UNREACHABLE',
    reasonDescription: 'The router IP address is not reachable from the backend.',
  );

  factory NetworkFailure.firewallBlocking() => const NetworkFailure(
    message: 'A firewall is blocking the connection to the backend.',
    code: 'FIREWALL_BLOCKING',
    reasonCode: 'FIREWALL_BLOCKING_CONNECTION',
    reasonDescription: 'A firewall or security group is blocking the connection to the backend.',
  );

  factory NetworkFailure.invalidBackendUrl() => const NetworkFailure(
    message: 'Invalid backend URL. Check the backend configuration.',
    code: 'INVALID_BACKEND_URL',
    reasonCode: 'INVALID_BACKEND_URL',
    reasonDescription: 'The configured backend URL is invalid or cannot be resolved.',
  );

  factory NetworkFailure.timeout() => const NetworkFailure(
    message: 'Connection to the backend timed out.',
    code: 'TIMEOUT',
    reasonCode: 'TIMEOUT',
    reasonDescription: 'The backend did not respond within the configured timeout period.',
  );

  factory NetworkFailure.cancelled() => const NetworkFailure(
    message: 'Request was cancelled.',
    code: 'CANCELLED',
    reasonCode: 'REQUEST_CANCELLED',
    reasonDescription: 'The network request was cancelled.',
  );
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

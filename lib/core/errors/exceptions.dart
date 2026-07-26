class ServerException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, List<String>>? errors;

  const ServerException({
    required this.message,
    this.statusCode,
    this.code,
    this.errors,
  });
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([
    this.message = 'Hospital NMS server is unreachable on the local network',
  ]);
}

class TimeoutException implements Exception {
  final String message;
  const TimeoutException([this.message = 'Request timed out']);
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  const AuthException(this.message, {this.statusCode});
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache error']);
}

class SerializationException implements Exception {
  final String message;
  const SerializationException(this.message);
}

class WebSocketException implements Exception {
  final String message;
  final int? code;
  const WebSocketException(this.message, {this.code});
}

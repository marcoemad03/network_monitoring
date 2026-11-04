import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'project_paths.dart';

class BackendConfig {
  static BackendConfig? instance;

  final String host;
  final int port;
  final bool useTls;
  final bool autoStartBackend;
  final String backendExecutablePath;
  final String backendWorkingDirectory;
  final int healthCheckIntervalSeconds;
  final int healthCheckTimeoutMs;
  final int connectionTimeoutMs;
  final int receiveTimeoutMs;

  /// Lets another PC use the server on the main PC. Empty on the main PC itself.
  final String accessKey;

  const BackendConfig({
    required this.host,
    required this.port,
    required this.useTls,
    required this.autoStartBackend,
    required this.backendExecutablePath,
    required this.backendWorkingDirectory,
    required this.healthCheckIntervalSeconds,
    required this.healthCheckTimeoutMs,
    required this.connectionTimeoutMs,
    required this.receiveTimeoutMs,
    this.accessKey = '',
  });

  String get baseUrl => '${useTls ? "https" : "http"}://$host:$port';
  String get apiBaseUrl => '$baseUrl';
  String get wsBaseUrl => '${useTls ? "wss" : "ws"}://$host:$port';
  String get healthUrl => '$baseUrl/api/v1/health';

  String get resolvedBackendExecutablePath =>
      _isAbsolutePath(backendExecutablePath)
          ? backendExecutablePath
          : ProjectPaths.resolve(backendExecutablePath);

  String get resolvedBackendWorkingDirectory =>
      _isAbsolutePath(backendWorkingDirectory)
          ? backendWorkingDirectory
          : ProjectPaths.resolve(backendWorkingDirectory);

  static bool _isAbsolutePath(String path) {
    if (path.startsWith('\\\\')) {
      return true;
    }
    if (Platform.isWindows) {
      return path.length >= 3 && path[1] == ':' && path[2] == '\\';
    }
    return path.startsWith('/');
  }

  static Future<BackendConfig> load() async {
    final jsonString = await rootBundle.loadString('assets/config/backend_config.json');
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return BackendConfig.fromJson(json, Platform.environment);
  }

  /// The program for other PCs sets NMS_SERVER_HOST and NMS_SERVER_KEY: the server is
  /// then on the main PC, so this PC must not try to start one.
  factory BackendConfig.fromJson(Map<String, dynamic> json, Map<String, String> env) {
    final remoteHost = env['NMS_SERVER_HOST'] ?? '';
    return BackendConfig(
      host: remoteHost.isNotEmpty ? remoteHost : json['host'] as String? ?? 'localhost',
      accessKey: env['NMS_SERVER_KEY'] ?? '',
      port: json['port'] as int? ?? 8080,
      useTls: json['useTls'] as bool? ?? false,
      autoStartBackend: remoteHost.isEmpty && (json['autoStartBackend'] as bool? ?? true),
      backendExecutablePath: json['backendExecutablePath'] as String? ?? 'backend/server.exe',
      backendWorkingDirectory: json['backendWorkingDirectory'] as String? ?? 'backend',
      healthCheckIntervalSeconds: json['healthCheckIntervalSeconds'] as int? ?? 30,
      healthCheckTimeoutMs: json['healthCheckTimeoutMs'] as int? ?? 5000,
      connectionTimeoutMs: json['connectionTimeoutMs'] as int? ?? 10000,
      receiveTimeoutMs: json['receiveTimeoutMs'] as int? ?? 10000,
    );
  }
}
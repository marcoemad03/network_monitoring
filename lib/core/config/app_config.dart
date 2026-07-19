import 'dart:io';

import 'environment.dart';

class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String appName;
  final String appVersion;
  final bool enableLogging;
  final bool enableAnalytics;
  final int connectTimeoutMs;
  final int receiveTimeoutMs;
  final int sendTimeoutMs;
  final int maxRetries;
  final int tokenRefreshThresholdMin;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.appName,
    required this.appVersion,
    required this.enableLogging,
    required this.enableAnalytics,
    required this.connectTimeoutMs,
    required this.receiveTimeoutMs,
    required this.sendTimeoutMs,
    required this.maxRetries,
    required this.tokenRefreshThresholdMin,
  });

  factory AppConfig.development() {
    String host;
    try {
      host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    } catch (_) {
      host = 'localhost';
    }
    return AppConfig(
      environment: Environment.development,
      apiBaseUrl: 'http://$host:8080',
      wsBaseUrl: 'ws://$host:8080/ws',
      appName: 'NMS Hospital (Dev)',
      appVersion: '1.0.0',
      enableLogging: true,
      enableAnalytics: false,
      connectTimeoutMs: 15000,
      receiveTimeoutMs: 15000,
      sendTimeoutMs: 15000,
      maxRetries: 2,
      tokenRefreshThresholdMin: 5,
    );
  }

  factory AppConfig.staging() => const AppConfig(
        environment: Environment.staging,
        apiBaseUrl: 'https://staging-api.hospital-nms.com/api/v1',
        wsBaseUrl: 'wss://staging-api.hospital-nms.com/ws',
        appName: 'NMS Hospital (Staging)',
        appVersion: '1.0.0',
        enableLogging: true,
        enableAnalytics: true,
        connectTimeoutMs: 10000,
        receiveTimeoutMs: 10000,
        sendTimeoutMs: 10000,
        maxRetries: 3,
        tokenRefreshThresholdMin: 10,
      );

  factory AppConfig.production() => const AppConfig(
        environment: Environment.production,
        apiBaseUrl: 'https://api.hospital-nms.com/api/v1',
        wsBaseUrl: 'wss://api.hospital-nms.com/ws',
        appName: 'NMS Hospital',
        appVersion: '1.0.0',
        enableLogging: false,
        enableAnalytics: true,
        connectTimeoutMs: 10000,
        receiveTimeoutMs: 10000,
        sendTimeoutMs: 10000,
        maxRetries: 3,
        tokenRefreshThresholdMin: 10,
      );
}

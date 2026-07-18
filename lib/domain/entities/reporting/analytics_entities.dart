import 'package:equatable/equatable.dart';

class TopWebsite extends Equatable {
  final String domain;
  final int visitCount;
  final int totalBytes;
  final int totalSeconds;

  const TopWebsite({
    required this.domain,
    this.visitCount = 0,
    this.totalBytes = 0,
    this.totalSeconds = 0,
  });

  @override
  List<Object?> get props => [domain, visitCount, totalBytes, totalSeconds];
}

class TopUser extends Equatable {
  final String userId;
  final String displayName;
  final int visitCount;
  final int totalBytes;
  final int totalSeconds;

  const TopUser({
    required this.userId,
    required this.displayName,
    this.visitCount = 0,
    this.totalBytes = 0,
    this.totalSeconds = 0,
  });

  @override
  List<Object?> get props =>
      [userId, displayName, visitCount, totalBytes, totalSeconds];
}

class TopBandwidthConsumer extends Equatable {
  final String deviceId;
  final String deviceName;
  final int totalBytes;
  final String? department;

  const TopBandwidthConsumer({
    required this.deviceId,
    required this.deviceName,
    this.totalBytes = 0,
    this.department,
  });

  @override
  List<Object?> get props => [deviceId, deviceName, totalBytes, department];
}

class DepartmentReport extends Equatable {
  final String department;
  final int totalBytes;
  final int visitCount;
  final int uniqueDevices;
  final int blockedAttempts;

  const DepartmentReport({
    required this.department,
    this.totalBytes = 0,
    this.visitCount = 0,
    this.uniqueDevices = 0,
    this.blockedAttempts = 0,
  });

  @override
  List<Object?> get props =>
      [department, totalBytes, visitCount, uniqueDevices, blockedAttempts];
}

class BandwidthDataPoint extends Equatable {
  final DateTime timestamp;
  final int bytesSent;
  final int bytesReceived;

  const BandwidthDataPoint({
    required this.timestamp,
    this.bytesSent = 0,
    this.bytesReceived = 0,
  });

  @override
  List<Object?> get props => [timestamp, bytesSent, bytesReceived];
}

class WebLogStats extends Equatable {
  final int totalCount;
  final int totalBytes;
  final int blockedCount;
  final int uniqueDomains;

  const WebLogStats({
    this.totalCount = 0,
    this.totalBytes = 0,
    this.blockedCount = 0,
    this.uniqueDomains = 0,
  });

  @override
  List<Object?> get props =>
      [totalCount, totalBytes, blockedCount, uniqueDomains];
}

class AnalyticsSummary extends Equatable {
  final int totalWebLogs;
  final int totalConnections;
  final int activeConnections;
  final int totalDownloads;
  final int totalBandwidthBytes;
  final int totalAlerts;
  final int unreadNotifications;

  const AnalyticsSummary({
    this.totalWebLogs = 0,
    this.totalConnections = 0,
    this.activeConnections = 0,
    this.totalDownloads = 0,
    this.totalBandwidthBytes = 0,
    this.totalAlerts = 0,
    this.unreadNotifications = 0,
  });

  @override
  List<Object?> get props => [
        totalWebLogs,
        totalConnections,
        activeConnections,
        totalDownloads,
        totalBandwidthBytes,
        totalAlerts,
        unreadNotifications,
      ];
}

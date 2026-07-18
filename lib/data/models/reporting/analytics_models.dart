import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/analytics_entities.dart';

part 'analytics_models.g.dart';

@JsonSerializable(explicitToJson: true)
class TopWebsiteModel {
  final String domain;
  @JsonKey(name: 'visit_count')
  final int visitCount;
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  @JsonKey(name: 'total_seconds')
  final int totalSeconds;

  const TopWebsiteModel({
    required this.domain,
    this.visitCount = 0,
    this.totalBytes = 0,
    this.totalSeconds = 0,
  });

  factory TopWebsiteModel.fromJson(Map<String, dynamic> json) =>
      _$TopWebsiteModelFromJson(json);

  Map<String, dynamic> toJson() => _$TopWebsiteModelToJson(this);

  TopWebsite toEntity() => TopWebsite(
        domain: domain,
        visitCount: visitCount,
        totalBytes: totalBytes,
        totalSeconds: totalSeconds,
      );
}

@JsonSerializable(explicitToJson: true)
class TopUserModel {
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'display_name')
  final String displayName;
  @JsonKey(name: 'visit_count')
  final int visitCount;
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  @JsonKey(name: 'total_seconds')
  final int totalSeconds;

  const TopUserModel({
    required this.userId,
    required this.displayName,
    this.visitCount = 0,
    this.totalBytes = 0,
    this.totalSeconds = 0,
  });

  factory TopUserModel.fromJson(Map<String, dynamic> json) =>
      _$TopUserModelFromJson(json);

  Map<String, dynamic> toJson() => _$TopUserModelToJson(this);

  TopUser toEntity() => TopUser(
        userId: userId,
        displayName: displayName,
        visitCount: visitCount,
        totalBytes: totalBytes,
        totalSeconds: totalSeconds,
      );
}

@JsonSerializable(explicitToJson: true)
class TopBandwidthConsumerModel {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'device_name')
  final String deviceName;
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  final String? department;

  const TopBandwidthConsumerModel({
    required this.deviceId,
    required this.deviceName,
    this.totalBytes = 0,
    this.department,
  });

  factory TopBandwidthConsumerModel.fromJson(Map<String, dynamic> json) =>
      _$TopBandwidthConsumerModelFromJson(json);

  Map<String, dynamic> toJson() => _$TopBandwidthConsumerModelToJson(this);

  TopBandwidthConsumer toEntity() => TopBandwidthConsumer(
        deviceId: deviceId,
        deviceName: deviceName,
        totalBytes: totalBytes,
        department: department,
      );
}

@JsonSerializable(explicitToJson: true)
class DepartmentReportModel {
  final String department;
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  @JsonKey(name: 'visit_count')
  final int visitCount;
  @JsonKey(name: 'unique_devices')
  final int uniqueDevices;
  @JsonKey(name: 'blocked_attempts')
  final int blockedAttempts;

  const DepartmentReportModel({
    required this.department,
    this.totalBytes = 0,
    this.visitCount = 0,
    this.uniqueDevices = 0,
    this.blockedAttempts = 0,
  });

  factory DepartmentReportModel.fromJson(Map<String, dynamic> json) =>
      _$DepartmentReportModelFromJson(json);

  Map<String, dynamic> toJson() => _$DepartmentReportModelToJson(this);

  DepartmentReport toEntity() => DepartmentReport(
        department: department,
        totalBytes: totalBytes,
        visitCount: visitCount,
        uniqueDevices: uniqueDevices,
        blockedAttempts: blockedAttempts,
      );
}

@JsonSerializable(explicitToJson: true)
class BandwidthDataPointModel {
  final DateTime timestamp;
  @JsonKey(name: 'bytes_sent')
  final int bytesSent;
  @JsonKey(name: 'bytes_received')
  final int bytesReceived;

  const BandwidthDataPointModel({
    required this.timestamp,
    this.bytesSent = 0,
    this.bytesReceived = 0,
  });

  factory BandwidthDataPointModel.fromJson(Map<String, dynamic> json) =>
      _$BandwidthDataPointModelFromJson(json);

  Map<String, dynamic> toJson() => _$BandwidthDataPointModelToJson(this);

  BandwidthDataPoint toEntity() => BandwidthDataPoint(
        timestamp: timestamp,
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
      );
}

@JsonSerializable(explicitToJson: true)
class WebLogStatsModel {
  @JsonKey(name: 'total_count')
  final int totalCount;
  @JsonKey(name: 'total_bytes')
  final int totalBytes;
  @JsonKey(name: 'blocked_count')
  final int blockedCount;
  @JsonKey(name: 'unique_domains')
  final int uniqueDomains;

  const WebLogStatsModel({
    this.totalCount = 0,
    this.totalBytes = 0,
    this.blockedCount = 0,
    this.uniqueDomains = 0,
  });

  factory WebLogStatsModel.fromJson(Map<String, dynamic> json) =>
      _$WebLogStatsModelFromJson(json);

  Map<String, dynamic> toJson() => _$WebLogStatsModelToJson(this);

  WebLogStats toEntity() => WebLogStats(
        totalCount: totalCount,
        totalBytes: totalBytes,
        blockedCount: blockedCount,
        uniqueDomains: uniqueDomains,
      );
}

@JsonSerializable(explicitToJson: true)
class AnalyticsSummaryModel {
  @JsonKey(name: 'total_web_logs')
  final int totalWebLogs;
  @JsonKey(name: 'total_connections')
  final int totalConnections;
  @JsonKey(name: 'active_connections')
  final int activeConnections;
  @JsonKey(name: 'total_downloads')
  final int totalDownloads;
  @JsonKey(name: 'total_bandwidth_bytes')
  final int totalBandwidthBytes;
  @JsonKey(name: 'total_alerts')
  final int totalAlerts;
  @JsonKey(name: 'unread_notifications')
  final int unreadNotifications;

  const AnalyticsSummaryModel({
    this.totalWebLogs = 0,
    this.totalConnections = 0,
    this.activeConnections = 0,
    this.totalDownloads = 0,
    this.totalBandwidthBytes = 0,
    this.totalAlerts = 0,
    this.unreadNotifications = 0,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsSummaryModelFromJson(json);

  Map<String, dynamic> toJson() => _$AnalyticsSummaryModelToJson(this);

  AnalyticsSummary toEntity() => AnalyticsSummary(
        totalWebLogs: totalWebLogs,
        totalConnections: totalConnections,
        activeConnections: activeConnections,
        totalDownloads: totalDownloads,
        totalBandwidthBytes: totalBandwidthBytes,
        totalAlerts: totalAlerts,
        unreadNotifications: unreadNotifications,
      );
}

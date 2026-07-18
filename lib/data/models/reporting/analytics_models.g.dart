// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analytics_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TopWebsiteModel _$TopWebsiteModelFromJson(Map<String, dynamic> json) =>
    TopWebsiteModel(
      domain: json['domain'] as String,
      visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      totalSeconds: (json['total_seconds'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$TopWebsiteModelToJson(TopWebsiteModel instance) =>
    <String, dynamic>{
      'domain': instance.domain,
      'visit_count': instance.visitCount,
      'total_bytes': instance.totalBytes,
      'total_seconds': instance.totalSeconds,
    };

TopUserModel _$TopUserModelFromJson(Map<String, dynamic> json) => TopUserModel(
  userId: json['user_id'] as String,
  displayName: json['display_name'] as String,
  visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
  totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
  totalSeconds: (json['total_seconds'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TopUserModelToJson(TopUserModel instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'display_name': instance.displayName,
      'visit_count': instance.visitCount,
      'total_bytes': instance.totalBytes,
      'total_seconds': instance.totalSeconds,
    };

TopBandwidthConsumerModel _$TopBandwidthConsumerModelFromJson(
  Map<String, dynamic> json,
) => TopBandwidthConsumerModel(
  deviceId: json['device_id'] as String,
  deviceName: json['device_name'] as String,
  totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
  department: json['department'] as String?,
);

Map<String, dynamic> _$TopBandwidthConsumerModelToJson(
  TopBandwidthConsumerModel instance,
) => <String, dynamic>{
  'device_id': instance.deviceId,
  'device_name': instance.deviceName,
  'total_bytes': instance.totalBytes,
  'department': instance.department,
};

DepartmentReportModel _$DepartmentReportModelFromJson(
  Map<String, dynamic> json,
) => DepartmentReportModel(
  department: json['department'] as String,
  totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
  visitCount: (json['visit_count'] as num?)?.toInt() ?? 0,
  uniqueDevices: (json['unique_devices'] as num?)?.toInt() ?? 0,
  blockedAttempts: (json['blocked_attempts'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$DepartmentReportModelToJson(
  DepartmentReportModel instance,
) => <String, dynamic>{
  'department': instance.department,
  'total_bytes': instance.totalBytes,
  'visit_count': instance.visitCount,
  'unique_devices': instance.uniqueDevices,
  'blocked_attempts': instance.blockedAttempts,
};

BandwidthDataPointModel _$BandwidthDataPointModelFromJson(
  Map<String, dynamic> json,
) => BandwidthDataPointModel(
  timestamp: DateTime.parse(json['timestamp'] as String),
  bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
  bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$BandwidthDataPointModelToJson(
  BandwidthDataPointModel instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp.toIso8601String(),
  'bytes_sent': instance.bytesSent,
  'bytes_received': instance.bytesReceived,
};

WebLogStatsModel _$WebLogStatsModelFromJson(Map<String, dynamic> json) =>
    WebLogStatsModel(
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
      totalBytes: (json['total_bytes'] as num?)?.toInt() ?? 0,
      blockedCount: (json['blocked_count'] as num?)?.toInt() ?? 0,
      uniqueDomains: (json['unique_domains'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$WebLogStatsModelToJson(WebLogStatsModel instance) =>
    <String, dynamic>{
      'total_count': instance.totalCount,
      'total_bytes': instance.totalBytes,
      'blocked_count': instance.blockedCount,
      'unique_domains': instance.uniqueDomains,
    };

AnalyticsSummaryModel _$AnalyticsSummaryModelFromJson(
  Map<String, dynamic> json,
) => AnalyticsSummaryModel(
  totalWebLogs: (json['total_web_logs'] as num?)?.toInt() ?? 0,
  totalConnections: (json['total_connections'] as num?)?.toInt() ?? 0,
  activeConnections: (json['active_connections'] as num?)?.toInt() ?? 0,
  totalDownloads: (json['total_downloads'] as num?)?.toInt() ?? 0,
  totalBandwidthBytes: (json['total_bandwidth_bytes'] as num?)?.toInt() ?? 0,
  totalAlerts: (json['total_alerts'] as num?)?.toInt() ?? 0,
  unreadNotifications: (json['unread_notifications'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$AnalyticsSummaryModelToJson(
  AnalyticsSummaryModel instance,
) => <String, dynamic>{
  'total_web_logs': instance.totalWebLogs,
  'total_connections': instance.totalConnections,
  'active_connections': instance.activeConnections,
  'total_downloads': instance.totalDownloads,
  'total_bandwidth_bytes': instance.totalBandwidthBytes,
  'total_alerts': instance.totalAlerts,
  'unread_notifications': instance.unreadNotifications,
};

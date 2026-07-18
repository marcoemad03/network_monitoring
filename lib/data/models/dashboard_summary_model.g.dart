// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_summary_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardSummaryModel _$DashboardSummaryModelFromJson(
  Map<String, dynamic> json,
) => DashboardSummaryModel(
  totalDevices: (json['total_devices'] as num).toInt(),
  onlineDevices: (json['online_devices'] as num).toInt(),
  offlineDevices: (json['offline_devices'] as num).toInt(),
  degradedDevices: (json['degraded_devices'] as num).toInt(),
  maintenanceDevices: (json['maintenance_devices'] as num).toInt(),
  criticalAlerts: (json['critical_alerts'] as num).toInt(),
  highAlerts: (json['high_alerts'] as num).toInt(),
  mediumAlerts: (json['medium_alerts'] as num).toInt(),
  lowAlerts: (json['low_alerts'] as num).toInt(),
  openAlerts: (json['open_alerts'] as num).toInt(),
  acknowledgedAlerts: (json['acknowledged_alerts'] as num).toInt(),
  activeScans: (json['active_scans'] as num).toInt(),
  averageCpuUsage: (json['average_cpu_usage'] as num?)?.toDouble(),
  averageMemoryUsage: (json['average_memory_usage'] as num?)?.toDouble(),
  averageLatency: (json['average_latency'] as num?)?.toDouble(),
  averagePacketLoss: (json['average_packet_loss'] as num?)?.toDouble(),
  totalBandwidthUsage: (json['total_bandwidth_usage'] as num?)?.toDouble(),
  newDevicesToday: (json['new_devices_today'] as num).toInt(),
  eventsLastHour: (json['events_last_hour'] as num).toInt(),
);

Map<String, dynamic> _$DashboardSummaryModelToJson(
  DashboardSummaryModel instance,
) => <String, dynamic>{
  'total_devices': instance.totalDevices,
  'online_devices': instance.onlineDevices,
  'offline_devices': instance.offlineDevices,
  'degraded_devices': instance.degradedDevices,
  'maintenance_devices': instance.maintenanceDevices,
  'critical_alerts': instance.criticalAlerts,
  'high_alerts': instance.highAlerts,
  'medium_alerts': instance.mediumAlerts,
  'low_alerts': instance.lowAlerts,
  'open_alerts': instance.openAlerts,
  'acknowledged_alerts': instance.acknowledgedAlerts,
  'active_scans': instance.activeScans,
  'average_cpu_usage': instance.averageCpuUsage,
  'average_memory_usage': instance.averageMemoryUsage,
  'average_latency': instance.averageLatency,
  'average_packet_loss': instance.averagePacketLoss,
  'total_bandwidth_usage': instance.totalBandwidthUsage,
  'new_devices_today': instance.newDevicesToday,
  'events_last_hour': instance.eventsLastHour,
};

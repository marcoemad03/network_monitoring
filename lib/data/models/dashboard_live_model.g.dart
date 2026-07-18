// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_live_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DashboardLiveModel _$DashboardLiveModelFromJson(Map<String, dynamic> json) =>
    DashboardLiveModel(
      totalDevices: (json['total_devices'] as num).toInt(),
      onlineDevices: (json['online_devices'] as num).toInt(),
      offlineDevices: (json['offline_devices'] as num).toInt(),
      degradedDevices: (json['degraded_devices'] as num).toInt(),
      totalClients: (json['total_clients'] as num).toInt(),
      activeClients: (json['active_clients'] as num).toInt(),
      criticalAlerts: (json['critical_alerts'] as num).toInt(),
      openAlerts: (json['open_alerts'] as num).toInt(),
      averageCpu: (json['average_cpu'] as num?)?.toDouble(),
      averageMemory: (json['average_memory'] as num?)?.toDouble(),
      averageLatency: (json['average_latency'] as num?)?.toDouble(),
      averagePacketLoss: (json['average_packet_loss'] as num?)?.toDouble(),
      totalUploadBps: (json['total_upload_bps'] as num?)?.toInt() ?? 0,
      totalDownloadBps: (json['total_download_bps'] as num?)?.toInt() ?? 0,
      devicesByType: (json['devices_by_type'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      devicesByStatus: (json['devices_by_status'] as Map<String, dynamic>?)
          ?.map((k, e) => MapEntry(k, (e as num).toInt())),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$DashboardLiveModelToJson(DashboardLiveModel instance) =>
    <String, dynamic>{
      'total_devices': instance.totalDevices,
      'online_devices': instance.onlineDevices,
      'offline_devices': instance.offlineDevices,
      'degraded_devices': instance.degradedDevices,
      'total_clients': instance.totalClients,
      'active_clients': instance.activeClients,
      'critical_alerts': instance.criticalAlerts,
      'open_alerts': instance.openAlerts,
      'average_cpu': instance.averageCpu,
      'average_memory': instance.averageMemory,
      'average_latency': instance.averageLatency,
      'average_packet_loss': instance.averagePacketLoss,
      'total_upload_bps': instance.totalUploadBps,
      'total_download_bps': instance.totalDownloadBps,
      'devices_by_type': instance.devicesByType,
      'devices_by_status': instance.devicesByStatus,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_metrics_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceMetricsModel _$DeviceMetricsModelFromJson(Map<String, dynamic> json) =>
    DeviceMetricsModel(
      deviceId: json['device_id'] as String,
      cpuUsagePercent: (json['cpu_usage_percent'] as num?)?.toDouble(),
      memoryUsagePercent: (json['memory_usage_percent'] as num?)?.toDouble(),
      diskUsagePercent: (json['disk_usage_percent'] as num?)?.toDouble(),
      temperatureCelsius: (json['temperature_celsius'] as num?)?.toDouble(),
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toDouble(),
      totalInterfaces: (json['total_interfaces'] as num?)?.toInt(),
      upInterfaces: (json['up_interfaces'] as num?)?.toInt(),
      totalTrafficInBps: (json['total_traffic_in_bps'] as num?)?.toDouble(),
      totalTrafficOutBps: (json['total_traffic_out_bps'] as num?)?.toDouble(),
      averageLatencyMs: (json['average_latency_ms'] as num?)?.toDouble(),
      maxLatencyMs: (json['max_latency_ms'] as num?)?.toDouble(),
      packetLossPercent: (json['packet_loss_percent'] as num?)?.toDouble(),
      totalAlerts: (json['total_alerts'] as num?)?.toInt(),
      criticalAlerts: (json['critical_alerts'] as num?)?.toInt(),
      warningAlerts: (json['warning_alerts'] as num?)?.toInt(),
      uploadSpeedBps: (json['upload_speed_bps'] as num?)?.toInt(),
      downloadSpeedBps: (json['download_speed_bps'] as num?)?.toInt(),
      signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt(),
      signalQualityPercent:
          (json['signal_quality_percent'] as num?)?.toDouble(),
      connectedApId: json['connected_ap_id'] as String?,
      connectedSwitchId: json['connected_switch_id'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$DeviceMetricsModelToJson(DeviceMetricsModel instance) =>
    <String, dynamic>{
      'device_id': instance.deviceId,
      'cpu_usage_percent': instance.cpuUsagePercent,
      'memory_usage_percent': instance.memoryUsagePercent,
      'disk_usage_percent': instance.diskUsagePercent,
      'temperature_celsius': instance.temperatureCelsius,
      'uptime_seconds': instance.uptimeSeconds,
      'total_interfaces': instance.totalInterfaces,
      'up_interfaces': instance.upInterfaces,
      'total_traffic_in_bps': instance.totalTrafficInBps,
      'total_traffic_out_bps': instance.totalTrafficOutBps,
      'average_latency_ms': instance.averageLatencyMs,
      'max_latency_ms': instance.maxLatencyMs,
      'packet_loss_percent': instance.packetLossPercent,
      'total_alerts': instance.totalAlerts,
      'critical_alerts': instance.criticalAlerts,
      'warning_alerts': instance.warningAlerts,
      'upload_speed_bps': instance.uploadSpeedBps,
      'download_speed_bps': instance.downloadSpeedBps,
      'signal_strength_dbm': instance.signalStrengthDbm,
      'signal_quality_percent': instance.signalQualityPercent,
      'connected_ap_id': instance.connectedApId,
      'connected_switch_id': instance.connectedSwitchId,
      'timestamp': instance.timestamp.toIso8601String(),
    };

import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_metrics.dart';

part 'device_metrics_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceMetricsModel {
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'cpu_usage_percent')
  final double? cpuUsagePercent;
  @JsonKey(name: 'memory_usage_percent')
  final double? memoryUsagePercent;
  @JsonKey(name: 'disk_usage_percent')
  final double? diskUsagePercent;
  @JsonKey(name: 'temperature_celsius')
  final double? temperatureCelsius;
  @JsonKey(name: 'uptime_seconds')
  final double? uptimeSeconds;
  @JsonKey(name: 'total_interfaces')
  final int? totalInterfaces;
  @JsonKey(name: 'up_interfaces')
  final int? upInterfaces;
  @JsonKey(name: 'total_traffic_in_bps')
  final double? totalTrafficInBps;
  @JsonKey(name: 'total_traffic_out_bps')
  final double? totalTrafficOutBps;
  @JsonKey(name: 'average_latency_ms')
  final double? averageLatencyMs;
  @JsonKey(name: 'max_latency_ms')
  final double? maxLatencyMs;
  @JsonKey(name: 'packet_loss_percent')
  final double? packetLossPercent;
  @JsonKey(name: 'total_alerts')
  final int? totalAlerts;
  @JsonKey(name: 'critical_alerts')
  final int? criticalAlerts;
  @JsonKey(name: 'warning_alerts')
  final int? warningAlerts;
  @JsonKey(name: 'upload_speed_bps')
  final int? uploadSpeedBps;
  @JsonKey(name: 'download_speed_bps')
  final int? downloadSpeedBps;
  @JsonKey(name: 'signal_strength_dbm')
  final int? signalStrengthDbm;
  @JsonKey(name: 'signal_quality_percent')
  final double? signalQualityPercent;
  @JsonKey(name: 'connected_ap_id')
  final String? connectedApId;
  @JsonKey(name: 'connected_switch_id')
  final String? connectedSwitchId;
  final DateTime timestamp;

  const DeviceMetricsModel({
    required this.deviceId,
    this.cpuUsagePercent,
    this.memoryUsagePercent,
    this.diskUsagePercent,
    this.temperatureCelsius,
    this.uptimeSeconds,
    this.totalInterfaces,
    this.upInterfaces,
    this.totalTrafficInBps,
    this.totalTrafficOutBps,
    this.averageLatencyMs,
    this.maxLatencyMs,
    this.packetLossPercent,
    this.totalAlerts,
    this.criticalAlerts,
    this.warningAlerts,
    this.uploadSpeedBps,
    this.downloadSpeedBps,
    this.signalStrengthDbm,
    this.signalQualityPercent,
    this.connectedApId,
    this.connectedSwitchId,
    required this.timestamp,
  });

  factory DeviceMetricsModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceMetricsModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceMetricsModelToJson(this);

  DeviceMetrics toEntity() => DeviceMetrics(
        deviceId: deviceId,
        cpuUsagePercent: cpuUsagePercent,
        memoryUsagePercent: memoryUsagePercent,
        diskUsagePercent: diskUsagePercent,
        temperatureCelsius: temperatureCelsius,
        uptimeSeconds: uptimeSeconds,
        totalInterfaces: totalInterfaces,
        upInterfaces: upInterfaces,
        totalTrafficInBps: totalTrafficInBps,
        totalTrafficOutBps: totalTrafficOutBps,
        averageLatencyMs: averageLatencyMs,
        maxLatencyMs: maxLatencyMs,
        packetLossPercent: packetLossPercent,
        totalAlerts: totalAlerts,
        criticalAlerts: criticalAlerts,
        warningAlerts: warningAlerts,
        uploadSpeedBps: uploadSpeedBps,
        downloadSpeedBps: downloadSpeedBps,
        signalStrengthDbm: signalStrengthDbm,
        signalQualityPercent: signalQualityPercent,
        connectedApId: connectedApId,
        connectedSwitchId: connectedSwitchId,
        timestamp: timestamp,
      );

  factory DeviceMetricsModel.fromEntity(DeviceMetrics entity) =>
      DeviceMetricsModel(
        deviceId: entity.deviceId,
        cpuUsagePercent: entity.cpuUsagePercent,
        memoryUsagePercent: entity.memoryUsagePercent,
        diskUsagePercent: entity.diskUsagePercent,
        temperatureCelsius: entity.temperatureCelsius,
        uptimeSeconds: entity.uptimeSeconds,
        totalInterfaces: entity.totalInterfaces,
        upInterfaces: entity.upInterfaces,
        totalTrafficInBps: entity.totalTrafficInBps,
        totalTrafficOutBps: entity.totalTrafficOutBps,
        averageLatencyMs: entity.averageLatencyMs,
        maxLatencyMs: entity.maxLatencyMs,
        packetLossPercent: entity.packetLossPercent,
        totalAlerts: entity.totalAlerts,
        criticalAlerts: entity.criticalAlerts,
        warningAlerts: entity.warningAlerts,
        uploadSpeedBps: entity.uploadSpeedBps,
        downloadSpeedBps: entity.downloadSpeedBps,
        signalStrengthDbm: entity.signalStrengthDbm,
        signalQualityPercent: entity.signalQualityPercent,
        connectedApId: entity.connectedApId,
        connectedSwitchId: entity.connectedSwitchId,
        timestamp: entity.timestamp,
      );
}

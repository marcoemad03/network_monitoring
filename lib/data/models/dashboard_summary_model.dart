import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/dashboard_summary.dart';

part 'dashboard_summary_model.g.dart';

@JsonSerializable()
class DashboardSummaryModel {
  @JsonKey(name: 'total_devices')
  final int totalDevices;
  @JsonKey(name: 'online_devices')
  final int onlineDevices;
  @JsonKey(name: 'offline_devices')
  final int offlineDevices;
  @JsonKey(name: 'degraded_devices')
  final int degradedDevices;
  @JsonKey(name: 'maintenance_devices')
  final int maintenanceDevices;
  @JsonKey(name: 'critical_alerts')
  final int criticalAlerts;
  @JsonKey(name: 'high_alerts')
  final int highAlerts;
  @JsonKey(name: 'medium_alerts')
  final int mediumAlerts;
  @JsonKey(name: 'low_alerts')
  final int lowAlerts;
  @JsonKey(name: 'open_alerts')
  final int openAlerts;
  @JsonKey(name: 'acknowledged_alerts')
  final int acknowledgedAlerts;
  @JsonKey(name: 'active_scans')
  final int activeScans;
  @JsonKey(name: 'average_cpu_usage')
  final double? averageCpuUsage;
  @JsonKey(name: 'average_memory_usage')
  final double? averageMemoryUsage;
  @JsonKey(name: 'average_latency')
  final double? averageLatency;
  @JsonKey(name: 'average_packet_loss')
  final double? averagePacketLoss;
  @JsonKey(name: 'total_bandwidth_usage')
  final double? totalBandwidthUsage;
  @JsonKey(name: 'new_devices_today')
  final int newDevicesToday;
  @JsonKey(name: 'events_last_hour')
  final int eventsLastHour;

  const DashboardSummaryModel({
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.degradedDevices,
    required this.maintenanceDevices,
    required this.criticalAlerts,
    required this.highAlerts,
    required this.mediumAlerts,
    required this.lowAlerts,
    required this.openAlerts,
    required this.acknowledgedAlerts,
    required this.activeScans,
    this.averageCpuUsage,
    this.averageMemoryUsage,
    this.averageLatency,
    this.averagePacketLoss,
    this.totalBandwidthUsage,
    required this.newDevicesToday,
    required this.eventsLastHour,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryModelFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardSummaryModelToJson(this);

  DashboardSummary toEntity() => DashboardSummary(
        totalDevices: totalDevices,
        onlineDevices: onlineDevices,
        offlineDevices: offlineDevices,
        degradedDevices: degradedDevices,
        maintenanceDevices: maintenanceDevices,
        criticalAlerts: criticalAlerts,
        highAlerts: highAlerts,
        mediumAlerts: mediumAlerts,
        lowAlerts: lowAlerts,
        openAlerts: openAlerts,
        acknowledgedAlerts: acknowledgedAlerts,
        activeScans: activeScans,
        averageCpuUsage: averageCpuUsage,
        averageMemoryUsage: averageMemoryUsage,
        averageLatency: averageLatency,
        averagePacketLoss: averagePacketLoss,
        totalBandwidthUsage: totalBandwidthUsage,
        newDevicesToday: newDevicesToday,
        eventsLastHour: eventsLastHour,
      );
}

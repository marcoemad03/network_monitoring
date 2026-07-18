import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/dashboard_live.dart';

part 'dashboard_live_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DashboardLiveModel {
  @JsonKey(name: 'total_devices')
  final int totalDevices;
  @JsonKey(name: 'online_devices')
  final int onlineDevices;
  @JsonKey(name: 'offline_devices')
  final int offlineDevices;
  @JsonKey(name: 'degraded_devices')
  final int degradedDevices;
  @JsonKey(name: 'total_clients')
  final int totalClients;
  @JsonKey(name: 'active_clients')
  final int activeClients;
  @JsonKey(name: 'critical_alerts')
  final int criticalAlerts;
  @JsonKey(name: 'open_alerts')
  final int openAlerts;
  @JsonKey(name: 'average_cpu')
  final double? averageCpu;
  @JsonKey(name: 'average_memory')
  final double? averageMemory;
  @JsonKey(name: 'average_latency')
  final double? averageLatency;
  @JsonKey(name: 'average_packet_loss')
  final double? averagePacketLoss;
  @JsonKey(name: 'total_upload_bps')
  final int totalUploadBps;
  @JsonKey(name: 'total_download_bps')
  final int totalDownloadBps;
  @JsonKey(name: 'devices_by_type')
  final Map<String, int>? devicesByType;
  @JsonKey(name: 'devices_by_status')
  final Map<String, int>? devicesByStatus;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const DashboardLiveModel({
    required this.totalDevices,
    required this.onlineDevices,
    required this.offlineDevices,
    required this.degradedDevices,
    required this.totalClients,
    required this.activeClients,
    required this.criticalAlerts,
    required this.openAlerts,
    this.averageCpu,
    this.averageMemory,
    this.averageLatency,
    this.averagePacketLoss,
    this.totalUploadBps = 0,
    this.totalDownloadBps = 0,
    this.devicesByType,
    this.devicesByStatus,
    required this.updatedAt,
  });

  factory DashboardLiveModel.fromJson(Map<String, dynamic> json) =>
      _$DashboardLiveModelFromJson(json);

  Map<String, dynamic> toJson() => _$DashboardLiveModelToJson(this);

  DashboardLive toEntity() => DashboardLive(
        totalDevices: totalDevices,
        onlineDevices: onlineDevices,
        offlineDevices: offlineDevices,
        degradedDevices: degradedDevices,
        totalClients: totalClients,
        activeClients: activeClients,
        criticalAlerts: criticalAlerts,
        openAlerts: openAlerts,
        averageCpu: averageCpu,
        averageMemory: averageMemory,
        averageLatency: averageLatency,
        averagePacketLoss: averagePacketLoss,
        totalUploadBps: totalUploadBps,
        totalDownloadBps: totalDownloadBps,
        devicesByType: devicesByType ?? {},
        devicesByStatus: devicesByStatus ?? {},
        updatedAt: updatedAt,
      );
}

import 'package:equatable/equatable.dart';

class DashboardLive extends Equatable {
  final int totalDevices;
  final int onlineDevices;
  final int offlineDevices;
  final int degradedDevices;
  final int totalClients;
  final int activeClients;
  final int criticalAlerts;
  final int openAlerts;
  final double? averageCpu;
  final double? averageMemory;
  final double? averageLatency;
  final double? averagePacketLoss;
  final int totalUploadBps;
  final int totalDownloadBps;
  final Map<String, int> devicesByType;
  final Map<String, int> devicesByStatus;
  final DateTime updatedAt;

  const DashboardLive({
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
    this.devicesByType = const {},
    this.devicesByStatus = const {},
    required this.updatedAt,
  });

  double get totalUploadMbps => totalUploadBps / 1000000;
  double get totalDownloadMbps => totalDownloadBps / 1000000;

  @override
  List<Object?> get props => [
        totalDevices, onlineDevices, offlineDevices, degradedDevices,
        totalClients, activeClients, criticalAlerts, openAlerts,
        averageCpu, averageMemory, averageLatency, averagePacketLoss,
        totalUploadBps, totalDownloadBps, devicesByType, devicesByStatus, updatedAt,
      ];
}

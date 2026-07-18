import 'package:equatable/equatable.dart';

class DashboardSummary extends Equatable {
  final int totalDevices;
  final int onlineDevices;
  final int offlineDevices;
  final int degradedDevices;
  final int maintenanceDevices;
  final int criticalAlerts;
  final int highAlerts;
  final int mediumAlerts;
  final int lowAlerts;
  final int openAlerts;
  final int acknowledgedAlerts;
  final int activeScans;
  final double? averageCpuUsage;
  final double? averageMemoryUsage;
  final double? averageLatency;
  final double? averagePacketLoss;
  final double? totalBandwidthUsage;
  final int newDevicesToday;
  final int eventsLastHour;

  const DashboardSummary({
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

  @override
  List<Object?> get props => [
        totalDevices,
        onlineDevices,
        offlineDevices,
        degradedDevices,
        maintenanceDevices,
        criticalAlerts,
        highAlerts,
        mediumAlerts,
        lowAlerts,
        openAlerts,
        acknowledgedAlerts,
        activeScans,
        averageCpuUsage,
        averageMemoryUsage,
        averageLatency,
        averagePacketLoss,
        totalBandwidthUsage,
        newDevicesToday,
        eventsLastHour,
      ];
}

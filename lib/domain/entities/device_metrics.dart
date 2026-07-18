import 'package:equatable/equatable.dart';

class DeviceMetrics extends Equatable {
  final String deviceId;
  final double? cpuUsagePercent;
  final double? memoryUsagePercent;
  final double? diskUsagePercent;
  final double? temperatureCelsius;
  final double? uptimeSeconds;
  final int? totalInterfaces;
  final int? upInterfaces;
  final double? totalTrafficInBps;
  final double? totalTrafficOutBps;
  final double? averageLatencyMs;
  final double? maxLatencyMs;
  final double? packetLossPercent;
  final int? totalAlerts;
  final int? criticalAlerts;
  final int? warningAlerts;
  final int? uploadSpeedBps;
  final int? downloadSpeedBps;
  final int? signalStrengthDbm;
  final double? signalQualityPercent;
  final String? connectedApId;
  final String? connectedSwitchId;
  final DateTime timestamp;

  const DeviceMetrics({
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

  double? get uploadSpeedMbps =>
      uploadSpeedBps != null ? uploadSpeedBps! / 1000000 : null;
  double? get downloadSpeedMbps =>
      downloadSpeedBps != null ? downloadSpeedBps! / 1000000 : null;

  String get signalStrengthLabel {
    if (signalStrengthDbm == null) return 'N/A';
    final s = signalStrengthDbm!;
    if (s >= -50) return 'Excellent';
    if (s >= -60) return 'Good';
    if (s >= -70) return 'Fair';
    if (s >= -80) return 'Weak';
    return 'Very Weak';
  }

  @override
  List<Object?> get props => [
        deviceId, cpuUsagePercent, memoryUsagePercent, diskUsagePercent,
        temperatureCelsius, uptimeSeconds, totalInterfaces, upInterfaces,
        totalTrafficInBps, totalTrafficOutBps, averageLatencyMs, maxLatencyMs,
        packetLossPercent, totalAlerts, criticalAlerts, warningAlerts,
        uploadSpeedBps, downloadSpeedBps, signalStrengthDbm, signalQualityPercent,
        connectedApId, connectedSwitchId, timestamp,
      ];
}

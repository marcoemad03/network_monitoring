import 'package:equatable/equatable.dart';

class DevicePing extends Equatable {
  final String id;
  final String deviceId;
  final double? minRttMs;
  final double? maxRttMs;
  final double? avgRttMs;
  final double? medianRttMs;
  final double? stddevRttMs;
  final double? jitterMs;
  final double packetLossPercent;
  final int packetsSent;
  final int packetsReceived;
  final int packetsLost;
  final bool isReachable;
  final DateTime timestamp;

  const DevicePing({
    required this.id,
    required this.deviceId,
    this.minRttMs,
    this.maxRttMs,
    this.avgRttMs,
    this.medianRttMs,
    this.stddevRttMs,
    this.jitterMs,
    this.packetLossPercent = 0,
    this.packetsSent = 0,
    this.packetsReceived = 0,
    this.packetsLost = 0,
    this.isReachable = true,
    required this.timestamp,
  });

  String get statusLabel {
    if (!isReachable) return 'Unreachable';
    if (packetLossPercent > 20) return 'High Loss';
    if (packetLossPercent > 5) return 'Degraded';
    if (avgRttMs != null && avgRttMs! > 200) return 'High Latency';
    if (avgRttMs != null && avgRttMs! > 100) return 'Elevated';
    return 'Normal';
  }

  @override
  List<Object?> get props => [
        id, deviceId, minRttMs, maxRttMs, avgRttMs, medianRttMs,
        stddevRttMs, jitterMs, packetLossPercent, packetsSent,
        packetsReceived, packetsLost, isReachable, timestamp,
      ];
}

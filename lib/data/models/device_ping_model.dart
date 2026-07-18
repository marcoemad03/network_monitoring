import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_ping.dart';

part 'device_ping_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DevicePingModel {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'min_rtt_ms')
  final double? minRttMs;
  @JsonKey(name: 'max_rtt_ms')
  final double? maxRttMs;
  @JsonKey(name: 'avg_rtt_ms')
  final double? avgRttMs;
  @JsonKey(name: 'median_rtt_ms')
  final double? medianRttMs;
  @JsonKey(name: 'stddev_rtt_ms')
  final double? stddevRttMs;
  @JsonKey(name: 'jitter_ms')
  final double? jitterMs;
  @JsonKey(name: 'packet_loss_percent')
  final double packetLossPercent;
  @JsonKey(name: 'packets_sent')
  final int packetsSent;
  @JsonKey(name: 'packets_received')
  final int packetsReceived;
  @JsonKey(name: 'packets_lost')
  final int packetsLost;
  @JsonKey(name: 'is_reachable')
  final bool isReachable;
  final DateTime timestamp;

  const DevicePingModel({
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

  factory DevicePingModel.fromJson(Map<String, dynamic> json) =>
      _$DevicePingModelFromJson(json);

  Map<String, dynamic> toJson() => _$DevicePingModelToJson(this);

  DevicePing toEntity() => DevicePing(
        id: id,
        deviceId: deviceId,
        minRttMs: minRttMs,
        maxRttMs: maxRttMs,
        avgRttMs: avgRttMs,
        medianRttMs: medianRttMs,
        stddevRttMs: stddevRttMs,
        jitterMs: jitterMs,
        packetLossPercent: packetLossPercent,
        packetsSent: packetsSent,
        packetsReceived: packetsReceived,
        packetsLost: packetsLost,
        isReachable: isReachable,
        timestamp: timestamp,
      );
}

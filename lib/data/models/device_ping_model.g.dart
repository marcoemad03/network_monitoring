// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_ping_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DevicePingModel _$DevicePingModelFromJson(Map<String, dynamic> json) =>
    DevicePingModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      minRttMs: (json['min_rtt_ms'] as num?)?.toDouble(),
      maxRttMs: (json['max_rtt_ms'] as num?)?.toDouble(),
      avgRttMs: (json['avg_rtt_ms'] as num?)?.toDouble(),
      medianRttMs: (json['median_rtt_ms'] as num?)?.toDouble(),
      stddevRttMs: (json['stddev_rtt_ms'] as num?)?.toDouble(),
      jitterMs: (json['jitter_ms'] as num?)?.toDouble(),
      packetLossPercent: (json['packet_loss_percent'] as num?)?.toDouble() ?? 0,
      packetsSent: (json['packets_sent'] as num?)?.toInt() ?? 0,
      packetsReceived: (json['packets_received'] as num?)?.toInt() ?? 0,
      packetsLost: (json['packets_lost'] as num?)?.toInt() ?? 0,
      isReachable: json['is_reachable'] as bool? ?? true,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$DevicePingModelToJson(DevicePingModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'min_rtt_ms': instance.minRttMs,
      'max_rtt_ms': instance.maxRttMs,
      'avg_rtt_ms': instance.avgRttMs,
      'median_rtt_ms': instance.medianRttMs,
      'stddev_rtt_ms': instance.stddevRttMs,
      'jitter_ms': instance.jitterMs,
      'packet_loss_percent': instance.packetLossPercent,
      'packets_sent': instance.packetsSent,
      'packets_received': instance.packetsReceived,
      'packets_lost': instance.packetsLost,
      'is_reachable': instance.isReachable,
      'timestamp': instance.timestamp.toIso8601String(),
    };

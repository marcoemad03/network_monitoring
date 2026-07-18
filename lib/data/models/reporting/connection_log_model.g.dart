// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connection_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConnectionLogModel _$ConnectionLogModelFromJson(Map<String, dynamic> json) =>
    ConnectionLogModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      deviceId: json['device_id'] as String?,
      userId: json['user_id'] as String?,
      protocol: json['protocol'] as String?,
      sourceIp: json['source_ip'] as String,
      destIp: json['dest_ip'] as String,
      sourcePort: (json['source_port'] as num?)?.toInt(),
      destPort: (json['dest_port'] as num?)?.toInt(),
      bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
      bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
      packetsSent: (json['packets_sent'] as num?)?.toInt() ?? 0,
      packetsReceived: (json['packets_received'] as num?)?.toInt() ?? 0,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime:
          json['end_time'] == null
              ? null
              : DateTime.parse(json['end_time'] as String),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      application: json['application'] as String?,
      department: json['department'] as String?,
      deviceName: json['device_name'] as String?,
    );

Map<String, dynamic> _$ConnectionLogModelToJson(ConnectionLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'device_id': instance.deviceId,
      'user_id': instance.userId,
      'protocol': instance.protocol,
      'source_ip': instance.sourceIp,
      'dest_ip': instance.destIp,
      'source_port': instance.sourcePort,
      'dest_port': instance.destPort,
      'bytes_sent': instance.bytesSent,
      'bytes_received': instance.bytesReceived,
      'packets_sent': instance.packetsSent,
      'packets_received': instance.packetsReceived,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'duration_seconds': instance.durationSeconds,
      'is_active': instance.isActive,
      'application': instance.application,
      'department': instance.department,
      'device_name': instance.deviceName,
    };

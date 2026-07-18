// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebLogModel _$WebLogModelFromJson(Map<String, dynamic> json) => WebLogModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  deviceId: json['device_id'] as String?,
  userId: json['user_id'] as String?,
  url: json['url'] as String,
  domain: json['domain'] as String?,
  category: json['category'] as String?,
  timestamp: DateTime.parse(json['timestamp'] as String),
  durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
  bytesSent: (json['bytes_sent'] as num?)?.toInt() ?? 0,
  bytesReceived: (json['bytes_received'] as num?)?.toInt() ?? 0,
  isBlocked: json['is_blocked'] as bool? ?? false,
  blockedBy: json['blocked_by'] as String?,
  isEncrypted: json['is_encrypted'] as bool? ?? false,
  protocol: json['protocol'] as String? ?? 'HTTPS',
  method: json['method'] as String? ?? 'GET',
  contentType: json['content_type'] as String?,
  statusCode: (json['status_code'] as num?)?.toInt() ?? 200,
  userAgent: json['user_agent'] as String?,
  deviceName: json['device_name'] as String?,
  department: json['department'] as String?,
);

Map<String, dynamic> _$WebLogModelToJson(WebLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'device_id': instance.deviceId,
      'user_id': instance.userId,
      'url': instance.url,
      'domain': instance.domain,
      'category': instance.category,
      'timestamp': instance.timestamp.toIso8601String(),
      'duration_seconds': instance.durationSeconds,
      'bytes_sent': instance.bytesSent,
      'bytes_received': instance.bytesReceived,
      'is_blocked': instance.isBlocked,
      'blocked_by': instance.blockedBy,
      'is_encrypted': instance.isEncrypted,
      'protocol': instance.protocol,
      'method': instance.method,
      'content_type': instance.contentType,
      'status_code': instance.statusCode,
      'user_agent': instance.userAgent,
      'device_name': instance.deviceName,
      'department': instance.department,
    };

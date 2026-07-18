// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadLogModel _$DownloadLogModelFromJson(Map<String, dynamic> json) =>
    DownloadLogModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      deviceId: json['device_id'] as String?,
      userId: json['user_id'] as String?,
      filename: json['filename'] as String,
      url: json['url'] as String?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      protocol: json['protocol'] as String? ?? 'HTTPS',
      mimeType: json['mime_type'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime:
          json['end_time'] == null
              ? null
              : DateTime.parse(json['end_time'] as String),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'completed',
      isAllowed: json['is_allowed'] as bool? ?? true,
      blockedBy: json['blocked_by'] as String?,
      deviceName: json['device_name'] as String?,
      department: json['department'] as String?,
    );

Map<String, dynamic> _$DownloadLogModelToJson(DownloadLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'device_id': instance.deviceId,
      'user_id': instance.userId,
      'filename': instance.filename,
      'url': instance.url,
      'size_bytes': instance.sizeBytes,
      'protocol': instance.protocol,
      'mime_type': instance.mimeType,
      'start_time': instance.startTime.toIso8601String(),
      'end_time': instance.endTime?.toIso8601String(),
      'duration_seconds': instance.durationSeconds,
      'status': instance.status,
      'is_allowed': instance.isAllowed,
      'blocked_by': instance.blockedBy,
      'device_name': instance.deviceName,
      'department': instance.department,
    };

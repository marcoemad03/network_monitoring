// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_block_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceBlockModel _$DeviceBlockModelFromJson(Map<String, dynamic> json) =>
    DeviceBlockModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      deviceId: json['device_id'] as String?,
      macAddress: json['mac_address'] as String?,
      ipAddress: json['ip_address'] as String?,
      reason: json['reason'] as String?,
      blockedBy: json['blocked_by'] as String?,
      blockedAt: DateTime.parse(json['blocked_at'] as String),
      unblockedAt:
          json['unblocked_at'] == null
              ? null
              : DateTime.parse(json['unblocked_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
    );

Map<String, dynamic> _$DeviceBlockModelToJson(DeviceBlockModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'device_id': instance.deviceId,
      'mac_address': instance.macAddress,
      'ip_address': instance.ipAddress,
      'reason': instance.reason,
      'blocked_by': instance.blockedBy,
      'blocked_at': instance.blockedAt.toIso8601String(),
      'unblocked_at': instance.unblockedAt?.toIso8601String(),
      'is_active': instance.isActive,
    };

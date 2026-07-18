// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_connection_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceConnectionModel _$DeviceConnectionModelFromJson(
  Map<String, dynamic> json,
) => DeviceConnectionModel(
  id: json['id'] as String,
  parentDeviceId: json['parent_device_id'] as String,
  childDeviceId: json['child_device_id'] as String,
  parentInterfaceId: json['parent_interface_id'] as String?,
  childInterfaceId: json['child_interface_id'] as String?,
  connectionType: json['connection_type'] as String? ?? 'ethernet',
  medium: json['medium'] as String? ?? 'copper',
  speedMbps: (json['speed_mbps'] as num?)?.toDouble(),
  vlanId: (json['vlan_id'] as num?)?.toInt(),
  isActive: json['is_active'] as bool? ?? true,
  discoveredMethod: json['discovered_method'] as String? ?? 'manual',
  discoveredAt: DateTime.parse(json['discovered_at'] as String),
  lastSeen: DateTime.parse(json['last_seen'] as String),
);

Map<String, dynamic> _$DeviceConnectionModelToJson(
  DeviceConnectionModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'parent_device_id': instance.parentDeviceId,
  'child_device_id': instance.childDeviceId,
  'parent_interface_id': instance.parentInterfaceId,
  'child_interface_id': instance.childInterfaceId,
  'connection_type': instance.connectionType,
  'medium': instance.medium,
  'speed_mbps': instance.speedMbps,
  'vlan_id': instance.vlanId,
  'is_active': instance.isActive,
  'discovered_method': instance.discoveredMethod,
  'discovered_at': instance.discoveredAt.toIso8601String(),
  'last_seen': instance.lastSeen.toIso8601String(),
};

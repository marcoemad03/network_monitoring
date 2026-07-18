// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map<String, dynamic> json) => DeviceModel(
  id: json['id'] as String,
  name: json['name'] as String,
  hostname: json['hostname'] as String?,
  ipAddress: json['ip_address'] as String,
  macAddress: json['mac_address'] as String?,
  deviceType: json['device_type'] as String,
  status: json['status'] as String,
  vendor: json['vendor'] as String?,
  model: json['model'] as String?,
  serialNumber: json['serial_number'] as String?,
  osVersion: json['os_version'] as String?,
  firmwareVersion: json['firmware_version'] as String?,
  location: json['location'] as String?,
  department: json['department'] as String?,
  notes: json['notes'] as String?,
  customFields: (json['custom_fields'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  firstSeen: DateTime.parse(json['first_seen'] as String),
  lastBoot:
      json['last_boot'] == null
          ? null
          : DateTime.parse(json['last_boot'] as String),
  lastSeen: DateTime.parse(json['last_seen'] as String),
  isCritical: json['is_critical'] as bool? ?? false,
  isMonitored: json['is_monitored'] as bool? ?? true,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'hostname': instance.hostname,
      'ip_address': instance.ipAddress,
      'mac_address': instance.macAddress,
      'device_type': instance.deviceType,
      'status': instance.status,
      'vendor': instance.vendor,
      'model': instance.model,
      'serial_number': instance.serialNumber,
      'os_version': instance.osVersion,
      'firmware_version': instance.firmwareVersion,
      'location': instance.location,
      'department': instance.department,
      'notes': instance.notes,
      'custom_fields': instance.customFields,
      'first_seen': instance.firstSeen.toIso8601String(),
      'last_boot': instance.lastBoot?.toIso8601String(),
      'last_seen': instance.lastSeen.toIso8601String(),
      'is_critical': instance.isCritical,
      'is_monitored': instance.isMonitored,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

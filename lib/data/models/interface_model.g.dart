// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'interface_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InterfaceModel _$InterfaceModelFromJson(Map<String, dynamic> json) =>
    InterfaceModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      macAddress: json['mac_address'] as String?,
      ipAddress: json['ip_address'] as String?,
      subnetMask: json['subnet_mask'] as String?,
      gateway: json['gateway'] as String?,
      dnsServers:
          (json['dns_servers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      connectionType: json['connection_type'] as String? ?? 'ethernet',
      isUp: json['is_up'] as bool? ?? false,
      isManagement: json['is_management'] as bool? ?? false,
      mtu: (json['mtu'] as num?)?.toInt() ?? 1500,
      speedMbps: (json['speed_mbps'] as num?)?.toDouble(),
      duplex: json['duplex'] as String?,
      mediaType: json['media_type'] as String?,
      index: (json['index'] as num?)?.toInt() ?? 0,
      vlanId: (json['vlan_id'] as num?)?.toInt(),
      switchPort: json['switch_port'] as String?,
      connectedDeviceId: json['connected_device_id'] as String?,
      connectedInterfaceName: json['connected_interface_name'] as String?,
      bytesIn: (json['bytes_in'] as num?)?.toInt() ?? 0,
      bytesOut: (json['bytes_out'] as num?)?.toInt() ?? 0,
      packetsIn: (json['packets_in'] as num?)?.toInt() ?? 0,
      packetsOut: (json['packets_out'] as num?)?.toInt() ?? 0,
      errorsIn: (json['errors_in'] as num?)?.toInt() ?? 0,
      errorsOut: (json['errors_out'] as num?)?.toInt() ?? 0,
      dropsIn: (json['drops_in'] as num?)?.toInt() ?? 0,
      dropsOut: (json['drops_out'] as num?)?.toInt() ?? 0,
      utilizationPercent: (json['utilization_percent'] as num?)?.toDouble(),
      lastStatusChange:
          json['last_status_change'] == null
              ? null
              : DateTime.parse(json['last_status_change'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$InterfaceModelToJson(InterfaceModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'name': instance.name,
      'description': instance.description,
      'mac_address': instance.macAddress,
      'ip_address': instance.ipAddress,
      'subnet_mask': instance.subnetMask,
      'gateway': instance.gateway,
      'dns_servers': instance.dnsServers,
      'connection_type': instance.connectionType,
      'is_up': instance.isUp,
      'is_management': instance.isManagement,
      'mtu': instance.mtu,
      'speed_mbps': instance.speedMbps,
      'duplex': instance.duplex,
      'media_type': instance.mediaType,
      'index': instance.index,
      'vlan_id': instance.vlanId,
      'switch_port': instance.switchPort,
      'connected_device_id': instance.connectedDeviceId,
      'connected_interface_name': instance.connectedInterfaceName,
      'bytes_in': instance.bytesIn,
      'bytes_out': instance.bytesOut,
      'packets_in': instance.packetsIn,
      'packets_out': instance.packetsOut,
      'errors_in': instance.errorsIn,
      'errors_out': instance.errorsOut,
      'drops_in': instance.dropsIn,
      'drops_out': instance.dropsOut,
      'utilization_percent': instance.utilizationPercent,
      'last_status_change': instance.lastStatusChange?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

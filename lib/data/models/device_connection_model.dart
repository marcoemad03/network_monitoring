import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_connection.dart';

part 'device_connection_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceConnectionModel {
  final String id;
  @JsonKey(name: 'parent_device_id')
  final String parentDeviceId;
  @JsonKey(name: 'child_device_id')
  final String childDeviceId;
  @JsonKey(name: 'parent_interface_id')
  final String? parentInterfaceId;
  @JsonKey(name: 'child_interface_id')
  final String? childInterfaceId;
  @JsonKey(name: 'connection_type')
  final String connectionType;
  final String medium;
  @JsonKey(name: 'speed_mbps')
  final double? speedMbps;
  @JsonKey(name: 'vlan_id')
  final int? vlanId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'discovered_method')
  final String discoveredMethod;
  @JsonKey(name: 'discovered_at')
  final DateTime discoveredAt;
  @JsonKey(name: 'last_seen')
  final DateTime lastSeen;

  const DeviceConnectionModel({
    required this.id,
    required this.parentDeviceId,
    required this.childDeviceId,
    this.parentInterfaceId,
    this.childInterfaceId,
    this.connectionType = 'ethernet',
    this.medium = 'copper',
    this.speedMbps,
    this.vlanId,
    this.isActive = true,
    this.discoveredMethod = 'manual',
    required this.discoveredAt,
    required this.lastSeen,
  });

  factory DeviceConnectionModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceConnectionModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceConnectionModelToJson(this);

  DeviceConnection toEntity() => DeviceConnection(
        id: id,
        parentDeviceId: parentDeviceId,
        childDeviceId: childDeviceId,
        parentInterfaceId: parentInterfaceId,
        childInterfaceId: childInterfaceId,
        connectionType: connectionType,
        medium: medium,
        speedMbps: speedMbps,
        vlanId: vlanId,
        isActive: isActive,
        discoveredMethod: discoveredMethod,
        discoveredAt: discoveredAt,
        lastSeen: lastSeen,
      );
}

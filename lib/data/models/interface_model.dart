import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/interface.dart';
import '../../core/enums/connection_type.dart';

part 'interface_model.g.dart';

@JsonSerializable(explicitToJson: true)
class InterfaceModel {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  final String name;
  final String? description;
  @JsonKey(name: 'mac_address')
  final String? macAddress;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  @JsonKey(name: 'subnet_mask')
  final String? subnetMask;
  final String? gateway;
  @JsonKey(name: 'dns_servers')
  final List<String>? dnsServers;
  @JsonKey(name: 'connection_type')
  final String connectionType;
  @JsonKey(name: 'is_up')
  final bool isUp;
  @JsonKey(name: 'is_management')
  final bool isManagement;
  final int mtu;
  @JsonKey(name: 'speed_mbps')
  final double? speedMbps;
  final String? duplex;
  @JsonKey(name: 'media_type')
  final String? mediaType;
  @JsonKey(name: 'index')
  final int index;
  @JsonKey(name: 'vlan_id')
  final int? vlanId;
  @JsonKey(name: 'switch_port')
  final String? switchPort;
  @JsonKey(name: 'connected_device_id')
  final String? connectedDeviceId;
  @JsonKey(name: 'connected_interface_name')
  final String? connectedInterfaceName;
  @JsonKey(name: 'bytes_in')
  final int bytesIn;
  @JsonKey(name: 'bytes_out')
  final int bytesOut;
  @JsonKey(name: 'packets_in')
  final int packetsIn;
  @JsonKey(name: 'packets_out')
  final int packetsOut;
  @JsonKey(name: 'errors_in')
  final int errorsIn;
  @JsonKey(name: 'errors_out')
  final int errorsOut;
  @JsonKey(name: 'drops_in')
  final int dropsIn;
  @JsonKey(name: 'drops_out')
  final int dropsOut;
  @JsonKey(name: 'utilization_percent')
  final double? utilizationPercent;
  @JsonKey(name: 'last_status_change')
  final DateTime? lastStatusChange;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const InterfaceModel({
    required this.id,
    required this.deviceId,
    required this.name,
    this.description,
    this.macAddress,
    this.ipAddress,
    this.subnetMask,
    this.gateway,
    this.dnsServers,
    this.connectionType = 'ethernet',
    this.isUp = false,
    this.isManagement = false,
    this.mtu = 1500,
    this.speedMbps,
    this.duplex,
    this.mediaType,
    this.index = 0,
    this.vlanId,
    this.switchPort,
    this.connectedDeviceId,
    this.connectedInterfaceName,
    this.bytesIn = 0,
    this.bytesOut = 0,
    this.packetsIn = 0,
    this.packetsOut = 0,
    this.errorsIn = 0,
    this.errorsOut = 0,
    this.dropsIn = 0,
    this.dropsOut = 0,
    this.utilizationPercent,
    this.lastStatusChange,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InterfaceModel.fromJson(Map<String, dynamic> json) =>
      _$InterfaceModelFromJson(json);

  Map<String, dynamic> toJson() => _$InterfaceModelToJson(this);

  NetworkInterface toEntity() => NetworkInterface(
        id: id,
        deviceId: deviceId,
        name: name,
        description: description,
        macAddress: macAddress,
        ipAddress: ipAddress,
        subnetMask: subnetMask,
        gateway: gateway,
        dnsServers: dnsServers ?? [],
        connectionType: ConnectionType.fromValue(connectionType),
        isUp: isUp,
        isManagement: isManagement,
        mtu: mtu,
        speedMbps: speedMbps,
        duplex: duplex,
        mediaType: mediaType,
        index: index,
        vlanId: vlanId,
        switchPort: switchPort,
        connectedDeviceId: connectedDeviceId,
        connectedInterfaceName: connectedInterfaceName,
        bytesIn: bytesIn,
        bytesOut: bytesOut,
        packetsIn: packetsIn,
        packetsOut: packetsOut,
        errorsIn: errorsIn,
        errorsOut: errorsOut,
        dropsIn: dropsIn,
        dropsOut: dropsOut,
        utilizationPercent: utilizationPercent,
        lastStatusChange: lastStatusChange,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory InterfaceModel.fromEntity(NetworkInterface entity) =>
      InterfaceModel(
        id: entity.id,
        deviceId: entity.deviceId,
        name: entity.name,
        description: entity.description,
        macAddress: entity.macAddress,
        ipAddress: entity.ipAddress,
        subnetMask: entity.subnetMask,
        gateway: entity.gateway,
        dnsServers: entity.dnsServers,
        connectionType: entity.connectionType.value,
        isUp: entity.isUp,
        isManagement: entity.isManagement,
        mtu: entity.mtu,
        speedMbps: entity.speedMbps,
        duplex: entity.duplex,
        mediaType: entity.mediaType,
        index: entity.index,
        vlanId: entity.vlanId,
        switchPort: entity.switchPort,
        connectedDeviceId: entity.connectedDeviceId,
        connectedInterfaceName: entity.connectedInterfaceName,
        bytesIn: entity.bytesIn,
        bytesOut: entity.bytesOut,
        packetsIn: entity.packetsIn,
        packetsOut: entity.packetsOut,
        errorsIn: entity.errorsIn,
        errorsOut: entity.errorsOut,
        dropsIn: entity.dropsIn,
        dropsOut: entity.dropsOut,
        utilizationPercent: entity.utilizationPercent,
        lastStatusChange: entity.lastStatusChange,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

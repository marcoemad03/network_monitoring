import 'package:equatable/equatable.dart';
import '../../core/enums/connection_type.dart';

class NetworkInterface extends Equatable {
  final String id;
  final String deviceId;
  final String name;
  final String? description;
  final String? macAddress;
  final String? ipAddress;
  final String? subnetMask;
  final String? gateway;
  final List<String> dnsServers;
  final ConnectionType connectionType;
  final bool isUp;
  final bool isManagement;
  final int mtu;
  final double? speedMbps;
  final String? duplex;
  final String? mediaType;
  final int? mtuSize;
  final int? mtuMaximum;
  final int index;
  final int? vlanId;
  final String? switchPort;
  final String? connectedDeviceId;
  final String? connectedInterfaceName;
  final int bytesIn;
  final int bytesOut;
  final int packetsIn;
  final int packetsOut;
  final int errorsIn;
  final int errorsOut;
  final int dropsIn;
  final int dropsOut;
  final double? utilizationPercent;
  final DateTime? lastStatusChange;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NetworkInterface({
    required this.id,
    required this.deviceId,
    required this.name,
    this.description,
    this.macAddress,
    this.ipAddress,
    this.subnetMask,
    this.gateway,
    this.dnsServers = const [],
    this.connectionType = ConnectionType.ethernet,
    this.isUp = false,
    this.isManagement = false,
    this.mtu = 1500,
    this.speedMbps,
    this.duplex,
    this.mediaType,
    this.mtuSize,
    this.mtuMaximum,
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

  NetworkInterface copyWith({
    String? id,
    String? deviceId,
    String? name,
    String? description,
    String? macAddress,
    String? ipAddress,
    String? subnetMask,
    String? gateway,
    List<String>? dnsServers,
    ConnectionType? connectionType,
    bool? isUp,
    bool? isManagement,
    int? mtu,
    double? speedMbps,
    String? duplex,
    String? mediaType,
    int? mtuSize,
    int? mtuMaximum,
    int? index,
    int? vlanId,
    String? switchPort,
    String? connectedDeviceId,
    String? connectedInterfaceName,
    int? bytesIn,
    int? bytesOut,
    int? packetsIn,
    int? packetsOut,
    int? errorsIn,
    int? errorsOut,
    int? dropsIn,
    int? dropsOut,
    double? utilizationPercent,
    DateTime? lastStatusChange,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NetworkInterface(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      description: description ?? this.description,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      subnetMask: subnetMask ?? this.subnetMask,
      gateway: gateway ?? this.gateway,
      dnsServers: dnsServers ?? this.dnsServers,
      connectionType: connectionType ?? this.connectionType,
      isUp: isUp ?? this.isUp,
      isManagement: isManagement ?? this.isManagement,
      mtu: mtu ?? this.mtu,
      speedMbps: speedMbps ?? this.speedMbps,
      duplex: duplex ?? this.duplex,
      mediaType: mediaType ?? this.mediaType,
      mtuSize: mtuSize ?? this.mtuSize,
      mtuMaximum: mtuMaximum ?? this.mtuMaximum,
      index: index ?? this.index,
      vlanId: vlanId ?? this.vlanId,
      switchPort: switchPort ?? this.switchPort,
      connectedDeviceId: connectedDeviceId ?? this.connectedDeviceId,
      connectedInterfaceName: connectedInterfaceName ?? this.connectedInterfaceName,
      bytesIn: bytesIn ?? this.bytesIn,
      bytesOut: bytesOut ?? this.bytesOut,
      packetsIn: packetsIn ?? this.packetsIn,
      packetsOut: packetsOut ?? this.packetsOut,
      errorsIn: errorsIn ?? this.errorsIn,
      errorsOut: errorsOut ?? this.errorsOut,
      dropsIn: dropsIn ?? this.dropsIn,
      dropsOut: dropsOut ?? this.dropsOut,
      utilizationPercent: utilizationPercent ?? this.utilizationPercent,
      lastStatusChange: lastStatusChange ?? this.lastStatusChange,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        deviceId,
        name,
        description,
        macAddress,
        ipAddress,
        subnetMask,
        gateway,
        dnsServers,
        connectionType,
        isUp,
        isManagement,
        mtu,
        speedMbps,
        duplex,
        mediaType,
        mtuSize,
        mtuMaximum,
        index,
        vlanId,
        switchPort,
        connectedDeviceId,
        connectedInterfaceName,
        bytesIn,
        bytesOut,
        packetsIn,
        packetsOut,
        errorsIn,
        errorsOut,
        dropsIn,
        dropsOut,
        utilizationPercent,
        lastStatusChange,
        createdAt,
        updatedAt,
      ];
}

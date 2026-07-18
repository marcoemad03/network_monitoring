import 'package:equatable/equatable.dart';

class DeviceConnection extends Equatable {
  final String id;
  final String parentDeviceId;
  final String childDeviceId;
  final String? parentInterfaceId;
  final String? childInterfaceId;
  final String connectionType;
  final String medium;
  final double? speedMbps;
  final int? vlanId;
  final bool isActive;
  final String discoveredMethod;
  final DateTime discoveredAt;
  final DateTime lastSeen;

  const DeviceConnection({
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

  @override
  List<Object?> get props => [
        id, parentDeviceId, childDeviceId, parentInterfaceId,
        childInterfaceId, connectionType, medium, speedMbps,
        vlanId, isActive, discoveredMethod, discoveredAt, lastSeen,
      ];
}

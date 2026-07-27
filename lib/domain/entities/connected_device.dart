import 'package:equatable/equatable.dart';

class ConnectedDevice extends Equatable {
  final String id;
  final String deviceId;
  final String deviceName;
  final String? hostname;
  final String ipAddress;
  final String macAddress;
  final String? vendor;
  final String deviceType;
  final bool isOnline;
  final String connectionType;
  final String? connectedAccessPoint;
  final String? interfaceName;
  final double? currentUploadMbps;
  final double? currentDownloadMbps;
  final int? signalStrengthDbm;
  final String? department;
  final String? room;
  final String? notes;
  final DateTime lastSeen;

  const ConnectedDevice({
    required this.id,
    this.deviceId = '',
    required this.deviceName,
    this.hostname,
    required this.ipAddress,
    required this.macAddress,
    this.vendor,
    this.deviceType = 'unknown',
    required this.isOnline,
    required this.connectionType,
    this.connectedAccessPoint,
    this.interfaceName,
    this.currentUploadMbps,
    this.currentDownloadMbps,
    this.signalStrengthDbm,
    this.department,
    this.room,
    this.notes,
    required this.lastSeen,
  });

  @override
  List<Object?> get props => [
    id, deviceId, deviceName, hostname, ipAddress, macAddress,
    vendor, deviceType, isOnline, connectionType, connectedAccessPoint,
    interfaceName, currentUploadMbps, currentDownloadMbps,
    signalStrengthDbm, department, room, notes, lastSeen,
  ];
}

import 'package:equatable/equatable.dart';

class ConnectedDevice extends Equatable {
  final String id;
  final String deviceName;
  final String? hostname;
  final String ipAddress;
  final String macAddress;
  final bool isOnline;
  final String connectionType;
  final String? connectedAccessPoint;
  final String? interfaceName;
  final double? currentUploadMbps;
  final double? currentDownloadMbps;
  final int? signalStrengthDbm;
  final DateTime lastSeen;

  const ConnectedDevice({
    required this.id,
    required this.deviceName,
    this.hostname,
    required this.ipAddress,
    required this.macAddress,
    required this.isOnline,
    required this.connectionType,
    this.connectedAccessPoint,
    this.interfaceName,
    this.currentUploadMbps,
    this.currentDownloadMbps,
    this.signalStrengthDbm,
    required this.lastSeen,
  });

  @override
  List<Object?> get props => [
    id,
    deviceName,
    hostname,
    ipAddress,
    macAddress,
    isOnline,
    connectionType,
    connectedAccessPoint,
    interfaceName,
    currentUploadMbps,
    currentDownloadMbps,
    signalStrengthDbm,
    lastSeen,
  ];
}

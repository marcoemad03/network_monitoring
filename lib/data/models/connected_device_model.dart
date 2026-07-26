import '../../domain/entities/connected_device.dart';

class ConnectedDeviceModel {
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

  const ConnectedDeviceModel({
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

  factory ConnectedDeviceModel.fromJson(Map<String, dynamic> json) =>
      ConnectedDeviceModel(
        id:
            json['id']?.toString() ??
            json['mac_address']?.toString() ??
            json['ip_address']?.toString() ??
            '',
        deviceName: json['device_name']?.toString() ?? 'Unknown Device',
        hostname: json['hostname']?.toString(),
        ipAddress: json['ip_address']?.toString() ?? '',
        macAddress: json['mac_address']?.toString() ?? '',
        isOnline: json['is_online'] == true,
        connectionType: json['connection_type']?.toString() ?? 'LAN',
        connectedAccessPoint: json['connected_access_point']?.toString(),
        interfaceName: json['interface_name']?.toString(),
        currentUploadMbps: (json['current_upload_mbps'] as num?)?.toDouble(),
        currentDownloadMbps:
            (json['current_download_mbps'] as num?)?.toDouble(),
        signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt(),
        lastSeen:
            DateTime.tryParse(json['last_seen']?.toString() ?? '') ??
            DateTime.now(),
      );

  ConnectedDevice toEntity() => ConnectedDevice(
    id: id,
    deviceName: deviceName,
    hostname: hostname,
    ipAddress: ipAddress,
    macAddress: macAddress,
    isOnline: isOnline,
    connectionType: connectionType,
    connectedAccessPoint: connectedAccessPoint,
    interfaceName: interfaceName,
    currentUploadMbps: currentUploadMbps,
    currentDownloadMbps: currentDownloadMbps,
    signalStrengthDbm: signalStrengthDbm,
    lastSeen: lastSeen,
  );
}

import '../../domain/entities/connected_device.dart';

class ConnectedDeviceModel {
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

  const ConnectedDeviceModel({
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

  factory ConnectedDeviceModel.fromJson(Map<String, dynamic> json) =>
      ConnectedDeviceModel(
        id: json['id']?.toString() ?? json['mac_address']?.toString() ?? json['ip_address']?.toString() ?? '',
        deviceId: json['device_id']?.toString() ?? '',
        deviceName: json['device_name']?.toString() ?? 'Unknown Device',
        hostname: json['hostname']?.toString(),
        ipAddress: json['ip_address']?.toString() ?? '',
        macAddress: json['mac_address']?.toString() ?? '',
        vendor: json['vendor']?.toString(),
        deviceType: json['device_type']?.toString() ?? 'unknown',
        isOnline: json['is_online'] == true,
        connectionType: json['connection_type']?.toString() ?? 'LAN',
        connectedAccessPoint: json['connected_access_point']?.toString(),
        interfaceName: json['interface_name']?.toString(),
        currentUploadMbps: (json['current_upload_mbps'] as num?)?.toDouble(),
        currentDownloadMbps: (json['current_download_mbps'] as num?)?.toDouble(),
        signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt(),
        department: json['department']?.toString(),
        room: json['room']?.toString(),
        notes: json['notes']?.toString(),
        lastSeen: DateTime.tryParse(json['last_seen']?.toString() ?? '') ?? DateTime.now(),
      );

  ConnectedDevice toEntity() => ConnectedDevice(
    id: id,
    deviceId: deviceId,
    deviceName: deviceName,
    hostname: hostname,
    ipAddress: ipAddress,
    macAddress: macAddress,
    vendor: vendor,
    deviceType: deviceType,
    isOnline: isOnline,
    connectionType: connectionType,
    connectedAccessPoint: connectedAccessPoint,
    interfaceName: interfaceName,
    currentUploadMbps: currentUploadMbps,
    currentDownloadMbps: currentDownloadMbps,
    signalStrengthDbm: signalStrengthDbm,
    department: department,
    room: room,
    notes: notes,
    lastSeen: lastSeen,
  );
}

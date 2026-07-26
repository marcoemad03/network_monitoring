import '../../domain/entities/device_inventory.dart';

class DeviceInventoryModel {
  final String deviceId;
  final String deviceName;
  final String ipAddress;
  final String? macAddress;
  final String? vendor;
  final String? model;
  final String? osVersion;
  final String? serialNumber;
  final String? building;
  final String? floor;
  final String? room;
  final String? department;
  final String? connectionType;
  final String status;
  final String deviceType;
  final int? signalStrength;
  final DateTime lastSeen;
  final bool isPinned;
  final bool isCritical;
  final String? notes;
  final List<String> tags;

  const DeviceInventoryModel({
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    this.macAddress,
    this.vendor,
    this.model,
    this.osVersion,
    this.serialNumber,
    this.building,
    this.floor,
    this.room,
    this.department,
    this.connectionType,
    required this.status,
    required this.deviceType,
    this.signalStrength,
    required this.lastSeen,
    this.isPinned = false,
    this.isCritical = false,
    this.notes,
    this.tags = const [],
  });

  factory DeviceInventoryModel.fromJson(Map<String, dynamic> json) {
    return DeviceInventoryModel(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      ipAddress: json['ip_address'] as String,
      macAddress: json['mac_address'] as String?,
      vendor: json['vendor'] as String?,
      model: json['model'] as String?,
      osVersion: json['os_version'] as String?,
      serialNumber: json['serial_number'] as String?,
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      room: json['room'] as String?,
      department: json['department'] as String?,
      connectionType: json['connection_type'] as String?,
      status: json['status'] as String,
      deviceType: json['device_type'] as String,
      signalStrength: (json['signal_strength'] as num?)?.toInt(),
      lastSeen: DateTime.parse(json['last_seen'] as String),
      isPinned: json['is_pinned'] as bool? ?? false,
      isCritical: json['is_critical'] as bool? ?? false,
      notes: json['notes'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'mac_address': macAddress,
      'vendor': vendor,
      'model': model,
      'os_version': osVersion,
      'serial_number': serialNumber,
      'building': building,
      'floor': floor,
      'room': room,
      'department': department,
      'connection_type': connectionType,
      'status': status,
      'device_type': deviceType,
      'signal_strength': signalStrength,
      'last_seen': lastSeen.toIso8601String(),
      'is_pinned': isPinned,
      'is_critical': isCritical,
      'notes': notes,
      'tags': tags,
    };
  }

  DeviceInventory toEntity() => DeviceInventory(
        deviceId: deviceId,
        deviceName: deviceName,
        ipAddress: ipAddress,
        macAddress: macAddress,
        vendor: vendor,
        model: model,
        osVersion: osVersion,
        serialNumber: serialNumber,
        building: building,
        floor: floor,
        room: room,
        department: department,
        connectionType: connectionType,
        status: status,
        deviceType: deviceType,
        signalStrength: signalStrength,
        lastSeen: lastSeen,
        isPinned: isPinned,
        isCritical: isCritical,
        notes: notes,
        tags: tags,
      );

  factory DeviceInventoryModel.fromEntity(DeviceInventory entity) =>
      DeviceInventoryModel(
        deviceId: entity.deviceId,
        deviceName: entity.deviceName,
        ipAddress: entity.ipAddress,
        macAddress: entity.macAddress,
        vendor: entity.vendor,
        model: entity.model,
        osVersion: entity.osVersion,
        serialNumber: entity.serialNumber,
        building: entity.building,
        floor: entity.floor,
        room: entity.room,
        department: entity.department,
        connectionType: entity.connectionType,
        status: entity.status,
        deviceType: entity.deviceType,
        signalStrength: entity.signalStrength,
        lastSeen: entity.lastSeen,
        isPinned: entity.isPinned,
        isCritical: entity.isCritical,
        notes: entity.notes,
        tags: entity.tags,
      );
}

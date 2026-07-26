import 'package:equatable/equatable.dart';

class DeviceInventory extends Equatable {
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

  const DeviceInventory({
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

  DeviceInventory copyWith({
    String? deviceId,
    String? deviceName,
    String? ipAddress,
    String? macAddress,
    String? vendor,
    String? model,
    String? osVersion,
    String? serialNumber,
    String? building,
    String? floor,
    String? room,
    String? department,
    String? connectionType,
    String? status,
    String? deviceType,
    int? signalStrength,
    DateTime? lastSeen,
    bool? isPinned,
    bool? isCritical,
    String? notes,
    List<String>? tags,
  }) {
    return DeviceInventory(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      room: room ?? this.room,
      department: department ?? this.department,
      connectionType: connectionType ?? this.connectionType,
      status: status ?? this.status,
      deviceType: deviceType ?? this.deviceType,
      signalStrength: signalStrength ?? this.signalStrength,
      lastSeen: lastSeen ?? this.lastSeen,
      isPinned: isPinned ?? this.isPinned,
      isCritical: isCritical ?? this.isCritical,
      notes: notes ?? this.notes,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
        deviceId,
        deviceName,
        ipAddress,
        macAddress,
        vendor,
        model,
        osVersion,
        serialNumber,
        building,
        floor,
        room,
        department,
        connectionType,
        status,
        deviceType,
        signalStrength,
        lastSeen,
        isPinned,
        isCritical,
        notes,
        tags,
      ];
}

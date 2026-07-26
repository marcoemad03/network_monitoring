import 'package:equatable/equatable.dart';
import '../../core/enums/device_status.dart';
import '../../core/enums/device_type.dart';

class Device extends Equatable {
  final String id;
  final String name;
  final String? hostname;
  final String ipAddress;
  final String? macAddress;
  final DeviceType type;
  final DeviceStatus status;
  final String? vendor;
  final String? model;
  final String? serialNumber;
  final String? osVersion;
  final String? firmwareVersion;
  final String? location;
  final String? building;
  final String? floor;
  final String? room;
  final String? department;
  final String? notes;
  final String? connectionType;
  final String? connectedInterface;
  final String? ap;
  final String? switchInfo;
  final String? switchPort;
  final String? dhcpStatus;
  final int? leaseTime;
  final int? signalStrength;
  final int? currentDlSpeed;
  final int? currentUlSpeed;
  final int? totalDlBytes;
  final int? totalUlBytes;
  final bool isPinned;
  final Map<String, String> customFields;
  final DateTime firstSeen;
  final DateTime? lastBoot;
  final DateTime lastSeen;
  final bool isCritical;
  final bool isMonitored;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Device({
    required this.id,
    required this.name,
    this.hostname,
    required this.ipAddress,
    this.macAddress,
    required this.type,
    required this.status,
    this.vendor,
    this.model,
    this.serialNumber,
    this.osVersion,
    this.firmwareVersion,
    this.location,
    this.building,
    this.floor,
    this.room,
    this.department,
    this.notes,
    this.connectionType,
    this.connectedInterface,
    this.ap,
    this.switchInfo,
    this.switchPort,
    this.dhcpStatus,
    this.leaseTime,
    this.signalStrength,
    this.currentDlSpeed,
    this.currentUlSpeed,
    this.totalDlBytes,
    this.totalUlBytes,
    this.isPinned = false,
    this.customFields = const {},
    required this.firstSeen,
    this.lastBoot,
    required this.lastSeen,
    this.isCritical = false,
    this.isMonitored = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Device copyWith({
    String? id,
    String? name,
    String? hostname,
    String? ipAddress,
    String? macAddress,
    DeviceType? type,
    DeviceStatus? status,
    String? vendor,
    String? model,
    String? serialNumber,
    String? osVersion,
    String? firmwareVersion,
    String? location,
    String? building,
    String? floor,
    String? room,
    String? department,
    String? notes,
    String? connectionType,
    String? connectedInterface,
    String? ap,
    String? switchInfo,
    String? switchPort,
    String? dhcpStatus,
    int? leaseTime,
    int? signalStrength,
    int? currentDlSpeed,
    int? currentUlSpeed,
    int? totalDlBytes,
    int? totalUlBytes,
    bool? isPinned,
    Map<String, String>? customFields,
    DateTime? firstSeen,
    DateTime? lastBoot,
    DateTime? lastSeen,
    bool? isCritical,
    bool? isMonitored,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      ipAddress: ipAddress ?? this.ipAddress,
      macAddress: macAddress ?? this.macAddress,
      type: type ?? this.type,
      status: status ?? this.status,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      osVersion: osVersion ?? this.osVersion,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      location: location ?? this.location,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      room: room ?? this.room,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      connectionType: connectionType ?? this.connectionType,
      connectedInterface: connectedInterface ?? this.connectedInterface,
      ap: ap ?? this.ap,
      switchInfo: switchInfo ?? this.switchInfo,
      switchPort: switchPort ?? this.switchPort,
      dhcpStatus: dhcpStatus ?? this.dhcpStatus,
      leaseTime: leaseTime ?? this.leaseTime,
      signalStrength: signalStrength ?? this.signalStrength,
      currentDlSpeed: currentDlSpeed ?? this.currentDlSpeed,
      currentUlSpeed: currentUlSpeed ?? this.currentUlSpeed,
      totalDlBytes: totalDlBytes ?? this.totalDlBytes,
      totalUlBytes: totalUlBytes ?? this.totalUlBytes,
      isPinned: isPinned ?? this.isPinned,
      customFields: customFields ?? this.customFields,
      firstSeen: firstSeen ?? this.firstSeen,
      lastBoot: lastBoot ?? this.lastBoot,
      lastSeen: lastSeen ?? this.lastSeen,
      isCritical: isCritical ?? this.isCritical,
      isMonitored: isMonitored ?? this.isMonitored,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        hostname,
        ipAddress,
        macAddress,
        type,
        status,
        vendor,
        model,
        serialNumber,
        osVersion,
        firmwareVersion,
        location,
        building,
        floor,
        room,
        department,
        notes,
        connectionType,
        connectedInterface,
        ap,
        switchInfo,
        switchPort,
        dhcpStatus,
        leaseTime,
        signalStrength,
        currentDlSpeed,
        currentUlSpeed,
        totalDlBytes,
        totalUlBytes,
        isPinned,
        customFields,
        firstSeen,
        lastBoot,
        lastSeen,
        isCritical,
        isMonitored,
        createdAt,
        updatedAt,
      ];
}

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
  final String? department;
  final String? notes;
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
    this.department,
    this.notes,
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
    String? department,
    String? notes,
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
      department: department ?? this.department,
      notes: notes ?? this.notes,
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
        department,
        notes,
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

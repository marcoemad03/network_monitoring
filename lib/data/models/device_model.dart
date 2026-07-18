import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device.dart';
import '../../core/enums/device_status.dart';
import '../../core/enums/device_type.dart';

part 'device_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceModel {
  final String id;
  final String name;
  final String? hostname;
  @JsonKey(name: 'ip_address')
  final String ipAddress;
  @JsonKey(name: 'mac_address')
  final String? macAddress;
  @JsonKey(name: 'device_type')
  final String deviceType;
  final String status;
  final String? vendor;
  final String? model;
  @JsonKey(name: 'serial_number')
  final String? serialNumber;
  @JsonKey(name: 'os_version')
  final String? osVersion;
  @JsonKey(name: 'firmware_version')
  final String? firmwareVersion;
  final String? location;
  final String? department;
  final String? notes;
  @JsonKey(name: 'custom_fields')
  final Map<String, String>? customFields;
  @JsonKey(name: 'first_seen')
  final DateTime firstSeen;
  @JsonKey(name: 'last_boot')
  final DateTime? lastBoot;
  @JsonKey(name: 'last_seen')
  final DateTime lastSeen;
  @JsonKey(name: 'is_critical')
  final bool isCritical;
  @JsonKey(name: 'is_monitored')
  final bool isMonitored;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const DeviceModel({
    required this.id,
    required this.name,
    this.hostname,
    required this.ipAddress,
    this.macAddress,
    required this.deviceType,
    required this.status,
    this.vendor,
    this.model,
    this.serialNumber,
    this.osVersion,
    this.firmwareVersion,
    this.location,
    this.department,
    this.notes,
    this.customFields,
    required this.firstSeen,
    this.lastBoot,
    required this.lastSeen,
    this.isCritical = false,
    this.isMonitored = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);

  Device toEntity() => Device(
        id: id,
        name: name,
        hostname: hostname,
        ipAddress: ipAddress,
        macAddress: macAddress,
        type: DeviceType.fromValue(deviceType),
        status: DeviceStatus.fromValue(status),
        vendor: vendor,
        model: model,
        serialNumber: serialNumber,
        osVersion: osVersion,
        firmwareVersion: firmwareVersion,
        location: location,
        department: department,
        notes: notes,
        customFields: customFields ?? {},
        firstSeen: firstSeen,
        lastBoot: lastBoot,
        lastSeen: lastSeen,
        isCritical: isCritical,
        isMonitored: isMonitored,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory DeviceModel.fromEntity(Device entity) => DeviceModel(
        id: entity.id,
        name: entity.name,
        hostname: entity.hostname,
        ipAddress: entity.ipAddress,
        macAddress: entity.macAddress,
        deviceType: entity.type.value,
        status: entity.status.value,
        vendor: entity.vendor,
        model: entity.model,
        serialNumber: entity.serialNumber,
        osVersion: entity.osVersion,
        firmwareVersion: entity.firmwareVersion,
        location: entity.location,
        department: entity.department,
        notes: entity.notes,
        customFields: entity.customFields,
        firstSeen: entity.firstSeen,
        lastBoot: entity.lastBoot,
        lastSeen: entity.lastSeen,
        isCritical: entity.isCritical,
        isMonitored: entity.isMonitored,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

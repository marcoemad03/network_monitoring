import '../../domain/entities/device_control_log.dart';

class DeviceControlLogModel {
  final String id;
  final String deviceId;
  final String? deviceName;
  final String action;
  final Map<String, dynamic> details;
  final String? performedBy;
  final String? performedByName;
  final DateTime createdAt;

  const DeviceControlLogModel({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.action,
    this.details = const {},
    this.performedBy,
    this.performedByName,
    required this.createdAt,
  });

  factory DeviceControlLogModel.fromJson(Map<String, dynamic> json) {
    return DeviceControlLogModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String?,
      action: json['action'] as String,
      details: (json['details'] as Map<String, dynamic>?) ?? const {},
      performedBy: json['performed_by'] as String?,
      performedByName: json['performed_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'action': action,
      'details': details,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DeviceControlLog toEntity() => DeviceControlLog(
        id: id,
        deviceId: deviceId,
        deviceName: deviceName,
        action: action,
        details: details,
        performedBy: performedBy,
        performedByName: performedByName,
        createdAt: createdAt,
      );

  factory DeviceControlLogModel.fromEntity(DeviceControlLog entity) =>
      DeviceControlLogModel(
        id: entity.id,
        deviceId: entity.deviceId,
        deviceName: entity.deviceName,
        action: entity.action,
        details: entity.details,
        performedBy: entity.performedBy,
        performedByName: entity.performedByName,
        createdAt: entity.createdAt,
      );
}

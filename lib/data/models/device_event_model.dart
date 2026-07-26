import '../../domain/entities/device_event.dart';

class DeviceEventModel {
  final String id;
  final String deviceId;
  final String? deviceName;
  final String organizationId;
  final String eventType;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const DeviceEventModel({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.organizationId,
    required this.eventType,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  factory DeviceEventModel.fromJson(Map<String, dynamic> json) {
    return DeviceEventModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String?,
      organizationId: json['organization_id'] as String,
      eventType: json['event_type'] as String,
      description: json['description'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'organization_id': organizationId,
      'event_type': eventType,
      'description': description,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DeviceEvent toEntity() => DeviceEvent(
        id: id,
        deviceId: deviceId,
        deviceName: deviceName,
        organizationId: organizationId,
        eventType: eventType,
        description: description,
        metadata: metadata,
        createdAt: createdAt,
      );

  factory DeviceEventModel.fromEntity(DeviceEvent entity) => DeviceEventModel(
        id: entity.id,
        deviceId: entity.deviceId,
        deviceName: entity.deviceName,
        organizationId: entity.organizationId,
        eventType: entity.eventType,
        description: entity.description,
        metadata: entity.metadata,
        createdAt: entity.createdAt,
      );
}

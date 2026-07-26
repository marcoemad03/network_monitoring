import 'package:equatable/equatable.dart';

class DeviceEvent extends Equatable {
  final String id;
  final String deviceId;
  final String? deviceName;
  final String organizationId;
  final String eventType;
  final String description;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const DeviceEvent({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.organizationId,
    required this.eventType,
    required this.description,
    this.metadata = const {},
    required this.createdAt,
  });

  DeviceEvent copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? organizationId,
    String? eventType,
    String? description,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return DeviceEvent(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      organizationId: organizationId ?? this.organizationId,
      eventType: eventType ?? this.eventType,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        deviceId,
        deviceName,
        organizationId,
        eventType,
        description,
        metadata,
        createdAt,
      ];
}

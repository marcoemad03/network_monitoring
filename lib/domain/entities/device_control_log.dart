import 'package:equatable/equatable.dart';

class DeviceControlLog extends Equatable {
  final String id;
  final String deviceId;
  final String? deviceName;
  final String action;
  final Map<String, dynamic> details;
  final String? performedBy;
  final String? performedByName;
  final DateTime createdAt;

  const DeviceControlLog({
    required this.id,
    required this.deviceId,
    this.deviceName,
    required this.action,
    this.details = const {},
    this.performedBy,
    this.performedByName,
    required this.createdAt,
  });

  DeviceControlLog copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? action,
    Map<String, dynamic>? details,
    String? performedBy,
    String? performedByName,
    DateTime? createdAt,
  }) {
    return DeviceControlLog(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      action: action ?? this.action,
      details: details ?? this.details,
      performedBy: performedBy ?? this.performedBy,
      performedByName: performedByName ?? this.performedByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        deviceId,
        deviceName,
        action,
        details,
        performedBy,
        performedByName,
        createdAt,
      ];
}

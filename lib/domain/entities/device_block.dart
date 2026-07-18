import 'package:equatable/equatable.dart';

class DeviceBlock extends Equatable {
  final String id;
  final String organizationId;
  final String? deviceId;
  final String? macAddress;
  final String? ipAddress;
  final String? reason;
  final String? blockedBy;
  final DateTime blockedAt;
  final DateTime? unblockedAt;
  final bool isActive;

  const DeviceBlock({
    required this.id,
    required this.organizationId,
    this.deviceId,
    this.macAddress,
    this.ipAddress,
    this.reason,
    this.blockedBy,
    required this.blockedAt,
    this.unblockedAt,
    this.isActive = true,
  });

  DeviceBlock copyWith({
    String? id,
    String? organizationId,
    String? deviceId,
    String? macAddress,
    String? ipAddress,
    String? reason,
    String? blockedBy,
    DateTime? blockedAt,
    DateTime? unblockedAt,
    bool? isActive,
  }) {
    return DeviceBlock(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      deviceId: deviceId ?? this.deviceId,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      reason: reason ?? this.reason,
      blockedBy: blockedBy ?? this.blockedBy,
      blockedAt: blockedAt ?? this.blockedAt,
      unblockedAt: unblockedAt ?? this.unblockedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        deviceId,
        macAddress,
        ipAddress,
        reason,
        blockedBy,
        blockedAt,
        unblockedAt,
        isActive,
      ];
}

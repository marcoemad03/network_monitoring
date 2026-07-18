import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_block.dart';

part 'device_block_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceBlockModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'mac_address')
  final String? macAddress;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  final String? reason;
  @JsonKey(name: 'blocked_by')
  final String? blockedBy;
  @JsonKey(name: 'blocked_at')
  final DateTime blockedAt;
  @JsonKey(name: 'unblocked_at')
  final DateTime? unblockedAt;
  @JsonKey(name: 'is_active')
  final bool isActive;

  const DeviceBlockModel({
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

  factory DeviceBlockModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceBlockModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceBlockModelToJson(this);

  DeviceBlock toEntity() => DeviceBlock(
        id: id,
        organizationId: organizationId,
        deviceId: deviceId,
        macAddress: macAddress,
        ipAddress: ipAddress,
        reason: reason,
        blockedBy: blockedBy,
        blockedAt: blockedAt,
        unblockedAt: unblockedAt,
        isActive: isActive,
      );

  factory DeviceBlockModel.fromEntity(DeviceBlock entity) => DeviceBlockModel(
        id: entity.id,
        organizationId: entity.organizationId,
        deviceId: entity.deviceId,
        macAddress: entity.macAddress,
        ipAddress: entity.ipAddress,
        reason: entity.reason,
        blockedBy: entity.blockedBy,
        blockedAt: entity.blockedAt,
        unblockedAt: entity.unblockedAt,
        isActive: entity.isActive,
      );
}

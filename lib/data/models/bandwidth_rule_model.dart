import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/bandwidth_rule.dart';

part 'bandwidth_rule_model.g.dart';

@JsonSerializable(explicitToJson: true)
class BandwidthRuleModel {
  final String id;
  @JsonKey(name: 'policy_id')
  final String policyId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'user_id')
  final String? userId;
  final int priority;
  @JsonKey(name: 'upload_limit_bps')
  final int? uploadLimitBps;
  @JsonKey(name: 'download_limit_bps')
  final int? downloadLimitBps;
  @JsonKey(name: 'rule_type')
  final String ruleType;
  @JsonKey(name: 'is_temporary')
  final bool isTemporary;
  @JsonKey(name: 'temp_expires_at')
  final DateTime? tempExpiresAt;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const BandwidthRuleModel({
    required this.id,
    required this.policyId,
    this.deviceId,
    this.userId,
    this.priority = 500,
    this.uploadLimitBps,
    this.downloadLimitBps,
    required this.ruleType,
    this.isTemporary = false,
    this.tempExpiresAt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BandwidthRuleModel.fromJson(Map<String, dynamic> json) =>
      _$BandwidthRuleModelFromJson(json);

  Map<String, dynamic> toJson() => _$BandwidthRuleModelToJson(this);

  BandwidthRule toEntity() => BandwidthRule(
        id: id,
        policyId: policyId,
        deviceId: deviceId,
        userId: userId,
        priority: priority,
        uploadLimitBps: uploadLimitBps,
        downloadLimitBps: downloadLimitBps,
        ruleType: ruleType,
        isTemporary: isTemporary,
        tempExpiresAt: tempExpiresAt,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory BandwidthRuleModel.fromEntity(BandwidthRule entity) =>
      BandwidthRuleModel(
        id: entity.id,
        policyId: entity.policyId,
        deviceId: entity.deviceId,
        userId: entity.userId,
        priority: entity.priority,
        uploadLimitBps: entity.uploadLimitBps,
        downloadLimitBps: entity.downloadLimitBps,
        ruleType: entity.ruleType,
        isTemporary: entity.isTemporary,
        tempExpiresAt: entity.tempExpiresAt,
        isActive: entity.isActive,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

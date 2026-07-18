// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bandwidth_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BandwidthRuleModel _$BandwidthRuleModelFromJson(Map<String, dynamic> json) =>
    BandwidthRuleModel(
      id: json['id'] as String,
      policyId: json['policy_id'] as String,
      deviceId: json['device_id'] as String?,
      userId: json['user_id'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 500,
      uploadLimitBps: (json['upload_limit_bps'] as num?)?.toInt(),
      downloadLimitBps: (json['download_limit_bps'] as num?)?.toInt(),
      ruleType: json['rule_type'] as String,
      isTemporary: json['is_temporary'] as bool? ?? false,
      tempExpiresAt:
          json['temp_expires_at'] == null
              ? null
              : DateTime.parse(json['temp_expires_at'] as String),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$BandwidthRuleModelToJson(BandwidthRuleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'policy_id': instance.policyId,
      'device_id': instance.deviceId,
      'user_id': instance.userId,
      'priority': instance.priority,
      'upload_limit_bps': instance.uploadLimitBps,
      'download_limit_bps': instance.downloadLimitBps,
      'rule_type': instance.ruleType,
      'is_temporary': instance.isTemporary,
      'temp_expires_at': instance.tempExpiresAt?.toIso8601String(),
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

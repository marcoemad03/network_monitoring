// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'internet_policy_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InternetPolicyModel _$InternetPolicyModelFromJson(Map<String, dynamic> json) =>
    InternetPolicyModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      department: json['department'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      uploadLimitBps: (json['upload_limit_bps'] as num?)?.toInt(),
      downloadLimitBps: (json['download_limit_bps'] as num?)?.toInt(),
      policyType: json['policy_type'] as String,
      priority: (json['priority'] as num?)?.toInt() ?? 500,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$InternetPolicyModelToJson(
  InternetPolicyModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'name': instance.name,
  'description': instance.description,
  'department': instance.department,
  'is_active': instance.isActive,
  'upload_limit_bps': instance.uploadLimitBps,
  'download_limit_bps': instance.downloadLimitBps,
  'policy_type': instance.policyType,
  'priority': instance.priority,
  'created_by': instance.createdBy,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

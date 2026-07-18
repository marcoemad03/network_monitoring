// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'filtering_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FilteringRuleModel _$FilteringRuleModelFromJson(Map<String, dynamic> json) =>
    FilteringRuleModel(
      id: json['id'] as String,
      policyId: json['policy_id'] as String,
      ruleType: json['rule_type'] as String,
      filterType: json['filter_type'] as String,
      value: json['value'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$FilteringRuleModelToJson(FilteringRuleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'policy_id': instance.policyId,
      'rule_type': instance.ruleType,
      'filter_type': instance.filterType,
      'value': instance.value,
      'description': instance.description,
      'is_active': instance.isActive,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

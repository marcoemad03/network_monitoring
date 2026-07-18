// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_rule_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlertRuleModel _$AlertRuleModelFromJson(Map<String, dynamic> json) =>
    AlertRuleModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      metric: json['metric'] as String,
      condition: json['condition'] as String,
      threshold: (json['threshold'] as num).toDouble(),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 5,
      severity: json['severity'] as String? ?? 'warning',
      channels:
          (json['channels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['email'],
      isActive: json['is_active'] as bool? ?? true,
      notifyRoles:
          (json['notify_roles'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      cooldownMinutes: (json['cooldown_minutes'] as num?)?.toInt() ?? 30,
      lastTriggeredAt:
          json['last_triggered_at'] == null
              ? null
              : DateTime.parse(json['last_triggered_at'] as String),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AlertRuleModelToJson(AlertRuleModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'name': instance.name,
      'description': instance.description,
      'metric': instance.metric,
      'condition': instance.condition,
      'threshold': instance.threshold,
      'duration_minutes': instance.durationMinutes,
      'severity': instance.severity,
      'channels': instance.channels,
      'is_active': instance.isActive,
      'notify_roles': instance.notifyRoles,
      'cooldown_minutes': instance.cooldownMinutes,
      'last_triggered_at': instance.lastTriggeredAt?.toIso8601String(),
      'created_by': instance.createdBy,
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

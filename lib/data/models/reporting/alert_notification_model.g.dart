// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_notification_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlertNotificationModel _$AlertNotificationModelFromJson(
  Map<String, dynamic> json,
) => AlertNotificationModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  ruleId: json['rule_id'] as String?,
  title: json['title'] as String,
  message: json['message'] as String,
  severity: json['severity'] as String? ?? 'warning',
  metricName: json['metric_name'] as String?,
  metricValue: (json['metric_value'] as num?)?.toDouble(),
  threshold: (json['threshold'] as num?)?.toDouble(),
  triggeredAt: DateTime.parse(json['triggered_at'] as String),
  acknowledgedAt:
      json['acknowledged_at'] == null
          ? null
          : DateTime.parse(json['acknowledged_at'] as String),
  acknowledgedBy: json['acknowledged_by'] as String?,
  isRead: json['is_read'] as bool? ?? false,
  channel: json['channel'] as String? ?? 'email',
);

Map<String, dynamic> _$AlertNotificationModelToJson(
  AlertNotificationModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'rule_id': instance.ruleId,
  'title': instance.title,
  'message': instance.message,
  'severity': instance.severity,
  'metric_name': instance.metricName,
  'metric_value': instance.metricValue,
  'threshold': instance.threshold,
  'triggered_at': instance.triggeredAt.toIso8601String(),
  'acknowledged_at': instance.acknowledgedAt?.toIso8601String(),
  'acknowledged_by': instance.acknowledgedBy,
  'is_read': instance.isRead,
  'channel': instance.channel,
};

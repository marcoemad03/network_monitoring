// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AlertModel _$AlertModelFromJson(Map<String, dynamic> json) => AlertModel(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String,
  severity: json['severity'] as String,
  status: json['status'] as String,
  category: json['category'] as String,
  deviceId: json['device_id'] as String?,
  deviceName: json['device_name'] as String?,
  interfaceId: json['interface_id'] as String?,
  interfaceName: json['interface_name'] as String?,
  metricName: json['metric_name'] as String?,
  metricValue: (json['metric_value'] as num?)?.toDouble(),
  thresholdValue: (json['threshold_value'] as num?)?.toDouble(),
  ruleId: json['rule_id'] as String?,
  acknowledgedBy: json['acknowledged_by'] as String?,
  acknowledgedAt:
      json['acknowledged_at'] == null
          ? null
          : DateTime.parse(json['acknowledged_at'] as String),
  resolvedBy: json['resolved_by'] as String?,
  resolvedAt:
      json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
  resolutionNotes: json['resolution_notes'] as String?,
  occurrenceCount: (json['occurrence_count'] as num?)?.toInt() ?? 1,
  isSuppressed: json['is_suppressed'] as bool? ?? false,
  suppressedUntil:
      json['suppressed_until'] == null
          ? null
          : DateTime.parse(json['suppressed_until'] as String),
  detectedAt: DateTime.parse(json['detected_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$AlertModelToJson(AlertModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'severity': instance.severity,
      'status': instance.status,
      'category': instance.category,
      'device_id': instance.deviceId,
      'device_name': instance.deviceName,
      'interface_id': instance.interfaceId,
      'interface_name': instance.interfaceName,
      'metric_name': instance.metricName,
      'metric_value': instance.metricValue,
      'threshold_value': instance.thresholdValue,
      'rule_id': instance.ruleId,
      'acknowledged_by': instance.acknowledgedBy,
      'acknowledged_at': instance.acknowledgedAt?.toIso8601String(),
      'resolved_by': instance.resolvedBy,
      'resolved_at': instance.resolvedAt?.toIso8601String(),
      'resolution_notes': instance.resolutionNotes,
      'occurrence_count': instance.occurrenceCount,
      'is_suppressed': instance.isSuppressed,
      'suppressed_until': instance.suppressedUntil?.toIso8601String(),
      'detected_at': instance.detectedAt.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt.toIso8601String(),
    };

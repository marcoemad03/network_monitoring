// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogModel _$AuditLogModelFromJson(Map<String, dynamic> json) =>
    AuditLogModel(
      id: json['id'] as String,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      entityName: json['entity_name'] as String?,
      performedBy: json['performed_by'] as String,
      performedByName: json['performed_by_name'] as String?,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      previousValues: json['previous_values'] as Map<String, dynamic>?,
      newValues: json['new_values'] as Map<String, dynamic>?,
      description: json['description'] as String?,
      isSuccess: json['is_success'] as bool? ?? true,
      failureReason: json['failure_reason'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$AuditLogModelToJson(AuditLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'action': instance.action,
      'entity_type': instance.entityType,
      'entity_id': instance.entityId,
      'entity_name': instance.entityName,
      'performed_by': instance.performedBy,
      'performed_by_name': instance.performedByName,
      'ip_address': instance.ipAddress,
      'user_agent': instance.userAgent,
      'previous_values': instance.previousValues,
      'new_values': instance.newValues,
      'description': instance.description,
      'is_success': instance.isSuccess,
      'failure_reason': instance.failureReason,
      'timestamp': instance.timestamp.toIso8601String(),
    };

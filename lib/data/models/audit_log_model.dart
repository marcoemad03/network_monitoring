import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/audit_log.dart';

part 'audit_log_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AuditLogModel {
  final String id;
  final String action;
  @JsonKey(name: 'entity_type')
  final String entityType;
  @JsonKey(name: 'entity_id')
  final String entityId;
  @JsonKey(name: 'entity_name')
  final String? entityName;
  @JsonKey(name: 'performed_by')
  final String performedBy;
  @JsonKey(name: 'performed_by_name')
  final String? performedByName;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  @JsonKey(name: 'user_agent')
  final String? userAgent;
  @JsonKey(name: 'previous_values')
  final Map<String, dynamic>? previousValues;
  @JsonKey(name: 'new_values')
  final Map<String, dynamic>? newValues;
  final String? description;
  @JsonKey(name: 'is_success')
  final bool isSuccess;
  @JsonKey(name: 'failure_reason')
  final String? failureReason;
  final DateTime timestamp;

  const AuditLogModel({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    this.entityName,
    required this.performedBy,
    this.performedByName,
    this.ipAddress,
    this.userAgent,
    this.previousValues,
    this.newValues,
    this.description,
    this.isSuccess = true,
    this.failureReason,
    required this.timestamp,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) =>
      _$AuditLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$AuditLogModelToJson(this);

  AuditLog toEntity() => AuditLog(
        id: id,
        action: AuditAction.values.firstWhere(
          (a) => a.name == action,
          orElse: () => AuditAction.other,
        ),
        entityType: AuditEntityType.values.firstWhere(
          (t) => t.name == entityType,
          orElse: () => AuditEntityType.device,
        ),
        entityId: entityId,
        entityName: entityName,
        performedBy: performedBy,
        performedByName: performedByName,
        ipAddress: ipAddress,
        userAgent: userAgent,
        previousValues: previousValues,
        newValues: newValues,
        description: description,
        isSuccess: isSuccess,
        failureReason: failureReason,
        timestamp: timestamp,
      );

  factory AuditLogModel.fromEntity(AuditLog entity) => AuditLogModel(
        id: entity.id,
        action: entity.action.name,
        entityType: entity.entityType.name,
        entityId: entity.entityId,
        entityName: entity.entityName,
        performedBy: entity.performedBy,
        performedByName: entity.performedByName,
        ipAddress: entity.ipAddress,
        userAgent: entity.userAgent,
        previousValues: entity.previousValues,
        newValues: entity.newValues,
        description: entity.description,
        isSuccess: entity.isSuccess,
        failureReason: entity.failureReason,
        timestamp: entity.timestamp,
      );
}

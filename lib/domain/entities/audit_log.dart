import 'package:equatable/equatable.dart';

enum AuditAction {
  login,
  logout,
  create,
  update,
  delete,
  acknowledge,
  resolve,
  scan,
  export,
  configuration,
  permissionChange,
  systemSetting,
  other
}

enum AuditEntityType {
  device,
  interface,
  alert,
  user,
  scan,
  configuration,
  system,
  report,
}

class AuditLog extends Equatable {
  final String id;
  final AuditAction action;
  final AuditEntityType entityType;
  final String entityId;
  final String? entityName;
  final String performedBy;
  final String? performedByName;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic>? previousValues;
  final Map<String, dynamic>? newValues;
  final String? description;
  final bool isSuccess;
  final String? failureReason;
  final DateTime timestamp;

  const AuditLog({
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

  @override
  List<Object?> get props => [
        id,
        action,
        entityType,
        entityId,
        entityName,
        performedBy,
        performedByName,
        ipAddress,
        userAgent,
        previousValues,
        newValues,
        description,
        isSuccess,
        failureReason,
        timestamp,
      ];
}

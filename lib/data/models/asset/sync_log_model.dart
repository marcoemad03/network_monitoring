import '../../../domain/entities/asset/sync_log.dart';

class SyncLogModel {
  final String id;
  final String organizationId;
  final String? vendorIntegrationId;
  final String status;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const SyncLogModel({
    required this.id,
    required this.organizationId,
    this.vendorIntegrationId,
    required this.status,
    this.details = const {},
    required this.createdAt,
  });

  factory SyncLogModel.fromJson(Map<String, dynamic> json) {
    return SyncLogModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      vendorIntegrationId: json['vendor_integration_id'] as String?,
      status: json['status'] as String,
      details: (json['details'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    if (vendorIntegrationId != null) 'vendor_integration_id': vendorIntegrationId,
    'status': status,
    'details': details,
    'created_at': createdAt.toIso8601String(),
  };

  SyncLog toEntity() => SyncLog(
    id: id,
    organizationId: organizationId,
    vendorIntegrationId: vendorIntegrationId,
    status: status,
    details: details,
    createdAt: createdAt,
  );

  factory SyncLogModel.fromEntity(SyncLog entity) => SyncLogModel(
    id: entity.id,
    organizationId: entity.organizationId,
    vendorIntegrationId: entity.vendorIntegrationId,
    status: entity.status,
    details: entity.details,
    createdAt: entity.createdAt,
  );
}

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_integration_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VendorIntegrationModel _$VendorIntegrationModelFromJson(
  Map<String, dynamic> json,
) => VendorIntegrationModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  vendorType: json['vendor_type'] as String,
  name: json['name'] as String,
  baseUrl: json['base_url'] as String,
  username: json['username'] as String?,
  apiVersion: json['api_version'] as String?,
  isActive: json['is_active'] as bool? ?? true,
  lastSyncAt:
      json['last_sync_at'] == null
          ? null
          : DateTime.parse(json['last_sync_at'] as String),
  lastSyncStatus: json['last_sync_status'] as String?,
  errorMessage: json['error_message'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$VendorIntegrationModelToJson(
  VendorIntegrationModel instance,
) => <String, dynamic>{
  'id': instance.id,
  'organization_id': instance.organizationId,
  'vendor_type': instance.vendorType,
  'name': instance.name,
  'base_url': instance.baseUrl,
  'username': instance.username,
  'api_version': instance.apiVersion,
  'is_active': instance.isActive,
  'last_sync_at': instance.lastSyncAt?.toIso8601String(),
  'last_sync_status': instance.lastSyncStatus,
  'error_message': instance.errorMessage,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

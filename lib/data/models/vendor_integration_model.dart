import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/vendor_integration.dart';

part 'vendor_integration_model.g.dart';

@JsonSerializable(explicitToJson: true)
class VendorIntegrationModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'vendor_type')
  final String vendorType;
  final String name;
  @JsonKey(name: 'base_url')
  final String baseUrl;
  final String? username;
  @JsonKey(name: 'api_version')
  final String? apiVersion;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'last_sync_at')
  final DateTime? lastSyncAt;
  @JsonKey(name: 'last_sync_status')
  final String? lastSyncStatus;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const VendorIntegrationModel({
    required this.id,
    required this.organizationId,
    required this.vendorType,
    required this.name,
    required this.baseUrl,
    this.username,
    this.apiVersion,
    this.isActive = true,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorIntegrationModel.fromJson(Map<String, dynamic> json) =>
      _$VendorIntegrationModelFromJson(json);

  Map<String, dynamic> toJson() => _$VendorIntegrationModelToJson(this);

  VendorIntegration toEntity() => VendorIntegration(
        id: id,
        organizationId: organizationId,
        vendorType: vendorType,
        name: name,
        baseUrl: baseUrl,
        username: username,
        apiVersion: apiVersion,
        isActive: isActive,
        lastSyncAt: lastSyncAt,
        lastSyncStatus: lastSyncStatus,
        errorMessage: errorMessage,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory VendorIntegrationModel.fromEntity(VendorIntegration entity) =>
      VendorIntegrationModel(
        id: entity.id,
        organizationId: entity.organizationId,
        vendorType: entity.vendorType,
        name: entity.name,
        baseUrl: entity.baseUrl,
        username: entity.username,
        apiVersion: entity.apiVersion,
        isActive: entity.isActive,
        lastSyncAt: entity.lastSyncAt,
        lastSyncStatus: entity.lastSyncStatus,
        errorMessage: entity.errorMessage,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

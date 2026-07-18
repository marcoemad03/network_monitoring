import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/internet_policy.dart';

part 'internet_policy_model.g.dart';

@JsonSerializable(explicitToJson: true)
class InternetPolicyModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  final String name;
  final String? description;
  final String? department;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'upload_limit_bps')
  final int? uploadLimitBps;
  @JsonKey(name: 'download_limit_bps')
  final int? downloadLimitBps;
  @JsonKey(name: 'policy_type')
  final String policyType;
  final int priority;
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const InternetPolicyModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.department,
    this.isActive = true,
    this.uploadLimitBps,
    this.downloadLimitBps,
    required this.policyType,
    this.priority = 500,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InternetPolicyModel.fromJson(Map<String, dynamic> json) =>
      _$InternetPolicyModelFromJson(json);

  Map<String, dynamic> toJson() => _$InternetPolicyModelToJson(this);

  InternetPolicy toEntity() => InternetPolicy(
        id: id,
        organizationId: organizationId,
        name: name,
        description: description,
        department: department,
        isActive: isActive,
        uploadLimitBps: uploadLimitBps,
        downloadLimitBps: downloadLimitBps,
        policyType: policyType,
        priority: priority,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory InternetPolicyModel.fromEntity(InternetPolicy entity) =>
      InternetPolicyModel(
        id: entity.id,
        organizationId: entity.organizationId,
        name: entity.name,
        description: entity.description,
        department: entity.department,
        isActive: entity.isActive,
        uploadLimitBps: entity.uploadLimitBps,
        downloadLimitBps: entity.downloadLimitBps,
        policyType: entity.policyType,
        priority: entity.priority,
        createdBy: entity.createdBy,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

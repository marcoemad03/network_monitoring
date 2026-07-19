import '../../../domain/entities/asset/policy.dart';

class PolicyModel {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String policyType;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PolicyModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    required this.policyType,
    this.config = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PolicyModel.fromJson(Map<String, dynamic> json) {
    return PolicyModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      policyType: json['policy_type'] as String,
      config: (json['config'] as Map<String, dynamic>?) ?? {},
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    if (description != null) 'description': description,
    'policy_type': policyType,
    'config': config,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  Policy toEntity() => Policy(
    id: id,
    organizationId: organizationId,
    name: name,
    description: description,
    policyType: policyType,
    config: config,
    isActive: isActive,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory PolicyModel.fromEntity(Policy entity) => PolicyModel(
    id: entity.id,
    organizationId: entity.organizationId,
    name: entity.name,
    description: entity.description,
    policyType: entity.policyType,
    config: entity.config,
    isActive: entity.isActive,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}

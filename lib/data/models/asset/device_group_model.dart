import '../../../domain/entities/asset/device_group.dart';

class DeviceGroupModel {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? parentGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceGroupModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.parentGroupId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceGroupModel.fromJson(Map<String, dynamic> json) {
    return DeviceGroupModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentGroupId: json['parent_group_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    if (description != null) 'description': description,
    if (parentGroupId != null) 'parent_group_id': parentGroupId,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  DeviceGroup toEntity() => DeviceGroup(
    id: id,
    organizationId: organizationId,
    name: name,
    description: description,
    parentGroupId: parentGroupId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory DeviceGroupModel.fromEntity(DeviceGroup entity) => DeviceGroupModel(
    id: entity.id,
    organizationId: entity.organizationId,
    name: entity.name,
    description: entity.description,
    parentGroupId: entity.parentGroupId,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}

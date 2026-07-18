// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permission_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PermissionModel _$PermissionModelFromJson(Map<String, dynamic> json) =>
    PermissionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      module: json['module'] as String,
    );

Map<String, dynamic> _$PermissionModelToJson(PermissionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'description': instance.description,
      'module': instance.module,
    };

RoleModel _$RoleModelFromJson(Map<String, dynamic> json) => RoleModel(
  id: json['id'] as String,
  name: json['name'] as String,
  slug: json['slug'] as String,
  description: json['description'] as String?,
  permissionLevel: (json['permission_level'] as num).toInt(),
  isSystemRole: json['is_system_role'] as bool? ?? false,
);

Map<String, dynamic> _$RoleModelToJson(RoleModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
  'description': instance.description,
  'permission_level': instance.permissionLevel,
  'is_system_role': instance.isSystemRole,
};

RoleWithPermissionsModel _$RoleWithPermissionsModelFromJson(
  Map<String, dynamic> json,
) => RoleWithPermissionsModel(
  role: RoleModel.fromJson(json['role'] as Map<String, dynamic>),
  permissions:
      (json['permissions'] as List<dynamic>)
          .map((e) => PermissionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
);

Map<String, dynamic> _$RoleWithPermissionsModelToJson(
  RoleWithPermissionsModel instance,
) => <String, dynamic>{
  'role': instance.role,
  'permissions': instance.permissions,
};

UserSessionModel _$UserSessionModelFromJson(Map<String, dynamic> json) =>
    UserSessionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      isRevoked: json['is_revoked'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$UserSessionModelToJson(UserSessionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'ip_address': instance.ipAddress,
      'user_agent': instance.userAgent,
      'last_activity': instance.lastActivity.toIso8601String(),
      'expires_at': instance.expiresAt.toIso8601String(),
      'is_revoked': instance.isRevoked,
      'created_at': instance.createdAt.toIso8601String(),
    };

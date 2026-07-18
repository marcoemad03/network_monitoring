import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/permission.dart';

part 'permission_model.g.dart';

@JsonSerializable()
class PermissionModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String module;

  const PermissionModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.module,
  });

  factory PermissionModel.fromJson(Map<String, dynamic> json) => _$PermissionModelFromJson(json);
  Map<String, dynamic> toJson() => _$PermissionModelToJson(this);

  Permission toEntity() => Permission(
        id: id,
        name: name,
        slug: slug,
        description: description,
        module: module,
      );
}

@JsonSerializable()
class RoleModel {
  final String id;
  final String name;
  final String slug;
  final String? description;
  @JsonKey(name: 'permission_level')
  final int permissionLevel;
  @JsonKey(name: 'is_system_role')
  final bool isSystemRole;

  const RoleModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.permissionLevel,
    this.isSystemRole = false,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) => _$RoleModelFromJson(json);
  Map<String, dynamic> toJson() => _$RoleModelToJson(this);

  Role toEntity() => Role(
        id: id,
        name: name,
        slug: slug,
        description: description,
        permissionLevel: permissionLevel,
        isSystemRole: isSystemRole,
      );
}

@JsonSerializable()
class RoleWithPermissionsModel {
  final RoleModel role;
  final List<PermissionModel> permissions;

  const RoleWithPermissionsModel({required this.role, required this.permissions});

  factory RoleWithPermissionsModel.fromJson(Map<String, dynamic> json) =>
      _$RoleWithPermissionsModelFromJson(json);
  Map<String, dynamic> toJson() => _$RoleWithPermissionsModelToJson(this);

  RoleWithPermissions toEntity() => RoleWithPermissions(
        role: role.toEntity(),
        permissions: permissions.map((p) => p.toEntity()).toList(),
      );
}

@JsonSerializable()
class UserSessionModel {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  @JsonKey(name: 'user_agent')
  final String? userAgent;
  @JsonKey(name: 'last_activity')
  final DateTime lastActivity;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'is_revoked')
  final bool isRevoked;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const UserSessionModel({
    required this.id,
    required this.userId,
    this.ipAddress,
    this.userAgent,
    required this.lastActivity,
    required this.expiresAt,
    this.isRevoked = false,
    required this.createdAt,
  });

  factory UserSessionModel.fromJson(Map<String, dynamic> json) =>
      _$UserSessionModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserSessionModelToJson(this);

  UserSession toEntity() => UserSession(
        id: id,
        userId: userId,
        ipAddress: ipAddress,
        userAgent: userAgent,
        lastActivity: lastActivity,
        expiresAt: expiresAt,
        isRevoked: isRevoked,
        createdAt: createdAt,
      );
}

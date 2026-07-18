import 'package:equatable/equatable.dart';

class Permission extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String module;

  const Permission({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.module,
  });

  @override
  List<Object?> get props => [id, name, slug, description, module];
}

class Role extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final int permissionLevel;
  final bool isSystemRole;

  const Role({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.permissionLevel,
    this.isSystemRole = false,
  });

  @override
  List<Object?> get props => [id, name, slug, description, permissionLevel, isSystemRole];
}

class RoleWithPermissions extends Equatable {
  final Role role;
  final List<Permission> permissions;

  const RoleWithPermissions({required this.role, required this.permissions});

  @override
  List<Object?> get props => [role, permissions];
}

class UserSession extends Equatable {
  final String id;
  final String userId;
  final String? ipAddress;
  final String? userAgent;
  final DateTime lastActivity;
  final DateTime expiresAt;
  final bool isRevoked;
  final DateTime createdAt;

  const UserSession({
    required this.id,
    required this.userId,
    this.ipAddress,
    this.userAgent,
    required this.lastActivity,
    required this.expiresAt,
    this.isRevoked = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, userId, ipAddress, userAgent, lastActivity, expiresAt, isRevoked, createdAt];
}

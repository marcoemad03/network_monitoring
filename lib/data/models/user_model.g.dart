// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
  id: json['id'] as String,
  username: json['username'] as String,
  email: json['email'] as String,
  displayName: json['display_name'] as String?,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  role: json['role'] as String,
  isActive: json['is_active'] as bool? ?? true,
  isLocked: json['is_locked'] as bool? ?? false,
  isMfaEnabled: json['is_mfa_enabled'] as bool? ?? false,
  department: json['department'] as String?,
  title: json['title'] as String?,
  phone: json['phone'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  lastLoginAt:
      json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at'] as String),
  lastLoginIp: json['last_login_ip'] as String?,
  failedLoginAttempts: (json['failed_login_attempts'] as num?)?.toInt() ?? 0,
  passwordChangedAt:
      json['password_changed_at'] == null
          ? null
          : DateTime.parse(json['password_changed_at'] as String),
  lockedUntil:
      json['locked_until'] == null
          ? null
          : DateTime.parse(json['locked_until'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
  'id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'display_name': instance.displayName,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'role': instance.role,
  'is_active': instance.isActive,
  'is_locked': instance.isLocked,
  'is_mfa_enabled': instance.isMfaEnabled,
  'department': instance.department,
  'title': instance.title,
  'phone': instance.phone,
  'avatar_url': instance.avatarUrl,
  'last_login_at': instance.lastLoginAt?.toIso8601String(),
  'last_login_ip': instance.lastLoginIp,
  'failed_login_attempts': instance.failedLoginAttempts,
  'password_changed_at': instance.passwordChangedAt?.toIso8601String(),
  'locked_until': instance.lockedUntil?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
};

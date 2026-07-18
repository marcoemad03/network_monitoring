import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/user.dart';
import '../../core/enums/user_role.dart';

part 'user_model.g.dart';

@JsonSerializable(explicitToJson: true)
class UserModel {
  final String id;
  final String username;
  final String email;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  final String role;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'is_locked')
  final bool isLocked;
  @JsonKey(name: 'is_mfa_enabled')
  final bool isMfaEnabled;
  final String? department;
  final String? title;
  final String? phone;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  @JsonKey(name: 'last_login_at')
  final DateTime? lastLoginAt;
  @JsonKey(name: 'last_login_ip')
  final String? lastLoginIp;
  @JsonKey(name: 'failed_login_attempts')
  final int failedLoginAttempts;
  @JsonKey(name: 'password_changed_at')
  final DateTime? passwordChangedAt;
  @JsonKey(name: 'locked_until')
  final DateTime? lockedUntil;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.firstName,
    this.lastName,
    required this.role,
    this.isActive = true,
    this.isLocked = false,
    this.isMfaEnabled = false,
    this.department,
    this.title,
    this.phone,
    this.avatarUrl,
    this.lastLoginAt,
    this.lastLoginIp,
    this.failedLoginAttempts = 0,
    this.passwordChangedAt,
    this.lockedUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  User toEntity() => User(
        id: id,
        username: username,
        email: email,
        displayName: displayName,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.fromValue(role),
        isActive: isActive,
        isLocked: isLocked,
        isMfaEnabled: isMfaEnabled,
        department: department,
        title: title,
        phone: phone,
        avatarUrl: avatarUrl,
        lastLoginAt: lastLoginAt,
        lastLoginIp: lastLoginIp,
        failedLoginAttempts: failedLoginAttempts,
        passwordChangedAt: passwordChangedAt,
        lockedUntil: lockedUntil,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory UserModel.fromEntity(User entity) => UserModel(
        id: entity.id,
        username: entity.username,
        email: entity.email,
        displayName: entity.displayName,
        firstName: entity.firstName,
        lastName: entity.lastName,
        role: entity.role.value,
        isActive: entity.isActive,
        isLocked: entity.isLocked,
        isMfaEnabled: entity.isMfaEnabled,
        department: entity.department,
        title: entity.title,
        phone: entity.phone,
        avatarUrl: entity.avatarUrl,
        lastLoginAt: entity.lastLoginAt,
        lastLoginIp: entity.lastLoginIp,
        failedLoginAttempts: entity.failedLoginAttempts,
        passwordChangedAt: entity.passwordChangedAt,
        lockedUntil: entity.lockedUntil,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}

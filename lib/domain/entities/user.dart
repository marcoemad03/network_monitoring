import 'package:equatable/equatable.dart';
import '../../core/enums/user_role.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final UserRole role;
  final bool isActive;
  final bool isLocked;
  final bool isMfaEnabled;
  final String? department;
  final String? title;
  final String? phone;
  final String? avatarUrl;
  final DateTime? lastLoginAt;
  final String? lastLoginIp;
  final int failedLoginAttempts;
  final DateTime? passwordChangedAt;
  final DateTime? lockedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
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

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    UserRole? role,
    bool? isActive,
    bool? isLocked,
    bool? isMfaEnabled,
    String? department,
    String? title,
    String? phone,
    String? avatarUrl,
    DateTime? lastLoginAt,
    String? lastLoginIp,
    int? failedLoginAttempts,
    DateTime? passwordChangedAt,
    DateTime? lockedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isLocked: isLocked ?? this.isLocked,
      isMfaEnabled: isMfaEnabled ?? this.isMfaEnabled,
      department: department ?? this.department,
      title: title ?? this.title,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLoginIp: lastLoginIp ?? this.lastLoginIp,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      lockedUntil: lockedUntil ?? this.lockedUntil,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get fullName => displayName ?? '$firstName $lastName';

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        displayName,
        firstName,
        lastName,
        role,
        isActive,
        isLocked,
        isMfaEnabled,
        department,
        title,
        phone,
        avatarUrl,
        lastLoginAt,
        lastLoginIp,
        failedLoginAttempts,
        passwordChangedAt,
        lockedUntil,
        createdAt,
        updatedAt,
      ];
}

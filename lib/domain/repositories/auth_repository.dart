import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/user.dart';
import '../entities/permission.dart';

abstract class AuthRepository {
  Future<Either<Failure, User>> login({
    required String username,
    required String password,
  });
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, User>> getCurrentUser();
  Future<Either<Failure, bool>> refreshToken();
  Future<Either<Failure, void>> forgotPassword(String email);
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String password,
  });
  Future<Either<Failure, bool>> isAuthenticated();
  Stream<bool> get authStateChanges;

  // User Management
  Future<Either<Failure, List<User>>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
  });
  Future<Either<Failure, User>> getUserById(String id);
  Future<Either<Failure, User>> createUser({
    required String username,
    required String email,
    required String password,
    required String role,
    String? displayName,
    String? firstName,
    String? lastName,
    String? department,
    String? title,
    String? phone,
    bool? isActive,
  });
  Future<Either<Failure, User>> updateUser({
    required String id,
    String? username,
    String? email,
    String? displayName,
    String? firstName,
    String? lastName,
    String? role,
    String? department,
    String? title,
    String? phone,
    bool? isActive,
  });
  Future<Either<Failure, void>> deleteUser(String id);
  Future<Either<Failure, void>> adminResetPassword(String userId, String newPassword);

  // Password Management
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  // Permissions
  Future<Either<Failure, List<String>>> getMyPermissions();

  // Session Management
  Future<Either<Failure, List<UserSession>>> getSessions();
  Future<Either<Failure, void>> revokeSession(String sessionId);
  Future<Either<Failure, void>> revokeAllSessions();

  // Roles & Permissions
  Future<Either<Failure, List<Role>>> getRoles();
  Future<Either<Failure, RoleWithPermissions>> getRoleWithPermissions(String roleId);
  Future<Either<Failure, List<Permission>>> getPermissions();
  Future<Either<Failure, List<RoleWithPermissions>>> getAllRolesWithPermissions();
  Future<Either<Failure, Role>> createRole({
    required String name,
    required String slug,
    String? description,
  });
  Future<Either<Failure, Role>> updateRole(String id, {String? name, String? description});
  Future<Either<Failure, void>> deleteRole(String id);
  Future<Either<Failure, void>> assignPermission(String roleId, String permissionId);
  Future<Either<Failure, void>> removePermission(String roleId, String permissionId);
}

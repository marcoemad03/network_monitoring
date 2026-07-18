import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/permission.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../../core/network/network_info.dart';
import '../../core/security/jwt_manager.dart';
import '../models/user_model.dart';
import '../models/permission_model.dart';
import '../datasources/remote/auth_remote_datasource.dart';
import '../datasources/local/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;
  final JwtManager _jwtManager;
  final NetworkInfo _networkInfo;
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
    required JwtManager jwtManager,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _jwtManager = jwtManager,
        _networkInfo = networkInfo;

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  Future<Either<Failure, User>> login({
    required String username,
    required String password,
  }) async {
    try {
      final data = await _remoteDataSource.login(
        username: username,
        password: password,
      );
      await _jwtManager.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      final userData = data['user'] as Map<String, dynamic>;
      final userModel = UserModel.fromJson(userData);
      await _localDataSource.cacheUser(userModel);
      _authStateController.add(true);
      return Right(userModel.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _remoteDataSource.logout();
    } catch (_) {}
    await _jwtManager.clearTokens();
    await _localDataSource.clearUser();
    _authStateController.add(false);
    return const Right(null);
  }

  @override
  Future<Either<Failure, User>> getCurrentUser() async {
    try {
      if (await _networkInfo.isConnected) {
        final response = await _remoteDataSource.getCurrentUser();
        final userData = response['user'] as Map<String, dynamic>;
        final model = UserModel.fromJson(userData);
        await _localDataSource.cacheUser(model);
        return Right(model.toEntity());
      }
      final cached = await _localDataSource.getCachedUser();
      if (cached != null) return Right(cached.toEntity());
      return const Left(CacheFailure(message: 'No cached user found'));
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> refreshToken() async {
    try {
      final refreshToken = await _jwtManager.getRefreshToken();
      if (refreshToken == null) return const Right(false);
      final tokenModel = await _remoteDataSource.refreshToken(refreshToken);
      await _jwtManager.saveTokens(
        accessToken: tokenModel.accessToken,
        refreshToken: tokenModel.refreshToken,
      );
      return const Right(true);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    try {
      await _remoteDataSource.forgotPassword(email);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String password,
  }) async {
    try {
      await _remoteDataSource.resetPassword(token: token, password: password);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, bool>> isAuthenticated() async {
    try {
      final valid = await _jwtManager.hasValidToken();
      return Right(valid);
    } catch (e) {
      return Right(false);
    }
  }

  @override
  Future<Either<Failure, List<User>>> getUsers({int page = 1, int limit = 20, String? search}) async {
    try {
      final models = await _remoteDataSource.getUsers(page: page, limit: limit, search: search);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, User>> getUserById(String id) async {
    try {
      final model = await _remoteDataSource.getUserById(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
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
  }) async {
    try {
      final model = await _remoteDataSource.createUser({
        'username': username,
        'email': email,
        'password': password,
        'role': role,
        if (displayName != null) 'display_name': displayName,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (department != null) 'department': department,
        if (title != null) 'title': title,
        if (phone != null) 'phone': phone,
        if (isActive != null) 'is_active': isActive,
      });
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
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
  }) async {
    try {
      final model = await _remoteDataSource.updateUser(id, {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (displayName != null) 'display_name': displayName,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (role != null) 'role': role,
        if (department != null) 'department': department,
        if (title != null) 'title': title,
        if (phone != null) 'phone': phone,
        if (isActive != null) 'is_active': isActive,
      });
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      await _remoteDataSource.deleteUser(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> adminResetPassword(String userId, String newPassword) async {
    try {
      await _remoteDataSource.adminResetPassword(userId, newPassword);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _remoteDataSource.changePassword(currentPassword, newPassword);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getMyPermissions() async {
    try {
      final perms = await _remoteDataSource.getMyPermissions();
      return Right(perms);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<UserSession>>> getSessions() async {
    try {
      final models = await _remoteDataSource.getSessions();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> revokeSession(String sessionId) async {
    try {
      await _remoteDataSource.revokeSession(sessionId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> revokeAllSessions() async {
    try {
      await _remoteDataSource.revokeAllSessions();
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Role>>> getRoles() async {
    try {
      final models = await _remoteDataSource.getRoles();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, RoleWithPermissions>> getRoleWithPermissions(String roleId) async {
    try {
      final data = await _remoteDataSource.getRoleWithPermissions(roleId);
      final role = RoleModel.fromJson(data['role'] as Map<String, dynamic>).toEntity();
      final perms = (data['permissions'] as List)
          .map((e) => PermissionModel.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();
      return Right(RoleWithPermissions(role: role, permissions: perms));
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Permission>>> getPermissions() async {
    try {
      final models = await _remoteDataSource.getPermissions();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<RoleWithPermissions>>> getAllRolesWithPermissions() async {
    try {
      final models = await _remoteDataSource.getAllRolesWithPermissions();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Role>> createRole({
    required String name,
    required String slug,
    String? description,
  }) async {
    try {
      final model = await _remoteDataSource.createRole({
        'name': name,
        'slug': slug,
        if (description != null) 'description': description,
      });
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Role>> updateRole(String id, {String? name, String? description}) async {
    try {
      final model = await _remoteDataSource.updateRole(id, {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      });
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRole(String id) async {
    try {
      await _remoteDataSource.deleteRole(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> assignPermission(String roleId, String permissionId) async {
    try {
      await _remoteDataSource.assignPermission(roleId, permissionId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> removePermission(String roleId, String permissionId) async {
    try {
      await _remoteDataSource.removePermission(roleId, permissionId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  void dispose() {
    _authStateController.close();
  }
}

import '../../models/user_model.dart';
import '../../models/auth_token_model.dart';
import '../../models/permission_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class AuthRemoteDataSource {
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  });
  Future<void> logout();
  Future<Map<String, dynamic>> getCurrentUser();
  Future<AuthTokenModel> refreshToken(String refreshToken);
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({
    required String token,
    required String password,
  });

  // User Management
  Future<List<UserModel>> getUsers({int page = 1, int limit = 20, String? search});
  Future<UserModel> getUserById(String id);
  Future<UserModel> createUser(Map<String, dynamic> data);
  Future<UserModel> updateUser(String id, Map<String, dynamic> data);
  Future<void> deleteUser(String id);
  Future<void> adminResetPassword(String userId, String newPassword);

  // Password
  Future<void> changePassword(String currentPassword, String newPassword);

  // Permissions
  Future<List<String>> getMyPermissions();

  // Sessions
  Future<List<UserSessionModel>> getSessions();
  Future<void> revokeSession(String sessionId);
  Future<void> revokeAllSessions();

  // Roles & Permissions
  Future<List<RoleModel>> getRoles();
  Future<Map<String, dynamic>> getRoleWithPermissions(String roleId);
  Future<List<PermissionModel>> getPermissions();
  Future<List<RoleWithPermissionsModel>> getAllRolesWithPermissions();
  Future<RoleModel> createRole(Map<String, dynamic> data);
  Future<RoleModel> updateRole(String id, Map<String, dynamic> data);
  Future<void> deleteRole(String id);
  Future<void> assignPermission(String roleId, String permissionId);
  Future<void> removePermission(String roleId, String permissionId);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      ApiConstants.login,
      data: {'username': username, 'password': password},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<void> logout() async {
    await _client.post(ApiConstants.logout);
  }

  @override
  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _client.get(ApiConstants.me);
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<AuthTokenModel> refreshToken(String refreshToken) async {
    final response = await _client.post(
      ApiConstants.refreshToken,
      data: {'refresh_token': refreshToken},
    );
    return AuthTokenModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _client.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    await _client.post(ApiConstants.resetPassword, data: {'token': token, 'new_password': password});
  }

  @override
  Future<List<UserModel>> getUsers({int page = 1, int limit = 20, String? search}) async {
    final response = await _client.get(
      ApiConstants.users,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null) 'search': search,
      },
    );
    final data = response.data['data'] as List;
    return data.map((e) => UserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<UserModel> getUserById(String id) async {
    final response = await _client.get(ApiConstants.userDetail(id));
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> createUser(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.users, data: data);
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<UserModel> updateUser(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConstants.userDetail(id), data: data);
    return UserModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteUser(String id) async {
    await _client.delete(ApiConstants.userDetail(id));
  }

  @override
  Future<void> adminResetPassword(String userId, String newPassword) async {
    await _client.post(
      ApiConstants.userResetPassword(userId),
      data: {'new_password': newPassword},
    );
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _client.post(
      ApiConstants.changePassword,
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  @override
  Future<List<String>> getMyPermissions() async {
    final response = await _client.get(ApiConstants.myPermissions);
    return (response.data['data'] as List).cast<String>();
  }

  @override
  Future<List<UserSessionModel>> getSessions() async {
    final response = await _client.get(ApiConstants.sessions);
    final data = response.data['data'] as List;
    return data.map((e) => UserSessionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> revokeSession(String sessionId) async {
    await _client.delete(ApiConstants.sessionDetail(sessionId));
  }

  @override
  Future<void> revokeAllSessions() async {
    await _client.delete(ApiConstants.sessions);
  }

  @override
  Future<List<RoleModel>> getRoles() async {
    final response = await _client.get(ApiConstants.roles);
    final data = response.data['data'] as List;
    return data.map((e) => RoleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, dynamic>> getRoleWithPermissions(String roleId) async {
    final response = await _client.get(ApiConstants.roleDetail(roleId));
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<PermissionModel>> getPermissions() async {
    final response = await _client.get(ApiConstants.permissions);
    final data = response.data['data'] as List;
    return data.map((e) => PermissionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<RoleWithPermissionsModel>> getAllRolesWithPermissions() async {
    final response = await _client.get(ApiConstants.permissionsAllWithRoles);
    final data = response.data['data'] as List;
    return data.map((e) => RoleWithPermissionsModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<RoleModel> createRole(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.roles, data: data);
    return RoleModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<RoleModel> updateRole(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConstants.roleDetail(id), data: data);
    return RoleModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteRole(String id) async {
    await _client.delete(ApiConstants.roleDetail(id));
  }

  @override
  Future<void> assignPermission(String roleId, String permissionId) async {
    await _client.post(
      ApiConstants.rolePermissions(roleId),
      data: {'permission_id': permissionId},
    );
  }

  @override
  Future<void> removePermission(String roleId, String permissionId) async {
    await _client.delete(ApiConstants.rolePermissionItem(roleId, permissionId));
  }
}

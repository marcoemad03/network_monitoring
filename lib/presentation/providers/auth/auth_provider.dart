import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/enums/user_role.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../data/datasources/remote/auth_remote_datasource.dart';
import '../../../data/datasources/local/auth_local_datasource.dart';

final authRepositoryProvider = Provider<AuthRepositoryImpl>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(authLocalDataSourceProvider),
    jwtManager: ref.watch(jwtManagerProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(dioProvider));
});

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final List<String> permissions;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.permissions = const [],
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    List<String>? permissions,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      permissions: permissions ?? this.permissions,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  bool hasPermission(String slug) => permissions.contains(slug);
  bool get canManageUsers => user?.role.canManageUsers ?? false;
  bool get canManageDevices => user?.role.canManageDevices ?? false;
  bool get canAcknowledgeAlerts => user?.role.canAcknowledgeAlerts ?? false;
  bool get canResolveAlerts => user?.role.canResolveAlerts ?? false;
  bool get canViewAuditLogs => user?.role.canViewAuditLogs ?? false;
  bool get canManagePermissions => user?.role.canManagePermissions ?? false;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepositoryImpl _authRepo;
  bool _disposed = false;

  AuthNotifier(this._authRepo) : super(const AuthState());

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(status: AuthStatus.loading);
    final valid = await _authRepo.isAuthenticated();
    if (_disposed) return;
    if (valid.getOrElse(() => false)) {
      await _loadUser();
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    final result = await _authRepo.login(
      username: username,
      password: password,
    );
    if (_disposed) return;
    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: failure.message,
      ),
      (user) async {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        await _loadPermissions();
      },
    );
  }

  Future<void> logout() async {
    await _authRepo.logout();
    if (!_disposed) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> _loadUser() async {
    final result = await _authRepo.getCurrentUser();
    if (_disposed) return;
    result.fold(
      (_) => state = state.copyWith(status: AuthStatus.unauthenticated),
      (user) {
        state = state.copyWith(status: AuthStatus.authenticated, user: user);
        _loadPermissions();
      },
    );
  }

  Future<void> _loadPermissions() async {
    final result = await _authRepo.getMyPermissions();
    if (_disposed) return;
    result.fold(
      (_) {},
      (perms) => state = state.copyWith(permissions: perms),
    );
  }
}

final authProvider = StateNotifierProvider.autoDispose<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final userPermissionsProvider = Provider<List<String>>((ref) {
  return ref.watch(authProvider).permissions;
});

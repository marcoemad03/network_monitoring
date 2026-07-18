import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/permission.dart';
import '../../../core/errors/failures.dart';

class GetRolesUseCase {
  final AuthRepository _repository;
  GetRolesUseCase(this._repository);
  Future<Either<Failure, List<Role>>> call() => _repository.getRoles();
}

class GetAllRolesWithPermissionsUseCase {
  final AuthRepository _repository;
  GetAllRolesWithPermissionsUseCase(this._repository);
  Future<Either<Failure, List<RoleWithPermissions>>> call() =>
      _repository.getAllRolesWithPermissions();
}

class CreateRoleUseCase {
  final AuthRepository _repository;
  CreateRoleUseCase(this._repository);
  Future<Either<Failure, Role>> call({
    required String name,
    required String slug,
    String? description,
  }) => _repository.createRole(name: name, slug: slug, description: description);
}

class UpdateRoleUseCase {
  final AuthRepository _repository;
  UpdateRoleUseCase(this._repository);
  Future<Either<Failure, Role>> call(String id, {String? name, String? description}) =>
      _repository.updateRole(id, name: name, description: description);
}

class DeleteRoleUseCase {
  final AuthRepository _repository;
  DeleteRoleUseCase(this._repository);
  Future<Either<Failure, void>> call(String id) => _repository.deleteRole(id);
}

class GetPermissionsUseCase {
  final AuthRepository _repository;
  GetPermissionsUseCase(this._repository);
  Future<Either<Failure, List<Permission>>> call() => _repository.getPermissions();
}

class AssignPermissionUseCase {
  final AuthRepository _repository;
  AssignPermissionUseCase(this._repository);
  Future<Either<Failure, void>> call(String roleId, String permissionId) =>
      _repository.assignPermission(roleId, permissionId);
}

class RemovePermissionUseCase {
  final AuthRepository _repository;
  RemovePermissionUseCase(this._repository);
  Future<Either<Failure, void>> call(String roleId, String permissionId) =>
      _repository.removePermission(roleId, permissionId);
}

import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';
import '../../../core/errors/failures.dart';

class UpdateUserUseCase {
  final AuthRepository _repository;

  UpdateUserUseCase(this._repository);

  Future<Either<Failure, User>> call({
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
  }) {
    return _repository.updateUser(
      id: id,
      username: username,
      email: email,
      displayName: displayName,
      firstName: firstName,
      lastName: lastName,
      role: role,
      department: department,
      title: title,
      phone: phone,
      isActive: isActive,
    );
  }
}

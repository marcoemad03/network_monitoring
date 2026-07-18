import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';
import '../../../core/errors/failures.dart';

class CreateUserUseCase {
  final AuthRepository _repository;

  CreateUserUseCase(this._repository);

  Future<Either<Failure, User>> call({
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
  }) {
    return _repository.createUser(
      username: username,
      email: email,
      password: password,
      role: role,
      displayName: displayName,
      firstName: firstName,
      lastName: lastName,
      department: department,
      title: title,
      phone: phone,
      isActive: isActive,
    );
  }
}

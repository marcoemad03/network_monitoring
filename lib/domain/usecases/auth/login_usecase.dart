import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';
import '../../../core/errors/failures.dart';

class LoginUseCase {
  final AuthRepository _repository;

  LoginUseCase(this._repository);

  Future<Either<Failure, User>> call({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }
}

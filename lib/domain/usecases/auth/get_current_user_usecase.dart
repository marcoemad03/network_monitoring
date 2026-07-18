import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';
import '../../../core/errors/failures.dart';

class GetCurrentUserUseCase {
  final AuthRepository _repository;

  GetCurrentUserUseCase(this._repository);

  Future<Either<Failure, User>> call() => _repository.getCurrentUser();
}

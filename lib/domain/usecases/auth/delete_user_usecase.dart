import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../../core/errors/failures.dart';

class DeleteUserUseCase {
  final AuthRepository _repository;

  DeleteUserUseCase(this._repository);

  Future<Either<Failure, void>> call(String id) => _repository.deleteUser(id);
}

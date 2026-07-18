import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';
import '../../../core/errors/failures.dart';

class GetUsersUseCase {
  final AuthRepository _repository;

  GetUsersUseCase(this._repository);

  Future<Either<Failure, List<User>>> call({
    int page = 1,
    int limit = 20,
    String? search,
  }) {
    return _repository.getUsers(page: page, limit: limit, search: search);
  }
}

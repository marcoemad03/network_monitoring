import 'package:dartz/dartz.dart';
import '../../repositories/auth_repository.dart';
import '../../entities/permission.dart';
import '../../../core/errors/failures.dart';

class GetSessionsUseCase {
  final AuthRepository _repository;
  GetSessionsUseCase(this._repository);
  Future<Either<Failure, List<UserSession>>> call() => _repository.getSessions();
}

class RevokeSessionUseCase {
  final AuthRepository _repository;
  RevokeSessionUseCase(this._repository);
  Future<Either<Failure, void>> call(String id) => _repository.revokeSession(id);
}

class RevokeAllSessionsUseCase {
  final AuthRepository _repository;
  RevokeAllSessionsUseCase(this._repository);
  Future<Either<Failure, void>> call() => _repository.revokeAllSessions();
}

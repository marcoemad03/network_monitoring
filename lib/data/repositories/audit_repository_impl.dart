import 'package:dartz/dartz.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/entities/audit_log.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../datasources/remote/audit_remote_datasource.dart';

class AuditRepositoryImpl implements AuditRepository {
  final AuditRemoteDataSource _remoteDataSource;

  AuditRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<AuditLog>>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? entityType,
    String? performedBy,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final models = await _remoteDataSource.getAuditLogs(
        page: page,
        limit: limit,
        action: action,
        entityType: entityType,
        performedBy: performedBy,
        from: from,
        to: to,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, AuditLog>> getAuditLogDetail(String id) async {
    try {
      final model = await _remoteDataSource.getAuditLogDetail(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> exportAuditLogs({
    required DateTime from,
    required DateTime to,
    required String format,
  }) async {
    try {
      await _remoteDataSource.exportAuditLogs(
        from: from,
        to: to,
        format: format,
      );
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }
}

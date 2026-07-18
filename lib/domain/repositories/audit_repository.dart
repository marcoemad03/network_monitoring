import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/audit_log.dart';

abstract class AuditRepository {
  Future<Either<Failure, List<AuditLog>>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? entityType,
    String? performedBy,
    DateTime? from,
    DateTime? to,
  });
  Future<Either<Failure, AuditLog>> getAuditLogDetail(String id);
  Future<Either<Failure, void>> exportAuditLogs({
    required DateTime from,
    required DateTime to,
    required String format,
  });
}

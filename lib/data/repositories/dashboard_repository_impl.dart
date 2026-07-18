import 'package:dartz/dartz.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../datasources/remote/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDataSource _remoteDataSource;

  DashboardRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, DashboardSummary>> getSummary() async {
    try {
      final model = await _remoteDataSource.getSummary();
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }
}

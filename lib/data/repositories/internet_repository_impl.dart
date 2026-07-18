import 'package:dartz/dartz.dart';
import '../../domain/repositories/internet_repository.dart';
import '../../domain/entities/internet_policy.dart';
import '../../domain/entities/bandwidth_rule.dart';
import '../../domain/entities/filtering_rule.dart';
import '../../domain/entities/time_schedule.dart';
import '../../domain/entities/device_block.dart';
import '../../domain/entities/vendor_integration.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../datasources/remote/internet_remote_datasource.dart';
import '../../core/network/network_info.dart';

class InternetRepositoryImpl implements InternetRepository {
  final InternetRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  InternetRepositoryImpl({
    required InternetRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, List<InternetPolicy>>> getPolicies({
    int page = 1,
    int limit = 20,
    String? search,
    String? policyType,
    bool? isActive,
  }) async {
    try {
      final models = await _remoteDataSource.getPolicies(
        page: page,
        limit: limit,
        search: search,
        policyType: policyType,
        isActive: isActive,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, InternetPolicy>> getPolicyById(String id) async {
    try {
      final model = await _remoteDataSource.getPolicyById(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, InternetPolicy>> createPolicy(
      InternetPolicy policy) async {
    try {
      final model = await _remoteDataSource.createPolicy(policy);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, InternetPolicy>> updatePolicy(
      InternetPolicy policy) async {
    try {
      final model = await _remoteDataSource.updatePolicy(policy);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePolicy(String id) async {
    try {
      await _remoteDataSource.deletePolicy(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<BandwidthRule>>> getBandwidthRules(
      String policyId) async {
    try {
      final models = await _remoteDataSource.getBandwidthRules(policyId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, BandwidthRule>> createBandwidthRule(
      String policyId, BandwidthRule rule) async {
    try {
      final model =
          await _remoteDataSource.createBandwidthRule(policyId, rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, BandwidthRule>> updateBandwidthRule(
      BandwidthRule rule) async {
    try {
      final model = await _remoteDataSource.updateBandwidthRule(rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBandwidthRule(String id) async {
    try {
      await _remoteDataSource.deleteBandwidthRule(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, BandwidthRule>> setTemporaryBandwidth(
    String ruleId, {
    required int uploadLimitBps,
    required int downloadLimitBps,
    required DateTime expiresAt,
  }) async {
    try {
      final model = await _remoteDataSource.setTemporaryBandwidth(
        ruleId,
        uploadLimitBps: uploadLimitBps,
        downloadLimitBps: downloadLimitBps,
        expiresAt: expiresAt,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> clearTemporaryBandwidth(String ruleId) async {
    try {
      await _remoteDataSource.clearTemporaryBandwidth(ruleId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<FilteringRule>>> getFilteringRules(
      String policyId) async {
    try {
      final models = await _remoteDataSource.getFilteringRules(policyId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, FilteringRule>> createFilteringRule(
      String policyId, FilteringRule rule) async {
    try {
      final model =
          await _remoteDataSource.createFilteringRule(policyId, rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, FilteringRule>> updateFilteringRule(
      FilteringRule rule) async {
    try {
      final model = await _remoteDataSource.updateFilteringRule(rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFilteringRule(String id) async {
    try {
      await _remoteDataSource.deleteFilteringRule(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<TimeSchedule>>> getSchedules(
      String policyId) async {
    try {
      final models = await _remoteDataSource.getSchedules(policyId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, TimeSchedule>> createSchedule(
      String policyId, TimeSchedule schedule) async {
    try {
      final model =
          await _remoteDataSource.createSchedule(policyId, schedule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, TimeSchedule>> updateSchedule(
      TimeSchedule schedule) async {
    try {
      final model = await _remoteDataSource.updateSchedule(schedule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteSchedule(String id) async {
    try {
      await _remoteDataSource.deleteSchedule(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<DeviceBlock>>> getDeviceBlocks({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final models = await _remoteDataSource.getDeviceBlocks(
        page: page,
        limit: limit,
        search: search,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, DeviceBlock>> blockDevice(DeviceBlock block) async {
    try {
      final model = await _remoteDataSource.blockDevice(block);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> unblockDevice(String id) async {
    try {
      await _remoteDataSource.unblockDevice(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<VendorIntegration>>>
      getVendorIntegrations() async {
    try {
      final models = await _remoteDataSource.getVendorIntegrations();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, VendorIntegration>> getVendorIntegrationById(
      String id) async {
    try {
      final model = await _remoteDataSource.getVendorIntegrationById(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, VendorIntegration>> createVendorIntegration(
      VendorIntegration integration) async {
    try {
      final model =
          await _remoteDataSource.createVendorIntegration(integration);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, VendorIntegration>> updateVendorIntegration(
      VendorIntegration integration) async {
    try {
      final model =
          await _remoteDataSource.updateVendorIntegration(integration);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteVendorIntegration(String id) async {
    try {
      await _remoteDataSource.deleteVendorIntegration(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> testVendorConnection(String id) async {
    try {
      await _remoteDataSource.testVendorConnection(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, VendorIntegration>> syncVendor(String id) async {
    try {
      final model = await _remoteDataSource.syncVendor(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }
}

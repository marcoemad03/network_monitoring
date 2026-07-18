import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/internet_policy.dart';
import '../entities/bandwidth_rule.dart';
import '../entities/filtering_rule.dart';
import '../entities/time_schedule.dart';
import '../entities/device_block.dart';
import '../entities/vendor_integration.dart';

abstract class InternetRepository {
  // Internet Policies
  Future<Either<Failure, List<InternetPolicy>>> getPolicies({
    int page = 1,
    int limit = 20,
    String? search,
    String? policyType,
    bool? isActive,
  });
  Future<Either<Failure, InternetPolicy>> getPolicyById(String id);
  Future<Either<Failure, InternetPolicy>> createPolicy(InternetPolicy policy);
  Future<Either<Failure, InternetPolicy>> updatePolicy(InternetPolicy policy);
  Future<Either<Failure, void>> deletePolicy(String id);

  // Bandwidth Rules
  Future<Either<Failure, List<BandwidthRule>>> getBandwidthRules(
      String policyId);
  Future<Either<Failure, BandwidthRule>> createBandwidthRule(
      String policyId, BandwidthRule rule);
  Future<Either<Failure, BandwidthRule>> updateBandwidthRule(
      BandwidthRule rule);
  Future<Either<Failure, void>> deleteBandwidthRule(String id);
  Future<Either<Failure, BandwidthRule>> setTemporaryBandwidth(
    String ruleId, {
    required int uploadLimitBps,
    required int downloadLimitBps,
    required DateTime expiresAt,
  });
  Future<Either<Failure, void>> clearTemporaryBandwidth(String ruleId);

  // Filtering Rules
  Future<Either<Failure, List<FilteringRule>>> getFilteringRules(
      String policyId);
  Future<Either<Failure, FilteringRule>> createFilteringRule(
      String policyId, FilteringRule rule);
  Future<Either<Failure, FilteringRule>> updateFilteringRule(
      FilteringRule rule);
  Future<Either<Failure, void>> deleteFilteringRule(String id);

  // Time Schedules
  Future<Either<Failure, List<TimeSchedule>>> getSchedules(String policyId);
  Future<Either<Failure, TimeSchedule>> createSchedule(
      String policyId, TimeSchedule schedule);
  Future<Either<Failure, TimeSchedule>> updateSchedule(TimeSchedule schedule);
  Future<Either<Failure, void>> deleteSchedule(String id);

  // Device Blocks
  Future<Either<Failure, List<DeviceBlock>>> getDeviceBlocks({
    int page = 1,
    int limit = 20,
    String? search,
  });
  Future<Either<Failure, DeviceBlock>> blockDevice(DeviceBlock block);
  Future<Either<Failure, void>> unblockDevice(String id);

  // Vendor Integrations
  Future<Either<Failure, List<VendorIntegration>>> getVendorIntegrations();
  Future<Either<Failure, VendorIntegration>> getVendorIntegrationById(
      String id);
  Future<Either<Failure, VendorIntegration>> createVendorIntegration(
      VendorIntegration integration);
  Future<Either<Failure, VendorIntegration>> updateVendorIntegration(
      VendorIntegration integration);
  Future<Either<Failure, void>> deleteVendorIntegration(String id);
  Future<Either<Failure, void>> testVendorConnection(String id);
  Future<Either<Failure, VendorIntegration>> syncVendor(String id);
}

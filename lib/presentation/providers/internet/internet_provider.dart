import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/internet_policy.dart';
import '../../../domain/entities/bandwidth_rule.dart';
import '../../../domain/entities/filtering_rule.dart';
import '../../../domain/entities/time_schedule.dart';
import '../../../domain/entities/device_block.dart';
import '../../../domain/entities/vendor_integration.dart';
import '../../../data/repositories/internet_repository_impl.dart';
import '../../../data/datasources/remote/internet_remote_datasource.dart';
import '../../../core/di/injection_container.dart';

final internetRemoteDataSourceProvider = Provider<InternetRemoteDataSource>((ref) {
  return InternetRemoteDataSourceImpl(ref.watch(dioProvider));
});

final internetRepositoryProvider = Provider<InternetRepositoryImpl>((ref) {
  return InternetRepositoryImpl(
    remoteDataSource: ref.watch(internetRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

final internetPoliciesProvider = FutureProvider<List<InternetPolicy>>((ref) async {
  final repo = ref.watch(internetRepositoryProvider);
  final result = await repo.getPolicies();
  return result.fold((_) => <InternetPolicy>[], (policies) => policies);
});

final internetPolicyDetailProvider = FutureProvider.family<InternetPolicy?, String>(
  (ref, id) async {
    final repo = ref.watch(internetRepositoryProvider);
    final result = await repo.getPolicyById(id);
    return result.fold((_) => null, (policy) => policy);
  },
);

final bandwidthRulesProvider = FutureProvider.family<List<BandwidthRule>, String>(
  (ref, policyId) async {
    final repo = ref.watch(internetRepositoryProvider);
    final result = await repo.getBandwidthRules(policyId);
    return result.fold((_) => <BandwidthRule>[], (rules) => rules);
  },
);

final filteringRulesProvider = FutureProvider.family<List<FilteringRule>, String>(
  (ref, policyId) async {
    final repo = ref.watch(internetRepositoryProvider);
    final result = await repo.getFilteringRules(policyId);
    return result.fold((_) => <FilteringRule>[], (rules) => rules);
  },
);

final schedulesProvider = FutureProvider.family<List<TimeSchedule>, String>(
  (ref, policyId) async {
    final repo = ref.watch(internetRepositoryProvider);
    final result = await repo.getSchedules(policyId);
    return result.fold((_) => <TimeSchedule>[], (schedules) => schedules);
  },
);

final deviceBlocksProvider = FutureProvider<List<DeviceBlock>>((ref) async {
  final repo = ref.watch(internetRepositoryProvider);
  final result = await repo.getDeviceBlocks();
  return result.fold((_) => <DeviceBlock>[], (blocks) => blocks);
});

final vendorIntegrationsProvider = FutureProvider<List<VendorIntegration>>((ref) async {
  final repo = ref.watch(internetRepositoryProvider);
  final result = await repo.getVendorIntegrations();
  return result.fold((_) => <VendorIntegration>[], (integrations) => integrations);
});

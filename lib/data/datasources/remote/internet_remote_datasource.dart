import 'package:dio/dio.dart';
import '../../models/internet_policy_model.dart';
import '../../models/bandwidth_rule_model.dart';
import '../../models/filtering_rule_model.dart';
import '../../models/time_schedule_model.dart';
import '../../models/device_block_model.dart';
import '../../models/vendor_integration_model.dart';
import '../../../domain/entities/internet_policy.dart';
import '../../../domain/entities/bandwidth_rule.dart';
import '../../../domain/entities/filtering_rule.dart';
import '../../../domain/entities/time_schedule.dart';
import '../../../domain/entities/device_block.dart';
import '../../../domain/entities/vendor_integration.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class InternetRemoteDataSource {
  // Internet Policies
  Future<List<InternetPolicyModel>> getPolicies({
    int page = 1,
    int limit = 20,
    String? search,
    String? policyType,
    bool? isActive,
  });
  Future<InternetPolicyModel> getPolicyById(String id);
  Future<InternetPolicyModel> createPolicy(InternetPolicy policy);
  Future<InternetPolicyModel> updatePolicy(InternetPolicy policy);
  Future<void> deletePolicy(String id);

  // Bandwidth Rules
  Future<List<BandwidthRuleModel>> getBandwidthRules(String policyId);
  Future<BandwidthRuleModel> createBandwidthRule(
      String policyId, BandwidthRule rule);
  Future<BandwidthRuleModel> updateBandwidthRule(BandwidthRule rule);
  Future<void> deleteBandwidthRule(String id);
  Future<BandwidthRuleModel> setTemporaryBandwidth(
    String ruleId, {
    required int uploadLimitBps,
    required int downloadLimitBps,
    required DateTime expiresAt,
  });
  Future<void> clearTemporaryBandwidth(String ruleId);

  // Filtering Rules
  Future<List<FilteringRuleModel>> getFilteringRules(String policyId);
  Future<FilteringRuleModel> createFilteringRule(
      String policyId, FilteringRule rule);
  Future<FilteringRuleModel> updateFilteringRule(FilteringRule rule);
  Future<void> deleteFilteringRule(String id);

  // Time Schedules
  Future<List<TimeScheduleModel>> getSchedules(String policyId);
  Future<TimeScheduleModel> createSchedule(
      String policyId, TimeSchedule schedule);
  Future<TimeScheduleModel> updateSchedule(TimeSchedule schedule);
  Future<void> deleteSchedule(String id);

  // Device Blocks
  Future<List<DeviceBlockModel>> getDeviceBlocks({
    int page = 1,
    int limit = 20,
    String? search,
  });
  Future<DeviceBlockModel> blockDevice(DeviceBlock block);
  Future<void> unblockDevice(String id);

  // Vendor Integrations
  Future<List<VendorIntegrationModel>> getVendorIntegrations();
  Future<VendorIntegrationModel> getVendorIntegrationById(String id);
  Future<VendorIntegrationModel> createVendorIntegration(
      VendorIntegration integration);
  Future<VendorIntegrationModel> updateVendorIntegration(
      VendorIntegration integration);
  Future<void> deleteVendorIntegration(String id);
  Future<void> testVendorConnection(String id);
  Future<VendorIntegrationModel> syncVendor(String id);
}

class InternetRemoteDataSourceImpl implements InternetRemoteDataSource {
  final DioClient _client;

  InternetRemoteDataSourceImpl(this._client);

  @override
  Future<List<InternetPolicyModel>> getPolicies({
    int page = 1,
    int limit = 20,
    String? search,
    String? policyType,
    bool? isActive,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
      if (policyType != null) 'policy_type': policyType,
      if (isActive != null) 'is_active': isActive,
    };
    final response = await _client.get(
      ApiConstants.internetPolicies,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => InternetPolicyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<InternetPolicyModel> getPolicyById(String id) async {
    final response = await _client.get(ApiConstants.internetPolicyDetail(id));
    return InternetPolicyModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<InternetPolicyModel> createPolicy(InternetPolicy policy) async {
    final data = InternetPolicyModel.fromEntity(policy).toJson();
    final response = await _client.post(ApiConstants.internetPolicies, data: data);
    return InternetPolicyModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<InternetPolicyModel> updatePolicy(InternetPolicy policy) async {
    final data = InternetPolicyModel.fromEntity(policy).toJson();
    final response =
        await _client.put(ApiConstants.internetPolicyDetail(policy.id), data: data);
    return InternetPolicyModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deletePolicy(String id) async {
    await _client.delete(ApiConstants.internetPolicyDetail(id));
  }

  @override
  Future<List<BandwidthRuleModel>> getBandwidthRules(String policyId) async {
    final response =
        await _client.get(ApiConstants.internetPolicyBandwidthRules(policyId));
    final data = response.data['data'] as List;
    return data
        .map((e) => BandwidthRuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<BandwidthRuleModel> createBandwidthRule(
      String policyId, BandwidthRule rule) async {
    final data = BandwidthRuleModel.fromEntity(rule).toJson();
    final response =
        await _client.post(ApiConstants.internetPolicyBandwidthRules(policyId), data: data);
    return BandwidthRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<BandwidthRuleModel> updateBandwidthRule(BandwidthRule rule) async {
    final data = BandwidthRuleModel.fromEntity(rule).toJson();
    final response =
        await _client.put(ApiConstants.bandwidthRuleDetail(rule.id), data: data);
    return BandwidthRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteBandwidthRule(String id) async {
    await _client.delete(ApiConstants.bandwidthRuleDetail(id));
  }

  @override
  Future<BandwidthRuleModel> setTemporaryBandwidth(
    String ruleId, {
    required int uploadLimitBps,
    required int downloadLimitBps,
    required DateTime expiresAt,
  }) async {
    final response = await _client.post(
      ApiConstants.bandwidthRuleTemporary(ruleId),
      data: {
        'upload_limit_bps': uploadLimitBps,
        'download_limit_bps': downloadLimitBps,
        'expires_at': expiresAt.toIso8601String(),
      },
    );
    return BandwidthRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> clearTemporaryBandwidth(String ruleId) async {
    await _client.delete(ApiConstants.bandwidthRuleTemporary(ruleId));
  }

  @override
  Future<List<FilteringRuleModel>> getFilteringRules(String policyId) async {
    final response =
        await _client.get(ApiConstants.internetPolicyFilteringRules(policyId));
    final data = response.data['data'] as List;
    return data
        .map((e) => FilteringRuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<FilteringRuleModel> createFilteringRule(
      String policyId, FilteringRule rule) async {
    final data = FilteringRuleModel.fromEntity(rule).toJson();
    final response =
        await _client.post(ApiConstants.internetPolicyFilteringRules(policyId), data: data);
    return FilteringRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<FilteringRuleModel> updateFilteringRule(FilteringRule rule) async {
    final data = FilteringRuleModel.fromEntity(rule).toJson();
    final response =
        await _client.put(ApiConstants.filteringRuleDetail(rule.id), data: data);
    return FilteringRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteFilteringRule(String id) async {
    await _client.delete(ApiConstants.filteringRuleDetail(id));
  }

  @override
  Future<List<TimeScheduleModel>> getSchedules(String policyId) async {
    final response =
        await _client.get(ApiConstants.internetPolicySchedules(policyId));
    final data = response.data['data'] as List;
    return data
        .map((e) => TimeScheduleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TimeScheduleModel> createSchedule(
      String policyId, TimeSchedule schedule) async {
    final data = TimeScheduleModel.fromEntity(schedule).toJson();
    final response =
        await _client.post(ApiConstants.internetPolicySchedules(policyId), data: data);
    return TimeScheduleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<TimeScheduleModel> updateSchedule(TimeSchedule schedule) async {
    final data = TimeScheduleModel.fromEntity(schedule).toJson();
    final response =
        await _client.put(ApiConstants.scheduleDetail(schedule.id), data: data);
    return TimeScheduleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await _client.delete(ApiConstants.scheduleDetail(id));
  }

  @override
  Future<List<DeviceBlockModel>> getDeviceBlocks({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
    };
    final response = await _client.get(
      ApiConstants.deviceBlocks,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => DeviceBlockModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DeviceBlockModel> blockDevice(DeviceBlock block) async {
    final data = DeviceBlockModel.fromEntity(block).toJson();
    final response = await _client.post(ApiConstants.deviceBlocks, data: data);
    return DeviceBlockModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> unblockDevice(String id) async {
    await _client.delete(ApiConstants.deviceBlockDetail(id));
  }

  @override
  Future<List<VendorIntegrationModel>> getVendorIntegrations() async {
    final response = await _client.get(ApiConstants.vendorIntegrations);
    final data = response.data['data'] as List;
    return data
        .map((e) => VendorIntegrationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<VendorIntegrationModel> getVendorIntegrationById(String id) async {
    final response =
        await _client.get(ApiConstants.vendorIntegrationDetail(id));
    return VendorIntegrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<VendorIntegrationModel> createVendorIntegration(
      VendorIntegration integration) async {
    final data = VendorIntegrationModel.fromEntity(integration).toJson();
    final response =
        await _client.post(ApiConstants.vendorIntegrations, data: data);
    return VendorIntegrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<VendorIntegrationModel> updateVendorIntegration(
      VendorIntegration integration) async {
    final data = VendorIntegrationModel.fromEntity(integration).toJson();
    final response =
        await _client.put(ApiConstants.vendorIntegrationDetail(integration.id), data: data);
    return VendorIntegrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteVendorIntegration(String id) async {
    await _client.delete(ApiConstants.vendorIntegrationDetail(id));
  }

  @override
  Future<void> testVendorConnection(String id) async {
    await _client.post(ApiConstants.vendorIntegrationTest(id));
  }

  @override
  Future<VendorIntegrationModel> syncVendor(String id) async {
    final response =
        await _client.post(ApiConstants.vendorIntegrationSync(id));
    return VendorIntegrationModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }
}

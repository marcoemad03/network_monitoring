import '../../models/alert_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class AlertRemoteDataSource {
  Future<List<AlertModel>> getAlerts({
    int page = 1,
    int limit = 20,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool ascending = false,
  });
  Future<AlertModel> getAlertById(String id);
  Future<AlertModel> acknowledgeAlert(String id, {String? notes});
  Future<AlertModel> resolveAlert(
    String id, {
    required String resolutionNotes,
  });
  Future<void> suppressAlert(String id, {required DateTime until});
}

class AlertRemoteDataSourceImpl implements AlertRemoteDataSource {
  final DioClient _client;

  AlertRemoteDataSourceImpl(this._client);

  @override
  Future<List<AlertModel>> getAlerts({
    int page = 1,
    int limit = 20,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool ascending = false,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status,
      if (severity != null) 'severity': severity,
      if (category != null) 'category': category,
      if (deviceId != null) 'device_id': deviceId,
      if (sortBy != null) 'sort_by': sortBy,
      'ascending': ascending,
    };
    final response = await _client.get(
      ApiConstants.alerts,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data.map((e) => AlertModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AlertModel> getAlertById(String id) async {
    final response = await _client.get(ApiConstants.alertDetail(id));
    return AlertModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AlertModel> acknowledgeAlert(String id, {String? notes}) async {
    final response = await _client.post(
      ApiConstants.acknowledgeAlert(id),
      data: {'notes': notes},
    );
    return AlertModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AlertModel> resolveAlert(
    String id, {
    required String resolutionNotes,
  }) async {
    final response = await _client.post(
      ApiConstants.resolveAlert(id),
      data: {'resolution_notes': resolutionNotes},
    );
    return AlertModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> suppressAlert(String id, {required DateTime until}) async {
    await _client.post(
      ApiConstants.alertDetail(id),
      data: {
        'action': 'suppress',
        'suppressed_until': until.toIso8601String(),
      },
    );
  }
}

import '../../models/audit_log_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class AuditRemoteDataSource {
  Future<List<AuditLogModel>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? entityType,
    String? performedBy,
    DateTime? from,
    DateTime? to,
  });
  Future<AuditLogModel> getAuditLogDetail(String id);
  Future<String> exportAuditLogs({
    required DateTime from,
    required DateTime to,
    required String format,
  });
}

class AuditRemoteDataSourceImpl implements AuditRemoteDataSource {
  final DioClient _client;

  AuditRemoteDataSourceImpl(this._client);

  @override
  Future<List<AuditLogModel>> getAuditLogs({
    int page = 1,
    int limit = 20,
    String? action,
    String? entityType,
    String? performedBy,
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (action != null) 'action': action,
      if (entityType != null) 'entity_type': entityType,
      if (performedBy != null) 'performed_by': performedBy,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _client.get(
      ApiConstants.auditLogs,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AuditLogModel> getAuditLogDetail(String id) async {
    final response = await _client.get('${ApiConstants.auditLogs}/$id');
    return AuditLogModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<String> exportAuditLogs({
    required DateTime from,
    required DateTime to,
    required String format,
  }) async {
    final response = await _client.get(
      '${ApiConstants.auditLogs}/export',
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'format': format,
      },
    );
    return response.data['data']['url'] as String;
  }
}

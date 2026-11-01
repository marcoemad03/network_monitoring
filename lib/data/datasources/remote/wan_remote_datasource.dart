import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/wan_usage_models.dart';

class WanRemoteDataSource {
  final DioClient _client;
  WanRemoteDataSource(this._client);

  Future<WanUsage> fetch() async {
    final response = await _client.get(
      '${ApiConstants.basePath}/monitoring/wan',
      options: Options(receiveTimeout: const Duration(seconds: 15)),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return WanUsage.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
}

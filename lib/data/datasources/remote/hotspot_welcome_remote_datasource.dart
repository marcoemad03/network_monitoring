import '../../../core/network/dio_client.dart';
import '../../models/hotspot_welcome_config.dart';

class HotspotWelcomeRemoteDataSource {
  final DioClient _client;

  HotspotWelcomeRemoteDataSource(this._client);

  Future<HotspotWelcomeConfig> getConfig() async {
    final response = await _client.get('/hotspot/welcome-page');
    return HotspotWelcomeConfig.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<HotspotWelcomeConfig> saveConfig(
    HotspotWelcomeConfig config,
  ) async {
    final response = await _client.put(
      '/hotspot/welcome-page',
      data: config.toJson(),
    );
    return HotspotWelcomeConfig.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  Future<String> generateLoginHtml() async {
    final response = await _client.get<String>('/hotspot/welcome-page/login.html');
    return response.data ?? '';
  }

  Future<HotspotProfileResult> configureProfile({
    required String endpoint,
    required String username,
    required String password,
    required String profile,
    required String htmlDirectory,
  }) async {
    final response = await _client.post(
      '/hotspot/welcome-page/configure-profile',
      data: {
        'endpoint': endpoint,
        'username': username,
        'password': password,
        'profile': profile,
        'html_directory': htmlDirectory,
      },
    );
    return HotspotProfileResult.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}

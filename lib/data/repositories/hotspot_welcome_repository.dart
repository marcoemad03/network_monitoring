import '../datasources/remote/hotspot_welcome_remote_datasource.dart';
import '../models/hotspot_welcome_config.dart';

class HotspotWelcomeRepository {
  final HotspotWelcomeRemoteDataSource _remote;

  HotspotWelcomeRepository(this._remote);

  Future<HotspotWelcomeConfig> getConfig() => _remote.getConfig();
  Future<HotspotWelcomeConfig> saveConfig(HotspotWelcomeConfig config) =>
      _remote.saveConfig(config);
  Future<String> generateLoginHtml() => _remote.generateLoginHtml();
  Future<HotspotProfileResult> configureProfile({
    required String endpoint,
    required String username,
    required String password,
    required String profile,
    required String htmlDirectory,
  }) => _remote.configureProfile(
    endpoint: endpoint,
    username: username,
    password: password,
    profile: profile,
    htmlDirectory: htmlDirectory,
  );
}

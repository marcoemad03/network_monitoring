import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/hotspot_welcome_remote_datasource.dart';
import '../../../data/models/hotspot_welcome_config.dart';
import '../../../data/repositories/hotspot_welcome_repository.dart';

final hotspotWelcomeRepositoryProvider = Provider<HotspotWelcomeRepository>(
  (ref) => HotspotWelcomeRepository(
    HotspotWelcomeRemoteDataSource(ref.watch(dioProvider)),
  ),
);

final hotspotWelcomeProvider =
    AsyncNotifierProvider<HotspotWelcomeController, HotspotWelcomeConfig>(
      HotspotWelcomeController.new,
    );

class HotspotWelcomeController extends AsyncNotifier<HotspotWelcomeConfig> {
  @override
  Future<HotspotWelcomeConfig> build() {
    return ref.watch(hotspotWelcomeRepositoryProvider).getConfig();
  }

  Future<bool> save(HotspotWelcomeConfig config) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(hotspotWelcomeRepositoryProvider).saveConfig(config),
    );
    return !state.hasError;
  }

  Future<String> generateLoginHtml() {
    return ref.read(hotspotWelcomeRepositoryProvider).generateLoginHtml();
  }

  Future<HotspotProfileResult> configureProfile({
    required String endpoint,
    required String username,
    required String password,
    required String profile,
    required String htmlDirectory,
  }) {
    return ref.read(hotspotWelcomeRepositoryProvider).configureProfile(
      endpoint: endpoint,
      username: username,
      password: password,
      profile: profile,
      htmlDirectory: htmlDirectory,
    );
  }
}

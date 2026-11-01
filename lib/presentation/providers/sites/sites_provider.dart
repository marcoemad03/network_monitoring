import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/sites_remote_datasource.dart';
import '../../../data/models/sites_models.dart';

final sitesRemoteProvider = Provider<SitesRemoteDataSource>(
  (ref) => SitesRemoteDataSource(ref.watch(dioProvider)),
);

/// The periods the page offers, in hours.
const sitesPeriods = <int, String>{
  1: 'Last hour',
  24: 'Last 24 hours',
  168: 'Last 7 days',
  720: 'Last 30 days',
};

class SitesState {
  final SitesOverview? overview;
  final String? fetchError;
  final bool loading;
  final int hours;
  final bool background;

  const SitesState({
    this.overview,
    this.fetchError,
    this.loading = true,
    this.hours = 24,
    this.background = false,
  });

  SitesState copyWith({
    SitesOverview? overview,
    String? fetchError,
    bool clearFetchError = false,
    bool? loading,
    int? hours,
    bool? background,
  }) => SitesState(
    overview: overview ?? this.overview,
    fetchError: clearFetchError ? null : (fetchError ?? this.fetchError),
    loading: loading ?? this.loading,
    hours: hours ?? this.hours,
    background: background ?? this.background,
  );
}

const sitesRefreshEvery = Duration(seconds: 30);

/// The recorded sites for the chosen period. Everything comes from the NMS
/// server's own recording; reading it never touches the router or the resolver.
final sitesProvider = NotifierProvider.autoDispose<SitesController, SitesState>(
  SitesController.new,
);

class SitesController extends AutoDisposeNotifier<SitesState> {
  Timer? _timer;

  @override
  SitesState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(refresh);
    _timer = Timer.periodic(sitesRefreshEvery, (_) => refresh());
    return const SitesState();
  }

  SitesRemoteDataSource get _remote => ref.read(sitesRemoteProvider);

  Future<void> refresh() async {
    final hours = state.hours;
    final background = state.background;
    try {
      final overview = await _remote.overview(
        hours: hours,
        background: background,
      );
      if (hours != state.hours || background != state.background)
        return; // the choice changed while loading
      state = state.copyWith(
        overview: overview,
        loading: false,
        clearFetchError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, fetchError: _describe(e));
    }
  }

  Future<void> setHours(int hours) async {
    if (hours == state.hours) return;
    state = state.copyWith(hours: hours, loading: true);
    await refresh();
  }

  Future<void> setBackground(bool value) async {
    if (value == state.background) return;
    state = state.copyWith(background: value, loading: true);
    await refresh();
  }

  void _changed() {
    ref.invalidate(siteLogoProvider);
    unawaited(refresh());
  }

  /// Adds a site to the catalog. Throws [SitesRequestFailed] with a message to show.
  Future<CatalogResult> create({
    required String name,
    required String category,
    required List<String> domains,
    bool fetchLogo = true,
  }) async {
    final r = await _remote.create(
      name: name,
      category: category,
      domains: domains,
      fetchLogo: fetchLogo,
    );
    _changed();
    return r;
  }

  Future<CatalogResult> adopt(
    String domain, {
    String name = '',
    String category = '',
  }) async {
    final r = await _remote.adopt(domain, name: name, category: category);
    _changed();
    return r;
  }

  Future<CatalogResult> update(
    String id, {
    required String name,
    required String category,
    required List<String> domains,
    bool fetchLogo = false,
  }) async {
    final r = await _remote.update(
      id,
      name: name,
      category: category,
      domains: domains,
      fetchLogo: fetchLogo,
    );
    _changed();
    return r;
  }

  Future<void> remove(String id) async {
    await _remote.delete(id);
    _changed();
  }

  Future<void> fetchLogo(String id, {String imageUrl = ''}) async {
    await _remote.fetchLogo(id, imageUrl: imageUrl);
    _changed();
  }

  Future<void> removeLogo(String id) async {
    await _remote.removeLogo(id);
    _changed();
  }

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('Connection refused') ||
        text.contains('connection error') ||
        text.contains('SocketException')) {
      return 'The NMS server is not reachable.';
    }
    if (text.contains('timeout'))
      return 'The NMS server took too long to answer.';
    return 'Could not load the recorded sites.';
  }
}

/// A site's logo, or null when it has none. Kept for the session; changes to the
/// catalog invalidate it.
final siteLogoProvider = FutureProvider.family<Uint8List?, String>(
  (ref, domain) => ref.watch(sitesRemoteProvider).logo(domain),
);

/// What one device asked for in the last 24 hours.
final deviceSitesProvider = FutureProvider.autoDispose
    .family<DeviceSites, String>(
      (ref, key) => ref.watch(sitesRemoteProvider).device(key, hours: 24),
    );

/// Which devices asked for a site.
final siteDetailProvider = FutureProvider.autoDispose
    .family<SiteDetail, ({String domain, int hours})>(
      (ref, q) => ref.watch(sitesRemoteProvider).site(q.domain, hours: q.hours),
    );

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/security_remote_datasource.dart';
import '../../../data/models/security_models.dart';

final securityRemoteProvider = Provider<SecurityRemoteDataSource>(
  (ref) => SecurityRemoteDataSource(ref.watch(dioProvider)),
);

/// What the Security page needs: the latest overview, why it could not be
/// refreshed, and the state of a scan the user started.
class SecurityState {
  final SecurityOverview? overview;
  final String? fetchError;
  final bool loading;
  final bool scanning;
  final ScanRefused? scanProblem;

  const SecurityState({this.overview, this.fetchError, this.loading = true, this.scanning = false, this.scanProblem});

  SecurityState copyWith({
    SecurityOverview? overview,
    String? fetchError,
    bool clearFetchError = false,
    bool? loading,
    bool? scanning,
    ScanRefused? scanProblem,
    bool clearScanProblem = false,
  }) =>
      SecurityState(
        overview: overview ?? this.overview,
        fetchError: clearFetchError ? null : (fetchError ?? this.fetchError),
        loading: loading ?? this.loading,
        scanning: scanning ?? this.scanning,
        scanProblem: clearScanProblem ? null : (scanProblem ?? this.scanProblem),
      );
}

const securityRefreshEvery = Duration(seconds: 30);

/// Keeps the overview fresh while the page is open. The overview comes from
/// the NMS server's last scan, so refreshing it never touches the router; only
/// [scan] does.
final securityProvider = NotifierProvider.autoDispose<SecurityController, SecurityState>(SecurityController.new);

class SecurityController extends AutoDisposeNotifier<SecurityState> {
  Timer? _timer;

  @override
  SecurityState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(refresh);
    _timer = Timer.periodic(securityRefreshEvery, (_) => refresh());
    return const SecurityState();
  }

  SecurityRemoteDataSource get _remote => ref.read(securityRemoteProvider);

  Future<void> refresh() async {
    try {
      final overview = await _remote.overview();
      state = state.copyWith(overview: overview, loading: false, clearFetchError: true, scanning: overview.settings.scanning);
    } catch (e) {
      state = state.copyWith(loading: false, fetchError: _describe(e));
    }
  }

  /// Reads the router now. The page asks the user to confirm first.
  Future<void> scan() async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, clearScanProblem: true);
    try {
      final overview = await _remote.scan();
      state = state.copyWith(overview: overview, scanning: false, clearFetchError: true);
    } on ScanRefused catch (e) {
      state = state.copyWith(scanning: false, scanProblem: e);
      unawaited(refresh());
    } catch (e) {
      state = state.copyWith(scanning: false, scanProblem: ScanRefused('NETWORK', _describe(e)));
    }
  }

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('Connection refused') || text.contains('connection error') || text.contains('SocketException')) {
      return 'The NMS server is not reachable.';
    }
    if (text.contains('timeout')) return 'The NMS server took too long to answer.';
    return 'Could not load the security overview.';
  }
}

/// One device's connections from the latest scan.
final securityDeviceProvider = FutureProvider.autoDispose.family<DeviceDetail, String>(
  (ref, key) => ref.watch(securityRemoteProvider).device(key),
);

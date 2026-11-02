import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/client_remote_datasource.dart';
import '../../../data/datasources/remote/network_map_remote_datasource.dart';
import '../../../data/models/network_map_models.dart';
import '../clients/clients_provider.dart';

final networkMapRemoteProvider = Provider<NetworkMapRemoteDataSource>(
  (ref) => NetworkMapRemoteDataSource(ref.watch(dioProvider)),
);

const networkMapPollInterval = Duration(seconds: 15);

class NetworkMapState {
  /// The newest map. Kept when a later poll fails so the page stays usable.
  final NetworkMapData? data;
  final String? fetchError;
  final bool loading;
  final DateTime? fetchedAt;

  const NetworkMapState({this.data, this.fetchError, this.loading = true, this.fetchedAt});
}

/// Polls the server's map while the page is open. Reading it never writes to the router.
final networkMapProvider = NotifierProvider.autoDispose<NetworkMapController, NetworkMapState>(
  NetworkMapController.new,
);

class NetworkMapController extends AutoDisposeNotifier<NetworkMapState> {
  Timer? _timer;
  bool _busy = false;

  @override
  NetworkMapState build() {
    ref.onDispose(() => _timer?.cancel());
    Future.microtask(refresh);
    _timer = Timer.periodic(networkMapPollInterval, (_) => refresh());
    return const NetworkMapState();
  }

  NetworkMapRemoteDataSource get _remote => ref.read(networkMapRemoteProvider);

  /// [force] also asks the server to read the router's wiring again.
  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    _busy = true;
    if (force) state = NetworkMapState(data: state.data, fetchedAt: state.fetchedAt);
    try {
      final data = await _remote.fetch(refresh: force);
      state = NetworkMapState(data: data, loading: false, fetchedAt: DateTime.now());
    } catch (e) {
      state = NetworkMapState(data: state.data, loading: false, fetchError: _describe(e), fetchedAt: state.fetchedAt);
    } finally {
      _busy = false;
    }
  }

  /// Saves the name, type or place of a device, then reloads. Throws [ClientApiException].
  Future<void> saveDevice(String mac, {String? displayName, String? kind, String? place}) async {
    await ref.read(clientRemoteProvider).saveNote(mac, displayName: displayName, kind: kind, place: place);
    await refresh();
  }

  Future<int> saveDevicePlaces(List<String> macs, String place) async {
    final n = await _remote.saveDevicePlaces(macs, place);
    await refresh();
    return n;
  }

  Future<void> savePortLabel(String port, String label) async {
    await _remote.savePortLabel(port, label);
    await refresh();
  }

  String _describe(Object e) {
    final text = e.toString();
    if (text.contains('Connection refused') || text.contains('connection error') || text.contains('SocketException')) {
      return 'The NMS server is not reachable.';
    }
    if (text.contains('timeout')) return 'The NMS server took too long to answer.';
    return 'Could not load the network map.';
  }
}

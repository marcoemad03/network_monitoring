import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/client_remote_datasource.dart';
import '../../../data/models/client_inventory_models.dart';

final clientRemoteProvider = Provider<ClientRemoteDataSource>(
  (ref) => ClientRemoteDataSource(ref.watch(dioProvider)),
);

/// One poll of the backend: the newest list plus, when this poll failed, why.
/// [data] keeps the last good list so the page stays usable, marked as old.
class ClientFeed {
  final ClientList? data;
  final String? fetchError;
  final DateTime fetchedAt;
  const ClientFeed({required this.data, required this.fetchError, required this.fetchedAt});
}

const clientPollInterval = Duration(seconds: 10);

/// Polls while the Devices page is open and stops when it is closed.
final clientFeedProvider = StreamProvider.autoDispose<ClientFeed>((ref) async* {
  final source = ref.watch(clientRemoteProvider);
  ClientList? last;
  while (true) {
    try {
      last = await source.fetch();
      yield ClientFeed(data: last, fetchError: null, fetchedAt: DateTime.now());
    } catch (e) {
      yield ClientFeed(data: last, fetchError: _describe(e), fetchedAt: DateTime.now());
    }
    await Future<void>.delayed(clientPollInterval);
  }
});

/// A device's usage per day, for the detail panel.
final clientUsageProvider = FutureProvider.autoDispose.family<List<ClientDay>, String>(
  (ref, mac) => ref.watch(clientRemoteProvider).usage(mac, days: 7),
);

String _describe(Object e) {
  final text = e.toString();
  if (text.contains('Connection refused') || text.contains('connection error') || text.contains('SocketException')) {
    return 'The NMS server is not reachable.';
  }
  if (text.contains('timeout')) return 'The NMS server took too long to answer.';
  return 'Could not load the devices.';
}

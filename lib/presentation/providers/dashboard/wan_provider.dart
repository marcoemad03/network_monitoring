import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/wan_remote_datasource.dart';
import '../../../data/models/wan_usage_models.dart';

final wanRemoteProvider = Provider<WanRemoteDataSource>(
  (ref) => WanRemoteDataSource(ref.watch(dioProvider)),
);

/// One poll of the backend: the newest data plus, when this poll failed, why.
/// On failure [data] still holds the last good result so the screen can keep
/// showing it, marked as out of date.
class WanFeed {
  final WanUsage? data;
  final String? fetchError;
  final DateTime fetchedAt;
  const WanFeed({required this.data, required this.fetchError, required this.fetchedAt});
}

const wanPollInterval = Duration(seconds: 5);

/// Polls while the dashboard is visible and stops when it is closed.
final wanUsageProvider = StreamProvider.autoDispose<WanFeed>((ref) async* {
  final source = ref.watch(wanRemoteProvider);
  WanUsage? last;
  while (true) {
    try {
      last = await source.fetch();
      yield WanFeed(data: last, fetchError: null, fetchedAt: DateTime.now());
    } catch (e) {
      yield WanFeed(data: last, fetchError: _describe(e), fetchedAt: DateTime.now());
    }
    await Future<void>.delayed(wanPollInterval);
  }
});

String _describe(Object e) {
  final text = e.toString();
  if (text.contains('Connection refused') || text.contains('connection error') || text.contains('SocketException')) {
    return 'The NMS server is not reachable.';
  }
  if (text.contains('timeout')) return 'The NMS server took too long to answer.';
  return 'Could not load internet usage.';
}

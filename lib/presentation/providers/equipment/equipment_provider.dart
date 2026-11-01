import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/models/equipment_models.dart';

/// One poll of the equipment list: the newest data plus, when it failed, why.
/// [items] keeps the last good list so the page stays usable, marked as old.
class EquipmentFeed {
  final List<EquipmentItem>? items;
  final String? fetchError;
  final DateTime fetchedAt;
  const EquipmentFeed({required this.items, required this.fetchError, required this.fetchedAt});
}

const equipmentPollInterval = Duration(seconds: 15);

/// Polls while the Equipment page is open and stops when it is closed.
final equipmentFeedProvider = StreamProvider.autoDispose<EquipmentFeed>((ref) async* {
  final client = ref.watch(dioProvider);
  List<EquipmentItem>? last;
  while (true) {
    try {
      final response = await client.get('${ApiConstants.basePath}/monitoring/equipment');
      final body = Map<String, dynamic>.from(response.data as Map);
      last = ((body['data'] as List?) ?? const [])
          .map((e) => EquipmentItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      yield EquipmentFeed(items: last, fetchError: null, fetchedAt: DateTime.now());
    } catch (e) {
      yield EquipmentFeed(items: last, fetchError: _describe(e), fetchedAt: DateTime.now());
    }
    await Future<void>.delayed(equipmentPollInterval);
  }
});

String _describe(Object e) {
  final text = e.toString();
  if (text.contains('Connection refused') || text.contains('connection error') || text.contains('SocketException')) {
    return 'The NMS server is not reachable.';
  }
  if (text.contains('timeout')) return 'The NMS server took too long to answer.';
  return 'Could not load the equipment.';
}

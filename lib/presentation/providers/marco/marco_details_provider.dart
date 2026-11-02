import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/marco_models.dart';
import '../../../data/models/marco_site_models.dart';
import 'marco_provider.dart';

/// One group with its devices, rules in plain words, blocked sites and recent changes.
/// Read again every 30 seconds so usage and online state stay current.
final marcoDetailsProvider = FutureProvider.autoDispose.family<MarcoGroupDetails, String>((ref, id) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(marcoRemoteProvider).details(id);
});

/// The ready-made site packs, the platforms and the always-allowed websites.
final marcoCatalogProvider = FutureProvider.autoDispose<MarcoCatalog>(
  (ref) => ref.watch(marcoRemoteProvider).catalog(),
);

/// Blocks and speed limits set on single devices, by MAC address.
final marcoOverridesProvider = FutureProvider.autoDispose<Map<String, MarcoDeviceControl>>((ref) async {
  final list = await ref.watch(marcoRemoteProvider).overrides();
  return {for (final o in list) o.mac.toUpperCase(): o};
});

/// The group a device belongs to, by MAC address, for every device at once.
final marcoGroupByMacMapProvider = Provider<Map<String, MarcoGroup>>((ref) {
  final groups = ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const <MarcoGroup>[];
  return {
    for (final g in groups)
      for (final m in g.members)
        if ((m.macAddress ?? '').isNotEmpty) m.macAddress!.toUpperCase(): g,
  };
});

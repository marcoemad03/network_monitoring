import '../../../data/models/client_inventory_models.dart';

/// Which devices to list by whether they are connected now.
enum ClientPresence {
  online('Online now'),
  all('All seen'),
  offline('Offline');

  const ClientPresence(this.label);
  final String label;
}

enum ClientSort {
  usage('Used today'),
  speed('Speed now'),
  name('Name'),
  ip('IP address'),
  lastSeen('Last seen');

  const ClientSort(this.label);
  final String label;
}

/// Filters and orders the device list. Pure, so the page and the tests share it.
List<ClientDevice> applyClientFilters(
  List<ClientDevice> all, {
  String query = '',
  ClientKind? kind,
  ClientPresence presence = ClientPresence.online,
  ClientSort sort = ClientSort.usage,
}) {
  final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final result = all.where((d) {
    if (presence == ClientPresence.online && !d.online) return false;
    if (presence == ClientPresence.offline && d.online) return false;
    if (kind != null && d.kind != kind) return false;
    if (terms.isEmpty) return true;
    final haystack = [d.displayName, d.hostname, d.ip, d.mac, d.note, d.routerComment, d.brand, d.kind.label].join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }).toList();

  int byName(ClientDevice a, ClientDevice b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  switch (sort) {
    case ClientSort.usage:
      result.sort((a, b) => b.todayTotal != a.todayTotal ? b.todayTotal.compareTo(a.todayTotal) : byName(a, b));
    case ClientSort.speed:
      result.sort((a, b) => b.currentBps != a.currentBps ? b.currentBps.compareTo(a.currentBps) : byName(a, b));
    case ClientSort.name:
      result.sort(byName);
    case ClientSort.ip:
      result.sort((a, b) => compareIp(a.ip, b.ip) != 0 ? compareIp(a.ip, b.ip) : byName(a, b));
    case ClientSort.lastSeen:
      result.sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        final x = a.lastSeen, y = b.lastSeen;
        if (x == null || y == null) return x == null ? (y == null ? byName(a, b) : 1) : -1;
        return y.compareTo(x);
      });
  }
  return result;
}

/// Orders dotted IPv4 addresses numerically; anything else sorts last.
int compareIp(String a, String b) {
  List<int>? parse(String s) {
    final parts = s.split('.');
    if (parts.length != 4) return null;
    final nums = parts.map(int.tryParse).toList();
    return nums.any((n) => n == null) ? null : nums.cast<int>();
  }

  final x = parse(a), y = parse(b);
  if (x == null || y == null) return x == null ? (y == null ? a.compareTo(b) : 1) : -1;
  for (var i = 0; i < 4; i++) {
    if (x[i] != y[i]) return x[i].compareTo(y[i]);
  }
  return 0;
}

/// Online devices per kind, kinds with at least one device, biggest first.
List<MapEntry<ClientKind, int>> kindCounts(List<ClientDevice> all, ClientPresence presence) {
  final counts = <ClientKind, int>{};
  for (final d in all) {
    if (presence == ClientPresence.online && !d.online) continue;
    if (presence == ClientPresence.offline && d.online) continue;
    counts[d.kind] = (counts[d.kind] ?? 0) + 1;
  }
  final entries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

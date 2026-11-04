import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/inventory_remote_datasource.dart';
import '../../../data/models/inventory_models.dart';
import '../../providers/clients/clients_provider.dart';
import '../../providers/reporting/usage_report_provider.dart';
import '../network/widgets/map_kinds.dart';

final inventoryRemoteProvider = Provider<InventoryRemoteDataSource>((ref) => InventoryRemoteDataSource(ref.watch(dioProvider)));

final inventoryProvider = FutureProvider.autoDispose<AssetInventory>((ref) => ref.watch(inventoryRemoteProvider).fetch());

/// Types a device can be given by hand. Phones and tablets are not counted.
const _editableKinds = ['router', 'switch', 'access_point', 'firewall', 'server', 'computer', 'printer', 'camera', 'medical', 'tv', 'iot', 'phone', 'tablet'];

const _phones = '_phones';
const _review = '_review';

/// Everything the hospital owns on the network, counted by type. What the scan and
/// the names suggest can be corrected device by device.
class AssetListScreen extends ConsumerStatefulWidget {
  const AssetListScreen({super.key});

  @override
  ConsumerState<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends ConsumerState<AssetListScreen> {
  String? _filter;
  String _search = '';
  Timer? _poll;
  bool _exporting = false;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _watchScan() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(inventoryProvider);
    });
  }

  Future<void> _scan() async {
    final go = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Scan the network?'),
            content: const Text(
              'The NMS tries a few ports on each device that is on, and asks it what it is over SNMP. '
              'It changes nothing and prints nothing, and the router is not used. '
              'Phones and medical devices are skipped. It takes a minute or two.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Scan')),
            ],
          ),
    );
    if (go != true) return;
    try {
      await ref.read(inventoryRemoteProvider).startScan();
      ref.invalidate(inventoryProvider);
      _watchScan();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('The scan did not start: $e')));
    }
  }

  Future<void> _export() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    try {
      final file = await ref.read(inventoryRemoteProvider).export();
      final path = await ref.read(reportFileSaverProvider)(file);
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('Saved the inventory report to $path'),
          action: Platform.isWindows ? SnackBarAction(label: 'Show in folder', onPressed: () => Process.run('explorer.exe', ['/select,', path])) : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save the report: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<InventoryItem> _visible(AssetInventory inv) {
    final base = switch (_filter) {
      null => inv.items,
      _phones => inv.excluded,
      _review => inv.items.where((i) => i.unsure).toList(),
      _ => inv.items.where((i) => i.kind == _filter).toList(),
    };
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((i) => [i.name, i.ip, i.mac, i.brand, i.vendor, i.model, i.place, i.serial].any((v) => v.toLowerCase().contains(q))).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryProvider);
    final scan = async.valueOrNull?.scan;
    if (scan != null && !scan.running) {
      _poll?.cancel();
      _poll = null;
    } else if (scan != null && scan.running && _poll == null) {
      _watchScan();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset inventory'),
        actions: [
          TextButton.icon(onPressed: scan?.running == true ? null : _scan, icon: const Icon(Icons.radar, size: 18), label: const Text('Scan network')),
          TextButton.icon(onPressed: _exporting ? null : _export, icon: const Icon(Icons.summarize_outlined, size: 18), label: const Text('Inventory report')),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(inventoryProvider)),
        ],
      ),
      body: async.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the inventory: $e')),
        data: (inv) => _body(context, inv),
      ),
    );
  }

  Widget _body(BuildContext context, AssetInventory inv) {
    final theme = Theme.of(context);
    final items = _visible(inv);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inv.scan.running) LinearProgressIndicator(value: inv.scan.total == 0 ? null : inv.scan.done / inv.scan.total),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CountCard(icon: Icons.inventory_2, label: 'All devices', total: inv.total, online: inv.online, color: theme.colorScheme.primary, selected: _filter == null, onTap: () => setState(() => _filter = null)),
              for (final c in inv.counts)
                _CountCard(
                  icon: kindStyle(c.kind).icon,
                  label: kindStyle(c.kind).label,
                  total: c.total,
                  online: c.online,
                  color: kindStyle(c.kind).color,
                  selected: _filter == c.kind,
                  onTap: () => setState(() => _filter = c.kind),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by name, IP, model or place', isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(width: 10),
              if (inv.needsReview > 0) ...[
                FilterChip(avatar: const Icon(Icons.help_outline, size: 16), label: Text('To review (${inv.needsReview})'), selected: _filter == _review, onSelected: (on) => setState(() => _filter = on ? _review : null)),
                const SizedBox(width: 8),
              ],
              FilterChip(avatar: const Icon(Icons.smartphone, size: 16), label: Text('Phones, not counted (${inv.excluded.length})'), selected: _filter == _phones, onSelected: (on) => setState(() => _filter = on ? _phones : null)),
            ],
          ),
        ),
        Expanded(
          child:
              items.isEmpty
                  ? const Center(child: Text('No devices here'))
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ItemRow(item: items[i], onTap: () => _edit(items[i])),
                  ),
        ),
      ],
    );
  }

  Future<void> _edit(InventoryItem item) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _EditDialog(item: item));
    if (saved == true) ref.invalidate(inventoryProvider);
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.icon, required this.label, required this.total, required this.online, required this.color, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final int total;
  final int online;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '$label: $total, $online online',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? color.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerLow,
            border: Border.all(color: selected ? color : theme.colorScheme.outlineVariant, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(label, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: 6),
              Text('$total', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('$online online', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});
  final InventoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle(item.kind);
    final details = <String>[
      if (item.brand.isNotEmpty) item.brand else if (item.vendor.isNotEmpty) item.vendor,
      if (item.model.isNotEmpty) item.model,
      if (item.serial.isNotEmpty) 'Serial ${item.serial}',
      if (item.pageCount != null) '${item.pageCount} pages',
      if (item.tonerPercent != null) 'Toner ${item.tonerPercent}%',
      if (item.place.isNotEmpty) item.place,
    ];
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(backgroundColor: style.color.withValues(alpha: 0.14), child: Icon(style.icon, size: 20, color: style.color)),
      title: Row(
        children: [
          Flexible(child: Text(item.name.isEmpty ? item.ip : item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(item.ip, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'Consolas')),
        ],
      ),
      subtitle: Text(details.isEmpty ? item.mac : details.join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.unsure) const Tooltip(message: 'Not sure about this one. Check its type.', child: Icon(Icons.help_outline, size: 18, color: Color(0xFFF9A825))),
          if (item.kindSource == 'manual') const Tooltip(message: 'You chose this type', child: Icon(Icons.edit, size: 16)),
          const SizedBox(width: 8),
          Text(style.label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          Icon(item.online ? Icons.circle : Icons.circle_outlined, size: 12, color: item.online ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E)),
          const SizedBox(width: 4),
          SizedBox(width: 48, child: Text(item.online ? 'Online' : 'Offline', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _EditDialog extends ConsumerStatefulWidget {
  const _EditDialog({required this.item});
  final InventoryItem item;

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late final _name = TextEditingController(text: widget.item.name);
  late final _place = TextEditingController(text: widget.item.place);
  late final _note = TextEditingController(text: widget.item.note);
  late String _kind = widget.item.kindSource == 'manual' ? widget.item.kind : '';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // Only what was changed: an untouched name or place must keep following the device.
      final item = widget.item;
      await ref.read(clientRemoteProvider).saveNote(
        item.mac,
        displayName: _name.text == item.name ? null : _name.text,
        place: _place.text == item.place ? null : _place.text,
        note: _note.text == item.note ? null : _note.text,
        kind: _kind,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final theme = Theme.of(context);
    final canEdit = item.mac.isNotEmpty;
    return AlertDialog(
      title: Text(item.name.isEmpty ? item.ip : item.name),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('IP ${item.ip}   MAC ${item.mac.isEmpty ? 'unknown' : item.mac}', style: theme.textTheme.bodySmall),
              if (item.reason.isNotEmpty) ...[const SizedBox(height: 4), Text(item.reason, style: theme.textTheme.bodySmall)],
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder(), isDense: true),
                items: [
                  DropdownMenuItem(value: '', child: Text('Automatic (now: ${kindStyle(item.kindSource == 'manual' ? 'unknown' : item.kind).label})')),
                  for (final k in _editableKinds) DropdownMenuItem(value: k, child: Text(kindStyle(k).label)),
                ],
                onChanged: canEdit ? (v) => setState(() => _kind = v ?? '') : null,
              ),
              const SizedBox(height: 12),
              TextField(controller: _name, enabled: canEdit, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: _place, enabled: canEdit, decoration: const InputDecoration(labelText: 'Place', hintText: 'Reception, Pharmacy...', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 12),
              TextField(controller: _note, enabled: canEdit, maxLines: 2, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder(), isDense: true)),
              if (!canEdit) ...[const SizedBox(height: 10), Text('This device has no MAC address on record, so it cannot be edited here.', style: theme.textTheme.bodySmall)],
              if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: TextStyle(color: theme.colorScheme.error))],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving || !canEdit ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

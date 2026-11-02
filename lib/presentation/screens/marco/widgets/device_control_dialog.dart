import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/marco_site_models.dart';
import '../../../providers/marco/marco_details_provider.dart';
import '../../../providers/marco/marco_provider.dart';

/// Block one device's internet or limit its speed. It works for a device in any
/// group, or in none. Returns true when something was saved.
Future<bool?> showDeviceControlDialog(
  BuildContext context, {
  required String mac,
  required String name,
  String ip = '',
  MarcoDeviceControl? control,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => DeviceControlDialog(mac: mac, name: name, ip: ip, control: control),
  );
}

class DeviceControlDialog extends ConsumerStatefulWidget {
  const DeviceControlDialog({super.key, required this.mac, required this.name, this.ip = '', this.control});
  final String mac;
  final String name;
  final String ip;
  final MarcoDeviceControl? control;

  @override
  ConsumerState<DeviceControlDialog> createState() => _DeviceControlDialogState();
}

class _DeviceControlDialogState extends ConsumerState<DeviceControlDialog> {
  late bool _blocked = widget.control?.blocked ?? false;
  late bool _limited = widget.control?.limited ?? false;
  late final TextEditingController _down = TextEditingController(text: _fmt(widget.control?.downloadMbps));
  late final TextEditingController _up = TextEditingController(text: _fmt(widget.control?.uploadMbps));
  late final TextEditingController _reason = TextEditingController(text: widget.control?.reason ?? '');
  bool _saving = false;
  String? _error;

  static String _fmt(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void dispose() {
    _down.dispose();
    _up.dispose();
    _reason.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _preset(double mbps) => setState(() {
    _limited = true;
    _down.text = _fmt(mbps);
    _up.text = _fmt((mbps / 2).clamp(0.5, 1000));
  });

  Future<void> _save() async {
    final dl = _limited ? _num(_down) : null;
    final ul = _limited ? _num(_up) : null;
    if (_limited && !_blocked) {
      if (dl == null && ul == null) {
        setState(() => _error = 'Type a download or upload speed, or turn the limit off');
        return;
      }
      if ((dl != null && dl <= 0) || (ul != null && ul <= 0)) {
        setState(() => _error = 'A speed must be more than 0 Mbps');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final remote = ref.read(marcoRemoteProvider);
      if (!_blocked && !_limited) {
        await remote.clearDeviceControl(widget.mac);
      } else {
        await remote.setDeviceControl(widget.mac, blocked: _blocked, downloadMbps: dl, uploadMbps: ul, reason: _reason.text.trim());
      }
      ref.invalidate(marcoOverridesProvider);
      ref.invalidate(marcoDetailsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dryRun = ref.watch(marcoGroupsProvider).valueOrNull?.dryRun ?? false;
    return AlertDialog(
      title: Text(widget.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.ip.isEmpty ? '' : '${widget.ip} · '}${widget.mac}', style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Block internet for this device'),
                subtitle: const Text('It stays on the hospital network but cannot reach the internet.'),
                value: _blocked,
                onChanged: _saving ? null : (v) => setState(() => _blocked = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Limit speed'),
                subtitle: Text(_blocked ? 'Not needed while the device is blocked.' : 'Overrides the speed of its group.'),
                value: _limited && !_blocked,
                onChanged: _saving || _blocked ? null : (v) => setState(() => _limited = v),
              ),
              if (_limited && !_blocked) ...[
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in const [1.0, 2.0, 5.0, 10.0, 20.0])
                      ActionChip(label: Text('${m.toInt()} Mbps'), onPressed: _saving ? null : () => _preset(m)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _down,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Download (Mbps)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _up,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Upload (Mbps)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                enabled: !_saving,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Shown in the activity log', border: OutlineInputBorder()),
              ),
              if (dryRun)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Safe mode: this is saved, but the router is not changed.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(!_blocked && !_limited ? (widget.control == null ? 'Close' : 'Remove block and limit') : 'Save'),
        ),
      ],
    );
  }
}

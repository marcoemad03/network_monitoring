import 'package:flutter/material.dart';
import '../../../../data/datasources/remote/client_remote_datasource.dart';
import '../../../../data/models/network_map_models.dart';
import 'map_kinds.dart';

/// The kinds the user may set on a device (the server accepts these).
const editableKinds = <String>['computer', 'phone', 'tablet', 'printer', 'camera', 'tv', 'network', 'server', 'iot', 'medical', 'unknown'];

const _maxName = 80;

/// What the user changed. A null field was left alone; an empty one clears it.
class DeviceEdit {
  final String? name;
  final String? kind;
  final String? place;
  const DeviceEdit({this.name, this.kind, this.place});
}

/// Asks for a new name, type and place for one device. Returns null when cancelled.
Future<DeviceEdit?> showEditDeviceDialog(BuildContext context, MapDevice device, List<String> knownPlaces) {
  return showDialog<DeviceEdit>(context: context, builder: (_) => _EditDeviceDialog(device: device, knownPlaces: knownPlaces));
}

class _EditDeviceDialog extends StatefulWidget {
  const _EditDeviceDialog({required this.device, required this.knownPlaces});
  final MapDevice device;
  final List<String> knownPlaces;

  @override
  State<_EditDeviceDialog> createState() => _EditDeviceDialogState();
}

class _EditDeviceDialogState extends State<_EditDeviceDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.device.nameSource == 'custom' ? widget.device.name : '');
  late final TextEditingController _place = TextEditingController(text: widget.device.placeSource == PlaceSource.custom ? widget.device.place : '');
  late String _kind = widget.device.kindCustom ? widget.device.kind : '';

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final detected = kindStyle(d.kind).label;
    return AlertDialog(
      title: const Text('Edit device'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${d.ip.isEmpty ? '' : '${d.ip} · '}${d.mac}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                maxLength: _maxName,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: d.hostname.isEmpty ? 'For example: Triage PC 2' : d.hostname,
                  helperText: 'Leave empty to use the name the device reports',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: '', child: Text(d.kindCustom ? 'Detect automatically' : 'Detected: $detected')),
                  for (final k in editableKinds)
                    DropdownMenuItem(
                      value: k,
                      child: Row(children: [Icon(kindStyle(k).icon, size: 18, color: kindStyle(k).color), const SizedBox(width: 8), Text(kindStyle(k).label)]),
                    ),
                ],
                onChanged: (v) => setState(() => _kind = v ?? ''),
              ),
              const SizedBox(height: 10),
              _PlaceField(controller: _place, knownPlaces: widget.knownPlaces, helper: 'Where the device is. Leave empty to use the router port.', hint: 'For example: Emergency ward, room 3'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final d = widget.device;
            final name = _name.text.trim();
            final place = _place.text.trim();
            final wasKind = d.kindCustom ? d.kind : '';
            Navigator.pop(
              context,
              DeviceEdit(
                name: name != (d.nameSource == 'custom' ? d.name : '') ? name : null,
                kind: _kind != wasKind ? _kind : null,
                place: place != (d.placeSource == PlaceSource.custom ? d.place : '') ? place : null,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Asks for the place to give several devices. Returns null when cancelled; an
/// empty string clears the place.
Future<String?> showSetPlaceDialog(BuildContext context, int count, List<String> knownPlaces) {
  return showDialog<String>(context: context, builder: (_) => _SetPlaceDialog(count: count, knownPlaces: knownPlaces));
}

class _SetPlaceDialog extends StatefulWidget {
  const _SetPlaceDialog({required this.count, required this.knownPlaces});
  final int count;
  final List<String> knownPlaces;

  @override
  State<_SetPlaceDialog> createState() => _SetPlaceDialogState();
}

class _SetPlaceDialogState extends State<_SetPlaceDialog> {
  final TextEditingController _place = TextEditingController();

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set place for ${widget.count} device${widget.count == 1 ? '' : 's'}'),
      content: SizedBox(
        width: 400,
        child: _PlaceField(controller: _place, knownPlaces: widget.knownPlaces, helper: 'Leave empty to remove the place', hint: 'For example: Laboratory', autofocus: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _place.text.trim()), child: const Text('Save')),
      ],
    );
  }
}

/// Asks for a name for a router port. Returns null when cancelled; an empty string
/// removes the name.
Future<String?> showPortLabelDialog(BuildContext context, MapPort port) {
  return showDialog<String>(context: context, builder: (_) => _PortLabelDialog(port: port));
}

class _PortLabelDialog extends StatefulWidget {
  const _PortLabelDialog({required this.port});
  final MapPort port;

  @override
  State<_PortLabelDialog> createState() => _PortLabelDialogState();
}

class _PortLabelDialogState extends State<_PortLabelDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.port.labelSource == 'custom' ? widget.port.label : '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final port = widget.port;
    return AlertDialog(
      title: Text('Name port ${port.name}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (port.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('The router calls this port "${port.comment}".')),
            if (port.trunk)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Many devices are behind this port, so it leads to another switch. Its name will not be used as the place of each device.'),
              ),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: _maxName,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'For example: Second floor switch', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Save')),
      ],
    );
  }
}

/// Runs a save and shows why it failed instead of losing the user's input silently.
Future<bool> runSave(BuildContext context, Future<void> Function() save, {String done = 'Saved'}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await save();
    messenger.showSnackBar(SnackBar(content: Text(done)));
    return true;
  } on ClientApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not save.')));
  }
  return false;
}

/// A text field for a place that can also pick one already used elsewhere.
class _PlaceField extends StatelessWidget {
  const _PlaceField({required this.controller, required this.knownPlaces, required this.helper, required this.hint, this.autofocus = false});
  final TextEditingController controller;
  final List<String> knownPlaces;
  final String helper;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: _maxName,
      decoration: InputDecoration(
        labelText: 'Place',
        hintText: hint,
        helperText: helper,
        border: const OutlineInputBorder(),
        suffixIcon: knownPlaces.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Places already in use',
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (v) => controller.text = v,
                itemBuilder: (_) => [for (final p in knownPlaces) PopupMenuItem(value: p, child: Text(p))],
              ),
      ),
    );
  }
}

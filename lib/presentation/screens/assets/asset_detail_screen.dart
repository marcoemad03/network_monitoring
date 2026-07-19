import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/asset_providers.dart';
import '../../../core/errors/failures.dart';

class AssetDetailScreen extends ConsumerStatefulWidget {
  final String deviceId;
  const AssetDetailScreen({super.key, required this.deviceId});

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  final _deptCtrl = TextEditingController();
  final _floorCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _portCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _apCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() async {
    final result = await ref.read(assetRepositoryProvider).getAssetDetail(widget.deviceId);
    result.fold(
      (failure) => setState(() => _isLoading = false),
      (detail) {
        _deptCtrl.text = detail.department ?? '';
        _floorCtrl.text = detail.floorName ?? '';
        _roomCtrl.text = detail.room ?? '';
        _portCtrl.text = detail.switchPort ?? '';
        _notesCtrl.text = detail.notes ?? '';
        _apCtrl.text = detail.accessPointId ?? '';
        setState(() => _isLoading = false);
      },
    );
  }

  void _save() async {
    await ref.read(assetRepositoryProvider).upsertAssetDetail({
      'device_id': widget.deviceId,
      'department': _deptCtrl.text.isEmpty ? null : _deptCtrl.text,
      'floor_name': _floorCtrl.text.isEmpty ? null : _floorCtrl.text,
      'room': _roomCtrl.text.isEmpty ? null : _roomCtrl.text,
      'switch_port': _portCtrl.text.isEmpty ? null : _portCtrl.text,
      'access_point_id': _apCtrl.text.isEmpty ? null : _apCtrl.text,
      'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset detail saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Detail'),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Device: ${widget.deviceId}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(controller: _deptCtrl, decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _floorCtrl, decoration: const InputDecoration(labelText: 'Floor', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _roomCtrl, decoration: const InputDecoration(labelText: 'Room', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _portCtrl, decoration: const InputDecoration(labelText: 'Switch Port', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _apCtrl, decoration: const InputDecoration(labelText: 'Access Point ID', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder()), maxLines: 3),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deptCtrl.dispose();
    _floorCtrl.dispose();
    _roomCtrl.dispose();
    _portCtrl.dispose();
    _notesCtrl.dispose();
    _apCtrl.dispose();
    super.dispose();
  }
}

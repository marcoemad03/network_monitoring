import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device/device_provider.dart';
import '../../providers/device/enterprise_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';

class DeviceControlPanel extends ConsumerStatefulWidget {
  final String deviceId;

  const DeviceControlPanel({super.key, required this.deviceId});

  @override
  ConsumerState<DeviceControlPanel> createState() => _DeviceControlPanelState();
}

class _DeviceControlPanelState extends ConsumerState<DeviceControlPanel> {
  final Set<String> _loadingActions = {};

  Future<void> _executeAction(String action, {Map<String, dynamic>? params}) async {
    setState(() => _loadingActions.add(action));
    try {
      final repo = ref.read(deviceRepositoryProvider);
      final result = await repo.controlDevice(widget.deviceId, action, params: params);
      result.fold(
        (failure) {
          if (mounted) AppSnackbar.error(context, '${_actionLabel(action)} failed: ${failure.message}');
        },
        (_) {
          if (mounted) AppSnackbar.success(context, '${_actionLabel(action)} successful');
        },
      );
    } catch (e) {
      if (mounted) AppSnackbar.error(context, 'Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingActions.remove(action));
        ref.invalidate(deviceControlLogsProvider(widget.deviceId));
      }
    }
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'disconnect':
        return 'Disconnect';
      case 'reconnect':
        return 'Reconnect';
      case 'block_internet':
        return 'Block Internet';
      case 'unblock_internet':
        return 'Unblock Internet';
      case 'limit_speed':
        return 'Limit Speed';
      case 'unlimited_speed':
        return 'Unlimited Speed';
      case 'rename':
        return 'Rename';
      default:
        return action;
    }
  }

  void _handleAction(String action) {
    switch (action) {
      case 'limit_speed':
        _showLimitSpeedDialog();
        break;
      case 'rename':
        _showRenameDialog();
        break;
      case 'view_logs':
        context.push('/devices/${widget.deviceId}/events');
        break;
      default:
        _executeAction(action);
    }
  }

  Future<void> _showLimitSpeedDialog() async {
    final downloadController = TextEditingController();
    final uploadController = TextEditingController();

    await AppDialog.show(
      context: context,
      title: 'Limit Speed',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: downloadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Download Limit (kbps)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: uploadController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Upload Limit (kbps)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      confirmText: 'Apply',
      onConfirm: () {
        final dl = int.tryParse(downloadController.text);
        final ul = int.tryParse(uploadController.text);
        _executeAction('limit_speed', params: {
          'download_limit_kbps': dl,
          'upload_limit_kbps': ul,
        });
      },
    );

    downloadController.dispose();
    uploadController.dispose();
  }

  Future<void> _showRenameDialog() async {
    final nameController = TextEditingController();

    await AppDialog.show(
      context: context,
      title: 'Rename Device',
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(
          labelText: 'New Name',
          border: OutlineInputBorder(),
        ),
      ),
      confirmText: 'Apply',
      onConfirm: () {
        final newName = nameController.text.trim();
        if (newName.isNotEmpty) {
          _executeAction('rename', params: {'name': newName});
        }
      },
    );

    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Device Control',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  _buildButton('Disconnect', Icons.power_settings_new, Colors.red, true, 'disconnect', itemWidth),
                  _buildButton('Reconnect', Icons.refresh, Colors.green, true, 'reconnect', itemWidth),
                  _buildButton('Block Internet', Icons.block, Colors.red, false, 'block_internet', itemWidth),
                  _buildButton('Unblock Internet', Icons.check_circle, Colors.green, false, 'unblock_internet', itemWidth),
                  _buildButton('Limit Speed', Icons.speed, Colors.orange, true, 'limit_speed', itemWidth),
                  _buildButton('Unlimited Speed', Icons.all_inclusive, Colors.green, true, 'unlimited_speed', itemWidth),
                  _buildButton('Rename', Icons.edit, Colors.blue, true, 'rename', itemWidth),
                  _buildButton('View Logs', Icons.history, Colors.grey, true, 'view_logs', itemWidth),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, Color color, bool filled, String action, double width) {
    final isLoading = _loadingActions.contains(action);
    final onPressed = isLoading ? null : () => _handleAction(action);

    final button = filled
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16),
                      const SizedBox(width: 6),
                      Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16),
                      const SizedBox(width: 6),
                      Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
          );

    return SizedBox(width: width, child: button);
  }
}

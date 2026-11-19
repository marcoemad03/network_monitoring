import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/data_format.dart';
import '../../../data/models/client_inventory_models.dart';
import '../../../data/models/network_problem_models.dart';
import '../../providers/clients/clients_provider.dart';
import '../dashboard/widgets/dash_card.dart';
import '../devices/widgets/kind_visuals.dart';

/// Devices that are connected but have no internet, and addresses two devices use
/// at once, read from the router when the page opens or is refreshed.
class NetworkProblemsScreen extends ConsumerWidget {
  const NetworkProblemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(networkProblemsProvider);
    final checking = async.isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network problems'),
        actions: [
          if (async.valueOrNull?.checkedAt case final at?)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'Checked ${formatAge(DateTime.now().difference(at))}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          FilledButton.tonalIcon(
            onPressed: checking ? null : () => ref.invalidate(networkProblemsProvider),
            icon:
                checking
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
            label: Text(checking ? 'Checking' : 'Check again'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth < 700 ? 12.0 : 20.0;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(networkProblemsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(pad),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: async.when(
                      skipLoadingOnRefresh: false,
                      loading:
                          () => const Column(
                            children: [SkeletonBox(height: 60), SizedBox(height: 14), SkeletonBox(height: 220)],
                          ),
                      error:
                          (e, _) => const EmptyNotice(
                            icon: Icons.cloud_off,
                            title: 'The network could not be checked',
                            detail: 'The NMS server did not answer. Check that it is running, then press Check again.',
                          ),
                      data: (p) => _Body(problems: p),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.problems});

  final NetworkProblems problems;

  @override
  Widget build(BuildContext context) {
    if (!problems.available) {
      return EmptyNotice(
        icon: Icons.router_outlined,
        title: 'The router could not be read',
        detail: problems.error.isEmpty ? null : problems.error,
      );
    }
    final conflicts = problems.issues.where((i) => i.isConflict).toList();
    final noNet = problems.issues.where((i) => !i.isConflict && i.severity != IssueSeverity.info).toList();
    final onPurpose = problems.issues.where((i) => i.severity == IssueSeverity.info).toList();
    final affected = <String>{
      for (final i in [...conflicts, ...noNet])
        for (final d in i.devices) d.mac,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              tone: StatusTone.neutral,
              icon: Icons.devices,
              label: '${problems.devicesSeen} devices connected now',
            ),
            StatusPill(
              tone: conflicts.isEmpty ? StatusTone.ok : StatusTone.error,
              label:
                  conflicts.isEmpty
                      ? 'No shared addresses'
                      : '${conflicts.length} address${conflicts.length == 1 ? '' : 'es'} used by two devices',
            ),
            StatusPill(
              tone: noNet.isEmpty ? StatusTone.ok : StatusTone.warning,
              label:
                  noNet.isEmpty
                      ? 'Every connected device can reach the internet'
                      : '${affected.length} device${affected.length == 1 ? '' : 's'} may have no internet',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Two devices on one address',
          icon: Icons.compare_arrows,
          empty: 'No address is used by two devices.',
          issues: conflicts,
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Connected but no internet',
          icon: Icons.wifi_off,
          empty: 'No connected device looks cut off.',
          issues: noNet,
        ),
        if (onPurpose.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Blocked on purpose',
            icon: Icons.block,
            empty: '',
            issues: onPurpose,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Read from the router: the Wi-Fi page, DHCP, ARP and the NMS blocks. A device that is switched off or out of range is not listed.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.empty, required this.issues});

  final String title;
  final IconData icon;
  final String empty;
  final List<NetworkIssue> issues;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      title: title,
      icon: icon,
      trailing: issues.isEmpty ? null : Text('${issues.length}', style: Theme.of(context).textTheme.titleSmall),
      child:
          issues.isEmpty
              ? Row(
                children: [
                  StatusPill(tone: StatusTone.ok, label: empty),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < issues.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _IssueCard(issue: issues[i]),
                  ],
                ],
              ),
    );
  }
}

class _IssueCard extends StatefulWidget {
  const _IssueCard({required this.issue});

  final NetworkIssue issue;

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  static const _shown = 6;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = widget.issue;
    final tone = switch (issue.severity) {
      IssueSeverity.error => StatusTone.error,
      IssueSeverity.warning => StatusTone.warning,
      IssueSeverity.info => StatusTone.neutral,
    };
    final style = toneStyle(context, tone);
    final devices = _all ? issue.devices : issue.devices.take(_shown).toList();
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: style.foreground, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(issue.severity == IssueSeverity.info ? Icons.info_outline : style.icon, color: style.foreground, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(issue.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(issue.detail, style: theme.textTheme.bodyMedium),
          if (issue.fix.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(issue.fix, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          for (final d in devices) _DeviceRow(device: d),
          if (issue.devices.length > _shown)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _all = !_all),
                child: Text(_all ? 'Show fewer' : 'Show all ${issue.devices.length}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device});

  final IssueDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final details = [
      if (device.ip.isNotEmpty) device.ip,
      device.mac,
      if (device.seen.isNotEmpty) device.seen,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(kindIcon(ClientKind.parse(device.kind)), size: 22, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.label, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(details, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ),
          if (!device.online)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text('not connected', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ),
          IconButton(
            tooltip: 'Copy MAC address',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: device.mac));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Copied ${device.mac}'), duration: const Duration(seconds: 2)),
              );
            },
          ),
        ],
      ),
    );
  }
}

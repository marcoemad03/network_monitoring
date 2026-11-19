import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/sites_models.dart';
import '../../../providers/clients/clients_provider.dart';
import '../../../providers/sites/sites_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../devices/widgets/kind_visuals.dart';
import 'site_widgets.dart';

/// The devices to search in, read once when the card opens.
final _searchDevicesProvider = FutureProvider.autoDispose<List<ClientDevice>>(
  (ref) async => (await ref.watch(clientRemoteProvider).fetch()).clients,
);

/// What one device asked for in a period.
final deviceSearchProvider = FutureProvider.autoDispose
    .family<DeviceSites, ({String key, int hours, bool background})>(
      (ref, q) => ref
          .watch(sitesRemoteProvider)
          .device(q.key, hours: q.hours, background: q.background),
    );

/// Find a device by name, IP or MAC address and see the sites it opened in a
/// period, most used first, with the last time each was opened.
class DeviceSearchCard extends ConsumerStatefulWidget {
  const DeviceSearchCard({super.key});

  @override
  ConsumerState<DeviceSearchCard> createState() => _DeviceSearchCardState();
}

class _DeviceSearchCardState extends ConsumerState<DeviceSearchCard> {
  String? _key;
  String _label = '';
  int _hours = 24;
  bool _background = false;

  static final _ipOrMac = RegExp(
    r'^(\d{1,3}(\.\d{1,3}){3}|([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2})$',
  );

  bool _matches(ClientDevice d, String q) =>
      d.displayName.toLowerCase().contains(q) ||
      d.hostname.toLowerCase().contains(q) ||
      d.ip.contains(q) ||
      d.mac.toLowerCase().contains(q);

  void _choose(String key, String label) => setState(() {
    _key = key;
    _label = label;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices =
        ref.watch(_searchDevicesProvider).valueOrNull ?? const <ClientDevice>[];
    return DashCard(
      title: 'Search a device',
      icon: Icons.manage_search,
      subtitle:
          'Type a device name, IP or MAC address to see the sites it opened in a period.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<ClientDevice>(
            displayStringForOption: (d) => d.displayName,
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<ClientDevice>.empty();
              return devices.where((d) => _matches(d, q)).take(12);
            },
            onSelected:
                (d) => _choose(d.mac.isNotEmpty ? d.mac : d.ip, d.displayName),
            fieldViewBuilder:
                (context, controller, focus, onSubmit) => TextField(
                  controller: controller,
                  focusNode: focus,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Device name, IP or MAC',
                    hintText: 'For example Engy-s-A26 or 172.16.0.96',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (text) {
                    final t = text.trim();
                    final q = t.toLowerCase();
                    final found = devices.where((d) => _matches(d, q)).toList();
                    if (found.length == 1) {
                      final d = found.first;
                      _choose(d.mac.isNotEmpty ? d.mac : d.ip, d.displayName);
                    } else if (_ipOrMac.hasMatch(t)) {
                      _choose(t.replaceAll('-', ':').toUpperCase(), t);
                    } else {
                      onSubmit();
                    }
                  },
                ),
            optionsViewBuilder:
                (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 320,
                        maxWidth: 520,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final d in options)
                            ListTile(
                              dense: true,
                              leading: Icon(kindIcon(d.kind)),
                              title: Text(d.displayName),
                              subtitle: Text(
                                [
                                  if (d.ip.isNotEmpty) d.ip,
                                  d.mac,
                                  d.kind.label,
                                ].join(' · '),
                              ),
                              trailing:
                                  d.online
                                      ? const Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: Colors.green,
                                      )
                                      : null,
                              onTap: () => onSelected(d),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final e in sitesPeriods.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _hours == e.key,
                  onSelected: (_) => setState(() => _hours = e.key),
                ),
              FilterChip(
                label: const Text('Include background'),
                tooltip: 'Updates, push notifications, ads and content delivery',
                selected: _background,
                onSelected: (v) => setState(() => _background = v),
              ),
            ],
          ),
          if (_key != null) ...[
            const SizedBox(height: 12),
            _Results(
              query: (key: _key!, hours: _hours, background: _background),
              label: _label,
            ),
          ],
          if (_key == null && devices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'The device list is loading. You can also type an IP or MAC address and press Enter.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.label});

  final ({String key, int hours, bool background}) query;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final period = (sitesPeriods[query.hours] ?? '${query.hours} hours').toLowerCase();
    return ref
        .watch(deviceSearchProvider(query))
        .when(
          loading: () => const SkeletonBox(height: 120),
          error:
              (e, _) => Text(
                'The sites of $label could not be loaded.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          data: (d) {
            final who = [
              d.name,
              if (d.ip.isNotEmpty) d.ip,
              if (d.mac.isNotEmpty) d.mac,
            ].join(' · ');
            if (d.sites.isEmpty) {
              return Text(
                d.recording
                    ? '$who: only background services in the $period (${d.hiddenBackground} lookups). Turn on Include background to see them.'
                    : '$who: no sites recorded in the $period. The device may have been off, used mobile data, or used encrypted DNS.',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              );
            }
            final total = d.sites.fold<int>(0, (n, s) => n + s.queries);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  who,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${d.sites.length} site${d.sites.length == 1 ? '' : 's'} in the $period, ${countText(total)} lookups'
                  '${d.hiddenBackground > 0 && !query.background ? ', ${countText(d.hiddenBackground)} background lookups hidden' : ''}.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 8),
                for (final s in d.sites) ...[
                  const Divider(height: 1),
                  _SiteLine(site: s),
                ],
              ],
            );
          },
        );
  }
}

class _SiteLine extends StatelessWidget {
  const _SiteLine({required this.site});

  final SiteUse site;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final last =
        site.lastSeen == null
            ? ''
            : 'last ${formatAge(DateTime.now().difference(site.lastSeen!))}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SiteLogo(site: site, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  site.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    if (site.domainText.isNotEmpty) site.domainText,
                    categoryLabel(site.category),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${countText(site.queries)} lookups',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                [
                  if (site.blocked > 0) '${countText(site.blocked)} blocked',
                  if (last.isNotEmpty) last,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: site.blocked > 0 ? theme.colorScheme.error : muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

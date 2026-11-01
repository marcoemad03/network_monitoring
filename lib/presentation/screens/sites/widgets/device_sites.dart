import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/sites_models.dart';
import '../../../providers/sites/sites_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../devices/widgets/kind_visuals.dart';
import 'site_widgets.dart';

/// The sites one device asked for in the last 24 hours, by name with logo.
/// Used inside the security device dialog and on its own.
class DeviceSitesSection extends ConsumerWidget {
  const DeviceSitesSection({
    super.key,
    required this.deviceKey,
    this.limit = 15,
  });

  final String deviceKey;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final sites = ref.watch(deviceSitesProvider(deviceKey));
    return sites.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SkeletonBox(height: 60),
          ),
      error:
          (_, __) => Text(
            'The sites this device asked for could not be loaded.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      data: (d) {
        if (d.sites.isEmpty) {
          return Text(
            d.recording
                ? 'Only background services in the last 24 hours (${d.hiddenBackground} lookups: updates, push notifications, content delivery).'
                : 'No sites recorded for this device in the last 24 hours. Either it did not use the hospital DNS, or the DNS recording is not set up (see the Websites page).',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in d.sites.take(limit))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Semantics(
                  label:
                      '${s.name}, ${categoryLabel(s.category)}, ${s.queries} lookups',
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        SiteLogo(site: s, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(categoryIcon(s.category), size: 15, color: muted),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 110,
                          child: Text(
                            categoryLabel(s.category),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            '${countText(s.queries)} lookups',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            s.lastSeen == null
                                ? ''
                                : formatAge(
                                  DateTime.now().difference(s.lastSeen!),
                                ),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (d.sites.length > limit)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'and ${d.sites.length - limit} more',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            if (d.hiddenBackground > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${countText(d.hiddenBackground)} lookups of background services (updates, push notifications, content delivery) are left out.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One device's sites in a dialog of its own, reached from a site.
class DeviceSitesDialog extends ConsumerWidget {
  const DeviceSitesDialog({
    super.key,
    required this.deviceKey,
    required this.name,
    required this.kind,
  });

  final String deviceKey;
  final String name;
  final String kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final k = ClientKind.parse(kind);
    return AlertDialog(
      title: Row(
        children: [
          Icon(kindIcon(k)),
          const SizedBox(width: 12),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          DeviceKindChip(kind: kind),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sites in the last 24 hours',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              DeviceSitesSection(deviceKey: deviceKey, limit: 30),
              const SizedBox(height: 12),
              Text(
                'Only domains are recorded, never page addresses or content. Opening this view is written to the audit log.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

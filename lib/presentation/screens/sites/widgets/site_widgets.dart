import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/sites_models.dart';
import '../../../providers/sites/sites_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../devices/widgets/kind_visuals.dart';

String countText(int n) =>
    n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

IconData categoryIcon(String c) => switch (c) {
  'insurance' => Icons.health_and_safety_outlined,
  'health' => Icons.local_hospital_outlined,
  'government' => Icons.account_balance_outlined,
  'banking' => Icons.account_balance_wallet_outlined,
  'social' => Icons.groups_outlined,
  'video' => Icons.play_circle_outline,
  'messaging' => Icons.chat_bubble_outline,
  'search' => Icons.search,
  'email' => Icons.mail_outline,
  'work' => Icons.work_outline,
  'cloud' => Icons.cloud_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  'news' => Icons.newspaper_outlined,
  'ai' => Icons.auto_awesome_outlined,
  'games' => Icons.sports_esports_outlined,
  'background' => Icons.settings_ethernet,
  _ => Icons.public,
};

/// The site's logo when the hospital has one, otherwise its first letter on the
/// category's colour. The name is always written next to it, so the logo is
/// decoration and is left out of the screen reader's path.
class SiteLogo extends ConsumerWidget {
  const SiteLogo({super.key, required this.site, this.size = 40});

  final SiteUse site;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = _Initial(
      name: site.name,
      category: site.category,
      size: size,
    );
    if (!site.hasLogo) return ExcludeSemantics(child: fallback);
    final logo = ref.watch(siteLogoProvider(site.key));
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: logo.when(
          loading: () => fallback,
          error: (_, __) => fallback,
          data:
              (bytes) =>
                  bytes == null
                      ? fallback
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(size * 0.22),
                        child: ColoredBox(
                          color:
                              Colors
                                  .white, // logos are drawn for a light background
                          child: Padding(
                            padding: EdgeInsets.all(size * 0.08),
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => fallback,
                            ),
                          ),
                        ),
                      ),
        ),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({
    required this.name,
    required this.category,
    required this.size,
  });

  final String name;
  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final letter =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child:
          category == 'other' || category == 'background'
              ? Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSecondaryContainer,
                ),
              )
              : Icon(
                categoryIcon(category),
                size: size * 0.5,
                color: scheme.onSecondaryContainer,
              ),
    );
  }
}

/// "Phone" or "Computer" with its icon, so a person can tell what the device is at a glance.
class DeviceKindChip extends StatelessWidget {
  const DeviceKindChip({super.key, required this.kind});

  final String kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = ClientKind.parse(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kindIcon(k),
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            k.label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether a site has a name the hospital chose, a common name, or only its domain.
Widget naming(SiteUse s) {
  if (s.named)
    return const StatusPill(
      tone: StatusTone.ok,
      icon: Icons.check_circle_outline,
      label: 'Named',
    );
  if (s.builtIn)
    return const StatusPill(
      tone: StatusTone.neutral,
      icon: Icons.verified_outlined,
      label: 'Common site',
    );
  return const StatusPill(
    tone: StatusTone.warning,
    icon: Icons.label_off_outlined,
    label: 'Not named yet',
  );
}

/// One site in the list.
class SiteRow extends StatelessWidget {
  const SiteRow({
    super.key,
    required this.site,
    required this.onTap,
    this.compact = false,
  });

  final SiteUse site;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final last =
        site.lastSeen == null
            ? ''
            : formatAge(DateTime.now().difference(site.lastSeen!));
    final summary =
        '${site.name}, ${categoryLabel(site.category)}, ${site.devices} device${site.devices == 1 ? '' : 's'}, ${site.queries} lookups'
        '${site.blocked > 0 ? ', ${site.blocked} blocked' : ''}';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          site.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (site.domainText.isNotEmpty)
          Text(
            site.domainText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: '$summary. Opens details.',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 10 : 12,
            ),
            child:
                compact
                    ? Row(
                      children: [
                        SiteLogo(site: site, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              const SizedBox(height: 4),
                              Text(
                                '${site.devices} device${site.devices == 1 ? '' : 's'}  ·  ${countText(site.queries)} lookups${last.isEmpty ? '' : '  ·  $last'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: muted),
                      ],
                    )
                    : Row(
                      children: [
                        SiteLogo(site: site, size: 44),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: title),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Icon(
                                categoryIcon(site.category),
                                size: 16,
                                color: muted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  categoryLabel(site.category),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${site.devices} device${site.devices == 1 ? '' : 's'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${countText(site.queries)} lookups${site.blocked > 0 ? '\n${countText(site.blocked)} blocked' : ''}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            last,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: naming(site),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
          ),
        ),
      ),
    );
  }
}

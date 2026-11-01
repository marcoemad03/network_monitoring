import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/data_format.dart';
import '../../../data/models/sites_models.dart';
import '../../providers/sites/sites_provider.dart';
import '../dashboard/widgets/dash_card.dart';
import 'widgets/device_sites.dart';
import 'widgets/site_dialogs.dart';
import 'widgets/site_widgets.dart';

/// The websites devices asked for, by name and logo, with the devices behind each.
class SitesScreen extends ConsumerStatefulWidget {
  const SitesScreen({super.key});

  @override
  ConsumerState<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends ConsumerState<SitesScreen> {
  String _category = 'all';
  String _search = '';

  void _addSite() {
    showDialog<bool>(context: context, builder: (_) => const SiteEditorDialog());
  }

  Future<void> _openSite(SiteUse site, int hours) {
    return showDialog<void>(
      context: context,
      builder:
          (_) => SiteDetailDialog(
            site: site,
            hours: hours,
            onOpenDevice:
                (d) => showDialog<void>(
                  context: context,
                  builder:
                      (_) => DeviceSitesDialog(
                        deviceKey: d.key,
                        name: d.name,
                        kind: d.kind,
                      ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sitesProvider);
    final overview = state.overview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Websites'),
        actions: [
          _PeriodMenu(
            hours: state.hours,
            onChanged: (h) => ref.read(sitesProvider.notifier).setHours(h),
          ),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width < 700)
            IconButton.filled(
              tooltip: 'Add a site',
              onPressed: overview == null ? null : _addSite,
              icon: const Icon(Icons.add),
            )
          else
            FilledButton.icon(
              onPressed: overview == null ? null : _addSite,
              icon: const Icon(Icons.add),
              label: const Text('Add a site'),
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth < 700 ? 12.0 : 20.0;
          return RefreshIndicator(
            onRefresh: () => ref.read(sitesProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(pad),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: _body(context, state, c.maxWidth),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, SitesState state, double width) {
    final overview = state.overview;
    if (state.fetchError != null && overview == null) {
      return EmptyNotice(
        icon: Icons.cloud_off,
        title: 'The recorded sites could not be loaded',
        detail: state.fetchError,
      );
    }
    if (overview == null) {
      return const Column(
        children: [
          SkeletonBox(height: 80),
          SizedBox(height: 14),
          SkeletonBox(height: 260),
        ],
      );
    }

    final children = <Widget>[];
    if (state.fetchError != null) {
      children.addAll([
        StatusPill(
          tone: StatusTone.warning,
          icon: Icons.sync_problem,
          label: 'Showing the last data. ${state.fetchError}',
        ),
        const SizedBox(height: 12),
      ]);
    }
    children.add(_Sources(overview: overview));
    children.add(const SizedBox(height: 14));

    if (!overview.recording) {
      children.add(_Setup(overview: overview));
      children.add(const SizedBox(height: 14));
      children.add(_PrivacyNote(overview: overview));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    children.add(_Summary(overview: overview, hours: state.hours));
    children.add(const SizedBox(height: 14));
    children.add(
      _Filters(
        overview: overview,
        category: _category,
        background: state.background,
        onCategory: (c) => setState(() => _category = c),
        onSearch: (s) => setState(() => _search = s),
        onBackground: (v) => ref.read(sitesProvider.notifier).setBackground(v),
      ),
    );
    children.add(const SizedBox(height: 12));

    final query = _search.trim().toLowerCase();
    final shown =
        overview.sites.where((s) {
          if (_category != 'all' && s.category != _category) return false;
          if (query.isEmpty) return true;
          return s.name.toLowerCase().contains(query) ||
              s.domains.any((d) => d.contains(query));
        }).toList();

    if (shown.isEmpty) {
      children.add(
        EmptyNotice(
          icon: Icons.travel_explore,
          title:
              query.isNotEmpty || _category != 'all'
                  ? 'No site matches'
                  : 'No sites in this period',
          detail:
              query.isNotEmpty || _category != 'all'
                  ? 'Clear the filter or choose a longer period.'
                  : 'Nobody asked for a site in the ${sitesPeriods[state.hours]?.toLowerCase()}.',
        ),
      );
    } else {
      final compact = width < 900;
      children.add(
        DashCard(
          title: '${shown.length} site${shown.length == 1 ? '' : 's'}',
          icon: Icons.language,
          subtitle:
              'Most devices first. Open a site to see which devices asked for it, to name it and to give it a logo.',
          child: Column(
            children: [
              if (!compact) const _ListHeader(),
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0 || !compact) const Divider(height: 1),
                SiteRow(
                  site: shown[i],
                  compact: compact,
                  onTap: () => _openSite(shown[i], state.hours),
                ),
              ],
            ],
          ),
        ),
      );
    }
    children.add(const SizedBox(height: 14));
    children.add(_PrivacyNote(overview: overview));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _PeriodMenu extends StatelessWidget {
  const _PeriodMenu({required this.hours, required this.onChanged});

  final int hours;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Period',
      initialValue: hours,
      onSelected: onChanged,
      itemBuilder:
          (_) => [
            for (final e in sitesPeriods.entries)
              PopupMenuItem(value: e.key, child: Text(e.value)),
          ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule, size: 18),
            if (MediaQuery.sizeOf(context).width >= 700) ...[
              const SizedBox(width: 6),
              Text(sitesPeriods[hours] ?? '$hours h'),
            ],
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          const SizedBox(width: 58),
          Expanded(flex: 5, child: Text('Site', style: style)),
          Expanded(flex: 3, child: Text('Category', style: style)),
          Expanded(flex: 2, child: Text('Devices', style: style)),
          Expanded(flex: 2, child: Text('Lookups', style: style)),
          Expanded(flex: 2, child: Text('Last seen', style: style)),
          SizedBox(width: 130, child: Text('Name', style: style)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.overview});

  final SitesOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = overview.sources.where((s) => s.enabled).toList();
    if (enabled.isEmpty) {
      return const Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          StatusPill(
            tone: StatusTone.warning,
            icon: Icons.power_off_outlined,
            label: 'No DNS source is set up',
          ),
        ],
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in enabled)
          StatusPill(
            tone:
                s.error.isNotEmpty
                    ? StatusTone.error
                    : s.lastEventAt == null
                    ? StatusTone.neutral
                    : StatusTone.ok,
            icon:
                s.error.isNotEmpty
                    ? Icons.error_outline
                    : s.lastEventAt == null
                    ? Icons.hourglass_empty
                    : Icons.check_circle_outline,
            label:
                s.error.isNotEmpty
                    ? '${s.title}: ${s.error}'
                    : s.lastEventAt == null
                    ? '${s.title}: waiting for lookups'
                    : '${s.title}: last lookup ${formatAge(DateTime.now().difference(s.lastEventAt!))} ago',
          ),
        if (overview.lastRecordedAt != null && overview.firstRecordedAt != null)
          Text(
            'Recording since ${_day(overview.firstRecordedAt!)}, kept ${overview.retentionDays} days',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Setup extends StatelessWidget {
  const _Setup({required this.overview});

  final SitesOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = overview.anySourceEnabled;
    Widget step(int n, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              '$n',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );

    return DashCard(
      title:
          waiting
              ? 'Waiting for the first lookups'
              : 'Websites need the hospital\'s own DNS',
      icon: waiting ? Icons.hourglass_empty : Icons.travel_explore,
      subtitle:
          waiting
              ? 'A source is set up but nothing has arrived yet. Devices only show here once they use the hospital DNS.'
              : 'The router cannot see site names (traffic is encrypted). The DNS server that devices ask for addresses can.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          step(
            1,
            'Make the hospital DNS the one devices use',
            'Pi-hole or the router as DNS, handed out by DHCP, with DNS-over-HTTPS and DNS-over-TLS blocked so devices cannot go around it.',
          ),
          step(
            2,
            'Tell the NMS where the lookups come from',
            'Pi-hole: set PIHOLE_URL and PIHOLE_PASSWORD (or PIHOLE_API_TOKEN) in backend/.env. Any other resolver or the router: send its query log to this server with syslog and set DNS_SYSLOG_LISTEN=:5514.',
          ),
          step(
            3,
            'Restart the NMS server and wait a minute',
            'Sites appear here by name. Add the insurance companies (and anything else) with "Add a site" to give them a name and logo.',
          ),
          Text(
            'The exact settings are in docs/OPERATIONS.md, under "Websites by name".',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.overview, required this.hours});

  final SitesOverview overview;
  final int hours;

  @override
  Widget build(BuildContext context) {
    final named = overview.sites.where((s) => s.named).length;
    final insurance = overview.byCategory['insurance'] ?? 0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Stat(
          icon: Icons.language,
          label: 'Sites',
          value: '${overview.sites.length}',
          note:
              overview.unnamed > 0
                  ? '${overview.unnamed} not named yet'
                  : 'all named',
        ),
        _Stat(
          icon: Icons.devices_other,
          label: 'Devices',
          value: '${overview.devices}',
          note: sitesPeriods[hours]?.toLowerCase() ?? '',
        ),
        _Stat(
          icon: Icons.manage_search,
          label: 'Lookups',
          value: countText(overview.queries),
          note:
              overview.hiddenBackground > 0
                  ? '${countText(overview.hiddenBackground)} background left out'
                  : '',
        ),
        _Stat(
          icon: Icons.health_and_safety_outlined,
          label: 'Insurance sites',
          value: '$insurance',
          note: '$named named by the hospital',
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.value,
    this.note = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label $value. $note',
      child: ExcludeSemantics(
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      value,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (note.isNotEmpty)
                      Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.overview,
    required this.category,
    required this.background,
    required this.onCategory,
    required this.onSearch,
    required this.onBackground,
  });

  final SitesOverview overview;
  final String category;
  final bool background;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onSearch;
  final ValueChanged<bool> onBackground;

  @override
  Widget build(BuildContext context) {
    // Insurance first (it is what the hospital watches), then by how many sites.
    final cats =
        overview.byCategory.entries.toList()..sort((a, b) {
          if (a.key == 'insurance') return -1;
          if (b.key == 'insurance') return 1;
          return b.value.compareTo(a.value);
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text('All (${overview.sites.length})'),
              selected: category == 'all',
              onSelected: (_) => onCategory('all'),
            ),
            for (final e in cats)
              ChoiceChip(
                avatar: Icon(categoryIcon(e.key), size: 16),
                label: Text('${categoryLabel(e.key)} (${e.value})'),
                selected: category == e.key,
                onSelected:
                    (_) => onCategory(category == e.key ? 'all' : e.key),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 340,
              child: TextField(
                onChanged: onSearch,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name or domain',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: background, onChanged: onBackground),
                const SizedBox(width: 6),
                const Flexible(child: Text('Show background services')),
                Tooltip(
                  message:
                      'Updates, push notifications, content delivery, ads and tracking. One page view or an idle phone makes dozens of them, so they are hidden unless you ask.',
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.overview});

  final SitesOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
    return DashCard(
      title: 'What is recorded',
      icon: Icons.privacy_tip_outlined,
      child: Column(
        children: [
          line(
            Icons.dns_outlined,
            'Only the site\'s domain and how many times each device asked for it, per hour. Never page addresses, content or what was typed.',
          ),
          line(
            Icons.schedule,
            'Kept ${overview.retentionDays} days, then deleted.',
          ),
          line(
            Icons.history,
            'Opening a device\'s list of sites is written to the audit log.',
          ),
          line(
            Icons.image_outlined,
            'Logos are downloaded by the NMS server from the site itself, only for sites you add, and never through an outside icon service.',
          ),
          line(
            Icons.gavel_outlined,
            'Monitoring people\'s activity is covered by the Personal Data Protection Law (151/2020). Keep the hospital\'s notice to staff and visitors up to date.',
          ),
        ],
      ),
    );
  }
}

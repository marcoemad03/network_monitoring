import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/marco_site_models.dart';
import '../../../providers/marco/marco_details_provider.dart';
import '../../../providers/marco/marco_provider.dart';
import '../../dashboard/widgets/dash_card.dart';

IconData packIcon(String name) => switch (name) {
  'sports_esports' => Icons.sports_esports,
  'groups' => Icons.groups,
  'smart_display' => Icons.smart_display,
  'music_note' => Icons.music_note,
  'chat' => Icons.chat_bubble_outline,
  'smart_toy' => Icons.smart_toy,
  'cloud_download' => Icons.cloud_download,
  'vpn_lock' => Icons.vpn_lock,
  _ => Icons.public,
};

/// Choose what a group cannot open: ready-made packs, single services, and sites
/// typed by hand. Nothing changes until Save is pressed.
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key, required this.details, required this.onSave});
  final MarcoGroupDetails details;

  /// Saves the whole policy and returns once the server has answered.
  final Future<void> Function(Map<String, dynamic> policy) onSave;

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  final Set<String> _packs = {};
  final Set<String> _platforms = {};
  final Set<String> _domains = {};
  final TextEditingController _site = TextEditingController();
  final TextEditingController _allow = TextEditingController();
  MarcoSiteCheck? _check;
  bool _checking = false;
  bool _saving = false;
  String? _siteError;
  String _loadedFrom = '';

  Map<String, dynamic> get _policy => widget.details.group.policy;

  static List<String> _strings(Object? v) => ((v as List?) ?? const []).map((e) => '$e').toList();

  void _load() {
    final p = _policy;
    final key = '${p['blocked_packs']}|${p['blocked_websites']}|${p['blocked_domains']}';
    if (key == _loadedFrom) return;
    _loadedFrom = key;
    _packs
      ..clear()
      ..addAll(_strings(p['blocked_packs']));
    _platforms
      ..clear()
      ..addAll(_strings(p['blocked_websites']));
    _domains
      ..clear()
      ..addAll(_strings(p['blocked_domains']));
  }

  bool get _dirty {
    bool same(Set<String> a, List<String> b) => a.length == b.length && a.containsAll(b);
    return !(same(_packs, _strings(_policy['blocked_packs'])) && same(_platforms, _strings(_policy['blocked_websites'])) && same(_domains, _strings(_policy['blocked_domains'])));
  }

  @override
  void dispose() {
    _site.dispose();
    _allow.dispose();
    super.dispose();
  }

  Future<void> _checkSite() async {
    final text = _site.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _checking = true;
      _siteError = null;
      _check = null;
    });
    try {
      final r = await ref.read(marcoRemoteProvider).checkSite(text);
      if (mounted) setState(() => _check = r);
    } catch (e) {
      if (mounted) setState(() => _siteError = '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _addChecked() {
    final c = _check;
    if (c == null || c.target.isEmpty) return;
    setState(() {
      _domains.add(c.target);
      _site.clear();
      _check = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final policy = Map<String, dynamic>.from(_policy);
    void put(String key, Set<String> v) {
      if (v.isEmpty) {
        policy.remove(key);
      } else {
        policy[key] = (v.toList()..sort());
      }
    }

    put('blocked_packs', _packs);
    put('blocked_websites', _platforms);
    put('blocked_domains', _domains);
    try {
      await widget.onSave(policy);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _allowChange(Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(marcoCatalogProvider);
      _allow.clear();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final theme = Theme.of(context);
    final catalog = ref.watch(marcoCatalogProvider);
    final lines = {for (final l in widget.details.sites) '${l.kind}:${l.target}': l};

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _Explainer(),
            const SizedBox(height: 16),
            catalog.when(
              loading: () => const SkeletonBox(height: 220),
              error: (e, _) => EmptyNotice(icon: Icons.cloud_off, title: 'The list of sites could not be loaded', detail: '$e'),
              data: (cat) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(theme, 'Ready-made packs', 'Block a whole kind of site in one tick.'),
                  LayoutBuilder(
                    builder: (context, box) {
                      final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
                      const gap = 12.0;
                      final w = (box.maxWidth - gap * (cols - 1)) / cols;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [for (final p in cat.packs) SizedBox(width: w, child: _PackCard(pack: p, selected: _packs.contains(p.key), onChanged: (v) => setState(() => v ? _packs.add(p.key) : _packs.remove(p.key))))],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  _section(theme, 'Single services', 'Pick the ones to block even if you do not block the whole pack.'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in cat.platforms)
                        FilterChip(
                          label: Text(p.label),
                          selected: _platforms.contains(p.key),
                          onSelected: (v) => setState(() => v ? _platforms.add(p.key) : _platforms.remove(p.key)),
                        ),
                    ],
                  ),
                  if (_platforms.contains('youtube'))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'YouTube shares addresses with Gmail, Firebase and Translate, so the block stops the videos from playing while those keep working. The YouTube app may still open.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 24),
                  _section(theme, 'Your own sites', 'Type a website, a link, an IP address or a small network. We look it up first and tell you if it can be blocked.'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _site,
                          onSubmitted: (_) => _checkSite(),
                          onChanged: (_) => setState(() {
                            _check = null;
                            _siteError = null;
                          }),
                          decoration: InputDecoration(
                            labelText: 'Website to block',
                            hintText: 'example.com',
                            border: const OutlineInputBorder(),
                            errorText: _siteError,
                            prefixIcon: const Icon(Icons.public, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: FilledButton.tonalIcon(
                          onPressed: _checking ? null : _checkSite,
                          icon: _checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 18),
                          label: const Text('Check'),
                        ),
                      ),
                    ],
                  ),
                  if (_check != null) _CheckResult(check: _check!, alreadyAdded: _domains.contains(_check!.target), onAdd: _addChecked),
                  const SizedBox(height: 12),
                  if (_domains.isEmpty)
                    Text('No sites added by hand.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                  else
                    for (final d in (_domains.toList()..sort())) _DomainRow(domain: d, line: lines['domain:$d'] ?? lines['ip:$d'] ?? lines['cidr:$d'], onRemove: () => setState(() => _domains.remove(d))),
                  const SizedBox(height: 24),
                  _AllowedSection(
                    catalog: cat,
                    controller: _allow,
                    onAdd: () => _allowChange(() => ref.read(marcoRemoteProvider).addAllowedSite(_allow.text.trim())),
                    onRemove: (d) => _allowChange(() => ref.read(marcoRemoteProvider).removeAllowedSite(d)),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_dirty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              color: theme.colorScheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(child: Text('You changed the blocked sites. Save to apply them.', style: TextStyle(color: theme.colorScheme.onInverseSurface))),
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _loadedFrom = '';
                                _load();
                              }),
                      child: const Text('Undo'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 2),
        Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    ),
  );
}

class _Explainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The router sees addresses, not website names. Blocking works on the address a site points to, for websites and for phone apps alike. Sites hosted on shared services (Google, Cloudflare) cannot be blocked this way without breaking other sites, and we tell you when that is the case.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.selected, required this.onChanged});
  final MarcoPack pack;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: selected ? theme.colorScheme.errorContainer.withValues(alpha: 0.45) : theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? theme.colorScheme.error.withValues(alpha: 0.6) : theme.colorScheme.outlineVariant.withValues(alpha: 0.6), width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(packIcon(pack.icon), color: selected ? theme.colorScheme.error : theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pack.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(pack.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Tooltip(
                      message: [...pack.platforms, ...pack.domains].take(40).join(', '),
                      child: Text('${pack.siteCount} sites', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              Switch(value: selected, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckResult extends StatelessWidget {
  const _CheckResult({required this.check, required this.alreadyAdded, required this.onAdd});
  final MarcoSiteCheck check;
  final bool alreadyAdded;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final partial = check.blockable && check.shared.isNotEmpty;
    final tone = !check.blockable ? StatusTone.error : (partial || check.many ? StatusTone.warning : StatusTone.ok);
    final style = toneStyle(context, tone);
    final literal = check.kind == 'ip' || check.kind == 'cidr';
    final text = !check.blockable
        ? '${check.target}: ${check.error.isEmpty ? 'cannot be blocked' : check.error}.'
        : literal
        ? '${check.target} can be blocked.'
        : partial
        ? '${check.target} points to ${check.ips.length + check.shared.length} addresses. ${check.shared.length} are on ${check.sharedProvider.isEmpty ? 'a shared service' : check.sharedProvider} and will be left out, so the site may still partly open.'
        : check.many
        ? '${check.target} uses ${check.ips.length} addresses, which looks like a content network. Blocking them may affect other sites.'
        : '${check.target} points to ${check.ips.length} address${check.ips.length == 1 ? '' : 'es'} and can be blocked.';
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 20, color: style.foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: style.foreground))),
          if (check.blockable) ...[
            const SizedBox(width: 10),
            FilledButton(onPressed: alreadyAdded ? null : onAdd, child: Text(alreadyAdded ? 'Added' : 'Add to blocked sites')),
          ],
        ],
      ),
    );
  }
}

class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.domain, required this.line, required this.onRemove});
  final String domain;
  final MarcoSiteLine? line;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = line?.status ?? 'pending';
    final tone = switch (status) {
      'blocked' => StatusTone.ok,
      'partial' => StatusTone.warning,
      'cannot' => StatusTone.error,
      _ => StatusTone.neutral,
    };
    final label = switch (status) {
      'blocked' => 'Blocked',
      'partial' => 'Partly blocked',
      'cannot' => 'Cannot block',
      _ => 'Saved, not applied yet',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.public, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(domain, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if ((line?.detail ?? '').isNotEmpty) Text(line!.detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          StatusPill(tone: tone, label: label),
          IconButton(tooltip: 'Remove $domain', icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
        ],
      ),
    );
  }
}

class _AllowedSection extends StatelessWidget {
  const _AllowedSection({required this.catalog, required this.controller, required this.onAdd, required this.onRemove});
  final MarcoCatalog catalog;
  final TextEditingController controller;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.verified_user_outlined),
        title: Text('Always allowed websites', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text('${catalog.allowedDefaults.length + catalog.allowedCustom.length} sites that keep working for every group'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When a block catches an address that one of these sites also uses, the site is let through first. This is why Gmail, Firebase and Translate keep working while YouTube is blocked.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          Text('Built in', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final d in catalog.allowedDefaults) Chip(label: Text(d, style: theme.textTheme.labelSmall), visualDensity: VisualDensity.compact)]),
          const SizedBox(height: 12),
          Text('Added by you', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          if (catalog.allowedCustom.isEmpty)
            Text('None yet.', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final d in catalog.allowedCustom) InputChip(label: Text(d), onDeleted: () => onRemove(d))],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(isDense: true, hintText: 'A website that must always work, for example portal.hospital.com', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: onAdd, child: const Text('Allow')),
            ],
          ),
        ],
      ),
    );
  }
}

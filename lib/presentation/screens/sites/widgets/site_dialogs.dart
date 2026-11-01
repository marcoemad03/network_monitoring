import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/datasources/remote/sites_remote_datasource.dart';
import '../../../../data/models/sites_models.dart';
import '../../../providers/sites/sites_provider.dart';
import 'site_widgets.dart';

/// Categories offered when naming a site, insurance first: it is what the
/// hospital adds most.
const _pickable = [
  'insurance',
  'health',
  'government',
  'banking',
  'work',
  'email',
  'cloud',
  'search',
  'social',
  'video',
  'messaging',
  'shopping',
  'news',
  'ai',
  'games',
  'background',
  'other',
];

/// Name a site, or change one. Pops with `true` when something was saved.
class SiteEditorDialog extends ConsumerStatefulWidget {
  const SiteEditorDialog({
    super.key,
    this.existing,
    this.domain = '',
    this.name = '',
    this.category = 'insurance',
  });

  final CatalogEntry? existing;

  /// A site seen in the recording that is being named.
  final String domain;
  final String name;
  final String category;

  @override
  ConsumerState<SiteEditorDialog> createState() => _SiteEditorDialogState();
}

class _SiteEditorDialogState extends ConsumerState<SiteEditorDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? widget.name,
  );
  late final TextEditingController _domains = TextEditingController(
    text: widget.existing?.domains.join('\n') ?? widget.domain,
  );
  late String _category = widget.existing?.category ?? widget.category;
  bool _fetchLogo = true;
  bool _saving = false;
  String? _error;
  String? _logoNote;

  @override
  void dispose() {
    _name.dispose();
    _domains.dispose();
    super.dispose();
  }

  List<String> get _domainList =>
      _domains.text
          .split(RegExp(r'[\s,;]+'))
          .where((d) => d.trim().isNotEmpty)
          .toList();

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Write the name people know the site by.');
      return;
    }
    if (_domainList.isEmpty) {
      setState(
        () => _error = 'Add at least one domain, for example insurer.com.eg.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final controller = ref.read(sitesProvider.notifier);
    try {
      final result =
          widget.existing == null
              ? await controller.create(
                name: _name.text.trim(),
                category: _category,
                domains: _domainList,
                fetchLogo: _fetchLogo,
              )
              : await controller.update(
                widget.existing!.id,
                name: _name.text.trim(),
                category: _category,
                domains: _domainList,
                fetchLogo: _fetchLogo,
              );
      if (!mounted) return;
      if (result.logoError.isNotEmpty) {
        // Saved, but the site gave no usable icon: say so, and let the person carry on.
        setState(() {
          _saving = false;
          _logoNote =
              'Saved. The logo could not be downloaded: ${result.logoError}. Open the site and use "Logo from an image address" to add one.';
        });
        return;
      }
      Navigator.of(context).pop(true);
    } on SitesRequestFailed catch (e) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = e.message;
        });
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Check the server connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit site' : 'Name a site'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_saving,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText:
                      'As staff know it, for example the insurance company\'s name',
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue:
                    _pickable.contains(_category) ? _category : 'other',
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in _pickable)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(categoryIcon(c), size: 18),
                          const SizedBox(width: 10),
                          Text(categoryLabel(c)),
                        ],
                      ),
                    ),
                ],
                onChanged:
                    _saving
                        ? null
                        : (v) => setState(() => _category = v ?? 'other'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _domains,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Domains',
                  helperText:
                      'One per line. A pasted link works too; page addresses are cut down to the domain.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _fetchLogo,
                onChanged:
                    _saving
                        ? null
                        : (v) => setState(() => _fetchLogo = v ?? false),
                title: const Text('Get the logo from the site'),
                subtitle: const Text(
                  'The NMS server downloads the site\'s own icon. Nothing is sent about who visited it.',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.error),
                    semanticsLabel: 'Error: $_error',
                  ),
                ),
              if (_logoNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_logoNote!, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _saving
                  ? null
                  : () => Navigator.of(context).pop(_logoNote != null),
          child: Text(_logoNote != null ? 'Close' : 'Cancel'),
        ),
        if (_logoNote == null)
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon:
                _saving
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Save'),
          ),
      ],
    );
  }
}

/// Who asked for a site, and what can be done with it.
class SiteDetailDialog extends ConsumerWidget {
  const SiteDetailDialog({
    super.key,
    required this.site,
    required this.hours,
    required this.onOpenDevice,
  });

  final SiteUse site;
  final int hours;
  final void Function(SiteDevice device) onOpenDevice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      siteDetailProvider((domain: site.key, hours: hours)),
    );
    final overview = ref.watch(sitesProvider).overview;
    // The row may be stale after naming or changing it; the latest copy wins.
    final live =
        overview?.sites
            .where((s) => s.key == site.key || s.domains.contains(site.key))
            .firstOrNull ??
        site;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final entry =
        overview?.catalog.where((c) => c.id == live.catalogId).firstOrNull;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SiteLogo(site: live, size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                live.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(
                                    categoryIcon(live.category),
                                    size: 16,
                                    color: muted,
                                  ),
                                  Text(
                                    categoryLabel(live.category),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  naming(live),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      live.domains.join('   ·   '),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${live.devices} device${live.devices == 1 ? '' : 's'} asked for this site, ${live.queries} lookups'
                      '${live.blocked > 0 ? ' (${live.blocked} blocked by the DNS filter)' : ''} in the ${sitesPeriods[hours]?.toLowerCase() ?? 'chosen period'}. A lookup is a device asking for the site\'s address; it shows the site was opened, not for how long.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 18),
                    _heading(theme, 'Devices'),
                    detail.when(
                      loading:
                          () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      error:
                          (_, __) => Text(
                            'Could not load the devices.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                      data:
                          (d) =>
                              d.devices.isEmpty
                                  ? Text(
                                    'No device asked for this site in this period.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: muted,
                                    ),
                                  )
                                  : Column(
                                    children: [
                                      for (final dev in d.devices.take(40))
                                        _DeviceLine(
                                          device: dev,
                                          onTap: () => onOpenDevice(dev),
                                        ),
                                    ],
                                  ),
                    ),
                    const SizedBox(height: 18),
                    _heading(
                      theme,
                      live.named ? 'Name and logo' : 'Give it a name and logo',
                    ),
                    _Management(site: live, entry: entry),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.device, required this.onTap});

  final SiteDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label:
          '${device.name}, ${device.kind}, ${device.queries} lookups. Opens the device.',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        device.ip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                          fontFamilyFallback: const ['Consolas', 'monospace'],
                        ),
                      ),
                    ],
                  ),
                ),
                DeviceKindChip(kind: device.kind),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${device.queries} lookups',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    device.lastSeen == null
                        ? ''
                        : formatAge(
                          DateTime.now().difference(device.lastSeen!),
                        ),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Name, logo and removal for the site being looked at.
class _Management extends ConsumerStatefulWidget {
  const _Management({required this.site, required this.entry});

  final SiteUse site;
  final CatalogEntry? entry;

  @override
  ConsumerState<_Management> createState() => _ManagementState();
}

class _ManagementState extends ConsumerState<_Management> {
  bool _busy = false;
  String? _message;
  bool _isError = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final note = await action();
      if (mounted) {
        setState(() {
          _isError = false;
          _message = note;
        });
      }
    } on SitesRequestFailed catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = 'The request failed. Check the server connection.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logoFromAddress() async {
    final controller = TextEditingController();
    final address = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Logo from an image address'),
            content: SizedBox(
              width: 460,
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Image address',
                  hintText: 'https://…/logo.png',
                  helperText:
                      'PNG, JPEG, GIF, WebP or ICO, up to 256 KB. The server downloads it.',
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Download'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (address == null || address.trim().isEmpty || !mounted) return;
    await _run(() async {
      await ref
          .read(sitesProvider.notifier)
          .fetchLogo(widget.entry!.id, imageUrl: address.trim());
      return 'Logo saved.';
    });
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove from the catalog?'),
            content: Text(
              '"${widget.site.name}" goes back to showing by its domain. The recorded lookups are kept.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref.read(sitesProvider.notifier).remove(widget.entry!.id);
      return 'Removed from the catalog.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final site = widget.site;
    final entry = widget.entry;
    final buttons = <Widget>[];

    if (entry != null) {
      buttons.addAll([
        OutlinedButton.icon(
          onPressed:
              _busy
                  ? null
                  : () => showDialog<bool>(
                    context: context,
                    builder: (_) => SiteEditorDialog(existing: entry),
                  ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit name, category, domains'),
        ),
        OutlinedButton.icon(
          onPressed:
              _busy
                  ? null
                  : () => _run(() async {
                    await ref.read(sitesProvider.notifier).fetchLogo(entry.id);
                    return 'Logo saved from the site.';
                  }),
          icon: const Icon(Icons.image_search_outlined),
          label: Text(
            entry.hasLogo ? 'Get the logo again' : 'Get the logo from the site',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy ? null : _logoFromAddress,
          icon: const Icon(Icons.link),
          label: const Text('Logo from an image address'),
        ),
        if (entry.hasLogo)
          OutlinedButton.icon(
            onPressed:
                _busy
                    ? null
                    : () => _run(() async {
                      await ref
                          .read(sitesProvider.notifier)
                          .removeLogo(entry.id);
                      return 'Logo removed.';
                    }),
            icon: const Icon(Icons.hide_image_outlined),
            label: const Text('Remove the logo'),
          ),
        TextButton.icon(
          onPressed: _busy ? null : _confirmRemove,
          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
          label: Text(
            'Remove from catalog',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
      ]);
    } else if (site.builtIn) {
      buttons.add(
        FilledButton.icon(
          onPressed:
              _busy
                  ? null
                  : () => _run(() async {
                    final r = await ref
                        .read(sitesProvider.notifier)
                        .adopt(site.key);
                    return r.logoError.isEmpty
                        ? 'Added to the catalog with its logo.'
                        : 'Added to the catalog. The logo could not be downloaded: ${r.logoError}';
                  }),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add to the catalog with its logo'),
        ),
      );
    } else {
      buttons.add(
        FilledButton.icon(
          onPressed:
              _busy
                  ? null
                  : () => showDialog<bool>(
                    context: context,
                    builder:
                        (_) => SiteEditorDialog(
                          domain:
                              site.domains.isEmpty
                                  ? site.key
                                  : site.domains.first,
                        ),
                  ),
          icon: const Icon(Icons.label_outline),
          label: const Text('Name this site'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 10, runSpacing: 10, children: buttons),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: LinearProgressIndicator(),
          ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _isError ? theme.colorScheme.error : null,
              ),
              semanticsLabel: _isError ? 'Error: $_message' : _message,
            ),
          ),
      ],
    );
  }
}

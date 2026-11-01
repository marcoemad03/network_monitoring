import 'package:flutter/material.dart';

/// Visual weight of a status message. Each tone also carries an icon, so the
/// meaning never depends on color alone.
enum StatusTone { ok, warning, error, neutral }

({Color background, Color foreground, IconData icon}) toneStyle(BuildContext context, StatusTone tone) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (tone) {
    case StatusTone.ok:
      final fg = dark ? Colors.green.shade200 : Colors.green.shade900;
      return (background: fg.withValues(alpha: 0.14), foreground: fg, icon: Icons.check_circle_outline);
    case StatusTone.warning:
      final fg = dark ? Colors.amber.shade200 : Colors.orange.shade900;
      return (background: fg.withValues(alpha: 0.16), foreground: fg, icon: Icons.warning_amber_rounded);
    case StatusTone.error:
      final fg = dark ? scheme.errorContainer : scheme.error;
      return (background: scheme.error.withValues(alpha: 0.14), foreground: fg, icon: Icons.error_outline);
    case StatusTone.neutral:
      return (background: scheme.surfaceContainerHighest, foreground: scheme.onSurfaceVariant, icon: Icons.sync);
  }
}

/// A compact pill with an icon and a short text.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.tone, required this.label, this.tooltip, this.icon});

  final StatusTone tone;
  final String label;
  final String? tooltip;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = toneStyle(context, tone);
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? style.icon, size: 16, color: style.foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: style.foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(child: tooltip == null ? pill : Tooltip(message: tooltip!, child: pill)),
    );
  }
}

/// The shared shell of every dashboard section.
class DashCard extends StatelessWidget {
  const DashCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/// A grey block shown while the first data is loading.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.height = 16, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Explains why a section has no data and, when it helps, how to fix it.
class EmptyNotice extends StatelessWidget {
  const EmptyNotice({super.key, required this.icon, required this.title, this.detail});

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

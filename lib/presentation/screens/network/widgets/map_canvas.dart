import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../data/models/network_map_models.dart';
import 'map_kinds.dart';

const _cardW = 176.0;
const _cardH = 66.0;
const _gap = 10.0;
const _groupPad = 12.0;
const _groupHeader = 38.0;
const _routerW = 180.0;
const _routerH = 92.0;
const _portW = 170.0;
const _portH = 68.0;
const _colGap = 70.0;
const _groupGap = 24.0;
const _margin = 40.0;

/// Where everything sits on the canvas. Computed from the data alone so it is easy
/// to test and so the page can fit it to the screen.
class MapLayout {
  final Size size;
  final Rect router;
  final List<GroupLayout> groups;
  const MapLayout(this.size, this.router, this.groups);

  factory MapLayout.compute(NetworkMapData data, List<MapDevice> devices) {
    final byPort = <String, List<MapDevice>>{};
    for (final d in devices) {
      byPort.putIfAbsent(d.port, () => []).add(d);
    }
    // Known ports in the router's order, then ports only seen on devices, then "no port".
    final order = <String>[
      for (final p in data.ports)
        if (byPort.containsKey(p.name)) p.name,
      for (final k in byPort.keys)
        if (k.isNotEmpty && data.port(k) == null) k,
      if (byPort.containsKey('')) '',
    ];

    final portX = _margin + _routerW + _colGap;
    final groupX = portX + _portW + _colGap;
    var y = _margin;
    var maxRight = groupX;
    final groups = <GroupLayout>[];
    for (final key in order) {
      final list = byPort[key]!;
      final cols = list.length <= 2 ? list.length : (list.length <= 9 ? 3 : (list.length <= 30 ? 4 : 5));
      final rows = (list.length / cols).ceil();
      final w = _groupPad * 2 + cols * _cardW + (cols - 1) * _gap;
      final h = _groupHeader + _groupPad + rows * _cardH + (rows - 1) * _gap + _groupPad;
      final rect = Rect.fromLTWH(groupX, y, w, h);
      final portRect = Rect.fromLTWH(portX, y + math.min(h / 2, 120) - _portH / 2, _portW, _portH);
      groups.add(GroupLayout(port: key, devices: list, rect: rect, portRect: portRect, cols: cols));
      maxRight = math.max(maxRight, rect.right);
      y += h + _groupGap;
    }
    final height = math.max(y - _groupGap + _margin, _routerH + _margin * 2);
    final routerCenter = groups.isEmpty ? height / 2 : math.min(height / 2, groups.first.portRect.center.dy + 160);
    final router = Rect.fromLTWH(_margin, routerCenter - _routerH / 2, _routerW, _routerH);
    return MapLayout(Size(maxRight + _margin, height), router, groups);
  }
}

class GroupLayout {
  final String port;
  final List<MapDevice> devices;
  final Rect rect;
  final Rect portRect;
  final int cols;
  const GroupLayout({required this.port, required this.devices, required this.rect, required this.portRect, required this.cols});

  Rect cardRect(int i) {
    final col = i % cols;
    final row = i ~/ cols;
    return Rect.fromLTWH(
      rect.left + _groupPad + col * (_cardW + _gap),
      rect.top + _groupHeader + _groupPad + row * (_cardH + _gap),
      _cardW,
      _cardH,
    );
  }
}

/// The map: the router on the left, its ports in the middle and the devices behind
/// each port on the right. Pan and zoom with the mouse; [MapCanvasState.fit] shows
/// everything.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.data,
    required this.devices,
    required this.selectedId,
    required this.onSelect,
    required this.onPortTap,
  });

  final NetworkMapData data;
  final List<MapDevice> devices;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onPortTap;

  @override
  State<MapCanvas> createState() => MapCanvasState();
}

class MapCanvasState extends State<MapCanvas> {
  final TransformationController _controller = TransformationController();
  Size _viewport = Size.zero;
  bool _fitted = false;
  MapLayout? _layout;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void zoomBy(double factor) {
    final m = _controller.value.clone();
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final scale = m.getMaxScaleOnAxis();
    final target = (scale * factor).clamp(0.15, 2.5);
    final f = target / scale;
    final next = Matrix4.translationValues(center.dx, center.dy, 0) *
        Matrix4.diagonal3Values(f, f, 1) *
        Matrix4.translationValues(-center.dx, -center.dy, 0);
    _controller.value = next * m;
  }

  /// Shows the whole map, never larger than real size.
  void fit() {
    final layout = _layout;
    if (layout == null || _viewport.isEmpty) return;
    final scale = math.min(1.0, math.min(_viewport.width / layout.size.width, _viewport.height / layout.size.height)).clamp(0.15, 1.0);
    final dx = math.max(0.0, (_viewport.width - layout.size.width * scale) / 2);
    _controller.value = Matrix4.translationValues(dx, 0, 0) * Matrix4.diagonal3Values(scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final layout = MapLayout.compute(widget.data, widget.devices);
    _layout = layout;
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        _viewport = Size(box.maxWidth, box.maxHeight);
        if (!_fitted && widget.devices.isNotEmpty) {
          _fitted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) fit();
          });
        }
        return ClipRect(
          child: InteractiveViewer(
            transformationController: _controller,
            constrained: false,
            minScale: 0.15,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(400),
            child: SizedBox(
              width: layout.size.width,
              height: layout.size.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onSelect(null),
                      child: CustomPaint(painter: _LinksPainter(layout, widget.data, theme)),
                    ),
                  ),
                  _RouterNode(rect: layout.router, router: widget.data.router),
                  for (final g in layout.groups) ..._group(g, theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _group(GroupLayout g, ThemeData theme) {
    final port = g.port.isEmpty ? null : widget.data.port(g.port);
    final online = g.devices.where((d) => d.online).length;
    return [
      Positioned.fromRect(
        rect: g.rect,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
          ),
        ),
      ),
      Positioned(
        left: g.rect.left + _groupPad,
        top: g.rect.top + 8,
        width: g.rect.width - _groupPad * 2,
        height: _groupHeader - 8,
        child: Row(
          children: [
            Expanded(
              child: Text(
                g.port.isEmpty ? 'Port not known' : (port?.title ?? g.port),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text('$online / ${g.devices.length} online', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
      Positioned.fromRect(
        rect: g.portRect,
        child: _PortNode(
          name: g.port,
          port: port,
          onTap: g.port.isEmpty ? null : () => widget.onPortTap(g.port),
        ),
      ),
      for (var i = 0; i < g.devices.length; i++)
        Positioned.fromRect(
          rect: g.cardRect(i),
          child: DeviceCard(
            device: g.devices[i],
            selected: widget.selectedId == g.devices[i].id,
            onTap: () => widget.onSelect(g.devices[i].id),
          ),
        ),
    ];
  }
}

class _LinksPainter extends CustomPainter {
  _LinksPainter(this.layout, this.data, this.theme);

  final MapLayout layout;
  final NetworkMapData data;
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in layout.groups) {
      final port = g.port.isEmpty ? null : data.port(g.port);
      final up = port?.running ?? false;
      final color = g.port.isEmpty ? theme.colorScheme.outline : (up ? const Color(0xFF2E7D32) : theme.colorScheme.outline);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final from = Offset(layout.router.right, layout.router.center.dy);
      final to = Offset(g.portRect.left, g.portRect.center.dy);
      final midX = (from.dx + to.dx) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(midX, from.dy, midX, to.dy, to.dx, to.dy);
      if (g.port.isEmpty) {
        _dashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
      canvas.drawLine(Offset(g.portRect.right, g.portRect.center.dy), Offset(g.rect.left, g.portRect.center.dy), paint);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 8, metric.length)), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(_LinksPainter old) => old.layout != layout || old.data != data;
}

class _RouterNode extends StatelessWidget {
  const _RouterNode({required this.rect, required this.router});
  final Rect rect;
  final MapRouter router;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle('router');
    return Positioned.fromRect(
      rect: rect,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: style.color, width: 2),
        ),
        child: Row(
          children: [
            Icon(style.icon, color: style.color, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(router.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  if (router.ip.isNotEmpty) Text(router.ip, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                  Text(
                    router.online ? 'Router online' : 'Router not read',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: router.online ? const Color(0xFF2E7D32) : theme.colorScheme.error),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortNode extends StatelessWidget {
  const _PortNode({required this.name, required this.port, required this.onTap});
  final String name;
  final MapPort? port;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final up = port?.running ?? false;
    final unknown = name.isEmpty;
    final color = unknown ? theme.colorScheme.outline : (up ? const Color(0xFF2E7D32) : theme.colorScheme.outline);
    final detail = unknown
        ? 'Router has not placed these'
        : [
            if (port != null && (port!.rxBps > 0 || port!.txBps > 0)) '↓ ${formatBps(port!.rxBps)}  ↑ ${formatBps(port!.txBps)}',
            if (port != null && port!.trunk) 'uplink to another switch',
          ].join(' · ');
    return Tooltip(
      message: unknown ? 'Devices whose router port could not be found' : 'Tap to name this port',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(unknown ? Icons.help_outline : Icons.settings_ethernet, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unknown ? 'No port' : name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (!unknown && port != null && port!.label.isNotEmpty) Text(port!.label, style: theme.textTheme.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (detail.isNotEmpty)
                      Text(detail, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
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

/// One device: icon for its type, name, address and where it is.
class DeviceCard extends StatelessWidget {
  const DeviceCard({super.key, required this.device, required this.selected, required this.onTap});
  final MapDevice device;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle(device.kind);
    final dot = statusColor(device);
    final where = whereLabel(device);
    return Semantics(
      button: true,
      label: '${device.name}, ${style.label}, ${device.ip}, ${statusLabel(device)}',
      child: Tooltip(
        message: '${device.name}\n${style.label} · ${device.ip.isEmpty ? device.mac : device.ip}${where.isEmpty ? '' : '\n$where'}',
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Opacity(
              opacity: device.online ? 1 : 0.6,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant, width: selected ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                      child: Icon(style.icon, size: 18, color: style.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(
                            device.ip.isEmpty ? device.mac : device.ip,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            device.hasPlace ? device.place : style.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: device.hasPlace ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../dashboard/widgets/dash_card.dart';

const _dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The group's internet, speed, schedule and data rules. Each device in the group
/// gets the speed and data limit; nothing changes until Save is pressed.
class RulesTab extends StatefulWidget {
  const RulesTab({super.key, required this.policy, required this.onSave, this.dryRun = false});
  final Map<String, dynamic> policy;
  final bool dryRun;
  final Future<void> Function(Map<String, dynamic> policy) onSave;

  @override
  State<RulesTab> createState() => _RulesTabState();
}

class _RulesTabState extends State<RulesTab> {
  late bool _internet;
  late bool _limit;
  late bool _schedule;
  late final TextEditingController _down = TextEditingController();
  late final TextEditingController _up = TextEditingController();
  late final TextEditingController _daily = TextEditingController();
  late final TextEditingController _monthly = TextEditingController();
  TimeOfDay? _start;
  TimeOfDay? _end;
  final Set<String> _days = {};
  int? _qos;
  bool _saving = false;
  String? _error;
  String _loadedFrom = '';
  String _loadedSig = '';

  static String _num(Object? v) => v == null ? '' : (v is num && v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  static TimeOfDay? _parse(Object? v) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('${v ?? ''}');
    if (m == null) return null;
    return TimeOfDay(hour: int.parse(m.group(1)!), minute: int.parse(m.group(2)!));
  }

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RulesTab old) {
    super.didUpdateWidget(old);
    if ('${widget.policy}' != _loadedFrom) _load();
  }

  void _load() {
    final p = widget.policy;
    _loadedFrom = '$p';
    _internet = p['internet_enabled'] as bool? ?? true;
    _limit = p['unlimited_speed'] == false && (p['download_limit_mbps'] != null || p['upload_limit_mbps'] != null);
    _down.text = _num(p['download_limit_mbps']);
    _up.text = _num(p['upload_limit_mbps']);
    _daily.text = _num(p['daily_quota_gb']);
    _monthly.text = _num(p['monthly_quota_gb']);
    _start = _parse(p['schedule_start_time']);
    _end = _parse(p['schedule_end_time']);
    _schedule = _start != null && _end != null;
    _days
      ..clear()
      ..addAll(((p['schedule_days'] as List?) ?? const []).map((e) => '$e'));
    final q = p['qos_priority'];
    _qos = q is num ? q.toInt() : null;
    _error = null;
    _loadedSig = _signature();
  }

  @override
  void dispose() {
    for (final c in [_down, _up, _daily, _monthly]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Map<String, dynamic>? _build() {
    if (_limit && _d(_down) == null && _d(_up) == null) {
      _error = 'Type a download or upload speed, or turn the speed limit off.';
      return null;
    }
    if (_schedule && (_start == null || _end == null)) {
      _error = 'Choose both times for the schedule.';
      return null;
    }
    for (final c in [_down, _up, _daily, _monthly]) {
      if (c.text.trim().isNotEmpty && (_d(c) == null || _d(c)! <= 0)) {
        _error = 'Limits must be numbers above 0.';
        return null;
      }
    }
    final policy = Map<String, dynamic>.from(widget.policy);
    void put(String key, Object? v) {
      if (v == null || (v is List && v.isEmpty) || (v is String && v.isEmpty)) {
        policy.remove(key);
      } else {
        policy[key] = v;
      }
    }

    policy['internet_enabled'] = _internet;
    policy['unlimited_speed'] = !_limit;
    put('download_limit_mbps', _limit ? _d(_down) : null);
    put('upload_limit_mbps', _limit ? _d(_up) : null);
    put('daily_quota_gb', _d(_daily));
    put('monthly_quota_gb', _d(_monthly));
    put('qos_priority', _qos);
    put('schedule_start_time', _schedule ? _fmt(_start!) : null);
    put('schedule_end_time', _schedule ? _fmt(_end!) : null);
    put('schedule_days', _schedule ? (_days.toList()..sort((a, b) => _dayKeys.indexOf(a).compareTo(_dayKeys.indexOf(b)))) : null);
    return policy;
  }

  /// Everything the draft holds, so a change is noticed even before it is valid.
  String _signature() => [_internet, _limit, _down.text.trim(), _up.text.trim(), _daily.text.trim(), _monthly.text.trim(), _schedule, _start, _end, (_days.toList()..sort()).join(','), _qos].join('|');

  bool get _dirty => _signature() != _loadedSig;

  Future<void> _save() async {
    final policy = _build();
    if (policy == null) {
      setState(() {});
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(policy);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pick(bool start) async {
    final t = await showTimePicker(context: context, initialTime: (start ? _start : _end) ?? const TimeOfDay(hour: 22, minute: 0));
    if (t != null) setState(() => start ? _start = t : _end = t);
  }

  void _preset(double mbps) => setState(() {
    _limit = true;
    _down.text = _num(mbps);
    _up.text = _num((mbps / 2).clamp(0.5, 1000));
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dirty = _dirty;
    Widget card({required IconData icon, required String title, String? subtitle, required Widget child}) => DashCard(title: title, icon: icon, subtitle: subtitle, child: child);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (widget.dryRun)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: toneStyle(context, StatusTone.warning).background, borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [Icon(Icons.shield_outlined, size: 18), SizedBox(width: 10), Expanded(child: Text('Safe mode: rules are saved but the router is not changed.'))]),
              ),
            card(
              icon: Icons.wifi,
              title: 'Internet',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_internet ? 'Internet is on' : 'Internet is off for this group'),
                subtitle: const Text('When it is off, devices stay on the network but cannot reach the internet.'),
                value: _internet,
                onChanged: (v) => setState(() => _internet = v),
              ),
            ),
            const SizedBox(height: 14),
            card(
              icon: Icons.speed,
              title: 'Speed limit',
              subtitle: 'Applies to each device in the group, not to the group as a whole.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Limit the speed of each device'), value: _limit, onChanged: (v) => setState(() => _limit = v)),
                  if (_limit) ...[
                    Wrap(spacing: 8, children: [for (final m in const [2.0, 5.0, 10.0, 20.0, 50.0]) ActionChip(label: Text('${m.toInt()} Mbps'), onPressed: () => _preset(m))]),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _field(_down, 'Download (Mbps)')),
                        const SizedBox(width: 10),
                        Expanded(child: _field(_up, 'Upload (Mbps)')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: _qos,
                      decoration: const InputDecoration(labelText: 'Priority when the line is busy', border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Normal')),
                        for (var i = 1; i <= 8; i++) DropdownMenuItem(value: i, child: Text(i == 1 ? '1 (highest)' : (i == 8 ? '8 (lowest)' : '$i'))),
                      ],
                      onChanged: (v) => setState(() => _qos = v),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            card(
              icon: Icons.schedule,
              title: 'Internet off at certain hours',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Turn the internet off between two times'), value: _schedule, onChanged: (v) => setState(() => _schedule = v)),
                  if (_schedule) ...[
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pick(true), icon: const Icon(Icons.bedtime_outlined, size: 18), label: Text(_start == null ? 'From' : 'From ${_fmt(_start!)}'))),
                        const SizedBox(width: 10),
                        Expanded(child: OutlinedButton.icon(onPressed: () => _pick(false), icon: const Icon(Icons.wb_sunny_outlined, size: 18), label: Text(_end == null ? 'Until' : 'Until ${_fmt(_end!)}'))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var i = 0; i < 7; i++)
                          FilterChip(label: Text(_dayNames[i]), selected: _days.contains(_dayKeys[i]), onSelected: (on) => setState(() => on ? _days.add(_dayKeys[i]) : _days.remove(_dayKeys[i]))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_days.isEmpty ? 'Every day.' : 'Only on the days chosen.', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            card(
              icon: Icons.data_usage,
              title: 'Data limit',
              subtitle: 'Per device. The internet is cut off for a device that reaches its limit, until the day or month ends.',
              child: Row(
                children: [
                  Expanded(child: _field(_daily, 'Per day (GB)')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_monthly, 'Per month (GB)')),
                ],
              ),
            ),
          ],
        ),
        if (dirty || _error != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              color: _error == null ? theme.colorScheme.inverseSurface : theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error ?? 'You changed the rules. Save to apply them.',
                        style: TextStyle(color: _error == null ? theme.colorScheme.onInverseSurface : theme.colorScheme.onErrorContainer),
                      ),
                    ),
                    TextButton(onPressed: _saving ? null : () => setState(_load), child: const Text('Undo')),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() => _error = null),
    decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/router_terminal_models.dart';
import '../../providers/marco/marco_provider.dart';

const _removeAll = '''/ip firewall raw remove [find where comment~"^nms-marco-"]
/ip firewall filter remove [find where comment~"^nms-marco-"]
/queue simple remove [find where comment~"^nms-marco-"]
/ip firewall address-list remove [find where comment~"^nms-marco-"]
/ip firewall layer7-protocol remove [find where name~"^nms-marco-"]
/system scheduler remove [find where name="nms-marco-deadman"]''';

/// Runs RouterOS commands from inside the app. A command that changes something
/// first shows what it matched and waits for a yes.
class RouterTerminalScreen extends ConsumerStatefulWidget {
  const RouterTerminalScreen({super.key});

  @override
  ConsumerState<RouterTerminalScreen> createState() => _RouterTerminalScreenState();
}

class _Entry {
  const _Entry(this.text, {this.color, this.bold = false});
  final String text;
  final Color? color;
  final bool bold;
}

class _RouterTerminalScreenState extends ConsumerState<RouterTerminalScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Entry> _output = [];
  bool _running = false;

  static const _green = Color(0xFF7EE787);
  static const _red = Color(0xFFFF7B72);
  static const _amber = Color(0xFFE3B341);
  static const _grey = Color(0xFF9DA7B3);

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _say(TerminalResult res, {required bool applied}) {
    for (final l in res.lines) {
      if (!applied || l.verb == 'print' || l.error != null) {
        _output.add(_Entry('> ${l.command}', bold: true));
      }
      if (l.error != null) {
        _output.add(_Entry(l.error!, color: _red));
      } else if (l.verb == 'print') {
        for (final r in l.rows) {
          _output.add(_Entry(r.entries.map((e) => '${e.key}=${e.value}').join('  '), color: _grey));
        }
        _output.add(_Entry(l.more > 0 ? '${l.matched} found, first ${l.matched - l.more} shown' : '${l.matched} found', color: _green));
      } else if (applied) {
        _output.add(_Entry('> ${l.command}', bold: true));
        _output.add(_Entry(res.dryRun ? 'Not changed: router writes are off (${l.matched} matched)' : '${l.changed} changed', color: res.dryRun ? _amber : _green));
      } else if (l.matched == 0) {
        _output.add(const _Entry('Nothing matched, nothing to do', color: _green));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _run() async {
    final text = _input.text.trim();
    if (text.isEmpty || _running) return;
    setState(() => _running = true);
    final remote = ref.read(marcoRemoteProvider);
    try {
      final preview = await remote.runTerminal(text);
      if (!mounted) return;
      setState(() => _say(preview, applied: false));
      if (preview.needsConfirm && !preview.lines.any((l) => l.error != null) && await _confirm(preview)) {
        final done = await remote.runTerminal(text, confirm: true);
        if (!mounted) return;
        setState(() => _say(done, applied: true));
      }
    } catch (e) {
      if (mounted) setState(() => _output.add(_Entry('$e', color: _red)));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<bool> _confirm(TerminalResult preview) async {
    final changes = preview.lines.where((l) => l.verb != 'print' && l.matched > 0).toList();
    final total = changes.fold<int>(0, (sum, l) => sum + l.matched);
    final answer = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Change $total ${total == 1 ? 'entry' : 'entries'} on the router?'),
            content: SizedBox(
              width: 560,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (preview.dryRun) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Router writes are off, so nothing will really change.')),
                  for (final l in changes) ...[
                    Text(l.command, style: const TextStyle(fontFamily: 'Consolas', fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    for (final n in l.names.take(15)) Text('  $n', style: const TextStyle(fontFamily: 'Consolas', fontSize: 12)),
                    if (l.names.length > 15) Text('  and ${l.names.length - 15} more', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('${changes.first.verb[0].toUpperCase()}${changes.first.verb.substring(1)}')),
            ],
          ),
    );
    return answer ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Router terminal'),
        actions: [
          TextButton.icon(onPressed: () => _input.text = _removeAll, icon: const Icon(Icons.healing_outlined, size: 18), label: const Text('Remove all NMS rules')),
          IconButton(tooltip: 'Clear output', icon: const Icon(Icons.clear_all), onPressed: () => setState(_output.clear)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0D1117), borderRadius: BorderRadius.circular(12)),
                child:
                    _output.isEmpty
                        ? const Text('Commands that can run here: print, remove, enable and disable.\nExample: /ip firewall filter print where chain=forward', style: TextStyle(color: _grey, fontFamily: 'Consolas', fontSize: 13))
                        : SelectionArea(
                          child: ListView.builder(
                            controller: _scroll,
                            itemCount: _output.length,
                            itemBuilder: (_, i) {
                              final e = _output[i];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Text(e.text, style: TextStyle(color: e.color ?? Colors.white, fontFamily: 'Consolas', fontSize: 13, fontWeight: e.bold ? FontWeight.w600 : FontWeight.normal)),
                              );
                            },
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Command (one per line)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _running ? null : _run,
                  icon: _running ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

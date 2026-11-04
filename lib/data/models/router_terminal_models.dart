/// What one typed line did on the router.
class TerminalLine {
  const TerminalLine({
    required this.command,
    required this.verb,
    this.matched = 0,
    this.changed = 0,
    this.names = const [],
    this.rows = const [],
    this.more = 0,
    this.error,
  });

  final String command;
  final String verb;
  final int matched;
  final int changed;
  final List<String> names;
  final List<Map<String, String>> rows;
  final int more;
  final String? error;

  factory TerminalLine.fromJson(Map<String, dynamic> json) => TerminalLine(
    command: json['command'] as String? ?? '',
    verb: json['verb'] as String? ?? '',
    matched: (json['matched'] as num?)?.toInt() ?? 0,
    changed: (json['changed'] as num?)?.toInt() ?? 0,
    names: List<String>.from(json['names'] as List? ?? const []),
    rows: [for (final r in (json['rows'] as List? ?? const [])) (r as Map).map((k, v) => MapEntry('$k', '$v'))],
    more: (json['more'] as num?)?.toInt() ?? 0,
    error: json['error'] as String?,
  );
}

class TerminalResult {
  const TerminalResult({required this.lines, this.needsConfirm = false, this.dryRun = false});

  final List<TerminalLine> lines;
  final bool needsConfirm;
  final bool dryRun;

  factory TerminalResult.fromJson(Map<String, dynamic> json) => TerminalResult(
    lines: [for (final l in (json['lines'] as List? ?? const [])) TerminalLine.fromJson(Map<String, dynamic>.from(l as Map))],
    needsConfirm: json['needs_confirm'] as bool? ?? false,
    dryRun: json['dry_run'] as bool? ?? false,
  );
}

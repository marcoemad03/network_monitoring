import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/datasources/remote/marco_remote_datasource.dart';
import 'package:network_monitorong/data/models/router_terminal_models.dart';
import 'package:network_monitorong/presentation/providers/marco/marco_provider.dart';
import 'package:network_monitorong/presentation/screens/marco/router_terminal_screen.dart';

class _FakeRemote implements MarcoRemoteDataSource {
  final List<bool> calls = [];

  @override
  Future<TerminalResult> runTerminal(String text, {bool confirm = false}) async {
    calls.add(confirm);
    return TerminalResult.fromJson({
      'needs_confirm': !confirm,
      'lines': [
        {'command': text, 'verb': 'remove', 'matched': 2, 'changed': confirm ? 2 : 0, 'names': ['nms-marco-a', 'nms-marco-b']},
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRemote> _pump(WidgetTester tester) async {
  final remote = _FakeRemote();
  await tester.pumpWidget(ProviderScope(overrides: [marcoRemoteProvider.overrideWithValue(remote)], child: const MaterialApp(home: RouterTerminalScreen())));
  await tester.enterText(find.byType(TextField), '/ip firewall filter remove [find where comment~"^nms-marco-"]');
  await tester.tap(find.text('Run'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500)); // the Run spinner keeps going behind the dialog
  return remote;
}

void main() {
  testWidgets('a change waits for a yes and shows what it would touch', (tester) async {
    final remote = await _pump(tester);
    expect(remote.calls, [false]);
    expect(find.text('Change 2 entries on the router?'), findsOneWidget);
    expect(find.textContaining('nms-marco-a'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(remote.calls, [false]);
  });

  testWidgets('saying yes runs it and reports the result', (tester) async {
    final remote = await _pump(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(remote.calls, [false, true]);
    expect(find.text('2 changed'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/datasources/remote/usage_report_remote_datasource.dart';
import 'package:network_monitorong/data/models/usage_report_models.dart';
import 'package:network_monitorong/presentation/providers/reporting/usage_report_provider.dart';
import 'package:network_monitorong/presentation/screens/reporting/reporting_hub_screen.dart';
import 'package:network_monitorong/presentation/screens/reporting/reports_screen.dart';

const _gb = 1000000000;

Map<String, dynamic> _json({bool noData = false, bool partial = false, int days = 3}) {
  final from = DateTime(2026, 11, 1);
  return {
    'generated_at': DateTime(2026, 11, 3, 10, 15).toIso8601String(),
    'period': {'from': '2026-11-01', 'to': '2026-11-0$days', 'days': days},
    'coverage': {'no_data': noData, 'partial': partial, 'note': noData ? 'Nothing has been measured yet.' : (partial ? 'Measuring started on 2 Nov 2026, so the days before it are empty, not zero.' : '')},
    'totals': {
      'wan_download_bytes': noData ? 0 : 8 * _gb,
      'wan_upload_bytes': noData ? 0 : 2 * _gb,
      'wan_total_bytes': noData ? 0 : 10 * _gb,
      'device_download_bytes': noData ? 0 : 6 * _gb,
      'device_upload_bytes': noData ? 0 : 1 * _gb,
      'device_total_bytes': noData ? 0 : 7 * _gb,
      'active_devices': noData ? 0 : 42,
      'new_devices': noData ? 0 : 3,
      'seen_devices': 60,
      'peak_download_bps': 90000000,
      'peak_upload_bps': 10000000,
      'avg_bytes_per_day': noData ? 0 : 3 * _gb,
      'device_coverage_pct': noData ? null : 70.0,
    },
    'compare': {
      'previous': {'from': '2026-10-29', 'to': '2026-10-31', 'days': days},
      'wan_total_bytes': 5 * _gb,
      'device_total_bytes': 4 * _gb,
      'wan_change_pct': noData ? null : 100.0,
      'device_change_pct': noData ? null : -12.0,
    },
    'daily': [
      for (var i = 0; i < days; i++)
        {
          'day': from.add(Duration(days: i)).toIso8601String().substring(0, 10),
          'wan_download_bytes': (i + 1) * _gb,
          'wan_upload_bytes': _gb ~/ 2,
          'device_download_bytes': _gb,
          'device_upload_bytes': _gb ~/ 4,
          'active_devices': 30 + i,
        },
    ],
    'hourly': [
      for (var h = 0; h < 24; h++) {'hour': h, 'download_bytes': h == 11 ? 4 * _gb : 1000000, 'upload_bytes': h == 11 ? _gb : 0, 'avg_bps': 1000000},
    ],
    'top_devices': noData
        ? <Object>[]
        : [
            {'rank': 1, 'mac': 'AA:00:00:00:00:01', 'name': 'Radiology PC', 'name_source': 'custom', 'ip': '172.16.0.10', 'kind': 'computer', 'place': 'Radiology', 'download_bytes': 2 * _gb, 'upload_bytes': _gb ~/ 2, 'total_bytes': 2500000000, 'share_pct': 35.7, 'active_days': 3, 'online': true},
            {'rank': 2, 'mac': 'AA:00:00:00:00:02', 'name': '172.16.0.11', 'name_source': 'ip', 'ip': '172.16.0.11', 'kind': 'phone', 'place': '', 'download_bytes': _gb, 'upload_bytes': 0, 'total_bytes': _gb, 'share_pct': 14.3, 'active_days': 2, 'online': false},
          ],
    'device_count': noData ? 0 : 42,
    'by_kind': noData
        ? <Object>[]
        : [
            {'key': 'computer', 'download_bytes': 4 * _gb, 'upload_bytes': _gb, 'total_bytes': 5 * _gb, 'devices': 20, 'share_pct': 71.4},
            {'key': 'phone', 'download_bytes': 2 * _gb, 'upload_bytes': 0, 'total_bytes': 2 * _gb, 'devices': 22, 'share_pct': 28.6},
          ],
    'by_place': noData
        ? <Object>[]
        : [
            {'key': 'Radiology', 'download_bytes': 2 * _gb, 'upload_bytes': 0, 'total_bytes': 2 * _gb, 'devices': 1, 'share_pct': 28.6},
            {'key': 'Not set', 'download_bytes': 4 * _gb, 'upload_bytes': _gb, 'total_bytes': 5 * _gb, 'devices': 41, 'share_pct': 71.4},
          ],
    'alerts': {'total': 3, 'open': 2, 'by_severity': {'high': 2, 'low': 1}},
    'events': [
      {'type': 'device_offline', 'count': 5},
    ],
    'security': {'taken_at': DateTime(2026, 11, 3, 9, 0).toIso8601String(), 'findings': 2, 'by_severity': {'medium': 2}},
    'insights': noData
        ? <Object>[]
        : [
            {'level': 'info', 'text': 'Internet use is up 100% compared with the 3 days before.'},
            {'level': 'warning', 'text': '1 of the 2 biggest users have no name.'},
          ],
  };
}

class _FakeRemote implements UsageReportRemoteDataSource {
  _FakeRemote(this.next);

  Object Function() next;
  final List<String> fetches = [];
  final List<String> exports = [];

  @override
  Future<UsageReport> fetch(DateTime from, DateTime to) async {
    fetches.add('${UsageReportRemoteDataSource.dateParam(from)}..${UsageReportRemoteDataSource.dateParam(to)}');
    final n = next();
    if (n is Exception) throw n;
    return UsageReport.fromJson(n as Map<String, dynamic>);
  }

  @override
  Future<ReportFile> export(DateTime from, DateTime to, String view) async {
    exports.add(view);
    return ReportFile('usage-$view.csv', [1, 2, 3]);
  }
}

Future<({_FakeRemote remote, List<String> saved})> _pump(WidgetTester tester, Object Function() next, {Size size = const Size(1400, 1800), Widget home = const ReportsScreen()}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final remote = _FakeRemote(next);
  final saved = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        usageReportRemoteProvider.overrideWithValue(remote),
        reportFileSaverProvider.overrideWithValue((file) async {
          saved.add(file.name);
          return r'C:\Users\x\Downloads\' + file.name;
        }),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return (remote: remote, saved: saved);
}

void main() {
  testWidgets('shows the numbers, what stands out, the charts and the top devices', (tester) async {
    await _pump(tester, _json);
    expect(find.text('Internet used'), findsOneWidget);
    expect(find.text('10.0 GB'), findsOneWidget);
    expect(find.text('↓ 8.00 GB   ↑ 2.00 GB'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.textContaining('100% more than the 3 days before'), findsOneWidget);
    expect(find.textContaining('12% less than'), findsOneWidget);
    expect(find.text('What stands out'), findsOneWidget);
    expect(find.textContaining('up 100%'), findsOneWidget);
    expect(find.text('Internet per day'), findsOneWidget);
    expect(find.text('Busiest hours'), findsOneWidget);
    expect(find.textContaining('Busiest hour: 11:00 to 12:00'), findsOneWidget);
    expect(find.text('Radiology PC'), findsOneWidget);
    expect(find.text('2.50 GB'), findsOneWidget);
    expect(find.text('Name devices in the Network Map'), findsOneWidget);
    expect(find.text('By device type'), findsOneWidget);
    expect(find.text('Computer · 20'), findsOneWidget);
    expect(find.text('Not set · 41'), findsOneWidget);
    expect(find.text('Alerts and security'), findsOneWidget);
    expect(find.text('2 High'), findsOneWidget);
    expect(find.text('3 raised, 2 still open'), findsOneWidget);
    expect(find.text('Updated 10:15'), findsOneWidget);
    expect(find.text('How these numbers are measured'), findsOneWidget);
  });

  testWidgets('choosing a period asks for exactly those days', (tester) async {
    final r = await _pump(tester, _json);
    expect(r.remote.fetches.single.split('..').last, UsageReportRemoteDataSource.dateParam(DateTime.now()));
    expect(r.remote.fetches.single.split('..').first, UsageReportRemoteDataSource.dateParam(DateTime.now().subtract(const Duration(days: 6))));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Yesterday'));
    await tester.pumpAndSettle();
    final y = UsageReportRemoteDataSource.dateParam(DateTime.now().subtract(const Duration(days: 1)));
    expect(r.remote.fetches.last, '$y..$y');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Last 30 days'));
    await tester.pumpAndSettle();
    expect(r.remote.fetches.last.split('..').first, UsageReportRemoteDataSource.dateParam(DateTime.now().subtract(const Duration(days: 29))));

    final now = DateTime.now();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Last month'));
    await tester.pumpAndSettle();
    expect(r.remote.fetches.last, '${UsageReportRemoteDataSource.dateParam(DateTime(now.year, now.month - 1))}..${UsageReportRemoteDataSource.dateParam(DateTime(now.year, now.month, 0))}');
  });

  testWidgets('a period with nothing measured says so and hides empty charts', (tester) async {
    await _pump(tester, () => _json(noData: true));
    expect(find.text('Nothing has been measured yet.'), findsOneWidget);
    expect(find.text('Internet used'), findsNothing);
    expect(find.text('Top devices'), findsNothing);
    expect(find.text('Alerts and security'), findsOneWidget);
  });

  testWidgets('a partly measured period warns that empty days are not zero', (tester) async {
    await _pump(tester, () => _json(partial: true));
    expect(find.textContaining('empty, not zero'), findsWidgets);
    expect(find.text('Internet used'), findsOneWidget);
  });

  testWidgets('a failed read shows the reason and a way to retry', (tester) async {
    var fail = true;
    final r = await _pump(tester, () => fail ? const ReportRequestFailed('The NMS server is not reachable.') : _json());
    expect(find.text('The report could not be built'), findsOneWidget);
    expect(find.text('The NMS server is not reachable.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Internet used'), findsOneWidget);
    expect(r.remote.fetches.length, 2);
  });

  testWidgets('keeps showing the last report when a refresh fails, and says so', (tester) async {
    var fail = false;
    await _pump(tester, () => fail ? const ReportRequestFailed('The NMS server took too long to answer.') : _json());
    fail = true;
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not refresh (The NMS server took too long to answer.)'), findsOneWidget);
    expect(find.text('Internet used'), findsOneWidget);
    expect(find.text('Radiology PC'), findsOneWidget);
  });

  testWidgets('exporting saves the file and tells where it went', (tester) async {
    final r = await _pump(tester, _json);
    await tester.tap(find.byTooltip('Save as a spreadsheet (CSV)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Totals per day'));
    await tester.pumpAndSettle();
    expect(r.remote.exports, ['daily']);
    expect(r.saved, ['usage-daily.csv']);
    expect(find.textContaining(r'Saved the daily totals to C:\Users\x\Downloads\usage-daily.csv'), findsOneWidget);
  });

  testWidgets('export from the top devices card sends the devices view', (tester) async {
    final r = await _pump(tester, _json);
    await tester.tap(find.text('Export all'));
    await tester.pumpAndSettle();
    expect(r.remote.exports, ['devices']);
  });

  testWidgets('a single day shows the hours instead of a one-bar chart', (tester) async {
    await _pump(tester, () => _json(days: 1));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Today'));
    await tester.pumpAndSettle();
    expect(find.text('Internet per day'), findsNothing);
    expect(find.text('Busiest hours'), findsOneWidget);
  });

  testWidgets('fits a narrow window without overflow', (tester) async {
    await _pump(tester, _json, size: const Size(420, 2200));
    expect(tester.takeException(), isNull);
    expect(find.text('Internet used'), findsOneWidget);
    expect(find.text('Radiology PC'), findsOneWidget);
  });

  testWidgets('the hub says which tools have data and which do not', (tester) async {
    await _pump(tester, _json, home: const ReportingHubScreen());
    expect(find.text('Ready to use'), findsOneWidget);
    expect(find.text('Not recording yet'), findsOneWidget);
    expect(find.text('Saved settings only'), findsOneWidget);
    expect(find.textContaining('used in the last 7 days · 42 devices'), findsOneWidget);
    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.text('No data source'), findsNWidgets(2));
  });
}

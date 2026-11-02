import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/usage_report_remote_datasource.dart';
import '../../../data/models/usage_report_models.dart';

final usageReportRemoteProvider = Provider<UsageReportRemoteDataSource>(
  (ref) => UsageReportRemoteDataSource(ref.watch(dioProvider)),
);

enum ReportPreset {
  today('Today'),
  yesterday('Yesterday'),
  last7('Last 7 days'),
  last30('Last 30 days'),
  thisMonth('This month'),
  lastMonth('Last month'),
  custom('Custom');

  const ReportPreset(this.label);
  final String label;
}

/// The days a report covers. Both ends are whole days and both are included.
class ReportRange {
  final ReportPreset preset;
  final DateTime from;
  final DateTime to;
  const ReportRange(this.preset, this.from, this.to);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  factory ReportRange.of(ReportPreset preset, DateTime now) {
    final today = _day(now);
    switch (preset) {
      case ReportPreset.today:
        return ReportRange(preset, today, today);
      case ReportPreset.yesterday:
        final y = today.subtract(const Duration(days: 1));
        return ReportRange(preset, y, y);
      case ReportPreset.last7:
        return ReportRange(preset, DateTime(today.year, today.month, today.day - 6), today);
      case ReportPreset.last30:
        return ReportRange(preset, DateTime(today.year, today.month, today.day - 29), today);
      case ReportPreset.thisMonth:
        return ReportRange(preset, DateTime(today.year, today.month), DateTime(today.year, today.month + 1, 0));
      case ReportPreset.lastMonth:
        return ReportRange(preset, DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0));
      case ReportPreset.custom:
        return ReportRange(preset, today, today);
    }
  }

  factory ReportRange.custom(DateTime from, DateTime to) => ReportRange(ReportPreset.custom, _day(from), _day(to));

  int get days => to.difference(from).inDays + 1;
  bool includesToday(DateTime now) => !_day(now).isBefore(from) && !_day(now).isAfter(to);

  @override
  bool operator ==(Object other) => other is ReportRange && other.preset == preset && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(preset, from, to);
}

class ReportRangeController extends Notifier<ReportRange> {
  @override
  ReportRange build() => ReportRange.of(ReportPreset.last7, DateTime.now());

  void choose(ReportPreset preset) => state = ReportRange.of(preset, DateTime.now());
  void custom(DateTime from, DateTime to) => state = ReportRange.custom(from, to);
}

final reportRangeProvider = NotifierProvider<ReportRangeController, ReportRange>(ReportRangeController.new);

/// How often a report that includes today is read again.
const reportRefreshEvery = Duration(minutes: 1);

/// The report for the chosen days. Reading it only queries what the NMS has
/// already recorded; it never touches the router.
final usageReportProvider = FutureProvider.autoDispose<UsageReport>((ref) async {
  final range = ref.watch(reportRangeProvider);
  if (range.includesToday(DateTime.now())) {
    final timer = Timer(reportRefreshEvery, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return ref.watch(usageReportRemoteProvider).fetch(range.from, range.to);
});

/// Writes an exported file to disk and returns where it went. Replaceable in tests.
typedef ReportFileSaver = Future<String> Function(ReportFile file);

Future<String> saveToDownloads(ReportFile file) async {
  final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  var path = '${dir.path}${Platform.pathSeparator}${file.name}';
  var n = 1;
  while (File(path).existsSync()) {
    final dot = file.name.lastIndexOf('.');
    final base = dot < 0 ? file.name : file.name.substring(0, dot);
    final ext = dot < 0 ? '' : file.name.substring(dot);
    path = '${dir.path}${Platform.pathSeparator}$base ($n)$ext';
    n++;
  }
  await File(path).writeAsBytes(file.bytes, flush: true);
  return path;
}

final reportFileSaverProvider = Provider<ReportFileSaver>((ref) => saveToDownloads);

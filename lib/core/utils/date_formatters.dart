import 'package:intl/intl.dart';

class DateFormatters {
  DateFormatters._();

  static final _dateFormat = DateFormat('yyyy-MM-dd');
  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final _dateTimeWithTzFormat = DateFormat('yyyy-MM-dd HH:mm:ss z');
  static final _relativeFormat = DateFormat('MMM d, yyyy');
  static final _shortDateTimeFormat = DateFormat('MMM d, HH:mm');

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String formatRelative(DateTime date) => _relativeFormat.format(date);
  static String formatShortDateTime(DateTime date) =>
      _shortDateTimeFormat.format(date);

  static String formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String formatBitrate(double bitsPerSecond) {
    if (bitsPerSecond < 1000) return '${bitsPerSecond.toStringAsFixed(0)} bps';
    if (bitsPerSecond < 1000000) {
      return '${(bitsPerSecond / 1000).toStringAsFixed(1)} Kbps';
    }
    if (bitsPerSecond < 1000000000) {
      return '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mbps';
    }
    return '${(bitsPerSecond / 1000000000).toStringAsFixed(2)} Gbps';
  }

  static String formatPercentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static String formatUptime(DateTime? lastBoot, DateTime? lastSeen) {
    if (lastBoot == null) return 'N/A';
    final end = lastSeen ?? DateTime.now();
    return formatDuration(end.difference(lastBoot));
  }

  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatRelative(date);
  }
}

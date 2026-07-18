String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

extension StringExtensions on String {
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get titleCase {
    return split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  bool get isValidIpAddress {
    final ipRegex = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    );
    final match = ipRegex.firstMatch(this);
    if (match == null) return false;
    for (int i = 1; i <= 4; i++) {
      final octet = int.tryParse(match.group(i)!);
      if (octet == null || octet < 0 || octet > 255) return false;
    }
    return true;
  }

  bool get isValidMacAddress {
    final macRegex = RegExp(
      r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$',
    );
    return macRegex.hasMatch(this);
  }

  String toMasked({int visibleChars = 4}) {
    if (length <= visibleChars) return this;
    return '${'*' * (length - visibleChars)}${substring(length - visibleChars)}';
  }

  String truncate(int maxLength, {String suffix = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}$suffix';
  }
}

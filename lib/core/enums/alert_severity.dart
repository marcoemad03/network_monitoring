enum AlertSeverity {
  critical('critical', 'Critical', 0xffF44336, 1),
  high('high', 'High', 0xffFF5722, 2),
  medium('medium', 'Medium', 0xffFF9800, 3),
  low('low', 'Low', 0xffFFC107, 4),
  info('info', 'Info', 0xff2196F3, 5);

  final String value;
  final String label;
  final int colorValue;
  final int priority;

  const AlertSeverity(
      this.value, this.label, this.colorValue, this.priority);

  static AlertSeverity fromValue(String value) {
    return AlertSeverity.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AlertSeverity.info,
    );
  }
}

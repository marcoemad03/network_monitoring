enum DeviceStatus {
  online('online', 'Online', 0xff4CAF50),
  offline('offline', 'Offline', 0xffF44336),
  degraded('degraded', 'Degraded', 0xffFF9800),
  maintenance('maintenance', 'Maintenance', 0xff2196F3),
  unknown('unknown', 'Unknown', 0xff9E9E9E),
  unmanaged('unmanaged', 'Unmanaged', 0xff607D8B);

  final String value;
  final String label;
  final int colorValue;

  const DeviceStatus(this.value, this.label, this.colorValue);

  static DeviceStatus fromValue(String value) {
    return DeviceStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => DeviceStatus.unknown,
    );
  }
}

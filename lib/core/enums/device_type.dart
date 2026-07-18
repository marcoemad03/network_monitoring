enum DeviceType {
  router('router', 'Router'),
  switch_('switch', 'Switch'),
  server('server', 'Server'),
  firewall('firewall', 'Firewall'),
  workstation('workstation', 'Workstation'),
  printer('printer', 'Printer'),
  accessPoint('access_point', 'Access Point'),
  camera('camera', 'Camera'),
  phone('phone', 'Phone'),
  iot('iot', 'IoT Device'),
  medicalDevice('medical_device', 'Medical Device'),
  unknown('unknown', 'Unknown');

  final String value;
  final String label;

  const DeviceType(this.value, this.label);

  static DeviceType fromValue(String value) {
    return DeviceType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DeviceType.unknown,
    );
  }
}

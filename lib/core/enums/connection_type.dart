enum ConnectionType {
  ethernet('ethernet', 'Ethernet'),
  wifi('wifi', 'Wi-Fi'),
  fiber('fiber', 'Fiber'),
  cellular('cellular', 'Cellular'),
  satellite('satellite', 'Satellite'),
  vpn('vpn', 'VPN'),
  virtual('virtual', 'Virtual'),
  unknown('unknown', 'Unknown');

  final String value;
  final String label;

  const ConnectionType(this.value, this.label);

  static ConnectionType fromValue(String value) {
    return ConnectionType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => ConnectionType.unknown,
    );
  }
}

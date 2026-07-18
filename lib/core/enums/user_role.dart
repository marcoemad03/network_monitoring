enum UserRole {
  superAdmin('super_admin', 'Super Admin', 100),
  networkAdmin('network_admin', 'Network Administrator', 80),
  itSupport('it_support', 'IT Support', 60),
  readOnly('read_only', 'Read Only', 30);

  final String value;
  final String label;
  final int permissionLevel;

  const UserRole(this.value, this.label, this.permissionLevel);

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (r) => r.value == value,
      orElse: () => UserRole.readOnly,
    );
  }

  bool get canManageUsers => this == UserRole.superAdmin;
  bool get canManageDevices => this == UserRole.superAdmin || this == UserRole.networkAdmin;
  bool get canAcknowledgeAlerts =>
      this == UserRole.superAdmin || this == UserRole.networkAdmin || this == UserRole.itSupport;
  bool get canResolveAlerts => this == UserRole.superAdmin || this == UserRole.networkAdmin;
  bool get canConfigureSystem => this == UserRole.superAdmin;
  bool get canViewAuditLogs => this != UserRole.readOnly;
  bool get canManagePermissions => this == UserRole.superAdmin;
  bool get canStartScans => this == UserRole.superAdmin || this == UserRole.networkAdmin;
  bool get canDeleteDevices => this == UserRole.superAdmin || this == UserRole.networkAdmin;
}

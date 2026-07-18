class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String devices = '/devices';
  static const String deviceDetail = '/devices/:id';
  static const String deviceCreate = '/devices/create';
  static const String deviceEdit = '/devices/:id/edit';
  static const String alerts = '/alerts';
  static const String alertDetail = '/alerts/:id';
  static const String networkMap = '/network/map';
  static const String networkScan = '/network/scan';
  static const String networkScanResults = '/network/scan/:id';
  static const String settings = '/settings';
  static const String userManagement = '/settings/users';
  static const String permissionManagement = '/settings/permissions';
  static const String auditLog = '/audit';
  static const String about = '/about';
  static const String internetManagement = '/internet';
  static const String internetPolicies = '/internet/policies';
  static const String internetPolicyDetail = '/internet/policies/:id';
  static const String internetPolicyCreate = '/internet/policies/create';
  static const String deviceBlocks = '/internet/blocks';
  static const String vendorIntegrations = '/internet/vendors';

  // Reporting & Analytics
  static const String reporting = '/reporting';
  static const String webLogs = '/reporting/web-logs';
  static const String connectionLogs = '/reporting/connections';
  static const String downloadLogs = '/reporting/downloads';
  static const String reports = '/reporting/reports';
  static const String alertRules = '/reporting/alerts';
  static const String widgets = '/reporting/widgets';
}

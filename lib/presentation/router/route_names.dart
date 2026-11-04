class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String login = '/login';
  static const String forgotPassword = '/forgot-password';
  static const String connectMikroTik = '/connect-mikrotik';
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
  static const String hotspotWelcome = '/settings/hotspot-welcome';
  static const String telegramSettings = '/settings/telegram';
  static const String auditLog = '/audit';
  static const String security = '/security';
  static const String securitySites = '/security/sites';
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

  // Asset Management
  static const String assetGroups = '/asset/groups';
  static String assetGroupDetail(String id) => '/asset/groups/$id';
  static const String marcoGroups = '/marco-groups';
  static const String routerTerminal = '/marco-groups/terminal';
  static String marcoGroupDetail(String id) => '/marco-groups/$id';
  static const String floorMaps = '/asset/floor-maps';
  static String floorMapDetail(String id) => '/asset/floor-maps/$id';
  static String floorMapEditor(String id) => '/asset/floor-maps/$id/edit';
  static const String assetPolicies = '/asset/policies';
  static String assetPolicyDetail(String id) => '/asset/policies/$id';
  static const String assetList = '/asset/list';
  static String assetDeviceDetail(String deviceId) => '/asset/list/$deviceId';

  // Enterprise Features
  static const String deviceEvents = '/devices/:id/events';
  static const String enhancedDeviceList = '/devices/enhanced';
  static const String connectedDevices = '/devices/connected';
  static const String deviceInfrastructure = '/devices/infrastructure';
  static const String activeConnections = '/devices/active-connections';

  // Infrastructure
  static const String infrastructureStatus = '/infrastructure';
}

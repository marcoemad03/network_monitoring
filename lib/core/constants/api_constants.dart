class ApiConstants {
  ApiConstants._();

  static const String apiVersion = 'v1';
  static const String basePath = '/api/$apiVersion';

  // Auth
  static const String login = '$basePath/auth/login';
  static const String logout = '$basePath/auth/logout';
  static const String refreshToken = '$basePath/auth/refresh';
  static const String forgotPassword = '$basePath/auth/forgot-password';
  static const String resetPassword = '$basePath/auth/reset-password';
  static const String me = '$basePath/auth/me';

  // Devices
  static const String devices = '$basePath/devices';
  static String deviceDetail(String id) => '$basePath/devices/$id';
  static String deviceInterfaces(String id) =>
      '$basePath/devices/$id/interfaces';
  static String deviceMetrics(String id) => '$basePath/devices/$id/metrics';

  // Alerts
  static const String alerts = '$basePath/alerts';
  static String alertDetail(String id) => '$basePath/alerts/$id';
  static String acknowledgeAlert(String id) =>
      '$basePath/alerts/$id/acknowledge';
  static String resolveAlert(String id) => '$basePath/alerts/$id/resolve';

  // Network Scan
  static const String scans = '$basePath/scans';
  static String scanResult(String id) => '$basePath/scans/$id';

  // Network Map
  static const String networkMap = '$basePath/network-map';

  // Audit
  static const String auditLogs = '$basePath/audit-logs';

  // Users
  static const String users = '$basePath/users';
  static String userDetail(String id) => '$basePath/users/$id';
  static String userResetPassword(String id) => '$basePath/users/$id/reset-password';

  // Sessions
  static const String sessions = '$basePath/sessions';
  static String sessionDetail(String id) => '$basePath/sessions/$id';

  // Permissions
  static const String permissions = '$basePath/permissions';
  static const String permissionsAllWithRoles = '$basePath/permissions/all-with-roles';
  static const String roles = '$basePath/roles';
  static String roleDetail(String id) => '$basePath/roles/$id';
  static String rolePermissions(String id) => '$basePath/roles/$id/permissions';
  static String rolePermissionItem(String roleId, String permId) =>
      '$basePath/roles/$roleId/permissions/$permId';

  // Auth
  static const String myPermissions = '$basePath/auth/me/permissions';
  static const String changePassword = '$basePath/auth/change-password';

  // Dashboard / Monitoring
  static const String dashboard = '$basePath/dashboard';
  static const String dashboardSummary = '$basePath/dashboard/summary';
  static const String monitoringDashboard = '$basePath/monitoring/dashboard';
  static const String monitoringClients = '$basePath/monitoring/clients';
  static const String monitoringConnections = '$basePath/monitoring/connections';

  // Device Monitoring
  static String deviceLatestMetrics(String id) => '$basePath/devices/$id/metrics/latest';
  static String deviceMetricsHistory(String id) => '$basePath/devices/$id/metrics/history';
  static String devicePingHistory(String id) => '$basePath/devices/$id/ping';
  static String deviceTrafficHistory(String id) => '$basePath/devices/$id/traffic';
  static String deviceClients(String id) => '$basePath/devices/$id/clients';

  // WebSocket
  static const String wsAlerts = '/ws/alerts';
  static const String wsMetrics = '/ws/metrics';
  static const String wsDiscovery = '/ws/discovery';
  static const String wsDashboard = '/ws/dashboard';

  // Headers
  static const String authHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer';
  static const String contentTypeHeader = 'Content-Type';
  static const String acceptHeader = 'Accept';
  static const String apiKeyHeader = 'X-API-Key';
  static const String correlationIdHeader = 'X-Correlation-ID';
  static const String requestIdHeader = 'X-Request-ID';

  // Internet Management
  static const String internetPolicies = '$basePath/internet-policies';
  static String internetPolicyDetail(String id) => '$basePath/internet-policies/$id';
  static String internetPolicyBandwidthRules(String id) => '$basePath/internet-policies/$id/bandwidth-rules';
  static String internetPolicyFilteringRules(String id) => '$basePath/internet-policies/$id/filtering-rules';
  static String internetPolicySchedules(String id) => '$basePath/internet-policies/$id/schedules';
  static const String bandwidthRules = '$basePath/bandwidth-rules';
  static String bandwidthRuleDetail(String id) => '$basePath/bandwidth-rules/$id';
  static String bandwidthRuleTemporary(String id) => '$basePath/bandwidth-rules/$id/temporary';
  static const String filteringRules = '$basePath/filtering-rules';
  static String filteringRuleDetail(String id) => '$basePath/filtering-rules/$id';
  static const String schedules = '$basePath/schedules';
  static String scheduleDetail(String id) => '$basePath/schedules/$id';
  static const String deviceBlocks = '$basePath/device-blocks';
  static String deviceBlockDetail(String id) => '$basePath/device-blocks/$id';
  static const String vendorIntegrations = '$basePath/vendor-integrations';
  static String vendorIntegrationDetail(String id) => '$basePath/vendor-integrations/$id';
  static String vendorIntegrationTest(String id) => '$basePath/vendor-integrations/$id/test';
  static String vendorIntegrationSync(String id) => '$basePath/vendor-integrations/$id/sync';

  // Content Types
  static const String applicationJson = 'application/json';
}

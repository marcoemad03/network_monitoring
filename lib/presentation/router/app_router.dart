import 'package:go_router/go_router.dart';
import '../../core/config/build_config.dart';
import '../../core/config/environment.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/connect/mikrotik_connect_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/devices/equipment_screen.dart';
import '../screens/security/security_screen.dart';
import '../screens/sites/sites_screen.dart';
import '../screens/devices/devices_screen.dart';
import '../screens/devices/device_detail_screen.dart';
import '../screens/devices/device_form_screen.dart';
import '../screens/devices/device_events_screen.dart';
import '../screens/devices/enhanced_device_list_screen.dart';
import '../screens/devices/connected_devices_screen.dart';
import '../screens/devices/active_connections_screen.dart';
import '../screens/alerts/alert_list_screen.dart';
import '../screens/alerts/alert_detail_screen.dart';
import '../screens/network/network_map_screen.dart';
import '../screens/network/scan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/settings/permission_management_screen.dart';
import '../screens/settings/hotspot_welcome_screen.dart';
import '../screens/settings/telegram_settings_screen.dart';
import '../screens/audit/audit_log_screen.dart';
import '../screens/internet/internet_management_screen.dart';
import '../screens/internet/policy_list_screen.dart';
import '../screens/internet/policy_detail_screen.dart';
import '../screens/internet/device_blocks_screen.dart';
import '../screens/internet/vendor_integrations_screen.dart';
import '../screens/reporting/reporting_hub_screen.dart';
import '../screens/reporting/web_logs_screen.dart';
import '../screens/reporting/connection_logs_screen.dart';
import '../screens/reporting/download_logs_screen.dart';
import '../screens/reporting/reports_screen.dart';
import '../screens/reporting/alert_rules_screen.dart';
import '../screens/reporting/dashboard_widgets_screen.dart';
import '../screens/groups/group_list_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/floor_map/floor_map_list_screen.dart';
import '../screens/floor_map/floor_map_viewer_screen.dart';
import '../screens/floor_map/floor_map_editor_screen.dart';
import '../screens/policies/policy_list_screen.dart';
import '../screens/policies/policy_detail_screen.dart';
import '../screens/marco/marco_groups_screen.dart';
import '../screens/marco/marco_group_detail_screen.dart';
import '../screens/assets/asset_list_screen.dart';
import '../screens/assets/asset_detail_screen.dart';
import '../screens/infrastructure/infrastructure_status_screen.dart';
import 'route_names.dart';
import '../widgets/layout/app_scaffold.dart';

class AppRouter {
  final GoRouter router;

  AppRouter()
    : router = GoRouter(
        initialLocation:
            BuildConfig.isInitialized &&
                    BuildConfig.environment == Environment.development
                ? RouteNames.connectMikroTik
                : RouteNames.splash,
        debugLogDiagnostics: false,
        routes: [
          GoRoute(
            path: RouteNames.splash,
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: RouteNames.login,
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: RouteNames.forgotPassword,
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: RouteNames.connectMikroTik,
            builder: (context, state) => const MikroTikConnectScreen(),
          ),
          ShellRoute(
            builder: (context, state, child) => AppScaffold(child: child),
            routes: [
              GoRoute(
                path: RouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: RouteNames.devices,
                builder: (context, state) => const DevicesScreen(),
                routes: [
                  GoRoute(
                    path: 'infrastructure',
                    builder: (context, state) => const EquipmentScreen(),
                  ),
                  GoRoute(
                    path: 'create',
                    builder: (context, state) => const DeviceFormScreen(),
                  ),
                  GoRoute(
                    path: 'enhanced',
                    builder:
                        (context, state) => const EnhancedDeviceListScreen(),
                  ),
                  GoRoute(
                    path: 'connected',
                    builder: (context, state) => const ConnectedDevicesScreen(),
                  ),
                  GoRoute(
                    path: 'active-connections',
                    builder: (context, state) => const ActiveConnectionsScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) =>
                            DeviceDetailScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder:
                            (context, state) => DeviceFormScreen(
                              deviceId: state.pathParameters['id'],
                            ),
                      ),
                      GoRoute(
                        path: 'events',
                        builder:
                            (context, state) => DeviceEventsScreen(
                              deviceId: state.pathParameters['id']!,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.alerts,
                builder: (context, state) => const AlertListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) =>
                            AlertDetailScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.networkMap,
                builder: (context, state) => const NetworkMapScreen(),
              ),
              GoRoute(
                path: RouteNames.networkScan,
                builder: (context, state) => const ScanScreen(),
              ),
              GoRoute(
                path: RouteNames.internetManagement,
                builder: (context, state) => const InternetManagementScreen(),
              ),
              GoRoute(
                path: RouteNames.internetPolicies,
                builder: (context, state) => const InternetPolicyListScreen(),
                routes: [
                  GoRoute(
                    path: 'create',
                    builder:
                        (context, state) => const InternetPolicyDetailScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => InternetPolicyDetailScreen(
                          policyId: state.pathParameters['id'],
                        ),
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.deviceBlocks,
                builder: (context, state) => const DeviceBlocksScreen(),
              ),
              GoRoute(
                path: RouteNames.vendorIntegrations,
                builder: (context, state) => const VendorIntegrationsScreen(),
              ),
              GoRoute(
                path: RouteNames.infrastructureStatus,
                builder: (context, state) => const InfrastructureStatusScreen(),
              ),
              GoRoute(
                path: RouteNames.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
              GoRoute(
                path: RouteNames.userManagement,
                builder: (context, state) => const UserManagementScreen(),
              ),
              GoRoute(
                path: RouteNames.permissionManagement,
                builder: (context, state) => const PermissionManagementScreen(),
              ),
              GoRoute(
                path: RouteNames.hotspotWelcome,
                builder: (context, state) => const HotspotWelcomeScreen(),
              ),
              GoRoute(
                path: RouteNames.telegramSettings,
                builder: (context, state) => const TelegramSettingsScreen(),
              ),
              GoRoute(
                path: RouteNames.security,
                builder: (context, state) => const SecurityScreen(),
              ),
              GoRoute(
                path: RouteNames.securitySites,
                builder: (context, state) => const SitesScreen(),
              ),
              GoRoute(
                path: RouteNames.auditLog,
                builder: (context, state) => const AuditLogScreen(),
              ),
              GoRoute(
                path: RouteNames.reporting,
                builder: (context, state) => const ReportingHubScreen(),
              ),
              GoRoute(
                path: RouteNames.webLogs,
                builder: (context, state) => const WebLogsScreen(),
              ),
              GoRoute(
                path: RouteNames.connectionLogs,
                builder: (context, state) => const ConnectionLogsScreen(),
              ),
              GoRoute(
                path: RouteNames.downloadLogs,
                builder: (context, state) => const DownloadLogsScreen(),
              ),
              GoRoute(
                path: RouteNames.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
              GoRoute(
                path: RouteNames.alertRules,
                builder: (context, state) => const AlertRulesScreen(),
              ),
              GoRoute(
                path: RouteNames.widgets,
                builder: (context, state) => const DashboardWidgetsScreen(),
              ),
              GoRoute(
                path: RouteNames.assetGroups,
                builder: (context, state) => const GroupListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => GroupDetailScreen(
                          groupId: state.pathParameters['id']!,
                        ),
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.floorMaps,
                builder: (context, state) => const FloorMapListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => FloorMapViewerScreen(
                          mapId: state.pathParameters['id']!,
                        ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder:
                            (context, state) => FloorMapEditorScreen(
                              mapId: state.pathParameters['id']!,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.assetPolicies,
                builder: (context, state) => const PolicyListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => PolicyDetailScreen(
                          policyId: state.pathParameters['id'],
                        ),
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.marcoGroups,
                builder: (context, state) => const MarcoGroupsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => MarcoGroupDetailScreen(
                          groupId: state.pathParameters['id']!,
                        ),
                  ),
                ],
              ),
              GoRoute(
                path: RouteNames.assetList,
                builder: (context, state) => const AssetListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder:
                        (context, state) => AssetDetailScreen(
                          deviceId: state.pathParameters['id']!,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
}

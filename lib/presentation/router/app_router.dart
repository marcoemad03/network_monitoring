import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/devices/device_list_screen.dart';
import '../screens/devices/device_detail_screen.dart';
import '../screens/devices/device_form_screen.dart';
import '../screens/alerts/alert_list_screen.dart';
import '../screens/alerts/alert_detail_screen.dart';
import '../screens/network/network_map_screen.dart';
import '../screens/network/scan_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/user_management_screen.dart';
import '../screens/settings/permission_management_screen.dart';
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
import 'route_names.dart';
import '../widgets/layout/app_scaffold.dart';

class AppRouter {
  final GoRouter router;

  AppRouter()
      : router = GoRouter(
          initialLocation: RouteNames.splash,
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
            ShellRoute(
              builder: (context, state, child) => AppScaffold(child: child),
              routes: [
                GoRoute(
                  path: RouteNames.dashboard,
                  builder: (context, state) => const DashboardScreen(),
                ),
                GoRoute(
                  path: RouteNames.devices,
                  builder: (context, state) => const DeviceListScreen(),
                  routes: [
                    GoRoute(
                      path: 'create',
                      builder: (context, state) => const DeviceFormScreen(),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => DeviceDetailScreen(
                        id: state.pathParameters['id']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'edit',
                          builder: (context, state) => DeviceFormScreen(
                            deviceId: state.pathParameters['id'],
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
                      builder: (context, state) => AlertDetailScreen(
                        id: state.pathParameters['id']!,
                      ),
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
                      builder: (context, state) => const InternetPolicyDetailScreen(),
                    ),
                    GoRoute(
                      path: ':id',
                      builder: (context, state) => InternetPolicyDetailScreen(
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
              ],
            ),
          ],
        );
}

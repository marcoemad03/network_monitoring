import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../router/route_names.dart';

class AppScaffold extends StatelessWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileLayout(context);
        }
        return _buildDesktopLayout(context, constraints);
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder:
              (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
        ),
      ),
      drawer: NavigationDrawer(
        onDestinationSelected:
            (index) => _onDestinationSelected(context, index),
        selectedIndex: _calculateSelectedIndex(context),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                Icon(
                  Icons.network_check,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'NMS',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ..._navItems.asMap().entries.map(
            (entry) => NavigationDrawerDestination(
              icon: Icon(entry.value.icon),
              selectedIcon: Icon(entry.value.selectedIcon),
              label: Text(entry.value.label),
            ),
          ),
        ],
      ),
      body: child,
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 88,
            child: NavigationRail(
              selectedIndex: _calculateSelectedIndex(context),
              onDestinationSelected:
                  (index) => _onDestinationSelected(context, index),
              labelType: NavigationRailLabelType.selected,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Icon(
                  Icons.network_check,
                  size: 26,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              destinations:
                  _navItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.dashboard)) return 0;
    if (location.startsWith(RouteNames.deviceInfrastructure)) return 2;
    if (location.startsWith('/devices')) return 1;
    if (location.startsWith('/alerts')) return 3;
    if (location.startsWith('/network')) return 4;
    if (location.startsWith('/reporting')) return 5;
    if (location.startsWith('/internet')) return 6;
    if (location.startsWith('/settings')) return 7;
    if (location.startsWith(RouteNames.marcoGroups)) return 8;
    if (location.startsWith('/asset')) return 9;
    if (location.startsWith('/audit')) return 10;
    return 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(RouteNames.dashboard);
      case 1:
        context.go(RouteNames.devices);
      case 2:
        context.go(RouteNames.deviceInfrastructure);
      case 3:
        context.go(RouteNames.alerts);
      case 4:
        context.go(RouteNames.networkMap);
      case 5:
        context.go(RouteNames.reporting);
      case 6:
        context.go(RouteNames.internetManagement);
      case 7:
        context.go(RouteNames.settings);
      case 8:
        context.go(RouteNames.marcoGroups);
      case 9:
        context.go(RouteNames.assetList);
      case 10:
        context.go(RouteNames.auditLog);
    }
  }
}

const _navItems = <_NavItem>[
  _NavItem(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  _NavItem(Icons.devices_outlined, Icons.devices, 'Devices'),
  _NavItem(Icons.router_outlined, Icons.router, 'Equipment'),
  _NavItem(Icons.warning_amber_outlined, Icons.warning_amber, 'Alerts'),
  _NavItem(Icons.hub_outlined, Icons.hub, 'Network'),
  _NavItem(Icons.analytics_outlined, Icons.analytics, 'Reports'),
  _NavItem(Icons.language_outlined, Icons.language, 'Internet'),
  _NavItem(Icons.settings_outlined, Icons.settings, 'Settings'),
  _NavItem(Icons.group_outlined, Icons.group, 'Groups'),
  _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'Assets'),
  _NavItem(Icons.history_outlined, Icons.history, 'Audit'),
];

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem(this.icon, this.selectedIcon, this.label);
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/services/marco_state_service.dart';
import 'package:network_monitorong/data/datasources/remote/marco_remote_datasource.dart';
import 'package:network_monitorong/data/datasources/remote/network_map_remote_datasource.dart';
import 'package:network_monitorong/data/models/marco_models.dart';
import 'package:network_monitorong/data/models/marco_site_models.dart';
import 'package:network_monitorong/data/models/network_map_models.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/providers/marco/marco_provider.dart';
import 'package:network_monitorong/presentation/providers/network/network_map_provider.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_group_detail_screen.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_groups_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tablet = MarcoMember(deviceId: 'd1', name: 'Ward tablet', macAddress: 'AA:BB:CC:DD:EE:01', ipAddress: '172.16.0.20', isOnline: true);

class _FakeMarco implements MarcoRemoteDataSource {
  _FakeMarco({this.policy = const {'internet_enabled': true}, this.empty = false});

  Map<String, dynamic> policy;
  bool empty;
  final List<String> calls = [];
  Map<String, dynamic>? savedPolicy;
  Map<String, dynamic>? createdPolicy;
  List<String>? addedMacs;
  Map<String, Object?>? control;
  MarcoSiteCheck Function(String site) checker = (site) => MarcoSiteCheck(target: site, kind: 'domain', ips: const ['203.0.113.5', '203.0.113.6']);

  MarcoGroup get _group => MarcoGroup(
    id: 'group-1',
    name: 'Wards',
    description: 'Ward devices',
    color: 'teal',
    icon: 'medical',
    policy: policy,
    members: const [_tablet],
    createdAt: DateTime(2026, 1, 1),
  );

  @override
  Future<MarcoGroupsResult> listGroups() async => MarcoGroupsResult(groups: empty ? const [] : [_group], dryRun: true);

  @override
  Future<List<MarcoPlatform>> listPlatforms() async => const [MarcoPlatform(key: 'youtube', label: 'YouTube')];

  @override
  Future<MarcoGroup> createGroup({required String name, String? description, required String color, required String icon, Map<String, dynamic>? policy}) async {
    calls.add('create:$name');
    createdPolicy = policy;
    return _group;
  }

  @override
  Future<MarcoActionResult> updatePolicy(String groupId, Map<String, dynamic> p) async {
    savedPolicy = p;
    policy = p;
    return const MarcoActionResult(dryRun: true, message: 'saved');
  }

  @override
  Future<MarcoActionResult> addMembers(String groupId, List<String> macAddresses) async {
    addedMacs = macAddresses;
    return const MarcoActionResult(dryRun: true, message: 'added');
  }

  @override
  Future<MarcoGroupDetails> details(String groupId) async => MarcoGroupDetails(
    group: _group,
    dryRun: true,
    onlineCount: 1,
    todayBytes: 1500000000,
    summary: const ['Speed is limited: 10 Mbps download, 5 Mbps upload'],
    members: [
      MarcoMemberDetail(
        deviceId: 'd1',
        mac: 'AA:BB:CC:DD:EE:01',
        name: 'Ward tablet',
        kind: 'tablet',
        ip: '172.16.0.20',
        online: true,
        todayBytes: 1500000000,
        monthBytes: 9000000000,
        place: 'Ward 2',
        control: control == null ? null : MarcoDeviceControl(mac: 'AA:BB:CC:DD:EE:01', blocked: control!['blocked'] == true),
      ),
      const MarcoMemberDetail(deviceId: 'd2', mac: 'AA:BB:CC:DD:EE:02', name: 'New phone', kind: 'phone', enforced: false, notEnforcedReason: 'The router has not seen this device yet.'),
    ],
    sites: [
      for (final d in (policy['blocked_domains'] as List? ?? const []))
        MarcoSiteLine(target: '$d', kind: 'domain', label: '$d', status: d == 'shared.example' ? 'cannot' : 'blocked', detail: d == 'shared.example' ? 'Hosted on Cloudflare.' : '', addresses: 2),
    ],
    logs: [MarcoPolicyLog(action: 'policy_applied', message: 'Policy applied to group "Wards"', status: 'saved', createdAt: DateTime.now().subtract(const Duration(minutes: 5)))],
  );

  @override
  Future<MarcoCatalog> catalog() async => const MarcoCatalog(
    platforms: [MarcoPlatform(key: 'youtube', label: 'YouTube'), MarcoPlatform(key: 'facebook', label: 'Facebook')],
    packs: [
      MarcoPack(key: 'games', label: 'Games', description: 'Game stores and online games.', icon: 'sports_esports', platforms: ['steam'], domains: ['roblox.com', 'minecraft.net']),
      MarcoPack(key: 'social', label: 'Social media', description: 'Facebook, Instagram, TikTok.', icon: 'groups', platforms: ['facebook'], domains: ['snapchat.com']),
    ],
    allowedDefaults: ['www.googleapis.com', 'translate.google.com'],
    allowedCustom: [],
  );

  @override
  Future<MarcoSiteCheck> checkSite(String site) async => checker(site);

  @override
  Future<List<MarcoDeviceControl>> overrides() async => const [];

  @override
  Future<MarcoActionResult> setDeviceControl(String mac, {required bool blocked, double? downloadMbps, double? uploadMbps, String reason = ''}) async {
    control = {'mac': mac, 'blocked': blocked, 'down': downloadMbps, 'up': uploadMbps, 'reason': reason};
    return const MarcoActionResult(dryRun: true, message: 'saved');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

class _FakeMap implements NetworkMapRemoteDataSource {
  @override
  Future<NetworkMapData> fetch({bool refresh = false}) async => NetworkMapData(
    available: true,
    devices: const [
      MapDevice(id: 'a', name: 'Ward tablet', ip: '172.16.0.20', mac: 'AA:BB:CC:DD:EE:01', kind: 'tablet', online: true, status: 'online'),
      MapDevice(id: 'b', name: 'Nurse PC', ip: '172.16.0.21', mac: 'AA:BB:CC:DD:EE:03', kind: 'computer', online: true, status: 'online'),
      MapDevice(id: 'c', name: 'Reception phone', ip: '172.16.0.22', mac: 'AA:BB:CC:DD:EE:04', kind: 'phone', online: true, status: 'online'),
    ],
    summary: const MapSummary(total: 3, online: 3, byKind: {'tablet': 1, 'computer': 1, 'phone': 1}),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, _FakeMarco remote, Widget home, {Size size = const Size(1200, 1000)}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        marcoRemoteProvider.overrideWithValue(remote),
        networkMapRemoteProvider.overrideWithValue(_FakeMap()),
        marcoStateServiceProvider.overrideWithValue(MarcoStateService(preferences)),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('groups overview', () {
    testWidgets('shows each group with its devices, rules and the safe mode notice', (tester) async {
      final remote = _FakeMarco(policy: const {'internet_enabled': false, 'unlimited_speed': false, 'download_limit_mbps': 10, 'upload_limit_mbps': 5, 'blocked_packs': ['games'], 'blocked_websites': ['youtube']});
      await _pump(tester, remote, const MarcoGroupsScreen());
      expect(find.text('Wards'), findsOneWidget);
      expect(find.text('Ward devices'), findsOneWidget);
      expect(find.text('1 online'), findsWidgets);
      expect(find.text('Internet off'), findsOneWidget);
      expect(find.text('10/5 Mbps'), findsOneWidget);
      expect(find.text('2 blocked'), findsOneWidget);
      expect(find.textContaining('Safe mode is on'), findsOneWidget);
    });

    testWidgets('a template creates a group with its rules already set', (tester) async {
      final remote = _FakeMarco(empty: true);
      await _pump(tester, remote, const MarcoGroupsScreen());
      expect(find.text('Make your first group'), findsOneWidget);
      await tester.tap(find.text('Guests'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Guests'), findsOneWidget); // the name is filled in
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(remote.calls, ['create:Guests']);
      expect(remote.createdPolicy?['download_limit_mbps'], 10);
      expect(remote.createdPolicy?['blocked_packs'], ['games', 'torrents', 'vpn']);
    });

    testWidgets('a group needs a name', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupsScreen());
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Give the group a name'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Group name'), 'wards');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.text('A group with this name already exists'), findsOneWidget);
      expect(remote.calls, isEmpty);
    });
  });

  group('group details', () {
    testWidgets('shows the group, its devices and the state of each', (tester) async {
      final remote = _FakeMarco(policy: const {'internet_enabled': true, 'unlimited_speed': false, 'download_limit_mbps': 10, 'upload_limit_mbps': 5});
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      expect(find.text('Wards'), findsWidgets);
      expect(find.text('2 devices'), findsOneWidget);
      expect(find.text('1 online'), findsOneWidget);
      expect(find.text('1.50 GB today'), findsOneWidget);
      expect(find.textContaining('Speed is limited'), findsOneWidget);
      expect(find.text('Ward tablet'), findsOneWidget);
      expect(find.text('Tablet · 172.16.0.20 · Ward 2'), findsOneWidget);
      expect(find.text('Not seen yet'), findsOneWidget);
      expect(find.textContaining('Safe mode'), findsOneWidget);
    });

    testWidgets('a device opens its details and can be blocked', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Ward tablet'));
      await tester.pumpAndSettle();
      expect(find.text('172.16.0.20'), findsWidgets);
      expect(find.text('AA:BB:CC:DD:EE:01'), findsWidgets);
      expect(find.text('Used today'), findsOneWidget);
      expect(find.text('Move to group'), findsNothing); // it is the only group

      await tester.tap(find.text('Block or limit speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Block internet for this device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(remote.control?['blocked'], true);
      expect(remote.control?['mac'], 'AA:BB:CC:DD:EE:01');
    });

    testWidgets('a speed limit needs a number', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Ward tablet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block or limit speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Limit speed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Type a download or upload speed'), findsOneWidget);
      expect(remote.control, isNull);
      await tester.tap(find.text('5 Mbps'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(remote.control?['down'], 5.0);
      expect(remote.control?['up'], 2.5);
    });

    testWidgets('devices are picked from the ones the router sees', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Add devices').first);
      await tester.pumpAndSettle();
      expect(find.text('Add devices to Wards'), findsOneWidget);
      expect(find.text('Nurse PC'), findsOneWidget);
      expect(find.text('In this group'), findsOneWidget);
      await tester.tap(find.text('Nurse PC'));
      await tester.tap(find.text('Reception phone'));
      await tester.pump();
      expect(find.text('Add 2 devices'), findsOneWidget);
      await tester.tap(find.text('Add 2 devices'));
      await tester.pumpAndSettle();
      expect(remote.addedMacs, ['AA:BB:CC:DD:EE:03', 'AA:BB:CC:DD:EE:04']);
    });

    testWidgets('a device can also be added by its MAC address', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Add devices').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add by MAC address'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'AA:BB:CC:DD:EE:FF'), 'nonsense');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      expect(find.text('Use the form AA:BB:CC:DD:EE:FF'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'AA:BB:CC:DD:EE:FF'), 'aa-bb-cc-dd-ee-09');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pump();
      await tester.tap(find.text('Add 1 device'));
      await tester.pumpAndSettle();
      expect(remote.addedMacs, ['AA:BB:CC:DD:EE:09']);
    });

    testWidgets('rules are saved from the Rules tab', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Rules'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsNothing); // nothing changed yet
      await tester.tap(find.widgetWithText(SwitchListTile, 'Limit the speed of each device'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Download (Mbps)'), '12');
      await tester.pump();
      expect(find.text('You changed the rules. Save to apply them.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(remote.savedPolicy?['unlimited_speed'], false);
      expect(remote.savedPolicy?['download_limit_mbps'], 12.0);
      expect(remote.savedPolicy?['internet_enabled'], true);
    });

    testWidgets('an empty speed limit is refused with a reason', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Rules'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Limit the speed of each device'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Type a download or upload speed'), findsOneWidget);
      expect(remote.savedPolicy, isNull);
    });

    testWidgets('packs and your own sites are blocked from the Websites tab', (tester) async {
      final remote = _FakeMarco()..checker = ((site) => const MarcoSiteCheck(target: 'example.com', kind: 'domain', ips: ['203.0.113.5', '203.0.113.6']));
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.textContaining('Websites'));
      await tester.pumpAndSettle();
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('Always allowed websites'), findsOneWidget);

      await tester.tap(find.text('Games'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Website to block'), 'https://www.Example.com/page');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(find.textContaining('points to 2 addresses and can be blocked'), findsOneWidget);
      await tester.tap(find.text('Add to blocked sites'));
      await tester.pump();
      expect(find.text('You changed the blocked sites. Save to apply them.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(remote.savedPolicy?['blocked_packs'], ['games']);
      expect(remote.savedPolicy?['blocked_domains'], ['example.com']); // the server's cleaned-up name, not what was typed
    });

    testWidgets('a site that cannot be blocked says why and is not added', (tester) async {
      final remote = _FakeMarco()
        ..checker = ((site) => MarcoSiteCheck(target: site, kind: 'domain', sharedProvider: 'Cloudflare', shared: const ['104.16.1.1'], error: 'hosted on Cloudflare, shared with thousands of other sites, so it cannot be blocked by address without breaking them'));
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.textContaining('Websites'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Website to block'), 'shared.example');
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
      expect(find.textContaining('hosted on Cloudflare'), findsOneWidget);
      expect(find.text('Add to blocked sites'), findsNothing);
    });

    testWidgets('sites already blocked show how well each one is blocked', (tester) async {
      final remote = _FakeMarco(policy: const {'blocked_domains': ['good.example', 'shared.example']});
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.textContaining('Websites'));
      await tester.pumpAndSettle();
      expect(find.text('good.example'), findsOneWidget);
      expect(find.text('Cannot block'), findsOneWidget);
      expect(find.text('Hosted on Cloudflare.'), findsOneWidget);
    });

    testWidgets('the Activity tab lists what happened', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'));
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();
      expect(find.text('Policy applied to group "Wards"'), findsOneWidget);
      expect(find.textContaining('saved, router not changed'), findsOneWidget);
    });

    testWidgets('fits a narrow window without overflow', (tester) async {
      final remote = _FakeMarco();
      await _pump(tester, remote, const MarcoGroupDetailScreen(groupId: 'group-1'), size: const Size(460, 900));
      expect(tester.takeException(), isNull);
      for (final tab in ['Rules', 'Websites', 'Activity']) {
        await tester.tap(find.textContaining(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  });
}

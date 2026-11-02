import 'package:flutter/material.dart';
import '../../../../data/models/marco_models.dart';

/// Colors a group can have. The name is what is stored.
const marcoColorNames = ['blue', 'green', 'teal', 'orange', 'red', 'purple', 'pink', 'indigo', 'brown', 'grey'];

Color marcoColor(String name) {
  switch (name) {
    case 'green':
      return Colors.green;
    case 'orange':
      return Colors.orange;
    case 'red':
      return Colors.red;
    case 'purple':
      return Colors.purple;
    case 'teal':
      return Colors.teal;
    case 'pink':
      return Colors.pink;
    case 'indigo':
      return Colors.indigo;
    case 'brown':
      return Colors.brown;
    case 'grey':
      return Colors.blueGrey;
    default:
      return Colors.blue;
  }
}

/// Icons a group can have. The name is what is stored.
const marcoIconNames = ['group', 'medical', 'device', 'school', 'guests', 'office', 'lab', 'camera', 'phone', 'shield'];

IconData marcoIcon(String name) {
  switch (name) {
    case 'device':
      return Icons.devices;
    case 'school':
      return Icons.school;
    case 'medical':
      return Icons.medical_services;
    case 'guests':
      return Icons.person_outline;
    case 'office':
      return Icons.business_center_outlined;
    case 'lab':
      return Icons.science_outlined;
    case 'camera':
      return Icons.videocam_outlined;
    case 'phone':
      return Icons.smartphone;
    case 'shield':
      return Icons.shield_outlined;
    default:
      return Icons.group;
  }
}

String marcoIconLabel(String name) => switch (name) {
  'device' => 'Devices',
  'school' => 'Training',
  'medical' => 'Medical',
  'guests' => 'Guests',
  'office' => 'Office',
  'lab' => 'Lab',
  'camera' => 'Cameras',
  'phone' => 'Phones',
  'shield' => 'Protected',
  _ => 'Group',
};

/// A starting point for a new group: rules that are usually wanted, so a group can
/// be useful in two clicks.
class GroupTemplate {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final String color;
  final String groupIcon;
  final Map<String, dynamic> policy;

  const GroupTemplate({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.groupIcon,
    this.policy = const {},
  });
}

const groupTemplates = <GroupTemplate>[
  GroupTemplate(
    key: 'blank',
    label: 'Empty group',
    description: 'No rules yet. Add them afterwards.',
    icon: Icons.add_box_outlined,
    color: 'blue',
    groupIcon: 'group',
  ),
  GroupTemplate(
    key: 'guests',
    label: 'Guests',
    description: 'Slower internet, no games, torrents or VPN sites.',
    icon: Icons.person_outline,
    color: 'orange',
    groupIcon: 'guests',
    policy: {
      'unlimited_speed': false,
      'download_limit_mbps': 10,
      'upload_limit_mbps': 5,
      'blocked_packs': ['games', 'torrents', 'vpn'],
    },
  ),
  GroupTemplate(
    key: 'work',
    label: 'Work only',
    description: 'Blocks social media, games, video and music.',
    icon: Icons.business_center_outlined,
    color: 'teal',
    groupIcon: 'office',
    policy: {
      'blocked_packs': ['social', 'games', 'video', 'music'],
    },
  ),
  GroupTemplate(
    key: 'no_internet',
    label: 'No internet',
    description: 'Devices stay on the network but cannot reach the internet.',
    icon: Icons.wifi_off,
    color: 'red',
    groupIcon: 'shield',
    policy: {'internet_enabled': false},
  ),
];

/// The rules of a group as short labels for its card.
List<({IconData icon, String label})> policyBadges(Map<String, dynamic> p) {
  final out = <({IconData icon, String label})>[];
  if (p['internet_enabled'] == false) out.add((icon: Icons.wifi_off, label: 'Internet off'));
  if (p['unlimited_speed'] == false && (p['download_limit_mbps'] != null || p['upload_limit_mbps'] != null)) {
    String n(Object? v) => v == null ? '–' : (v is num && v == v.roundToDouble() ? '${v.toInt()}' : '$v');
    out.add((icon: Icons.speed, label: '${n(p['download_limit_mbps'])}/${n(p['upload_limit_mbps'])} Mbps'));
  }
  if (p['schedule_start_time'] != null && p['schedule_end_time'] != null) {
    out.add((icon: Icons.schedule, label: 'Off ${p['schedule_start_time']}–${p['schedule_end_time']}'));
  }
  if (p['daily_quota_gb'] != null || p['monthly_quota_gb'] != null) out.add((icon: Icons.data_usage, label: 'Data limit'));
  final sites = ((p['blocked_websites'] as List?)?.length ?? 0) + ((p['blocked_packs'] as List?)?.length ?? 0) + ((p['blocked_domains'] as List?)?.length ?? 0);
  if (sites > 0) out.add((icon: Icons.block, label: '$sites blocked'));
  return out;
}

/// Plain label of a device kind for group lists.
String groupMemberLabel(MarcoMember m) => m.label;

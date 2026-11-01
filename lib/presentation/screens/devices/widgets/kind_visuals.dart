import 'package:flutter/material.dart';

import '../../../../data/models/client_inventory_models.dart';

/// Icon for each kind of device. Always shown next to the kind's name, so the
/// icon is a hint and never the only signal.
IconData kindIcon(ClientKind kind) => switch (kind) {
      ClientKind.phone => Icons.smartphone,
      ClientKind.tablet => Icons.tablet_mac,
      ClientKind.computer => Icons.computer,
      ClientKind.printer => Icons.print_outlined,
      ClientKind.camera => Icons.videocam_outlined,
      ClientKind.tv => Icons.tv,
      ClientKind.network => Icons.router_outlined,
      ClientKind.server => Icons.dns_outlined,
      ClientKind.iot => Icons.sensors,
      ClientKind.medical => Icons.medical_services_outlined,
      ClientKind.unknown => Icons.device_unknown_outlined,
    };

/// Plural form for filter chips ("Phones", "Computers").
String kindPlural(ClientKind kind) => switch (kind) {
      ClientKind.phone => 'Phones',
      ClientKind.tablet => 'Tablets',
      ClientKind.computer => 'Computers',
      ClientKind.printer => 'Printers',
      ClientKind.camera => 'Cameras',
      ClientKind.tv => 'TVs',
      ClientKind.network => 'Network equipment',
      ClientKind.server => 'Servers',
      ClientKind.iot => 'Smart devices',
      ClientKind.medical => 'Medical devices',
      ClientKind.unknown => 'Unknown',
    };

/// How sure the detection is, in words.
String confidenceLabel(String confidence) => switch (confidence) {
      'high' => 'High confidence',
      'medium' => 'Medium confidence',
      'low' => 'Low confidence, a best guess',
      _ => 'Not identified',
    };

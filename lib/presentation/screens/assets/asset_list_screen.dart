import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/asset_providers.dart';
import '../../router/route_names.dart';

class AssetListScreen extends ConsumerWidget {
  const AssetListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Asset Inventory')),
      body: FutureBuilder(
        future: repo.getAssetDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Error loading assets'));
          }
          return result.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (details) {
              if (details.isEmpty) {
                return const Center(child: Text('No asset details yet'));
              }
              return ListView.builder(
                itemCount: details.length,
                itemBuilder: (context, index) {
                  final d = details[index];
                  return ListTile(
                    title: Text(d.deviceId),
                    subtitle: Text('${d.department ?? "No Dept"} | ${d.floorName ?? ""} ${d.room ?? ""}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteNames.assetDeviceDetail(d.deviceId)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AlertDetailScreen extends StatelessWidget {
  final String id;

  const AlertDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Details'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {},
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'acknowledge', child: Text('Acknowledge')),
              const PopupMenuItem(value: 'resolve', child: Text('Resolve')),
              const PopupMenuItem(value: 'suppress', child: Text('Suppress')),
            ],
          ),
        ],
      ),
      body: Center(
        child: Text('Alert ID: $id - Implementation pending'),
      ),
    );
  }
}

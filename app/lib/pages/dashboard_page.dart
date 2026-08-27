import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_provider.dart';
import '../providers/traffic_provider.dart';
import '../widgets/traffic_summary.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(coreVersionProvider);
    final traffic = ref.watch(trafficProvider);
    final settings = ref.watch(coreSettingsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Controller: ${settings.host}:${settings.port}'),
                  const SizedBox(height: 8),
                  version.when(
                    data: (v) => Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Text('mihomo $v'),
                      ],
                    ),
                    loading: () => const Text('Connecting...'),
                    error: (err, _) => Text('Not connected: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 8),
                  traffic.when(
                    data: (t) => TrafficSummary(traffic: t),
                    loading: () => const TrafficSummary(traffic: null),
                    error: (_, _) => const TrafficSummary(traffic: null),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

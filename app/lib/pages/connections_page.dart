import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connections_provider.dart';

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  double value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value < 10 && unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}';
}

class ConnectionsPage extends ConsumerWidget {
  const ConnectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(connectionsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connections', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: snapshotAsync.when(
              data: (snapshot) => snapshot.connections.isEmpty
                  ? const Center(child: Text('No active connections.'))
                  : ListView.separated(
                      itemCount: snapshot.connections.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final conn = snapshot.connections[index];
                        return ListTile(
                          title: Text(conn.metadata.displayTarget),
                          subtitle: Text('${conn.chains.join(' -> ')} · ${conn.rule}'),
                          trailing: Text('↑${_formatBytes(conn.upload)} ↓${_formatBytes(conn.download)}'),
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load connections: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

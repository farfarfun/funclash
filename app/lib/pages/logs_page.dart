import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/logs_provider.dart';

class LogsPage extends ConsumerWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(logsProvider);
    final controller = ref.read(logsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Logs', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(icon: const Icon(Icons.clear_all), onPressed: controller.clear),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: lines.isEmpty
                ? const Center(child: Text('No log output yet.'))
                : ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, index) => Text(
                      lines[index],
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

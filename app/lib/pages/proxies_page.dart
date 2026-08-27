import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proxy.dart';
import '../providers/proxies_provider.dart';
import '../widgets/proxy_card.dart';

class ProxiesPage extends ConsumerWidget {
  const ProxiesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proxiesAsync = ref.watch(proxiesProvider);
    final controller = ref.read(proxiesProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Proxies', style: Theme.of(context).textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.refresh(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: proxiesAsync.when(
              data: (proxies) => _ProxyGroups(proxies: proxies, controller: controller),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load proxies: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProxyGroups extends StatelessWidget {
  final Map<String, Proxy> proxies;
  final ProxiesController controller;

  const _ProxyGroups({required this.proxies, required this.controller});

  @override
  Widget build(BuildContext context) {
    final groups = proxies.values.where((p) => p.isGroup).toList();
    if (groups.isEmpty) {
      return const Center(child: Text('No proxy groups found.'));
    }
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return ExpansionTile(
          title: Text(group.name),
          subtitle: Text('${group.type} · now: ${group.now ?? '-'}'),
          children: group.all.map((memberName) {
            final member = proxies[memberName];
            return ProxyCard(
              proxy: member ?? Proxy(name: memberName, type: '?', udp: false, all: const [], history: const []),
              selected: group.now == memberName,
              onTap: () => controller.select(group.name, memberName),
              onTestDelay: () => controller.testDelay(memberName),
            );
          }).toList(),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../models/proxy.dart';
import 'latency_badge.dart';

class ProxyCard extends StatelessWidget {
  final Proxy proxy;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onTestDelay;

  const ProxyCard({
    super.key,
    required this.proxy,
    this.selected = false,
    this.onTap,
    this.onTestDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onTap,
        title: Text(proxy.name),
        subtitle: Text(proxy.type),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LatencyBadge(delayMs: proxy.latestDelay),
            IconButton(
              icon: const Icon(Icons.network_ping, size: 18),
              tooltip: 'Test latency',
              onPressed: onTestDelay,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/proxy.dart';
import 'core_provider.dart';

class ProxiesController extends AsyncNotifier<Map<String, Proxy>> {
  @override
  Future<Map<String, Proxy>> build() async {
    final client = ref.watch(mihomoApiClientProvider);
    return client.getProxies();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> select(String groupName, String proxyName) async {
    final client = ref.read(mihomoApiClientProvider);
    await client.selectProxy(groupName, proxyName);
    await refresh();
  }

  Future<int> testDelay(String proxyName) async {
    final client = ref.read(mihomoApiClientProvider);
    final delay = await client.testDelay(proxyName);
    await refresh();
    return delay;
  }
}

final proxiesProvider = AsyncNotifierProvider<ProxiesController, Map<String, Proxy>>(ProxiesController.new);

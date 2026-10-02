import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/traffic.dart';
import 'core_provider.dart';

/// `/traffic` 首次连接失败时返回错误；成功接收数据后的断线会自动重试。
final trafficProvider = StreamProvider.autoDispose<Traffic>((ref) async* {
  final client = ref.watch(mihomoApiClientProvider);
  var hasStreamedOnce = false;
  while (true) {
    try {
      await for (final traffic in client.watchTraffic()) {
        hasStreamedOnce = true;
        yield traffic;
      }
    } catch (_) {
      if (!hasStreamedOnce) rethrow;
    }
    await Future.delayed(const Duration(seconds: 2));
  }
});

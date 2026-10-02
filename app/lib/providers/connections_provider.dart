import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection.dart';
import 'core_provider.dart';

/// 每两秒轮询 `/connections`，用于更新连接面板。
///
/// 首次成功前的失败会作为错误返回；成功后发生的瞬时失败会自动重试，
/// `StreamProvider` 在轮询恢复前保留最后一次快照。
final connectionsProvider = StreamProvider.autoDispose<ConnectionsSnapshot>((ref) async* {
  final client = ref.watch(mihomoApiClientProvider);
  var hasLoadedOnce = false;
  while (true) {
    try {
      yield await client.getConnections();
      hasLoadedOnce = true;
    } catch (_) {
      if (!hasLoadedOnce) rethrow;
    }
    await Future.delayed(const Duration(seconds: 2));
  }
});

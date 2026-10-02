import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/mihomo_api_client.dart';
import 'core_provider.dart';

const _maxLogLines = 500;
const _reconnectDelay = Duration(seconds: 2);

/// `/logs` WebSocket 断开后自动重连，避免日志视图停滞。
class LogsController extends Notifier<List<String>> {
  StreamSubscription<String>? _subscription;
  bool _disposed = false;

  @override
  List<String> build() {
    final client = ref.watch(mihomoApiClientProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _subscription?.cancel();
    });
    _connect(client);
    return const [];
  }

  void _connect(MihomoApiClient client) {
    _subscription?.cancel();
    _subscription = client.watchLogs().listen(
          (line) {
            final next = [...state, line];
            state = next.length > _maxLogLines ? next.sublist(next.length - _maxLogLines) : next;
          },
          onError: (_) => _scheduleReconnect(client),
          onDone: () => _scheduleReconnect(client),
        );
  }

  void _scheduleReconnect(MihomoApiClient client) {
    if (_disposed) return;
    Future.delayed(_reconnectDelay, () {
      if (_disposed) return;
      _connect(client);
    });
  }

  void clear() => state = const [];
}

final logsProvider = NotifierProvider<LogsController, List<String>>(LogsController.new);

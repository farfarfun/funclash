import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_provider.dart';

const _maxLogLines = 500;

class LogsController extends Notifier<List<String>> {
  StreamSubscription<String>? _subscription;

  @override
  List<String> build() {
    final client = ref.watch(mihomoApiClientProvider);
    _subscription?.cancel();
    _subscription = client.watchLogs().listen(
          (line) {
            final next = [...state, line];
            state = next.length > _maxLogLines ? next.sublist(next.length - _maxLogLines) : next;
          },
          onError: (_) {},
        );
    ref.onDispose(() => _subscription?.cancel());
    return const [];
  }

  void clear() => state = const [];
}

final logsProvider = NotifierProvider<LogsController, List<String>>(LogsController.new);

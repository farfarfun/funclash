import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/traffic.dart';
import 'core_provider.dart';

/// As with [connectionsProvider], only the first connection attempt
/// surfaces as an error; once the `/traffic` WebSocket has streamed at
/// least once, a later drop (e.g. the core being restarted from the
/// Settings page) is retried instead of leaving the dashboard stuck on a
/// stale error.
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

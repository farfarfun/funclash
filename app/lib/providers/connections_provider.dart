import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection.dart';
import 'core_provider.dart';

/// Polls `/connections` every couple seconds. Simpler than mihomo's
/// WebSocket push for this, and just as usable for a dashboard view.
///
/// A poll failure only surfaces as an error before the first successful
/// poll (e.g. the core isn't running yet). Once connections have loaded at
/// least once, later transient failures — such as the core being
/// restarted from the Settings page — are swallowed and retried instead of
/// collapsing the page to a permanent error screen: the `StreamProvider`
/// simply keeps its last snapshot until polling recovers.
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

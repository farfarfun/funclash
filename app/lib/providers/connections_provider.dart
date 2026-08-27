import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/connection.dart';
import 'core_provider.dart';

/// Polls `/connections` every couple seconds. Simpler than mihomo's
/// WebSocket push for this, and just as usable for a dashboard view.
final connectionsProvider = StreamProvider.autoDispose<ConnectionsSnapshot>((ref) async* {
  final client = ref.watch(mihomoApiClientProvider);
  while (true) {
    yield await client.getConnections();
    await Future.delayed(const Duration(seconds: 2));
  }
});

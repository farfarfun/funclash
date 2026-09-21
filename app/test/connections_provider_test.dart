import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclash_app/core/mihomo_api_client.dart';
import 'package:funclash_app/models/connection.dart';
import 'package:funclash_app/providers/connections_provider.dart';
import 'package:funclash_app/providers/core_provider.dart';

/// Fails every second call, succeeds otherwise — simulates the core briefly
/// dropping `/connections` (e.g. a restart triggered from the Settings page).
class _FlakyClient extends MihomoApiClient {
  int calls = 0;
  _FlakyClient() : super(const MihomoEndpoint(host: 'unused'));

  @override
  Future<ConnectionsSnapshot> getConnections() async {
    calls++;
    if (calls == 2) throw MihomoApiException('transient failure');
    return ConnectionsSnapshot(downloadTotal: calls, uploadTotal: 0, connections: const []);
  }
}

void main() {
  test(
    'a transient poll failure after the first success does not surface as an error',
    () async {
      final client = _FlakyClient();
      final container = ProviderContainer(
        overrides: [mihomoApiClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final seenErrors = [];
      final sub = container.listen(connectionsProvider, (previous, next) {
        next.whenOrNull(error: (err, _) => seenErrors.add(err));
      });
      addTearDown(sub.close);

      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return client.calls < 1;
      });
      expect(container.read(connectionsProvider).value?.downloadTotal, 1);

      // Wait through the failing 2nd poll and a successful 3rd one.
      await Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return client.calls < 3;
      });

      expect(seenErrors, isEmpty);
      expect(container.read(connectionsProvider).value?.downloadTotal, 3);
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}

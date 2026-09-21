import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclash_app/core/mihomo_api_client.dart';
import 'package:funclash_app/providers/core_provider.dart';
import 'package:funclash_app/providers/logs_provider.dart';

/// Hands out a fresh `StreamController` per `watchLogs()` call so a test can
/// simulate the WebSocket dropping (`breakConnection`) and later reconnecting.
class _FlakyLogsClient extends MihomoApiClient {
  int connectCount = 0;
  StreamController<String>? _controller;

  _FlakyLogsClient() : super(const MihomoEndpoint(host: 'unused'));

  @override
  Stream<String> watchLogs({String level = 'info'}) {
    connectCount++;
    _controller = StreamController<String>();
    return _controller!.stream;
  }

  void emit(String line) => _controller?.add(line);

  void breakConnection() => _controller?.close();
}

void main() {
  test('a dropped /logs WebSocket is reconnected automatically', () async {
    final client = _FlakyLogsClient();
    final container = ProviderContainer(
      overrides: [mihomoApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    container.listen(logsProvider, (_, _) {});
    expect(client.connectCount, 1);

    client.emit('booted');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(container.read(logsProvider), contains('booted'));

    client.breakConnection();
    await Future.delayed(const Duration(seconds: 3));
    expect(client.connectCount, 2);

    client.emit('reconnected');
    await Future.delayed(const Duration(milliseconds: 50));
    expect(container.read(logsProvider), contains('reconnected'));
  }, timeout: const Timeout(Duration(seconds: 15)));
}

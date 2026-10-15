import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/constant.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_address.dart';
import 'package:funclash/remote/panel_core_bridge.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_dialer_native.dart';
import 'package:funclash/remote/panel_linker.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_server_native.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';

import 'fakes.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';
const _config = {'currentProfileId': 'abc'};
const _usable = PanelSettings(enabled: true, token: _token, port: 0);

Future<PanelServer> _host({FakeCore? core}) async {
  final server = PanelServer(config: () => _config);
  addTearDown(server.dispose);
  if (core != null) {
    final bridge = PanelCoreBridge(core: core);
    server.sessions.listen(bridge.attach);
  }
  await server.start(_usable);
  return server;
}

/// The page a panel would have been served on by that host.
Uri _pageOf(PanelServer server, {String token = _token}) => Uri(
  scheme: 'http',
  host: localhost,
  port: server.address!.port,
  path: '/',
  fragment: 'token=$token',
);

void main() {
  group('bridgeBeside', () {
    test('is the bridge path on the page own host and port', () {
      expect(
        bridgeBeside(Uri.parse('http://127.0.0.1:47891/?a=b#token=t')),
        Uri.parse('ws://127.0.0.1:47891$panelBridgePath'),
      );
    });

    test('keeps a secure page on a secure socket', () {
      expect(
        bridgeBeside(Uri.parse('https://panel.example/app')).scheme,
        'wss',
      );
      expect(bridgeBeside(Uri.parse('http://panel.example/app')).scheme, 'ws');
    });

    test('leaves the default port to the scheme', () {
      expect(bridgeBeside(Uri.parse('http://panel.example')).hasPort, isFalse);
    });
  });

  group('tokenInFragment', () {
    test('reads the token a host put in the fragment', () {
      expect(tokenInFragment('token=abc'), 'abc');
      expect(tokenInFragment('other=1&token=abc'), 'abc');
    });

    test('reads nothing out of a fragment without one', () {
      for (final fragment in ['', 'other=1', 'token', 'notatoken']) {
        expect(tokenInFragment(fragment), isEmpty, reason: fragment);
      }
    });
  });

  group('PanelLinker', () {
    test('links a panel to the host that served its page', () async {
      final server = await _host();
      final client = PanelCoreClient();
      addTearDown(client.unbind);

      final result = await PanelLinker(
        client,
        dial: dialPanel,
        page: _pageOf(server),
      ).link();

      expect(result, isA<PanelLinked>());
      expect((result as PanelLinked).config, _config);
      expect(client.isLinked, isTrue);
    });

    test('dials nothing when the page carries no token', () async {
      final client = PanelCoreClient();

      final result = await PanelLinker(
        client,
        dial: (_) => throw StateError('should not dial'),
        page: Uri.parse('http://127.0.0.1:1/'),
      ).link();

      expect((result as PanelRefused).reason, PanelRejectReason.badToken);
      expect(client.isLinked, isFalse);
    });

    test('reports the host refusal and leaves the client unlinked', () async {
      final server = await _host();
      final client = PanelCoreClient();

      final result = await PanelLinker(
        client,
        dial: dialPanel,
        page: _pageOf(server, token: 'wrong'),
      ).link();

      expect((result as PanelRefused).reason, PanelRejectReason.badToken);
      expect(client.isLinked, isFalse);
    });

    test('carries a Core call the whole way and back', () async {
      final core = FakeCore(answer: (method, arguments) => 'from $method');
      final server = await _host(core: core);
      final client = PanelCoreClient();
      addTearDown(client.unbind);
      await PanelLinker(client, dial: dialPanel, page: _pageOf(server)).link();

      final answer = await client.invokeMethod<Object>(
        method: CoreMethod.getTraffic,
        arguments: {'q': 1},
      );

      expect(answer, 'from CoreMethod.getTraffic');
      expect(core.lastArguments, {'q': 1});
    });

    test('a refused method travels back as the host wrote it', () async {
      final core = FakeCore();
      final server = await _host(core: core);
      final client = PanelCoreClient();
      addTearDown(client.unbind);
      await PanelLinker(client, dial: dialPanel, page: _pageOf(server)).link();

      await expectLater(
        client.invokeMethod<Object>(method: CoreMethod.shutdown),
        throwsA(
          isA<CoreMethodException>().having(
            (failure) => failure.code,
            'code',
            'panel_method_refused',
          ),
        ),
      );
      expect(core.calls, isEmpty);
    });

    test('a call in flight fails when the host stops', () async {
      final server = await _host(core: FakeCore(hold: true));
      final client = PanelCoreClient();
      addTearDown(client.unbind);
      await PanelLinker(client, dial: dialPanel, page: _pageOf(server)).link();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.getTraffic,
      );
      final failure = expectLater(
        pending,
        throwsA(
          isA<CoreMethodException>().having(
            (thrown) => thrown.code,
            'code',
            'transport_disconnected',
          ),
        ),
      );
      await server.stop();

      await failure;
      expect(client.isLinked, isFalse);
    });
  });
}

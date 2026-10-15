import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/constant.dart';
import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';
const _config = {'currentProfileId': 'abc'};

/// Port zero so the operating system picks one no other test is holding.
const _usable = PanelSettings(enabled: true, token: _token, port: 0);

final class _Store {
  PanelSettings? settings;

  Future<PanelSettings?> read() async => settings;

  Future<void> write(PanelSettings value) async {
    settings = value;
  }
}

PanelHost _host(_Store store, {List<PanelChannelHandler> handlers = const []}) {
  final host = PanelHost(
    handlers: handlers,
    readSettings: store.read,
    writeSettings: store.write,
  );
  addTearDown(host.shutdown);
  return host;
}

final class _RecordingHandler implements PanelChannelHandler {
  final sessions = <PanelSession>[];

  @override
  void attach(PanelSession session) => sessions.add(session);
}

Future<void> _greet(PanelHost host) async {
  final socket = await WebSocket.connect(
    'ws://$localhost:${host.address!.port}$panelBridgePath',
  );
  addTearDown(socket.close);
  socket.add(
    json.encode(
      const PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
    ),
  );
  await socket.first;
  await pumpEventQueue();
}

void main() {
  group('PanelHost', () {
    test('stores a token the first time, with the bridge still off', () async {
      final store = _Store();
      final host = _host(store);

      await host.load(config: () => _config);

      expect(store.settings?.token, isNotEmpty);
      expect(store.settings?.enabled, isFalse);
      expect(host.settings, store.settings);
      expect(host.isRunning, isFalse);
      expect(host.address, isNull);
    });

    test('keeps the token it stored across a load', () async {
      final store = _Store();

      await _host(store).load(config: () => _config);
      final first = store.settings;
      await _host(store).load(config: () => _config);

      expect(store.settings, first);
    });

    test('starts the bridge the stored settings asked for', () async {
      final store = _Store()..settings = _usable;
      final host = _host(store);

      await host.load(config: () => _config);

      expect(host.isRunning, isTrue);
      expect(host.address?.host, localhost);
      expect(host.settings, _usable);
    });

    test('starts nothing for stored settings that are off', () async {
      final store = _Store()..settings = _usable.copyWith(enabled: false);
      final host = _host(store);

      await host.load(config: () => _config);

      expect(host.isRunning, isFalse);
    });

    test('applying settings stores them and binds', () async {
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);

      await host.apply(_usable.copyWith(allowLan: true));

      expect(host.isRunning, isTrue);
      expect(host.address?.host, anyAddress);
      expect(store.settings?.allowLan, isTrue);
    });

    test('gives up the port when the settings turn it off', () async {
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);
      await host.apply(_usable);
      final port = host.address!.port;

      await host.apply(_usable.copyWith(enabled: false));

      expect(host.isRunning, isFalse);
      expect(host.address, isNull);
      expect(store.settings?.enabled, isFalse);
      await expectLater(
        Socket.connect(localhost, port, timeout: const Duration(seconds: 2)),
        throwsA(isA<SocketException>()),
      );
    });

    test('converges on the last settings it was handed', () async {
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);

      await Future.wait([
        host.apply(_usable),
        host.apply(_usable.copyWith(allowLan: true)),
      ]);

      expect(host.isRunning, isTrue);
      expect(host.address?.host, anyAddress);
      expect(host.settings.allowLan, isTrue);
      expect(store.settings?.allowLan, isTrue);
    });

    test('reports a port it cannot have rather than throwing', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(blocker.close);
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);

      await host.apply(_usable.copyWith(port: blocker.port));

      expect(host.isRunning, isFalse);
      expect(host.settings.port, blocker.port);
    });

    test('a shutdown leaves the stored settings saying on', () async {
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);
      await host.apply(_usable);

      await host.shutdown();

      expect(host.isRunning, isFalse);
      expect(host.address, isNull);
      expect(store.settings, _usable);
      expect(host.settings, _usable);
    });

    test('never comes back up after a shutdown', () async {
      final store = _Store();
      final host = _host(store);
      await host.load(config: () => _config);
      await host.shutdown();

      await host.apply(_usable);
      await host.load(config: () => _config);

      expect(host.isRunning, isFalse);
      expect(store.settings?.enabled, isFalse);
    });

    test('hands every session that arrives to every handler', () async {
      final first = _RecordingHandler();
      final second = _RecordingHandler();
      final host = _host(
        _Store()..settings = _usable,
        handlers: [first, second],
      );
      await host.load(config: () => _config);

      await _greet(host);

      expect(first.sessions, hasLength(1));
      expect(second.sessions.single, same(first.sessions.single));
    });

    test('hands a handler nothing once the bridge is down', () async {
      final handler = _RecordingHandler();
      final host = _host(_Store()..settings = _usable, handlers: [handler]);
      await host.load(config: () => _config);
      final port = host.address!.port;

      await host.shutdown();

      expect(handler.sessions, isEmpty);
      await expectLater(
        WebSocket.connect('ws://$localhost:$port$panelBridgePath'),
        throwsA(isA<Exception>()),
      );
    });

    test('a load that lands after a shutdown starts nothing', () async {
      final gate = Completer<PanelSettings?>();
      final host = PanelHost(
        readSettings: () => gate.future,
        writeSettings: (_) async {},
      );

      final loading = host.load(config: () => _config);
      await host.shutdown();
      gate.complete(_usable);
      await loading;

      expect(host.isRunning, isFalse);
      expect(host.address, isNull);
    });

    test('shutting down twice is not an error', () async {
      final host = _host(_Store());

      await host.shutdown();
      await host.shutdown();
    });
  });
}

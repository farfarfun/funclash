import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_config_bridge.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';

Config _config({int? profileId, bool openLogs = false}) => Config(
  themeProps: const ThemeProps(),
  currentProfileId: profileId,
  appSettingProps: AppSettingProps(openLogs: openLogs),
);

final class _FakeSocket implements PanelSocket {
  final _incoming = StreamController<String>();
  final sent = <Object?>[];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) => sent.add(json.decode(message));

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }

  void receive(Object? message) => _incoming.add(json.encode(message));

  void offer(Config config) =>
      receive(PanelFrame(PanelChannel.config, config.toJson()).toJson());

  Iterable<Config> get pushed => sent
      .map(PanelFrame.fromJson)
      .nonNulls
      .where((frame) => frame.channel == PanelChannel.config)
      .map(
        (frame) => Config.realFromJson(
          (frame.payload! as Map).cast<String, Object?>(),
        ),
      );
}

Future<PanelSession> _session(_FakeSocket socket) async {
  socket.receive(
    const PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await acceptPanel(socket, token: _token, config: const {});
  addTearDown(session!.close);
  return session;
}

void main() {
  group('PanelConfigBridge', () {
    test('pushes to every panel it holds', () async {
      final first = _FakeSocket();
      final second = _FakeSocket();
      final bridge = PanelConfigBridge();
      addTearDown(bridge.dispose);
      bridge.attach(await _session(first));
      bridge.attach(await _session(second));

      bridge.push(_config(openLogs: true));

      expect(first.pushed.single.appSettingProps.openLogs, isTrue);
      expect(second.pushed.single.appSettingProps.openLogs, isTrue);
    });

    test('reports what a panel writes back', () async {
      final socket = _FakeSocket();
      final bridge = PanelConfigBridge();
      addTearDown(bridge.dispose);
      bridge.attach(await _session(socket));
      final written = bridge.writes.first;

      socket.offer(_config(profileId: 7));

      expect((await written).currentProfileId, 7);
    });

    test('reads nothing out of a frame that is not a config', () async {
      final socket = _FakeSocket();
      final bridge = PanelConfigBridge();
      addTearDown(bridge.dispose);
      bridge.attach(await _session(socket));
      final seen = <Config>[];
      final watching = bridge.writes.listen(seen.add);
      addTearDown(watching.cancel);

      socket.receive(const PanelFrame(PanelChannel.config, 'text').toJson());
      await pumpEventQueue();

      expect(seen, isEmpty);
    });

    test('stops pushing to a panel that has gone', () async {
      final staying = _FakeSocket();
      final leaving = _FakeSocket();
      final bridge = PanelConfigBridge();
      addTearDown(bridge.dispose);
      bridge.attach(await _session(staying));
      final gone = await _session(leaving);
      bridge.attach(gone);

      await gone.close();
      await pumpEventQueue();
      bridge.push(_config(openLogs: true));

      expect(leaving.pushed, isEmpty);
      expect(staying.pushed, hasLength(1));
    });
  });

  group('PanelConfigClient', () {
    test('applies what the host sends', () async {
      final socket = _FakeSocket();
      final client = PanelConfigClient();
      final applied = <Config>[];
      client.bind(await _session(socket), apply: applied.add);

      socket.offer(_config(profileId: 3));
      await pumpEventQueue();

      expect(applied.single.currentProfileId, 3);
    });

    test('never echoes back what the host just sent', () async {
      final socket = _FakeSocket();
      final session = await _session(socket);
      final client = PanelConfigClient();
      late Config applied;
      client.bind(session, apply: (config) => applied = config);

      socket.offer(_config(openLogs: true));
      await pumpEventQueue();
      client.push(session, applied);

      expect(socket.pushed, isEmpty);
    });

    test('sends a change the panel made itself', () async {
      final socket = _FakeSocket();
      final session = await _session(socket);
      final client = PanelConfigClient();
      client.bind(session, apply: (_) {});

      socket.offer(_config(openLogs: true));
      await pumpEventQueue();
      client.push(session, _config(openLogs: false));

      expect(socket.pushed.single.appSettingProps.openLogs, isFalse);
    });

    test('sends anything at all before the host has spoken', () async {
      final socket = _FakeSocket();
      final session = await _session(socket);
      final client = PanelConfigClient();
      client.bind(session, apply: (_) {});

      client.push(session, _config(openLogs: true));

      expect(socket.pushed, hasLength(1));
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_event_bridge.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';

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

  Iterable<Object?> get pushed => sent
      .map(PanelFrame.fromJson)
      .nonNulls
      .where((frame) => frame.channel == PanelChannel.core)
      .map((frame) => PanelEvent.fromJson(frame.payload))
      .nonNulls
      .map((event) => event.data);
}

Future<PanelSession> _session(_FakeSocket socket) async {
  socket.receive(
    PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await acceptPanel(socket, token: _token, config: const {});
  addTearDown(session!.close);
  return session;
}

void main() {
  group('PanelEventBridge', () {
    late StreamController<CoreEvent> events;

    setUp(() => events = StreamController<CoreEvent>.broadcast());
    tearDown(() => events.close());

    test('pushes an event to the panel as the Core reported it', () async {
      final socket = _FakeSocket();
      PanelEventBridge(events: events.stream).attach(await _session(socket));

      events.add(const CoreEvent(type: CoreEventType.loaded, data: 'p'));
      await pumpEventQueue();

      expect(socket.pushed, [
        {'type': 'loaded', 'data': 'p'},
      ]);
    });

    test('pushes every event in the order they were reported', () async {
      final socket = _FakeSocket();
      PanelEventBridge(events: events.stream).attach(await _session(socket));

      for (final name in ['a', 'b', 'c']) {
        events.add(CoreEvent(type: CoreEventType.loaded, data: name));
      }
      await pumpEventQueue();

      expect(socket.pushed.map((data) => (data as Map)['data']), [
        'a',
        'b',
        'c',
      ]);
    });

    test('reaches every panel that is watching', () async {
      final first = _FakeSocket();
      final second = _FakeSocket();
      final bridge = PanelEventBridge(events: events.stream);
      bridge.attach(await _session(first));
      bridge.attach(await _session(second));

      events.add(const CoreEvent(type: CoreEventType.loaded, data: 'p'));
      await pumpEventQueue();

      expect(first.pushed, hasLength(1));
      expect(second.pushed, hasLength(1));
    });

    test('stops pushing once that panel is gone', () async {
      final socket = _FakeSocket();
      final session = await _session(socket);
      PanelEventBridge(events: events.stream).attach(session);

      await session.close();
      await pumpEventQueue();
      events.add(const CoreEvent(type: CoreEventType.loaded, data: 'p'));
      await pumpEventQueue();

      expect(socket.pushed, isEmpty);
    });

    test('one panel leaving leaves the other watching', () async {
      final staying = _FakeSocket();
      final leaving = _FakeSocket();
      final bridge = PanelEventBridge(events: events.stream);
      bridge.attach(await _session(staying));
      final gone = await _session(leaving);
      bridge.attach(gone);

      await gone.close();
      await pumpEventQueue();
      events.add(const CoreEvent(type: CoreEventType.loaded, data: 'p'));
      await pumpEventQueue();

      expect(leaving.pushed, isEmpty);
      expect(staying.pushed, hasLength(1));
    });
  });
}

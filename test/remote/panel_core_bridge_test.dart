import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_core_bridge.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

import 'fakes.dart';

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
      await _incoming.close();
    }
  }

  void receive(Object? message) => _incoming.add(json.encode(message));

  Iterable<PanelReply> get replies => sent
      .map(PanelFrame.fromJson)
      .nonNulls
      .where((frame) => frame.channel == PanelChannel.core)
      .map((frame) => PanelReply.fromJson(frame.payload))
      .nonNulls;
}

Future<_FakeSocket> _attached(PanelCoreBridge bridge) async {
  final socket = _FakeSocket();
  socket.receive(
    PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await acceptPanel(socket, token: _token, config: const {});
  addTearDown(session!.close);
  bridge.attach(session);
  return socket;
}

void _call(
  _FakeSocket socket,
  String method, {
  String id = '1',
  Object? arguments,
}) {
  socket.receive(
    PanelFrame(
      PanelChannel.core,
      PanelCall(id: id, method: method, arguments: arguments).toJson(),
    ).toJson(),
  );
}

void main() {
  group('PanelCoreBridge', () {
    test('forwards a method and answers with what the Core gave', () async {
      final core = FakeCore(answer: (_, _) => {'now': 1});
      final socket = await _attached(PanelCoreBridge(core: core));

      _call(socket, 'getTraffic');
      await pumpEventQueue();

      expect(core.calls, [CoreMethod.getTraffic]);
      final reply = socket.replies.single;
      expect(reply.id, '1');
      expect(reply.result, {'now': 1});
      expect(reply.error, isNull);
    });

    test('hands the arguments and the timeout straight through', () async {
      final core = FakeCore();
      const timeout = Duration(seconds: 7);
      final socket = await _attached(
        PanelCoreBridge(core: core, timeout: timeout),
      );

      _call(socket, 'changeProxy', arguments: {'group': 'a', 'name': 'b'});
      await pumpEventQueue();

      expect(core.lastArguments, {'group': 'a', 'name': 'b'});
      expect(core.lastTimeout, timeout);
    });

    test('answers null results without calling them a failure', () async {
      final core = FakeCore();
      final socket = await _attached(PanelCoreBridge(core: core));

      _call(socket, 'getProxies');
      await pumpEventQueue();

      final reply = socket.replies.single;
      expect(reply.result, isNull);
      expect(reply.error, isNull);
    });

    test('refuses the methods that own the host Core', () async {
      final core = FakeCore();
      final socket = await _attached(PanelCoreBridge(core: core));

      for (final method in refusedPanelCoreMethods) {
        _call(socket, method.name, id: method.name);
      }
      await pumpEventQueue();

      expect(core.calls, isEmpty);
      expect(socket.replies.map((reply) => reply.error?.code).toSet(), {
        'panel_method_refused',
      });
      expect(
        socket.replies.map((reply) => reply.id).toSet(),
        refusedPanelCoreMethods.map((method) => method.name).toSet(),
      );
    });

    test('names a method the Core does not have', () async {
      final core = FakeCore();
      final socket = await _attached(PanelCoreBridge(core: core));

      _call(socket, 'nosuchmethod');
      await pumpEventQueue();

      expect(core.calls, isEmpty);
      expect(socket.replies.single.error?.code, 'panel_unknown_method');
    });

    test('answers for a host that holds no Core', () async {
      final socket = await _attached(PanelCoreBridge());

      _call(socket, 'getTraffic');
      await pumpEventQueue();

      expect(socket.replies.single.error?.code, 'panel_core_unavailable');
    });

    test("passes a Core failure back in the Core's own words", () async {
      final core = FakeCore(
        failure: const CoreMethodException(
          code: 'transport_disconnected',
          message: 'no core',
          details: {'tries': 2},
        ),
      );
      final socket = await _attached(PanelCoreBridge(core: core));

      _call(socket, 'getTraffic');
      await pumpEventQueue();

      final error = socket.replies.single.error;
      expect(error?.code, 'transport_disconnected');
      expect(error?.message, 'no core');
      expect(error?.details, {'tries': 2});
    });

    test('wraps a failure that is not the Core speaking', () async {
      final core = FakeCore(failure: StateError('broken'));
      final socket = await _attached(PanelCoreBridge(core: core));

      _call(socket, 'getTraffic');
      await pumpEventQueue();

      final error = socket.replies.single.error;
      expect(error?.code, 'panel_call_failed');
      expect(error?.message, contains('broken'));
    });

    test('says nothing to a frame it cannot read as a call', () async {
      final core = FakeCore();
      final socket = await _attached(PanelCoreBridge(core: core));

      socket.receive(const PanelFrame(PanelChannel.core, 'text').toJson());
      socket.receive(
        const PanelFrame(PanelChannel.core, {'method': 'getTraffic'}).toJson(),
      );
      await pumpEventQueue();

      expect(core.calls, isEmpty);
      expect(socket.replies, isEmpty);
    });

    test('leaves the other channels alone', () async {
      final core = FakeCore();
      final socket = await _attached(PanelCoreBridge(core: core));

      for (final channel in PanelChannel.values) {
        if (channel == PanelChannel.core) {
          continue;
        }
        socket.receive(
          PanelFrame(
            channel,
            const PanelCall(id: '1', method: 'getTraffic').toJson(),
          ).toJson(),
        );
      }
      await pumpEventQueue();

      expect(core.calls, isEmpty);
      expect(socket.replies, isEmpty);
    });

    test('answers each of several calls on its own id', () async {
      final core = FakeCore(answer: (_, arguments) => arguments);
      final socket = await _attached(PanelCoreBridge(core: core));

      for (var i = 0; i < 3; i++) {
        _call(socket, 'getTraffic', id: 'call-$i', arguments: i);
      }
      await pumpEventQueue();

      expect(
        {for (final reply in socket.replies) reply.id: reply.result},
        {'call-0': 0, 'call-1': 1, 'call-2': 2},
      );
    });
  });
}

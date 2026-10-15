import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/core/desktop/model.dart';
import 'package:funclash/core/event.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_core_client.dart';
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
      await _incoming.close();
    }
  }

  void receive(Object? message) => _incoming.add(json.encode(message));

  void reply(PanelReply reply) =>
      receive(PanelFrame(PanelChannel.core, reply.toJson()).toJson());

  Iterable<PanelCall> get calls => sent
      .map(PanelFrame.fromJson)
      .nonNulls
      .where((frame) => frame.channel == PanelChannel.core)
      .map((frame) => PanelCall.fromJson(frame.payload))
      .nonNulls;
}

Future<PanelSession> _session(_FakeSocket socket) async {
  socket.receive(
    PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await acceptPanel(socket, token: _token, config: const {});
  addTearDown(session!.close);
  return session;
}

Future<(PanelCoreClient, _FakeSocket)> _linked() async {
  final socket = _FakeSocket();
  final client = PanelCoreClient();
  addTearDown(client.unbind);
  await client.bind(await _session(socket));
  return (client, socket);
}

void main() {
  group('PanelCoreClient', () {
    test('refuses a call before it is linked to a host', () async {
      final client = PanelCoreClient();

      expect(client.isLinked, isFalse);
      await expectLater(
        client.invokeMethod<Object>(method: CoreMethod.getTraffic),
        throwsA(
          isA<CoreMethodException>()
              .having((e) => e.code, 'code', 'transport_disconnected')
              .having((e) => e.isCoreUnavailable, 'isCoreUnavailable', isTrue),
        ),
      );
    });

    test('sends the method name the host already speaks', () async {
      final (client, socket) = await _linked();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.changeProxy,
        arguments: {'group': 'a'},
      );
      await pumpEventQueue();

      final call = socket.calls.single;
      expect(call.method, 'changeProxy');
      expect(call.arguments, {'group': 'a'});
      expect(client.pendingCount, 1);

      socket.reply(PanelReply(id: call.id, result: 'done'));
      expect(await pending, 'done');
      expect(client.pendingCount, 0);
    });

    test('answers a null result as a result', () async {
      final (client, socket) = await _linked();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.getProxies,
      );
      await pumpEventQueue();
      socket.reply(PanelReply(id: socket.calls.single.id));

      expect(await pending, isNull);
    });

    test('raises the failure the host reported, code and all', () async {
      final (client, socket) = await _linked();

      final pending = client.invokeMethod<Object>(method: CoreMethod.initClash);
      await pumpEventQueue();
      socket.reply(
        PanelReply.failed(
          socket.calls.single.id,
          code: 'panel_method_refused',
          message: 'initClash belongs to the host alone',
        ),
      );

      await expectLater(
        pending,
        throwsA(
          isA<CoreMethodException>()
              .having((e) => e.code, 'code', 'panel_method_refused')
              .having((e) => e.message, 'message', contains('host alone')),
        ),
      );
      expect(client.pendingCount, 0);
    });

    test('pairs each answer with the call that asked', () async {
      final (client, socket) = await _linked();

      final first = client.invokeMethod<Object>(method: CoreMethod.getTraffic);
      final second = client.invokeMethod<Object>(method: CoreMethod.getProxies);
      await pumpEventQueue();

      final ids = socket.calls.map((call) => call.id).toList();
      expect(ids.toSet(), hasLength(2));

      socket.reply(PanelReply(id: ids[1], result: 'proxies'));
      socket.reply(PanelReply(id: ids[0], result: 'traffic'));

      expect(await first, 'traffic');
      expect(await second, 'proxies');
    });

    test("feeds a pushed event into the panel's own event manager", () async {
      final (client, socket) = await _linked();
      final seen = <CoreEvent>[];
      final watching = coreEventManager.events.listen(seen.add);
      addTearDown(watching.cancel);

      socket.receive(
        PanelFrame(
          PanelChannel.core,
          const PanelEvent({'type': 'loaded', 'data': 'p'}).toJson(),
        ).toJson(),
      );
      await pumpEventQueue();

      expect(seen.single.type, CoreEventType.loaded);
      expect(seen.single.data, 'p');
      expect(client.pendingCount, 0);
    });

    test('takes a batch of events as readily as one', () async {
      final (_, socket) = await _linked();
      final seen = <CoreEvent>[];
      final watching = coreEventManager.events.listen(seen.add);
      addTearDown(watching.cancel);

      socket.receive(
        PanelFrame(
          PanelChannel.core,
          const PanelEvent([
            {'type': 'loaded', 'data': 'a'},
            {'type': 'loaded', 'data': 'b'},
          ]).toJson(),
        ).toJson(),
      );
      await pumpEventQueue();

      expect(seen.map((event) => event.data), ['a', 'b']);
    });

    test('an event never answers a call that is waiting', () async {
      final (client, socket) = await _linked();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.getTraffic,
      );
      await pumpEventQueue();
      socket.receive(
        PanelFrame(
          PanelChannel.core,
          const PanelEvent({'type': 'loaded', 'data': 'p'}).toJson(),
        ).toJson(),
      );
      await pumpEventQueue();

      expect(client.pendingCount, 1);
      socket.reply(PanelReply(id: socket.calls.single.id, result: 'late'));
      expect(await pending, 'late');
    });

    test('drops an answer to a call it is no longer waiting on', () async {
      final (client, socket) = await _linked();

      socket.reply(const PanelReply(id: 'nosuchcall', result: 1));
      socket.receive(const PanelFrame(PanelChannel.core, 'text').toJson());
      await pumpEventQueue();

      expect(client.isLinked, isTrue);
      expect(client.pendingCount, 0);
    });

    test('fails everything waiting when the host goes away', () async {
      final (client, socket) = await _linked();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.getTraffic,
      );
      // Watched before the host goes, or the error lands on a future nothing
      // is listening to and the zone reports it as unhandled.
      final failure = expectLater(
        pending,
        throwsA(
          isA<CoreMethodException>().having(
            (e) => e.code,
            'code',
            'transport_disconnected',
          ),
        ),
      );
      await pumpEventQueue();
      await socket.close();
      await pumpEventQueue();

      await failure;
      expect(client.isLinked, isFalse);
      expect(client.pendingCount, 0);
    });

    test('a second bind leaves the first call with no host', () async {
      final (client, first) = await _linked();

      final pending = client.invokeMethod<Object>(
        method: CoreMethod.getTraffic,
      );
      final failure = expectLater(pending, throwsA(isA<CoreMethodException>()));
      await pumpEventQueue();
      await client.bind(await _session(_FakeSocket()));

      await failure;
      expect(first.calls, hasLength(1));
      expect(client.isLinked, isTrue);
    });

    test("reports a lifecycle request as the host's own decision", () async {
      final (client, socket) = await _linked();

      for (final result in [
        await client.start(),
        await client.restart(),
        await client.stop(),
      ]) {
        expect(result.outcome, CoreLifecycleOutcome.coalesced);
        expect(result.session, isNull);
      }

      expect(socket.calls, isEmpty);
    });

    test('closing unbinds, so a later call reports no host', () async {
      final (client, _) = await _linked();

      await client.close();

      expect(client.isLinked, isFalse);
      await expectLater(
        client.invokeMethod<Object>(method: CoreMethod.getTraffic),
        throwsA(isA<CoreMethodException>()),
      );
    });
  });
}

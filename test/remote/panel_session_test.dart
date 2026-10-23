import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';
const _config = {
  'currentProfileId': 'abc',
  'appSettingProps': {'openLogs': true},
};

final class _FakeSocket implements PanelSocket {
  final _incoming = StreamController<String>();
  final sent = <String>[];
  var closed = false;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) => sent.add(message);

  // Unawaited because a single-subscription controller nothing has listened to
  // yet never completes its close, which is the socket shut before the accept.
  @override
  Future<void> close() async {
    closed = true;
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }

  void receive(Object message) => _incoming.add(json.encode(message));

  void receiveRaw(String message) => _incoming.add(message);

  Object? get lastSent => sent.isEmpty ? null : json.decode(sent.last);
}

Future<PanelSession?> _accept(
  _FakeSocket socket, {
  String token = _token,
  Duration timeout = const Duration(seconds: 5),
}) {
  return acceptPanel(socket, token: token, config: _config, timeout: timeout);
}

Future<PanelSession> _connected(_FakeSocket socket) async {
  socket.receive(
    const PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await _accept(socket);
  return session!;
}

void main() {
  group('acceptPanel', () {
    test('welcomes a good hello with the config it was given', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);
      addTearDown(session.close);

      final welcome = PanelWelcome.fromJson(socket.lastSent);
      expect(welcome?.protocol, panelProtocolVersion);
      expect(welcome?.config, _config);
      expect(socket.closed, isFalse);
    });

    test('hangs up on a bad token and says why', () async {
      final socket = _FakeSocket();
      socket.receive(
        const PanelHello(
          protocol: panelProtocolVersion,
          token: 'wrong',
        ).toJson(),
      );

      expect(await _accept(socket), isNull);
      expect(
        PanelReject.fromJson(socket.lastSent)?.reason,
        PanelRejectReason.badToken,
      );
      expect(socket.closed, isTrue);
    });

    test('hangs up on a protocol it does not speak', () async {
      final socket = _FakeSocket();
      socket.receive(
        const PanelHello(
          protocol: panelProtocolVersion + 1,
          token: _token,
        ).toJson(),
      );

      expect(await _accept(socket), isNull);
      expect(
        PanelReject.fromJson(socket.lastSent)?.reason,
        PanelRejectReason.protocolMismatch,
      );
    });

    test('hangs up when the first message is not a hello', () async {
      for (final opening in <void Function(_FakeSocket)>[
        (socket) => socket.receiveRaw('not json at all'),
        (socket) => socket.receive({'c': 'core', 'p': 1}),
        (socket) => socket.receive({
          'hello': {'token': _token},
        }),
      ]) {
        final socket = _FakeSocket();
        opening(socket);

        expect(await _accept(socket), isNull);
        expect(
          PanelReject.fromJson(socket.lastSent)?.reason,
          PanelRejectReason.malformed,
        );
        expect(socket.closed, isTrue);
      }
    });

    test('hangs up on a socket that never says who it is', () async {
      final socket = _FakeSocket();

      expect(
        await _accept(socket, timeout: const Duration(milliseconds: 20)),
        isNull,
      );
      expect(
        PanelReject.fromJson(socket.lastSent)?.reason,
        PanelRejectReason.timeout,
      );
      expect(socket.closed, isTrue);
    });

    test('says nothing to a socket that hangs up first', () async {
      final socket = _FakeSocket();
      await socket.close();

      expect(await _accept(socket), isNull);
      expect(socket.sent, isEmpty);
    });

    test('never forwards a frame sent before the hello', () async {
      final socket = _FakeSocket();
      socket.receive({'c': 'core', 'p': 1});
      socket.receive(
        const PanelHello(
          protocol: panelProtocolVersion,
          token: _token,
        ).toJson(),
      );

      expect(await _accept(socket), isNull);
    });
  });

  group('PanelSession', () {
    test('unwraps frames for every channel handler', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);
      addTearDown(session.close);

      final core = session.frames
          .where((frame) => frame.channel == PanelChannel.core)
          .toList();
      final db = session.databaseFrames.toList();

      socket.receive(const PanelFrame(PanelChannel.core, {'id': 1}).toJson());
      socket.receive(const PanelFrame(PanelChannel.db, [2]).toJson());
      await pumpEventQueue();
      await session.close();

      expect((await core).single.payload, {'id': 1});
      expect((await db).single.payload, [2]);
    });

    test('drops an unreadable frame and keeps the socket', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);
      addTearDown(session.close);

      final frames = session.frames.toList();
      socket.receiveRaw('{');
      socket.receive({'c': 'nosuchchannel', 'p': 1});
      socket.receive(const PanelFrame(PanelChannel.fs, 'after').toJson());
      await pumpEventQueue();
      await session.close();

      expect((await frames).single.payload, 'after');
      expect(socket.closed, isTrue);
    });

    test('a late hello is just a frame it cannot place', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);
      addTearDown(session.close);

      final frames = session.frames.toList();
      socket.receive(
        const PanelHello(
          protocol: panelProtocolVersion,
          token: _token,
        ).toJson(),
      );
      await pumpEventQueue();
      await session.close();

      expect(await frames, isEmpty);
      expect(socket.sent, hasLength(1));
    });

    test('puts a frame on the wire as the protocol spells it', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);
      addTearDown(session.close);

      session.send(const PanelFrame(PanelChannel.config, {'epoch': 3}));

      expect(socket.lastSent, {
        'c': 'config',
        'p': {'epoch': 3},
      });
    });

    test('ends its frame stream when the socket goes away', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);

      final frames = session.frames.toList();
      final databaseFrames = session.databaseFrames.toList();
      await socket.close();

      expect(await frames, isEmpty);
      expect(await databaseFrames, isEmpty);
    });

    test('closing twice is not an error', () async {
      final socket = _FakeSocket();
      final session = await _connected(socket);

      await session.close();
      await session.close();
    });
  });
}

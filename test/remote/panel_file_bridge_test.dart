import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/remote/panel_file_bridge.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:path/path.dart' as p;

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';

final class _FakeSocket implements PanelSocket {
  final _incoming = StreamController<String>();
  final sent = <Object?>[];
  final _waiting = <String, Completer<PanelReply>>{};

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) {
    final decoded = json.decode(message);
    sent.add(decoded);
    final reply = _replyOf(decoded);
    if (reply != null) {
      _waiting.remove(reply.id)?.complete(reply);
    }
  }

  @override
  Future<void> close() async {
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }

  void receive(Object? message) => _incoming.add(json.encode(message));

  /// Real file I/O answers after however many turns the machine needs.
  Future<PanelReply> replyTo(String id) =>
      (_waiting[id] ??= Completer<PanelReply>()).future;

  Iterable<PanelReply> get replies => sent.map(_replyOf).nonNulls;
}

PanelReply? _replyOf(Object? message) {
  final frame = PanelFrame.fromJson(message);
  if (frame == null || frame.channel != PanelChannel.fs) {
    return null;
  }
  return PanelReply.fromJson(frame.payload);
}

String _root() {
  final directory = Directory.systemTemp.createTempSync('panel_fs');
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return directory.path;
}

Future<_FakeSocket> _served(String root) async {
  final socket = _FakeSocket();
  socket.receive(
    const PanelHello(protocol: panelProtocolVersion, token: _token).toJson(),
  );
  final session = await acceptPanel(socket, token: _token, config: const {});
  addTearDown(session!.close);
  PanelFileBridge(root: Future.value(root)).attach(session);
  return socket;
}

Future<PanelReply> _ask(
  _FakeSocket socket,
  String method,
  Map<String, Object?> arguments,
) {
  final id = '${socket.sent.length}';
  final reply = socket.replyTo(id);
  socket.receive(
    PanelFrame(
      PanelChannel.fs,
      PanelCall(id: id, method: method, arguments: arguments).toJson(),
    ).toJson(),
  );
  return reply;
}

void main() {
  group('PanelFileBridge', () {
    test('reads a file the host has', () async {
      final root = _root();
      File(p.join(root, 'a.txt')).writeAsStringSync('hello');
      final socket = await _served(root);

      final reply = await _ask(socket, 'readPathAsStringOrEmpty', {
        'path': p.join(root, 'a.txt'),
      });

      expect(reply.result, 'hello');
      expect(reply.error, isNull);
    });

    test('writes where the panel asks, inside the root', () async {
      final root = _root();
      final socket = await _served(root);

      final reply = await _ask(socket, 'safeWritePathAsString', {
        'path': p.join(root, 'written.txt'),
        'content': 'from the panel',
      });

      expect(reply.error, isNull);
      expect(
        File(p.join(root, 'written.txt')).readAsStringSync(),
        'from the panel',
      );
    });

    test('carries bytes both ways', () async {
      final root = _root();
      final socket = await _served(root);
      final path = p.join(root, 'bytes.bin');

      await _ask(socket, 'safeWritePathAsBytes', {
        'path': path,
        'bytes': [1, 2, 3],
      });
      final read = await _ask(socket, 'readPathAsBytes', {'path': path});

      expect(read.result, [1, 2, 3]);
      expect(panelBytes(read.result), [1, 2, 3]);
    });

    test('answers a stat as numbers and a date', () async {
      final root = _root();
      File(p.join(root, 'a.txt')).writeAsStringSync('12345');
      final socket = await _served(root);

      final reply = await _ask(socket, 'readPathStat', {
        'path': p.join(root, 'a.txt'),
      });

      final stat = reply.result! as Map;
      expect(stat['size'], 5);
      expect(DateTime.tryParse(stat['lastModified']! as String), isNotNull);
    });

    test('refuses a path outside the root', () async {
      final root = _root();
      File(p.join(p.dirname(root), 'secret.txt')).writeAsStringSync('no');
      addTearDown(
        () => File(p.join(p.dirname(root), 'secret.txt')).deleteSync(),
      );
      final socket = await _served(root);

      for (final path in [
        p.join(p.dirname(root), 'secret.txt'),
        p.join(root, '..', 'secret.txt'),
        '/etc/passwd',
      ]) {
        final reply = await _ask(socket, 'readPathAsStringOrEmpty', {
          'path': path,
        });

        expect(reply.error?.code, 'panel_path_refused', reason: path);
        expect(reply.result, isNull, reason: path);
      }
    });

    test('refuses a destination outside the root', () async {
      final root = _root();
      File(p.join(root, 'a.txt')).writeAsStringSync('x');
      final socket = await _served(root);

      final reply = await _ask(socket, 'safeCopyPath', {
        'path': p.join(root, 'a.txt'),
        'to': p.join(p.dirname(root), 'escaped.txt'),
      });

      expect(reply.error?.code, 'panel_file_failed');
      expect(
        File(p.join(p.dirname(root), 'escaped.txt')).existsSync(),
        isFalse,
      );
    });

    test('names a call that carries no path', () async {
      final socket = await _served(_root());

      final reply = await _ask(socket, 'pathExists', {'nothing': 1});

      expect(reply.error?.code, 'panel_bad_path');
    });

    test('names an operation it does not have', () async {
      final root = _root();
      final socket = await _served(root);

      final reply = await _ask(socket, 'nosuchcall', {
        'path': p.join(root, 'a.txt'),
      });

      expect(reply.error?.code, 'panel_file_failed');
    });

    test('reports a read of a file that is not there', () async {
      final root = _root();
      final socket = await _served(root);

      final missing = await _ask(socket, 'pathExists', {
        'path': p.join(root, 'gone.txt'),
      });
      final empty = await _ask(socket, 'readPathAsBytesOrNull', {
        'path': p.join(root, 'gone.txt'),
      });

      expect(missing.result, isFalse);
      expect(empty.result, isNull);
      expect(empty.error, isNull);
    });

    test('leaves the other channels alone', () async {
      final root = _root();
      final socket = await _served(root);

      socket.receive(
        PanelFrame(
          PanelChannel.core,
          const PanelCall(id: 'x', method: 'pathExists').toJson(),
        ).toJson(),
      );
      await pumpEventQueue();

      expect(socket.replies, isEmpty);
    });
  });
}

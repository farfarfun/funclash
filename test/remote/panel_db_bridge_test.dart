import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
// ignore: experimental_member_use, a panel runs the drift its host shipped.
import 'package:drift/remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/database/database.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_db_bridge.dart';
import 'package:funclash/remote/panel_db_channel.dart';
import 'package:funclash/remote/panel_session.dart';

QueryExecutor _memory() => NativeDatabase.memory();

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';

Profile _profile(int id, String label) =>
    Profile(id: id, label: label, autoUpdateDuration: Duration.zero);

/// Two sockets wired to each other: what the WebSocket is between a host and
/// a panel, without the socket.
final class _Pipe {
  _Pipe() {
    host = _PipeEnd(_toPanel, _toHost);
    panel = _PipeEnd(_toHost, _toPanel);
  }

  final StreamController<String> _toHost = StreamController<String>();
  final StreamController<String> _toPanel = StreamController<String>();

  late final _PipeEnd host;
  late final _PipeEnd panel;

  Future<void> close() async {
    await host.close();
    await panel.close();
    if (!_toHost.isClosed) {
      unawaited(_toHost.close());
    }
    if (!_toPanel.isClosed) {
      unawaited(_toPanel.close());
    }
  }
}

final class _PipeEnd implements PanelSocket {
  _PipeEnd(this._out, this._in);

  final StreamController<String> _out;
  final StreamController<String> _in;

  @override
  Stream<String> get messages => _in.stream;

  @override
  void send(String message) {
    if (!_out.isClosed) {
      _out.add(message);
    }
  }

  @override
  Future<void> close() async {
    if (!_out.isClosed) {
      unawaited(_out.close());
    }
  }
}

Future<(Database, Database)> _linkedPair(_Pipe pipe) async {
  final accepting = acceptPanel(pipe.host, token: _token, config: const {});
  final linking = linkPanel(pipe.panel, token: _token);
  final host = (await accepting)!;
  final panel = (await linking as PanelLinked).session;

  final isolate = await DriftIsolate.spawn(_memory);
  addTearDown(isolate.shutdownAll);
  final hostDatabase = Database(await isolate.connect());
  addTearDown(hostDatabase.close);
  PanelDatabaseBridge(connect: isolate.connect).attach(host);

  final panelDatabase = Database(
    await connectToRemoteAndInitialize(panelDatabaseChannel(panel)),
  );
  addTearDown(panelDatabase.close);
  return (hostDatabase, panelDatabase);
}

void main() {
  group('PanelDatabaseBridge', () {
    test('a panel reads what the host wrote', () async {
      final pipe = _Pipe();
      addTearDown(pipe.close);
      final (host, panel) = await _linkedPair(pipe);

      await host.profilesDao.setAll([_profile(1, 'from the host')]);

      final rows = await panel.profilesDao.query().get();
      expect(rows.map((profile) => profile.label), ['from the host']);
    });

    test('a write from the panel lands in the host database', () async {
      final pipe = _Pipe();
      addTearDown(pipe.close);
      final (host, panel) = await _linkedPair(pipe);

      await panel.profilesDao.setAll([_profile(2, 'from the panel')]);

      final rows = await host.profilesDao.query().get();
      expect(rows.map((profile) => profile.label), ['from the panel']);
    });

    test('a transaction the panel opens is one on the host', () async {
      final pipe = _Pipe();
      addTearDown(pipe.close);
      final (host, panel) = await _linkedPair(pipe);

      await expectLater(
        panel.transaction(() async {
          await panel.profilesDao.setAll([_profile(3, 'rolled back')]);
          throw StateError('give up');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await host.profilesDao.query().get(), isEmpty);
    });

    test('a stream query on the panel sees a host write', () async {
      final pipe = _Pipe();
      addTearDown(pipe.close);
      final (host, panel) = await _linkedPair(pipe);
      final seen = <int>[];
      final watching = panel.profilesDao.query().watch().listen(
        (rows) => seen.add(rows.length),
      );
      addTearDown(watching.cancel);
      await pumpEventQueue();

      await host.profilesDao.setAll([_profile(4, 'watched')]);
      await pumpEventQueue();

      expect(seen.last, 1);
    });
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/constant.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_server_native.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:path/path.dart' as p;

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';
const _config = {'currentProfileId': 'abc'};

/// Port zero so the operating system picks one no other test is holding.
const _usable = PanelSettings(enabled: true, token: _token, port: 0);

Future<PanelServer> _started({bool allowLan = false, String? pageRoot}) async {
  final server = PanelServer(config: () => _config, pageRoot: pageRoot);
  addTearDown(server.dispose);
  await server.start(_usable.copyWith(allowLan: allowLan));
  return server;
}

/// A panel build as far as the host is concerned: a tree of files to hand back.
String _pageTree() {
  final root = Directory.systemTemp.createTempSync('panel_page');
  addTearDown(() => root.deleteSync(recursive: true));
  File(p.join(root.path, 'index.html')).writeAsStringSync('<html>panel</html>');
  File(p.join(root.path, 'main.dart.js')).writeAsStringSync('console.log(1)');
  Directory(p.join(root.path, 'assets')).createSync();
  File(p.join(root.path, 'assets', 'f.json')).writeAsStringSync('{"a":1}');
  File(p.join(root.parent.path, 'outside.txt')).writeAsStringSync('secret');
  addTearDown(() => File(p.join(root.parent.path, 'outside.txt')).deleteSync());
  return root.path;
}

Future<({int status, String? type, String? cacheControl, String body})> _get(
  PanelServer server,
  String path,
) async {
  final client = HttpClient();
  addTearDown(client.close);
  final request = await client.getUrl(
    Uri.parse('http://$localhost:${server.address!.port}$path'),
  );
  final response = await request.close();
  return (
    status: response.statusCode,
    type: response.headers.contentType?.mimeType,
    cacheControl: response.headers.value(HttpHeaders.cacheControlHeader),
    body: await response.transform(utf8.decoder).join(),
  );
}

String _bridgeUrl(PanelServer server) =>
    'ws://$localhost:${server.address!.port}$panelBridgePath';

/// Reads the replies in order, which a bare `socket.first` cannot do twice.
final class _PanelClient {
  _PanelClient._(WebSocket socket)
    : _socket = socket,
      _incoming = StreamIterator(socket.cast<String>());

  static Future<_PanelClient> connect(
    PanelServer server, {
    String? origin,
  }) async {
    return _PanelClient._(
      await WebSocket.connect(
        _bridgeUrl(server),
        headers: origin == null ? null : {'origin': origin},
      ),
    );
  }

  final WebSocket _socket;
  final StreamIterator<String> _incoming;

  void send(Object message) => _socket.add(json.encode(message));

  void sayHello([String token = _token]) =>
      send(PanelHello(protocol: panelProtocolVersion, token: token).toJson());

  /// Null once the host has hung up.
  Future<Object?> next() async =>
      await _incoming.moveNext() ? json.decode(_incoming.current) : null;

  Future<void> close() async {
    await _incoming.cancel();
    await _socket.close();
  }
}

/// A hand-written upgrade, because the headers the host judges — `Host` above
/// all — are ones `HttpClient` writes for itself.
Future<int> _status(
  PanelServer server, {
  String path = panelBridgePath,
  String? host,
  String? origin,
  bool upgrade = true,
}) async {
  final port = server.address!.port;
  final authority = host ?? '$localhost:$port';
  final socket = await Socket.connect(localhost, port);
  final request = StringBuffer()
    ..write('GET $path HTTP/1.1\r\n')
    ..write('Host: $authority\r\n');
  if (upgrade) {
    request
      ..write('Connection: Upgrade\r\n')
      ..write('Upgrade: websocket\r\n')
      ..write('Sec-WebSocket-Version: 13\r\n')
      ..write('Sec-WebSocket-Key: ${base64.encode(List.filled(16, 7))}\r\n');
  }
  if (origin != null) {
    request.write('Origin: $origin\r\n');
  }
  socket.write('$request\r\n');
  await socket.flush();
  final head = await utf8.decoder.bind(socket).first;
  socket.destroy();
  return int.parse(head.split(' ')[1]);
}

void main() {
  group('PanelServer', () {
    test('welcomes a panel that knows the token and publishes it', () async {
      final server = await _started();
      final session = server.sessions.first;
      final client = await _PanelClient.connect(server);
      addTearDown(client.close);

      client.sayHello();
      final welcome = PanelWelcome.fromJson(await client.next());

      expect(welcome?.protocol, panelProtocolVersion);
      expect(welcome?.config, _config);
      await expectLater(session, completes);
    });

    test('hands each panel the config as it stands when it arrives', () async {
      var epoch = 1;
      final server = PanelServer(config: () => {'epoch': epoch});
      addTearDown(server.dispose);
      await server.start(_usable);

      final first = await _PanelClient.connect(server);
      addTearDown(first.close);
      first.sayHello();
      expect(PanelWelcome.fromJson(await first.next())?.config, {'epoch': 1});

      epoch = 2;
      final second = await _PanelClient.connect(server);
      addTearDown(second.close);
      second.sayHello();
      expect(PanelWelcome.fromJson(await second.next())?.config, {'epoch': 2});
    });

    test('tells a panel with the wrong token why it is leaving', () async {
      final server = await _started();
      final client = await _PanelClient.connect(server);
      addTearDown(client.close);

      client.sayHello('wrong');

      expect(
        PanelReject.fromJson(await client.next())?.reason,
        PanelRejectReason.badToken,
      );
      expect(await client.next(), isNull);
    });

    test('carries frames both ways once the panel is in', () async {
      final server = await _started();
      final pending = server.sessions.first;
      final client = await _PanelClient.connect(server);
      addTearDown(client.close);
      client.sayHello();
      await client.next();
      final session = await pending;

      final arrived = session.frames.first;
      client.send(const PanelFrame(PanelChannel.core, {'id': 1}).toJson());
      expect((await arrived).payload, {'id': 1});

      session.send(const PanelFrame(PanelChannel.db, [2]));
      expect(await client.next(), {
        'c': 'db',
        'p': [2],
      });
    });

    test('closes the panels it is holding when it stops', () async {
      final server = await _started();
      final pending = server.sessions.first;
      final client = await _PanelClient.connect(server);
      addTearDown(client.close);
      client.sayHello();
      await client.next();
      final session = await pending;
      final frames = session.frames.toList();

      await server.stop();

      expect(await frames, isEmpty);
      expect(await client.next(), isNull);
    });

    test('answers nothing outside the bridge path', () async {
      final server = await _started();

      expect(await _status(server, path: '/'), HttpStatus.notFound);
      expect(
        await _status(server, path: '$panelBridgePath/extra'),
        HttpStatus.notFound,
      );
    });

    test('refuses a request that is not a websocket upgrade', () async {
      final server = await _started();

      expect(await _status(server, upgrade: false), HttpStatus.badRequest);
    });

    test('refuses a host that is a name rather than an address', () async {
      final server = await _started();

      expect(
        await _status(server, host: 'panel.example.com'),
        HttpStatus.forbidden,
      );
    });

    test('takes the loopback under either literal name', () async {
      final server = await _started();
      final port = server.address!.port;

      expect(await _status(server, host: '$localhost:$port'), 101);
      expect(await _status(server, host: 'localhost:$port'), 101);
    });

    test('refuses an origin other than the host it was asked for', () async {
      final server = await _started();
      final port = server.address!.port;

      expect(
        await _status(server, origin: 'http://evil.example'),
        HttpStatus.forbidden,
      );
      expect(await _status(server, origin: 'http://$localhost:$port'), 101);
    });

    test('turns a panel away while the handshake queue is full', () async {
      final server = await _started();
      final waiting = <_PanelClient>[];
      for (var i = 0; i < maxPendingPanelHandshakes; i++) {
        waiting.add(await _PanelClient.connect(server));
      }
      addTearDown(() => Future.wait(waiting.map((client) => client.close())));

      expect(await _status(server), HttpStatus.serviceUnavailable);
    });

    test('listens on nothing until the settings can let a panel in', () async {
      final server = PanelServer(config: () => _config);
      addTearDown(server.dispose);

      for (final settings in const [
        PanelSettings(),
        PanelSettings(enabled: true),
        PanelSettings(token: _token),
      ]) {
        await server.start(settings);

        expect(server.isRunning, isFalse, reason: '$settings');
        expect(server.address, isNull, reason: '$settings');
      }
    });

    test('names the address it was told to bind', () async {
      expect((await _started()).address?.host, localhost);
      expect((await _started(allowLan: true)).address?.host, anyAddress);
    });

    test('gives up the port when it stops', () async {
      final server = await _started();
      final port = server.address!.port;

      await server.stop();

      expect(server.isRunning, isFalse);
      expect(server.address, isNull);
      await expectLater(
        Socket.connect(localhost, port, timeout: const Duration(seconds: 2)),
        throwsA(isA<SocketException>()),
      );
    });

    test('a second start leaves one bridge rather than two', () async {
      final server = await _started();
      await server.start(_usable);

      expect(server.isRunning, isTrue);
      final client = await _PanelClient.connect(server);
      addTearDown(client.close);
      client.sayHello();
      expect(PanelWelcome.fromJson(await client.next())?.config, _config);
    });

    test('ends its session stream when it is disposed', () async {
      final server = PanelServer(config: () => _config);
      final sessions = server.sessions.toList();

      await server.dispose();

      expect(await sessions, isEmpty);
    });

    test('serves the panel build it was pointed at', () async {
      final server = await _started(pageRoot: _pageTree());

      final index = await _get(server, '/');
      expect(index.status, HttpStatus.ok);
      expect(index.body, '<html>panel</html>');
      expect(index.type, 'text/html');
      expect(index.cacheControl, 'no-cache');

      final script = await _get(server, '/main.dart.js');
      expect(script.body, 'console.log(1)');
      expect(script.type, 'application/javascript');
      expect(script.cacheControl, 'no-cache');

      final asset = await _get(server, '/assets/f.json');
      expect(asset.body, '{"a":1}');
      expect(asset.type, 'application/json');
    });

    test('answers nothing for a file the build does not have', () async {
      final server = await _started(pageRoot: _pageTree());

      expect((await _get(server, '/nothing.html')).status, HttpStatus.notFound);
    });

    test('hands back nothing above the build it serves', () async {
      final server = await _started(pageRoot: _pageTree());

      for (final path in [
        '/../outside.txt',
        '/assets/../../outside.txt',
        '/%2e%2e/outside.txt',
      ]) {
        final answer = await _get(server, path);
        expect(answer.status, HttpStatus.notFound, reason: path);
        expect(answer.body, isNot(contains('secret')), reason: path);
      }
    });

    test('serves no page at all when it was pointed at nothing', () async {
      final server = await _started();

      expect((await _get(server, '/')).status, HttpStatus.notFound);
    });

    test('answers only GET for a page', () async {
      final server = await _started(pageRoot: _pageTree());
      final client = HttpClient();
      addTearDown(client.close);

      final request = await client.postUrl(
        Uri.parse('http://$localhost:${server.address!.port}/'),
      );
      final response = await request.close();
      await response.drain<void>();

      expect(response.statusCode, HttpStatus.notFound);
    });

    test('stopping one that never started is not an error', () async {
      final server = PanelServer(config: () => _config);
      addTearDown(server.dispose);

      await server.stop();
      await server.stop();
    });
  });
}

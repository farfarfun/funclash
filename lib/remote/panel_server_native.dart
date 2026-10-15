import 'dart:async';
import 'dart:io';

import 'package:funclash/common/constant.dart';
import 'package:funclash/common/print.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:path/path.dart' as p;

typedef PanelConfigSource = Map<String, Object?> Function();

const maxPendingPanelHandshakes = 8;

final class PanelServer {
  PanelServer({required PanelConfigSource config, String? pageRoot})
    : _config = config,
      _pageRoot = pageRoot;

  final PanelConfigSource _config;
  final String? _pageRoot;
  final _sessions = StreamController<PanelSession>.broadcast();
  final _live = <PanelSession>{};

  HttpServer? _server;
  PanelSettings _settings = const PanelSettings();
  int _pending = 0;

  Stream<PanelSession> get sessions => _sessions.stream;

  bool get isRunning => _server != null;

  Uri? get address {
    final server = _server;
    if (server == null) {
      return null;
    }
    return Uri(scheme: 'http', host: _settings.bindAddress, port: server.port);
  }

  Future<void> start(PanelSettings settings) async {
    await stop();
    if (!settings.isUsable) {
      return;
    }
    _settings = settings;
    final server = await HttpServer.bind(
      settings.allowLan
          ? InternetAddress.anyIPv4
          : InternetAddress.loopbackIPv4,
      settings.port,
    );
    _server = server;
    server.listen(
      _handle,
      onError: (Object error) => commonPrint.log(
        'panel server error $error',
        logLevel: LogLevel.warning,
      ),
    );
    commonPrint.log('panel server listening on $address');
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _pending = 0;
    final live = _live.toList();
    _live.clear();
    await Future.wait(live.map((session) => session.close()));
    await server?.close(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _sessions.close();
  }

  Future<void> _handle(HttpRequest request) async {
    // The page too: a name resolving here could rebind its own DNS past this.
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (host == null || !_isLiteralHost(host)) {
      await _refuse(request, HttpStatus.forbidden);
      return;
    }
    if (request.uri.path != panelBridgePath) {
      await _servePage(request);
      return;
    }
    final refusal = _refuseBridge(request, host);
    if (refusal != null) {
      await _refuse(request, refusal);
      return;
    }
    _pending++;
    try {
      final session = await acceptPanel(
        _WebSocketPanelSocket(await WebSocketTransformer.upgrade(request)),
        token: _settings.token,
        config: _config(),
      );
      if (session == null) {
        return;
      }
      _live.add(session);
      unawaited(
        session.frames.drain<void>().whenComplete(() => _live.remove(session)),
      );
      _sessions.add(session);
    } catch (error) {
      commonPrint.log(
        'panel handshake failed $error',
        logLevel: LogLevel.warning,
      );
    } finally {
      if (_pending > 0) {
        _pending--;
      }
    }
  }

  int? _refuseBridge(HttpRequest request, String host) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      return HttpStatus.badRequest;
    }
    if (_pending >= maxPendingPanelHandshakes) {
      return HttpStatus.serviceUnavailable;
    }
    // WebSocket upgrades are not subject to CORS, so a page anywhere could
    // open this socket and ride the browser to a host it cannot name.
    final origin = request.headers.value('origin');
    if (origin != null && Uri.tryParse(origin)?.authority != host) {
      return HttpStatus.forbidden;
    }
    return null;
  }

  Future<void> _servePage(HttpRequest request) async {
    final root = _pageRoot;
    final file = root == null || request.method != 'GET'
        ? null
        : panelPageFile(root, request.uri.path);
    if (file == null || !file.existsSync()) {
      await _refuse(request, HttpStatus.notFound);
      return;
    }
    request.response.headers.contentType = panelPageType(file.path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  }

  Future<void> _refuse(HttpRequest request, int status) async {
    request.response.statusCode = status;
    await request.response.close();
  }
}

/// Null for a path that would leave [root], which a `..` in a request does.
File? panelPageFile(String root, String path) {
  final base = p.normalize(p.absolute(root));
  final resolved = p.normalize(
    p.join(base, path == '/' ? 'index.html' : path.replaceFirst('/', '')),
  );
  if (resolved != base && !p.isWithin(base, resolved)) {
    return null;
  }
  return File(resolved);
}

ContentType panelPageType(String path) => switch (p.extension(path)) {
  '.html' => ContentType.html,
  '.js' || '.mjs' => ContentType('application', 'javascript', charset: 'utf-8'),
  '.json' => ContentType.json,
  '.css' => ContentType('text', 'css', charset: 'utf-8'),
  '.wasm' => ContentType('application', 'wasm'),
  '.png' => ContentType('image', 'png'),
  '.svg' => ContentType('image', 'svg+xml'),
  '.ico' => ContentType('image', 'x-icon'),
  '.ttf' => ContentType('font', 'ttf'),
  '.otf' => ContentType('font', 'otf'),
  '.woff2' => ContentType('font', 'woff2'),
  _ => ContentType.binary,
};

bool _isLiteralHost(String host) {
  final hostname = Uri.tryParse('http://$host')?.host ?? '';
  return hostname == 'localhost' || InternetAddress.tryParse(hostname) != null;
}

final class _WebSocketPanelSocket implements PanelSocket {
  _WebSocketPanelSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.map((message) => message is String ? message : '');

  // A panel already gone is nothing to report from here: the host hears of it
  // through the closed frame stream, while a reject written into a dead socket
  // throws inside a handshake no longer being awaited.
  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(message);
    }
  }

  @override
  Future<void> close() => _socket.close();
}

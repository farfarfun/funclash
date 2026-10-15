import 'dart:async';
import 'dart:io';

import 'package:funclash/common/constant.dart';
import 'package:funclash/common/print.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';

typedef PanelConfigSource = Map<String, Object?> Function();

const maxPendingPanelHandshakes = 8;

final class PanelServer {
  PanelServer({required PanelConfigSource config}) : _config = config;

  final PanelConfigSource _config;
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
    final refusal = _refuse(request);
    if (refusal != null) {
      request.response.statusCode = refusal;
      await request.response.close();
      return;
    }
    _pending++;
    try {
      final socket = await WebSocketTransformer.upgrade(request);
      final session = await acceptPanel(
        _WebSocketPanelSocket(socket),
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

  int? _refuse(HttpRequest request) {
    if (request.uri.path != panelBridgePath) {
      return HttpStatus.notFound;
    }
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      return HttpStatus.badRequest;
    }
    if (_pending >= maxPendingPanelHandshakes) {
      return HttpStatus.serviceUnavailable;
    }
    final host = request.headers.value(HttpHeaders.hostHeader);
    // A page on any name that resolves here would otherwise pass the origin
    // check below by rebinding its own DNS to the loopback address.
    if (host == null || !_isLiteralHost(host)) {
      return HttpStatus.forbidden;
    }
    // WebSocket upgrades are not subject to CORS, so a page anywhere could
    // open this socket and ride the browser to a host it cannot name.
    final origin = request.headers.value('origin');
    if (origin != null && Uri.tryParse(origin)?.authority != host) {
      return HttpStatus.forbidden;
    }
    return null;
  }
}

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

import 'dart:async';
import 'dart:js_interop';

import 'package:funclash/remote/panel_session.dart';

const _open = 1;

@JS('WebSocket')
extension type _BrowserSocket._(JSObject _) implements JSObject {
  external factory _BrowserSocket(String url);

  external int get readyState;

  external void send(String data);

  external void close();

  external set onopen(JSFunction? value);

  external set onmessage(JSFunction? value);

  external set onerror(JSFunction? value);

  external set onclose(JSFunction? value);
}

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSAny? get data;
}

/// Completes when the browser says the socket is open, so the hello the link
/// writes next cannot land on one still connecting.
Future<PanelSocket> dialPanel(Uri bridge) {
  final opened = Completer<PanelSocket>();
  final incoming = StreamController<String>();
  final socket = _BrowserSocket(bridge.toString());

  void shutDown() {
    if (!opened.isCompleted) {
      opened.completeError(StateError('the panel bridge refused the socket'));
    }
    if (!incoming.isClosed) {
      incoming.close().ignore();
    }
  }

  socket.onopen = ((JSAny _) {
    if (!opened.isCompleted) {
      opened.complete(_WebPanelSocket(socket, incoming));
    }
  }).toJS;
  socket.onmessage = ((JSAny event) {
    final data = _MessageEvent._(event as JSObject).data;
    if (data.isA<JSString>() && !incoming.isClosed) {
      incoming.add((data as JSString).toDart);
    }
  }).toJS;
  socket.onerror = ((JSAny _) => shutDown()).toJS;
  socket.onclose = ((JSAny _) => shutDown()).toJS;

  return opened.future;
}

final class _WebPanelSocket implements PanelSocket {
  _WebPanelSocket(this._socket, this._incoming);

  final _BrowserSocket _socket;
  final StreamController<String> _incoming;

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) {
    if (_socket.readyState == _open) {
      _socket.send(message);
    }
  }

  @override
  Future<void> close() async {
    _socket.close();
    if (!_incoming.isClosed) {
      await _incoming.close();
    }
  }
}

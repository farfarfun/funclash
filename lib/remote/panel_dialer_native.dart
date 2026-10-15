import 'dart:io';

import 'package:funclash/remote/panel_session.dart';

/// The desktop hosts a bridge rather than dialing one; this half drives tests.
Future<PanelSocket> dialPanel(Uri bridge) async =>
    _IoPanelSocket(await WebSocket.connect(bridge.toString()));

final class _IoPanelSocket implements PanelSocket {
  _IoPanelSocket(this._socket);

  final WebSocket _socket;

  @override
  Stream<String> get messages =>
      _socket.map((message) => message is String ? message : '');

  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) {
      _socket.add(message);
    }
  }

  @override
  Future<void> close() => _socket.close();
}

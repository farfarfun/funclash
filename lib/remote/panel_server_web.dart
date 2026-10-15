import 'dart:async';

import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';

typedef PanelConfigSource = Map<String, Object?> Function();

// A panel is the client of a bridge, never the host of one.
final class PanelServer {
  PanelServer({required PanelConfigSource config});

  final _sessions = StreamController<PanelSession>.broadcast();

  Stream<PanelSession> get sessions => _sessions.stream;

  bool get isRunning => false;

  Uri? get address => null;

  Future<void> start(PanelSettings settings) async {}

  Future<void> stop() async {}

  Future<void> dispose() => _sessions.close();
}

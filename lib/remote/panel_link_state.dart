import 'dart:async';

import 'package:funclash/remote/panel_session.dart';

final _linked = Completer<PanelSession>();
Map<String, Object?> _config = const {};

Future<Map<String, Object?>> get linkedPanelConfig async {
  await _linked.future;
  return _config;
}

/// For the parts built before the link is up, which can only wait for it.
Future<PanelSession> get linkedPanelSession => _linked.future;

void reportPanelLinked(
  PanelSession session, {
  Map<String, Object?> config = const {},
}) {
  if (!_linked.isCompleted) {
    _config = config;
    _linked.complete(session);
  }
}

void reportPanelRefused(Object reason) {
  if (!_linked.isCompleted) {
    _linked.completeError(reason);
  }
}

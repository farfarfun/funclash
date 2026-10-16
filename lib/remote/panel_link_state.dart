import 'dart:async';

import 'package:funclash/remote/panel_session.dart';

final _linked = Completer<PanelSession>();

/// For the parts built before the link is up, which can only wait for it.
Future<PanelSession> get linkedPanelSession => _linked.future;

void reportPanelLinked(PanelSession session) {
  if (!_linked.isCompleted) {
    _linked.complete(session);
  }
}

void reportPanelRefused(Object reason) {
  if (!_linked.isCompleted) {
    _linked.completeError(reason);
  }
}

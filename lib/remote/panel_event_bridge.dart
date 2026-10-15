import 'dart:async';

import 'package:funclash/core/event.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

/// Pushes what the host's Core reports to every panel watching it.
final class PanelEventBridge implements PanelChannelHandler {
  PanelEventBridge({Stream<CoreEvent>? events})
    : _events = events ?? coreEventManager.events;

  final Stream<CoreEvent> _events;

  @override
  void attach(PanelSession session) {
    final watching = _events.listen(
      (event) => session.send(
        PanelFrame(PanelChannel.core, PanelEvent(event.toJson()).toJson()),
      ),
    );
    unawaited(session.frames.drain<void>().whenComplete(watching.cancel));
  }
}

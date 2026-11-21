import 'dart:async';
import 'dart:convert';

import 'package:funclash/core/event.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

/// Pushes what the host's Core reports to every panel watching it.
final class PanelEventBridge implements PanelChannelHandler {
  PanelEventBridge({Stream<CoreEvent>? events})
    : _events = events ?? coreEventManager.events;

  final Stream<CoreEvent> _events;
  final _sessions = <PanelSession>{};
  StreamSubscription<CoreEvent>? _watching;

  @override
  void attach(PanelSession session) {
    if (session.isClosed) {
      return;
    }
    _sessions.add(session);
    _watching ??= _events.listen(_broadcast);
    unawaited(
      session.frames.drain<void>().whenComplete(() => _detach(session)),
    );
  }

  void _broadcast(CoreEvent event) {
    if (_sessions.isEmpty) {
      return;
    }
    final encoded = json.encode(
      PanelFrame(
        PanelChannel.core,
        PanelEvent(event.toJson()).toJson(),
      ).toJson(),
    );
    for (final session in List.of(_sessions)) {
      if (!session.isClosed) {
        session.sendRaw(encoded);
      }
    }
  }

  void _detach(PanelSession session) {
    _sessions.remove(session);
    if (_sessions.isEmpty) {
      unawaited(_watching?.cancel());
      _watching = null;
    }
  }
}

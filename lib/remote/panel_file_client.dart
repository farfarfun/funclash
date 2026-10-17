import 'dart:async';

import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

/// The file system a panel reaches is the host's, one call at a time.
final class PanelFileClient {
  final Map<String, Completer<Object?>> _pending = {};

  PanelSession? _bound;
  int _nextId = 0;

  Future<T?> call<T>(String method, Map<String, Object?> arguments) async {
    final session = await _session();
    final id = '${_nextId++}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    session.send(
      PanelFrame(
        PanelChannel.fs,
        PanelCall(id: id, method: method, arguments: arguments).toJson(),
      ),
    );
    return await completer.future as T?;
  }

  Future<PanelSession> _session() async {
    final bound = _bound;
    if (bound != null) {
      return bound;
    }
    final session = await linkedPanelSession;
    if (_bound == null) {
      _bound = session;
      session.frames
          .where((frame) => frame.channel == PanelChannel.fs)
          .listen(_receive, onDone: _fail);
    }
    return session;
  }

  void _receive(PanelFrame frame) {
    final reply = PanelReply.fromJson(frame.payload);
    final completer = reply == null ? null : _pending.remove(reply.id);
    if (completer == null || completer.isCompleted) {
      return;
    }
    final error = reply!.error;
    if (error == null) {
      completer.complete(reply.result);
      return;
    }
    completer.completeError(
      CoreMethodException(
        code: error.code,
        message: error.message,
        details: error.details,
      ),
    );
  }

  void _fail() {
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) {
        completer.completeError(
          const CoreMethodException(
            code: 'transport_disconnected',
            message: 'the panel lost the host',
          ),
        );
      }
    }
  }
}

final panelFiles = PanelFileClient();

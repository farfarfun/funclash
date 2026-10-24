import 'dart:async';

import 'package:funclash/core/desktop/model.dart';
import 'package:funclash/core/event.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

const _disconnected = CoreMethodException(
  code: 'transport_disconnected',
  message: 'this panel is not linked to a host',
);

/// A panel asking the host to start says nothing the host was not already
/// going to decide for itself, so the request is reported as merged into it.
const _hostOwnsIt = CoreLifecycleResult(
  revision: 0,
  outcome: CoreLifecycleOutcome.coalesced,
);

/// Fills the slot a tab has no local Core for. It keeps no timer of its own:
/// the host already bounds the call it forwards, and a closed socket reports a
/// dead link outright where a second timer could only guess at one.
final class PanelCoreClient extends CoreHandlerInterface {
  final Map<String, Completer<Object?>> _pending = {};
  final _startTimes = StreamController<int?>.broadcast();

  Stream<int?> get startTimes => _startTimes.stream;

  Future<int?> getStartTime() => _call<int>('panel.getStartTime');

  Future<bool> setRunning(bool running) async =>
      await _call<bool>('panel.setRunning', running) ?? false;

  Future<bool> applyProfile() async =>
      await _call<bool>('panel.applyProfile') ?? false;

  Future<bool> restartHostCore() async =>
      await _call<bool>('panel.restartCore') ?? false;

  PanelSession? _session;
  StreamSubscription<PanelFrame>? _frames;
  int _nextId = 0;

  bool get isLinked => _session != null;

  int get pendingCount => _pending.length;

  Future<void> bind(PanelSession session) async {
    await unbind();
    _session = session;
    _frames = session.frames
        .where((frame) => frame.channel == PanelChannel.core)
        .listen(_receive, onDone: () => unawaited(unbind()));
  }

  Future<void> unbind() async {
    _session = null;
    await _frames?.cancel();
    _frames = null;
    _failPending();
  }

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) => _call<T>(method.name, arguments);

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    final session = _session;
    if (session == null) {
      throw _disconnected;
    }
    final id = '${_nextId++}';
    final completer = Completer<Object?>();
    _pending[id] = completer;
    session.send(
      PanelFrame(
        PanelChannel.core,
        PanelCall(id: id, method: method, arguments: arguments).toJson(),
      ),
    );
    return await completer.future as T?;
  }

  @override
  Future<CoreLifecycleResult> start() async => _hostOwnsIt;

  @override
  Future<CoreLifecycleResult> restart() async => _hostOwnsIt;

  @override
  Future<CoreLifecycleResult> stop() async => _hostOwnsIt;

  @override
  Future<CoreLifecycleResult> close() async {
    await unbind();
    await _startTimes.close();
    return _hostOwnsIt;
  }

  void _receive(PanelFrame frame) {
    if (frame.payload case {'startedAt': final Object? startedAt}) {
      if (startedAt == null || startedAt is int) {
        _startTimes.add(startedAt as int?);
      }
      return;
    }
    final pushed = PanelEvent.fromJson(frame.payload);
    if (pushed != null) {
      for (final event in coreEventsFromData(pushed.data)) {
        coreEventManager.sendEvent(event);
      }
      return;
    }
    final reply = PanelReply.fromJson(frame.payload);
    if (reply == null) {
      return;
    }
    final completer = _pending.remove(reply.id);
    if (completer == null || completer.isCompleted) {
      return;
    }
    final error = reply.error;
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

  void _failPending() {
    final waiting = _pending.values.toList();
    _pending.clear();
    for (final completer in waiting) {
      if (!completer.isCompleted) {
        completer.completeError(_disconnected);
      }
    }
  }
}

final panelCoreClient = PanelCoreClient();

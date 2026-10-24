import 'dart:async';

import 'package:funclash/common/print.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

/// Three of these own the host's own Core process, and `message` is the Core
/// answering rather than anyone calling.
const refusedPanelCoreMethods = {
  CoreMethod.initClash,
  CoreMethod.shutdown,
  CoreMethod.crash,
  CoreMethod.message,
};

final class PanelCoreBridge implements PanelChannelHandler {
  PanelCoreBridge({
    CoreHandlerInterface? core,
    Duration? timeout,
    this.hostAction,
  }) : _core = core,
       _timeout = timeout;

  final CoreHandlerInterface? _core;
  final Duration? _timeout;
  Future<Object?> Function(String method, Object? arguments)? hostAction;
  final _panels = <PanelSession>{};

  void pushStartTime(int? startedAt) {
    for (final session in _panels) {
      session.send(PanelFrame(PanelChannel.core, {'startedAt': startedAt}));
    }
  }

  @override
  void attach(PanelSession session) {
    _panels.add(session);
    session.frames
        .where((frame) => frame.channel == PanelChannel.core)
        .listen(
          (frame) => unawaited(_serve(session, frame)),
          onDone: () => _panels.remove(session),
        );
  }

  Future<void> _serve(PanelSession session, PanelFrame frame) async {
    final call = PanelCall.fromJson(frame.payload);
    if (call == null) {
      return;
    }
    final reply = await _answer(call);
    session.send(PanelFrame(PanelChannel.core, reply.toJson()));
  }

  Future<PanelReply> _answer(PanelCall call) async {
    if (call.method.startsWith('panel.')) {
      try {
        final action = hostAction;
        if (action == null) {
          throw StateError('the panel host is not ready');
        }
        return PanelReply(
          id: call.id,
          result: await action(call.method, call.arguments),
        );
      } catch (failure) {
        return PanelReply.failed(
          call.id,
          code: 'panel_action_failed',
          message: compactError(failure),
        );
      }
    }
    final core = _core;
    if (core == null) {
      return PanelReply.failed(
        call.id,
        code: 'panel_core_unavailable',
        message: 'this host holds no Core',
      );
    }
    final method = CoreMethod.values.asNameMap()[call.method];
    if (method == null) {
      return PanelReply.failed(
        call.id,
        code: 'panel_unknown_method',
        message: '${call.method} is not a Core method',
      );
    }
    if (refusedPanelCoreMethods.contains(method)) {
      return PanelReply.failed(
        call.id,
        code: 'panel_method_refused',
        message: '${call.method} belongs to the host alone',
      );
    }
    try {
      return PanelReply(
        id: call.id,
        result: await core.invokeMethod<Object>(
          method: method,
          arguments: call.arguments,
          timeout: _timeout,
        ),
      );
    } on CoreMethodException catch (failure) {
      return PanelReply(
        id: call.id,
        error: CoreMethodError(
          code: failure.code,
          message: failure.message,
          details: failure.details,
        ),
      );
    } catch (failure) {
      return PanelReply.failed(
        call.id,
        code: 'panel_call_failed',
        message: compactError(failure),
      );
    }
  }
}

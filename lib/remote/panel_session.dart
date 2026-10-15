import 'dart:async';
import 'dart:convert';

import 'package:funclash/remote/panel_protocol.dart';

abstract interface class PanelChannelHandler {
  void attach(PanelSession session);
}

abstract interface class PanelSocket {
  Stream<String> get messages;

  void send(String message);

  Future<void> close();
}

final class PanelSession {
  final PanelSocket _socket;
  final StreamSubscription<String> _subscription;

  // Broadcast because every channel handler listens for its own frames.
  final _frames = StreamController<PanelFrame>.broadcast();

  PanelSession._(this._socket, this._subscription) {
    _subscription
      ..onData(_receive)
      ..onDone(_closeFrames)
      ..onError((Object _, StackTrace _) => _closeFrames());
  }

  Stream<PanelFrame> get frames => _frames.stream;

  void send(PanelFrame frame) => _socket.send(json.encode(frame.toJson()));

  void _receive(String message) {
    final frame = PanelFrame.fromJson(_decode(message));
    if (frame == null) {
      return;
    }
    _frames.add(frame);
  }

  void _closeFrames() {
    if (!_frames.isClosed) {
      _frames.close();
    }
  }

  Future<void> close() async {
    await _subscription.cancel();
    _closeFrames();
    await _socket.close();
  }
}

/// Null when the socket failed the handshake, in which case it is already
/// closed and the reason has been sent.
Future<PanelSession?> acceptPanel(
  PanelSocket socket, {
  required String token,
  required Map<String, Object?> config,
  Duration timeout = panelHandshakeTimeout,
}) {
  final handshake = Completer<PanelSession?>();
  late final StreamSubscription<String> subscription;
  Timer? timer;
  var hungUp = false;

  // The null lands only once the reason is sent and the socket is shut, which
  // is what the caller takes it to mean.
  Future<void> hangUp(PanelRejectReason reason) async {
    if (hungUp || handshake.isCompleted) {
      return;
    }
    hungUp = true;
    timer?.cancel();
    socket.send(json.encode(PanelReject(reason).toJson()));
    await subscription.cancel();
    await socket.close();
    if (!handshake.isCompleted) {
      handshake.complete(null);
    }
  }

  // The session inherits this subscription rather than listening again: a
  // second listen on a single-subscription stream either throws or loses the
  // frames that arrive before it is in place.
  subscription = socket.messages.listen(
    (message) {
      if (handshake.isCompleted) {
        return;
      }
      final reason = rejectHello(PanelHello.fromJson(_decode(message)), token);
      if (reason != null) {
        unawaited(hangUp(reason));
        return;
      }
      timer?.cancel();
      socket.send(
        json.encode(
          PanelWelcome(protocol: panelProtocolVersion, config: config).toJson(),
        ),
      );
      handshake.complete(PanelSession._(socket, subscription));
    },
    onDone: () {
      timer?.cancel();
      if (!handshake.isCompleted) {
        handshake.complete(null);
      }
    },
    onError: (Object _, StackTrace _) =>
        unawaited(hangUp(PanelRejectReason.malformed)),
  );

  timer = Timer(timeout, () => unawaited(hangUp(PanelRejectReason.timeout)));

  return handshake.future;
}

sealed class PanelLinkResult {
  const PanelLinkResult();
}

final class PanelLinked extends PanelLinkResult {
  final PanelSession session;
  final Map<String, Object?> config;

  const PanelLinked(this.session, this.config);
}

/// The host said no, said nothing this version can read, or went away before
/// it said anything at all.
final class PanelRefused extends PanelLinkResult {
  final PanelRejectReason reason;

  const PanelRefused(this.reason);

  @override
  String toString() => 'PanelRefused(${reason.name})';
}

/// The panel's half of [acceptPanel]: say hello, then take the welcome. The
/// socket is closed for every answer but a welcome.
Future<PanelLinkResult> linkPanel(
  PanelSocket socket, {
  required String token,
  Duration timeout = panelHandshakeTimeout,
}) {
  final link = Completer<PanelLinkResult>();
  late final StreamSubscription<String> subscription;
  Timer? timer;
  var given = false;

  Future<void> giveUp(PanelRejectReason reason) async {
    if (given || link.isCompleted) {
      return;
    }
    given = true;
    timer?.cancel();
    await subscription.cancel();
    await socket.close();
    if (!link.isCompleted) {
      link.complete(PanelRefused(reason));
    }
  }

  subscription = socket.messages.listen(
    (message) {
      if (link.isCompleted || given) {
        return;
      }
      final decoded = _decode(message);
      final welcome = PanelWelcome.fromJson(decoded);
      if (welcome == null || welcome.protocol != panelProtocolVersion) {
        final refusal = PanelReject.fromJson(decoded);
        unawaited(
          giveUp(
            refusal?.reason ??
                (welcome == null
                    ? PanelRejectReason.malformed
                    : PanelRejectReason.protocolMismatch),
          ),
        );
        return;
      }
      timer?.cancel();
      link.complete(
        PanelLinked(PanelSession._(socket, subscription), welcome.config),
      );
    },
    onDone: () {
      timer?.cancel();
      if (!link.isCompleted) {
        link.complete(const PanelRefused(PanelRejectReason.malformed));
      }
    },
    onError: (Object _, StackTrace _) =>
        unawaited(giveUp(PanelRejectReason.malformed)),
  );

  timer = Timer(timeout, () => unawaited(giveUp(PanelRejectReason.timeout)));
  socket.send(
    json.encode(
      PanelHello(protocol: panelProtocolVersion, token: token).toJson(),
    ),
  );

  return link.future;
}

Object? _decode(String message) {
  try {
    return json.decode(message);
  } catch (_) {
    return null;
  }
}

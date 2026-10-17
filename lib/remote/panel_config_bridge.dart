import 'dart:async';

import 'package:funclash/models/models.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

/// The host's side: pushes to every panel, reports what comes back.
final class PanelConfigBridge implements PanelChannelHandler {
  final _writes = StreamController<Config>.broadcast();
  final _panels = <PanelSession>{};

  Stream<Config> get writes => _writes.stream;

  @override
  void attach(PanelSession session) {
    _panels.add(session);
    session.frames
        .where((frame) => frame.channel == PanelChannel.config)
        .listen((frame) => _read(frame.payload));
    unawaited(
      session.frames.drain<void>().whenComplete(() => _panels.remove(session)),
    );
  }

  void push(Config config) {
    final payload = config.toJson();
    for (final session in _panels) {
      session.send(PanelFrame(PanelChannel.config, payload));
    }
  }

  Future<void> dispose() => _writes.close();

  void _read(Object? payload) {
    if (payload is! Map) {
      return;
    }
    final config = Config.realFromJson(payload.cast<String, Object?>());
    if (!_writes.isClosed) {
      _writes.add(config);
    }
  }
}

/// The panel's side. What just came from the host is never sent back to it.
final class PanelConfigClient {
  Config? _fromHost;

  void bind(PanelSession session, {required void Function(Config) apply}) {
    session.frames
        .where((frame) => frame.channel == PanelChannel.config)
        .listen((frame) {
          final payload = frame.payload;
          if (payload is! Map) {
            return;
          }
          final config = Config.realFromJson(payload.cast<String, Object?>());
          _fromHost = config;
          apply(config);
        });
  }

  void push(PanelSession session, Config config) {
    if (config == _fromHost) {
      return;
    }
    session.send(PanelFrame(PanelChannel.config, config.toJson()));
  }
}

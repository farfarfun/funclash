import 'dart:async';

import 'package:funclash/common/constant.dart';
import 'package:funclash/common/preferences.dart';
import 'package:funclash/common/print.dart';
import 'package:funclash/common/system.dart';
import 'package:funclash/core/service.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_core_bridge.dart';
import 'package:funclash/remote/panel_event_bridge.dart';
import 'package:funclash/remote/panel_server.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';

/// Settings converge here on the last one, never racing to bind the same port.
final class PanelHost {
  PanelHost({
    List<PanelChannelHandler> handlers = const [],
    Future<PanelSettings?> Function()? readSettings,
    Future<void> Function(PanelSettings settings)? writeSettings,
  }) : _handlers = handlers,
       _readSettings = readSettings ?? preferences.getPanelSettings,
       _writeSettings = writeSettings ?? preferences.savePanelSettings;

  final List<PanelChannelHandler> _handlers;
  final Future<PanelSettings?> Function() _readSettings;
  final Future<void> Function(PanelSettings settings) _writeSettings;

  StreamSubscription<PanelSession>? _arrivals;
  PanelServer? _server;
  PanelSettings _settings = const PanelSettings();
  PanelSettings? _wanted;
  Future<void>? _converging;
  bool _closed = false;

  PanelSettings get settings => _settings;

  bool get isRunning => _server?.isRunning ?? false;

  Uri? get address => _server?.address;

  Future<void> load({required PanelConfigSource config}) async {
    if (_closed) {
      return;
    }
    // A token minted on each launch would change under the person reading it.
    final stored = await _readSettings();
    if (stored == null) {
      _settings = PanelSettings.fresh();
      await _writeSettings(_settings);
    } else {
      _settings = stored;
    }
    if (_closed) {
      return;
    }
    final server = _server ??= PanelServer(config: config);
    _arrivals ??= server.sessions.listen(_attach);
    await _converge(_settings);
  }

  void _attach(PanelSession session) {
    for (final handler in _handlers) {
      handler.attach(session);
    }
  }

  Future<void> apply(PanelSettings settings) async {
    if (_closed) {
      return;
    }
    _settings = settings;
    await _writeSettings(settings);
    await _converge(settings);
  }

  /// The bridge is down because the app is, so the settings keep saying on.
  Future<void> shutdown() async {
    _closed = true;
    await _converge(const PanelSettings());
    await _arrivals?.cancel();
    _arrivals = null;
    final server = _server;
    _server = null;
    await server?.dispose();
  }

  Future<void> _converge(PanelSettings settings) {
    _wanted = settings;
    return _converging ??= _drain().whenComplete(() {
      _converging = null;
    });
  }

  Future<void> _drain() async {
    var settings = _wanted;
    while (settings != null) {
      _wanted = null;
      final server = _server;
      if (server != null) {
        try {
          await server.start(_closed ? const PanelSettings() : settings);
        } catch (error) {
          commonPrint.log(
            'panel bridge could not take $settings: $error',
            logLevel: LogLevel.warning,
          );
        }
      }
      settings = _wanted;
    }
  }
}

final panelHost = system.isDesktop && !safeModeBuild
    ? PanelHost(
        handlers: [
          PanelCoreBridge(core: coreService),
          PanelEventBridge(),
        ],
      )
    : null;

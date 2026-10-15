import 'dart:ui' show Brightness, Color;

import 'package:funclash/common/provider_reader.dart';
import 'package:funclash/models/models.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;

abstract interface class WindowPort {
  Future<void> init(int version, WindowProps props);

  /// Every desktop runner leaves the window hidden until [init] reveals it, so
  /// a failure before that point would leave the error screen with no window.
  Future<void> showInitFailure({required AsyncCallback onExit});

  Future<WindowProps?> captureNormalGeometry(WindowProps current);

  /// Returns whether a backdrop is now drawn behind the content.
  Future<bool> setBlur({
    required bool enabled,
    required Brightness brightness,
    required Color tint,
  });

  Future<void> show();

  Future<void> hide();

  Future<void> toggle();

  Future<void> close();

  void forceExit();
}

abstract interface class TrayPort {
  Future<void> shutdown();

  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  });

  Future<void> updateTitle({
    required bool showTrayTitle,
    required Traffic traffic,
  });
}

abstract interface class NavigationPort {
  List<NavigationItem> getItems({bool openLogs, bool hasProxies});
}

WindowPort? windowPort;
TrayPort? trayPort;
NavigationPort? navigationPort;

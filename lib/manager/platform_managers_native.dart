import 'package:funclash/manager/android_manager.dart';
import 'package:funclash/manager/hotkey_manager.dart';
import 'package:funclash/manager/proxy_manager.dart';
import 'package:funclash/manager/tile_manager.dart';
import 'package:funclash/manager/tray_manager.dart';
import 'package:funclash/manager/vpn_manager.dart';
import 'package:funclash/manager/window_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:funclash/common/desktop_startup.dart';

Widget buildPlatformManagers({
  required bool isDesktop,
  required Stream<void>? terminateSignals,
  required Widget child,
}) {
  if (isDesktop && desktopStartup.headless) {
    return WindowManager(terminateSignals: terminateSignals, child: child);
  }
  return isDesktop
      ? WindowManager(
          terminateSignals: terminateSignals,
          child: TrayManager(
            child: HotKeyManager(child: ProxyManager(child: child)),
          ),
        )
      : AndroidManager(child: TileManager(child: child));
}

Widget buildPlatformApp({required bool isDesktop, required Widget child}) {
  return isDesktop
      ? WindowHeaderContainer(child: child)
      : VpnManager(child: child);
}

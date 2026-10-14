import 'package:fl_clash/manager/android_manager.dart';
import 'package:fl_clash/manager/hotkey_manager.dart';
import 'package:fl_clash/manager/proxy_manager.dart';
import 'package:fl_clash/manager/tile_manager.dart';
import 'package:fl_clash/manager/tray_manager.dart';
import 'package:fl_clash/manager/vpn_manager.dart';
import 'package:fl_clash/manager/window_manager.dart';
import 'package:flutter/widgets.dart';

Widget buildPlatformManagers({
  required bool isDesktop,
  required Stream<void>? terminateSignals,
  required Widget child,
}) {
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

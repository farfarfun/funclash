import 'package:flutter/widgets.dart';

/// The window, the tray, the hotkeys, the system proxy and the VPN are all
/// the host's to run, and a tab has no title bar of its own to draw.
Widget buildPlatformManagers({
  required bool isDesktop,
  required Stream<void>? terminateSignals,
  required Widget child,
}) => child;

Widget buildPlatformApp({required bool isDesktop, required Widget child}) =>
    child;

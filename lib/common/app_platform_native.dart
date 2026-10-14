import 'dart:io';

/// The one place that knows the operating system; `system.is*` forwards here.
abstract final class AppPlatform {
  static bool get isWindows => Platform.isWindows;

  static bool get isMacOS => Platform.isMacOS;

  static bool get isLinux => Platform.isLinux;

  static bool get isAndroid => Platform.isAndroid;

  static bool get isWeb => false;

  static String get operatingSystem => Platform.operatingSystem;

  static String get executablePath => Platform.resolvedExecutable;

  static Map<String, String> get environment => Platform.environment;

  static int get currentRss => ProcessInfo.currentRss;

  static Stream<void>? watchTerminateSignal() => ProcessSignal.sigterm.watch();

  static Never exitProcess() => exit(0);
}

/// No operating system here; the desktop this panel controls answers for it.
abstract final class AppPlatform {
  static bool get isWindows => false;

  static bool get isMacOS => false;

  static bool get isLinux => false;

  static bool get isAndroid => false;

  static bool get isWeb => true;

  static String get operatingSystem => 'web';

  static String get executablePath =>
      throw UnsupportedError('a browser tab has no executable path');

  static Map<String, String> get environment => const {};

  static int get currentRss => 0;

  static Stream<void>? watchTerminateSignal() => null;

  static Never exitProcess([int code = 0]) =>
      throw UnsupportedError('a browser tab cannot exit itself');
}

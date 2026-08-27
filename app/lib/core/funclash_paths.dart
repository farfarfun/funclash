import 'dart:io';

/// Mirrors `launcher/src/core/paths.js`: both the Node CLI and this desktop
/// app resolve the same `~/.funclash` layout, so `funclash install` (CLI)
/// and "Start core" (this app) can operate on the same install without any
/// extra configuration.
class FunclashPaths {
  FunclashPaths._();

  static String get _home {
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError("Could not resolve the current user's home directory.");
    }
    return home;
  }

  static String get root => '$_home${Platform.pathSeparator}.funclash';

  static String get binDir => '$root${Platform.pathSeparator}bin';

  static String get coreBinary =>
      '$binDir${Platform.pathSeparator}${Platform.isWindows ? 'mihomo.exe' : 'mihomo'}';

  static String get configDir => '$root${Platform.pathSeparator}config';

  static String get configFile => '$configDir${Platform.pathSeparator}config.yaml';
}

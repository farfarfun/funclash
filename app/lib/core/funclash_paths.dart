import 'dart:io';

/// 对齐 `launcher/src/core/paths.js`，使 Node CLI 与桌面应用使用同一目录布局。
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

  /// 对齐 FlClash 的 `<appSupportDir>/profiles/` 布局，每行配置对应一个 YAML 文件。
  static String get profilesDir => '$root${Platform.pathSeparator}profiles';

  static String profileFile(int id) => '$profilesDir${Platform.pathSeparator}$id.yaml';
}

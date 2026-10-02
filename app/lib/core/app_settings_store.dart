import 'dart:convert';
import 'dart:io';

import 'funclash_paths.dart';

/// 将设置页填写的 mihomo 控制器地址（host/port/secret）持久化为 JSON，
/// 避免应用重启后每次恢复为本机默认值。该功能用于连接 CLI 启动的外部控制器。
///
/// secret 是控制器凭据，优先从 [secretEnvVar] 环境变量读取（优先级高于配置文件）；
/// 走环境变量时不会写入 JSON 文件，这样部署方可以做到凭据完全不落盘。
/// 仍然需要落盘的情况下，文件权限会收紧到仅本人可读写。
class AppSettingsStore {
  /// 控制器 secret 的环境变量名，与 `launcher/src/config/config-manager.js` 保持一致。
  static const secretEnvVar = 'FUNCLASH_SECRET';

  static const defaults = (host: '127.0.0.1', port: 9090, secret: '');

  final File _file;

  /// 来自环境变量（或测试注入）的 secret；为 null 表示应当使用文件里的那份。
  final String? _secretOverride;

  AppSettingsStore._(this._file, this._secretOverride);

  /// [secretOverride] 仅供测试注入，默认取 [secretEnvVar] 环境变量。
  factory AppSettingsStore.open({String? path, String? secretOverride}) {
    final settingsPath = path ?? '${FunclashPaths.root}${Platform.pathSeparator}app_settings.json';
    final override = secretOverride ?? Platform.environment[secretEnvVar];
    return AppSettingsStore._(File(settingsPath), (override == null || override.isEmpty) ? null : override);
  }

  /// 环境变量里配置了 secret 时为 true，此时 secret 不会被持久化。
  bool get hasSecretOverride => _secretOverride != null;

  ({String host, int port, String secret}) load() {
    if (!_file.existsSync()) {
      return (host: defaults.host, port: defaults.port, secret: _secretOverride ?? defaults.secret);
    }
    try {
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return (
        host: json['host'] as String? ?? defaults.host,
        port: json['port'] as int? ?? defaults.port,
        secret: _secretOverride ?? (json['secret'] as String? ?? defaults.secret),
      );
    } catch (_) {
      return (host: defaults.host, port: defaults.port, secret: _secretOverride ?? defaults.secret);
    }
  }

  void save({required String host, required int port, required String secret}) {
    _file.parent.createSync(recursive: true);
    // secret 来自环境变量时不落盘，避免把凭据又写回明文 JSON。
    _file.writeAsStringSync(
      jsonEncode({'host': host, 'port': port, 'secret': hasSecretOverride ? '' : secret}),
    );
    _restrictPermissions();
  }

  /// 把设置文件收紧为 0600。Dart 没有 chmod API，只能调用系统命令；
  /// 失败时忽略——权限收紧是额外加固，不应该让保存设置这件事失败。
  void _restrictPermissions() {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', ['600', _file.path]);
    } catch (_) {
      // 平台没有 chmod 时跳过。
    }
  }
}

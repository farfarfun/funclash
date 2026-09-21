import 'dart:convert';
import 'dart:io';

import 'funclash_paths.dart';

/// 将设置页填写的 mihomo 控制器地址（host/port/secret）持久化为 JSON，
/// 避免应用重启后每次恢复为本机默认值。该功能用于连接 CLI 启动的外部控制器。
class AppSettingsStore {
  static const defaults = (host: '127.0.0.1', port: 9090, secret: '');

  final File _file;

  AppSettingsStore._(this._file);

  factory AppSettingsStore.open({String? path}) {
    final settingsPath = path ?? '${FunclashPaths.root}${Platform.pathSeparator}app_settings.json';
    return AppSettingsStore._(File(settingsPath));
  }

  ({String host, int port, String secret}) load() {
    if (!_file.existsSync()) return defaults;
    try {
      final json = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
      return (
        host: json['host'] as String? ?? defaults.host,
        port: json['port'] as int? ?? defaults.port,
        secret: json['secret'] as String? ?? defaults.secret,
      );
    } catch (_) {
      return defaults;
    }
  }

  void save({required String host, required int port, required String secret}) {
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync(jsonEncode({'host': host, 'port': port, 'secret': secret}));
  }
}

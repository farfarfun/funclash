import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/flclash_backup/flclash_backup_importer.dart';
import '../core/funclash_paths.dart';
import '../core/mihomo_api_client.dart';
import '../database/profiles_database.dart';
import '../models/profile.dart';
import 'core_provider.dart';

/// 管理用户添加的订阅，并持久化到 [ProfilesDatabase]。
///
/// 数据库结构与 FlClash 的 `profiles` 表一致，可通过
/// [importFlClashBackupZip] 直接导入备份。
class ProfilesController extends Notifier<List<Profile>> {
  late final ProfilesDatabase _db;

  @override
  List<Profile> build() {
    _db = ProfilesDatabase.open();
    ref.onDispose(_db.close);
    return _load();
  }

  List<Profile> _load() => _db.listProfiles().map(Profile.fromRow).toList();

  void add(Profile profile) {
    _db.upsertProfile(profile.toRow());
    state = _load();
  }

  void remove(int id) {
    _db.deleteProfile(id);
    state = _load();
  }

  /// 导入 FlClash `backup.zip`，合并订阅后从数据库重新加载 [state]。
  Future<FlClashImportResult> importFlClashBackup(String zipFilePath) async {
    final result = await importFlClashBackupZip(zipFilePath, db: _db);
    state = _load();
    return result;
  }

  /// 获取订阅 YAML，并通过 `PUT /configs` 的 payload 模式发送到运行中的内核。
  ///
  /// 成功获取的内容缓存到 `<root>/profiles/<id>.yaml`。网络请求失败时使用本地副本，
  /// 使导入的订阅在原始 URL 失效后仍可使用（见 [importFlClashBackup]）。
  Future<void> apply(int id) async {
    final profile = state.firstWhere((p) => p.id == id);
    final localFile = File(FunclashPaths.profileFile(id));

    String? yaml;
    try {
      final response = await http.get(Uri.parse(profile.url));
      if (response.statusCode == 200) {
        yaml = response.body;
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(yaml);
      }
    } catch (_) {
      // 网络或 URL 失败时在下方回退到本地副本。
    }
    if (yaml == null && await localFile.exists()) {
      yaml = await localFile.readAsString();
    }
    if (yaml == null) {
      throw MihomoApiException('Failed to fetch profile YAML and no local copy is available');
    }

    final client = ref.read(mihomoApiClientProvider);
    await client.applyConfigPayload(yaml);
    final updated = profile.copyWith(lastAppliedAt: DateTime.now());
    _db.upsertProfile(updated.toRow());
    state = _load();
  }
}

final profilesProvider = NotifierProvider<ProfilesController, List<Profile>>(ProfilesController.new);

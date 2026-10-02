import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../core/funclash_paths.dart';

const _columns = [
  'id',
  'label',
  'current_group_name',
  'url',
  'last_update_date',
  'overwrite_type',
  'script_id',
  'auto_update_duration_millis',
  'subscription_info',
  'auto_update',
  'selected_map',
  'unfold_set',
  '"order"',
];

/// `profiles` 表的一行，与 FlClash 的 Drift 表结构逐列一致。
///
/// 因此可用 `INSERT ... SELECT` 合并 FlClash 备份中的 `database.sqlite`，
/// 无需逐字段转换。
class ProfileRow {
  final int id;
  final String label;
  final String? currentGroupName;
  final String url;
  final DateTime? lastUpdateDate;
  final String overwriteType;
  final int? scriptId;
  final int autoUpdateDurationMillis;
  final String? subscriptionInfo;
  final bool autoUpdate;
  final String selectedMap;
  final String unfoldSet;
  final int? order;

  const ProfileRow({
    required this.id,
    required this.label,
    this.currentGroupName,
    required this.url,
    this.lastUpdateDate,
    this.overwriteType = 'none',
    this.scriptId,
    this.autoUpdateDurationMillis = 0,
    this.subscriptionInfo,
    this.autoUpdate = false,
    this.selectedMap = '{}',
    this.unfoldSet = '[]',
    this.order,
  });

  factory ProfileRow.fromRow(Row row) => ProfileRow(
        id: row['id'] as int,
        label: row['label'] as String,
        currentGroupName: row['current_group_name'] as String?,
        url: row['url'] as String,
        // Drift 将 DateTime 持久化为 Unix 秒，而不是毫秒。
        lastUpdateDate: row['last_update_date'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch((row['last_update_date'] as int) * 1000, isUtc: true),
        overwriteType: row['overwrite_type'] as String,
        scriptId: row['script_id'] as int?,
        autoUpdateDurationMillis: row['auto_update_duration_millis'] as int,
        subscriptionInfo: row['subscription_info'] as String?,
        autoUpdate: (row['auto_update'] as int) != 0,
        selectedMap: row['selected_map'] as String,
        unfoldSet: row['unfold_set'] as String,
        order: row['order'] as int?,
      );
}

/// 基于 `package:sqlite3` 的轻量手写封装，不依赖 Drift 代码生成。
///
/// 表结构与 FlClash 的 `profiles` 表一致，可直接导入其备份数据库。
class ProfilesDatabase {
  final Database _db;

  ProfilesDatabase._(this._db);

  /// 打开订阅数据库，不存在时创建。
  ///
  /// 默认路径为 `<FunclashPaths.root>/database.sqlite`；测试应传入 [path]。
  factory ProfilesDatabase.open({String? path}) {
    final dbPath = path ?? '${FunclashPaths.root}${Platform.pathSeparator}database.sqlite';
    File(dbPath).parent.createSync(recursive: true);
    final db = sqlite3.open(dbPath);
    final instance = ProfilesDatabase._(db);
    instance._createSchema();
    return instance;
  }

  void _createSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY,
        label TEXT NOT NULL,
        current_group_name TEXT,
        url TEXT NOT NULL,
        last_update_date INTEGER,
        overwrite_type TEXT NOT NULL DEFAULT 'none',
        script_id INTEGER,
        auto_update_duration_millis INTEGER NOT NULL DEFAULT 0,
        subscription_info TEXT,
        auto_update INTEGER NOT NULL DEFAULT 0,
        selected_map TEXT NOT NULL DEFAULT '{}',
        unfold_set TEXT NOT NULL DEFAULT '[]',
        "order" INTEGER
      );
    ''');
  }

  List<ProfileRow> listProfiles() {
    final result = _db.select('SELECT * FROM profiles ORDER BY "order" IS NULL, "order", id;');
    return result.map(ProfileRow.fromRow).toList();
  }

  void upsertProfile(ProfileRow profile) {
    _db.execute('''
      INSERT INTO profiles (${_columns.join(', ')})
      VALUES (${List.filled(_columns.length, '?').join(', ')})
      ON CONFLICT(id) DO UPDATE SET
        label = excluded.label,
        current_group_name = excluded.current_group_name,
        url = excluded.url,
        last_update_date = excluded.last_update_date,
        overwrite_type = excluded.overwrite_type,
        script_id = excluded.script_id,
        auto_update_duration_millis = excluded.auto_update_duration_millis,
        subscription_info = excluded.subscription_info,
        auto_update = excluded.auto_update,
        selected_map = excluded.selected_map,
        unfold_set = excluded.unfold_set,
        "order" = excluded."order";
    ''', [
      profile.id,
      profile.label,
      profile.currentGroupName,
      profile.url,
      profile.lastUpdateDate == null ? null : profile.lastUpdateDate!.toUtc().millisecondsSinceEpoch ~/ 1000,
      profile.overwriteType,
      profile.scriptId,
      profile.autoUpdateDurationMillis,
      profile.subscriptionInfo,
      profile.autoUpdate ? 1 : 0,
      profile.selectedMap,
      profile.unfoldSet,
      profile.order,
    ]);
  }

  void deleteProfile(int id) {
    _db.execute('DELETE FROM profiles WHERE id = ?;', [id]);
  }

  /// 将另一个兼容 FlClash 的数据库中的订阅行合并到当前数据库。
  ///
  /// 使用以 `id` 为键的 `INSERT OR REPLACE`，用于导入 FlClash 备份中的
  /// `database.sqlite`。
  List<int> importFromFlClashDatabase(String extractedDbPath) {
    _db.execute('ATTACH DATABASE ? AS src;', [extractedDbPath]);
    try {
      final ids = _db.select('SELECT id FROM src.profiles;').map((r) => r['id'] as int).toList();
      _db.execute('''
        INSERT OR REPLACE INTO profiles (${_columns.join(', ')})
        SELECT ${_columns.join(', ')} FROM src.profiles;
      ''');
      return ids;
    } finally {
      _db.execute('DETACH DATABASE src;');
    }
  }

  void close() => _db.dispose();
}

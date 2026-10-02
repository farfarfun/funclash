import 'profiles_store.dart';

/// Web 平台的订阅存储：只在内存中保存。
///
/// `package:sqlite3` 依赖 `dart:ffi`，Web 构建用不了；而 Web 版客户端的定位是
/// 连接一个已经在运行的内核（订阅由内核侧或桌面端维护），所以这里不做持久化，
/// 刷新页面后订阅列表会清空。
class InMemoryProfilesStore implements ProfilesStore {
  final Map<int, ProfileRow> _rows = {};

  @override
  List<ProfileRow> listProfiles() {
    final rows = _rows.values.toList();
    // 与 SQLite 实现的 `ORDER BY "order" IS NULL, "order", id` 保持一致。
    rows.sort((a, b) {
      if (a.order == null && b.order == null) return a.id.compareTo(b.id);
      if (a.order == null) return 1;
      if (b.order == null) return -1;
      final byOrder = a.order!.compareTo(b.order!);
      return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
    });
    return rows;
  }

  @override
  void upsertProfile(ProfileRow profile) => _rows[profile.id] = profile;

  @override
  void deleteProfile(int id) => _rows.remove(id);

  @override
  List<int> importFromFlClashDatabase(String extractedDbPath) {
    throw UnsupportedError('Web 端无法读取本地 FlClash 备份数据库，请在桌面端导入。');
  }

  @override
  void close() => _rows.clear();
}

/// 供 `profiles_store_factory.dart` 条件导入。
ProfilesStore createPlatformProfilesStore({String? path}) => InMemoryProfilesStore();

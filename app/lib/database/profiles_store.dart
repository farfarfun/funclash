/// 订阅存储的平台无关接口与行数据结构。
///
/// 这里**不能**引入 `package:sqlite3`：该包走 `dart:ffi`，Web 构建不可用。
/// 具体实现见 `profiles_database.dart`（原生平台，SQLite）与
/// `profiles_store_memory.dart`（Web，内存），由 `profiles_store_factory.dart` 选择。
library;

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
}

/// 订阅存储接口。原生平台由 SQLite 实现并持久化，Web 平台只在内存中保存。
abstract interface class ProfilesStore {
  /// 按 FlClash 的排序规则（`order` 为空的排在最后）列出全部订阅。
  List<ProfileRow> listProfiles();

  /// 按 `id` 插入或更新一条订阅。
  void upsertProfile(ProfileRow profile);

  /// 删除指定 `id` 的订阅。
  void deleteProfile(int id);

  /// 合并另一个兼容 FlClash 的 `database.sqlite`，返回导入的订阅 id 列表。
  ///
  /// Web 平台读不到本地 SQLite 文件，实现会抛 [UnsupportedError]。
  List<int> importFromFlClashDatabase(String extractedDbPath);

  /// 释放底层资源。
  void close();
}

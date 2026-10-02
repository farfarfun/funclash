import '../database/profiles_store.dart';

/// 用户添加的订阅源。启用时从 [url] 获取 YAML，并通过 `PUT /configs`
/// 的 payload 模式发送给 mihomo。成功获取的内容缓存到
/// `<root>/profiles/<id>.yaml`，后续网络请求失败时使用本地副本。
///
/// [id] 等字段与 FlClash 的 `profiles` 表保持一致（见 [ProfileRow]），
/// [lastAppliedAt] 对应该表的 `last_update_date` 列。
class Profile {
  final int id;
  final String name;
  final String url;
  final DateTime? lastAppliedAt;
  final String? currentGroupName;
  final bool autoUpdate;
  final Duration autoUpdateDuration;
  final int? order;

  const Profile({
    required this.id,
    required this.name,
    required this.url,
    this.lastAppliedAt,
    this.currentGroupName,
    this.autoUpdate = false,
    this.autoUpdateDuration = Duration.zero,
    this.order,
  });

  Profile copyWith({DateTime? lastAppliedAt}) {
    return Profile(
      id: id,
      name: name,
      url: url,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
      currentGroupName: currentGroupName,
      autoUpdate: autoUpdate,
      autoUpdateDuration: autoUpdateDuration,
      order: order,
    );
  }

  factory Profile.fromRow(ProfileRow row) => Profile(
        id: row.id,
        name: row.label,
        url: row.url,
        lastAppliedAt: row.lastUpdateDate,
        currentGroupName: row.currentGroupName,
        autoUpdate: row.autoUpdate,
        autoUpdateDuration: Duration(milliseconds: row.autoUpdateDurationMillis),
        order: row.order,
      );

  ProfileRow toRow() => ProfileRow(
        id: id,
        label: name,
        currentGroupName: currentGroupName,
        url: url,
        lastUpdateDate: lastAppliedAt,
        autoUpdate: autoUpdate,
        autoUpdateDurationMillis: autoUpdateDuration.inMilliseconds,
        order: order,
      );
}

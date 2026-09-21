import '../database/profiles_database.dart';

/// A subscription source the user has added. funclash fetches the raw
/// config/subscription YAML from [url] and pushes it to the mihomo core via
/// `PUT /configs` (payload mode) when activated — see
/// `MihomoApiClient.applyConfigPayload`. Each successful fetch is cached to
/// `<root>/profiles/<id>.yaml` (`ProfilesController.apply`); if a later fetch
/// fails — no connectivity, or a URL imported from an old FlClash backup
/// that's since gone stale — that local copy is used instead.
///
/// [id] and the fields below intentionally mirror FlClash's `profiles`
/// table (see [ProfileRow]) so a profile imported from a FlClash backup
/// round-trips without lossy conversion; [lastAppliedAt] maps onto that
/// table's `last_update_date` column.
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

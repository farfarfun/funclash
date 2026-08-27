/// A subscription source the user has added. funclash fetches the raw
/// config/subscription YAML from [url] and pushes it to the mihomo core via
/// `PUT /configs` (payload mode) when activated — see
/// `MihomoApiClient.applyConfigPayload`.
class Profile {
  final String id;
  final String name;
  final String url;
  final DateTime addedAt;
  final DateTime? lastAppliedAt;

  const Profile({
    required this.id,
    required this.name,
    required this.url,
    required this.addedAt,
    this.lastAppliedAt,
  });

  Profile copyWith({DateTime? lastAppliedAt}) {
    return Profile(
      id: id,
      name: name,
      url: url,
      addedAt: addedAt,
      lastAppliedAt: lastAppliedAt ?? this.lastAppliedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'addedAt': addedAt.toIso8601String(),
        'lastAppliedAt': lastAppliedAt?.toIso8601String(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        name: json['name'] as String,
        url: json['url'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        lastAppliedAt: json['lastAppliedAt'] != null
            ? DateTime.tryParse(json['lastAppliedAt'] as String)
            : null,
      );
}

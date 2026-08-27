class ProxyHistoryEntry {
  final DateTime time;
  final int delay;

  const ProxyHistoryEntry({required this.time, required this.delay});

  factory ProxyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ProxyHistoryEntry(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      delay: (json['delay'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A single proxy or proxy-group entry as returned by mihomo's `/proxies` API.
class Proxy {
  final String name;
  final String type;
  final bool udp;
  final List<String> all;
  final String? now;
  final List<ProxyHistoryEntry> history;

  const Proxy({
    required this.name,
    required this.type,
    required this.udp,
    required this.all,
    required this.history,
    this.now,
  });

  /// True if this entry is a group (Selector/URLTest/Fallback/...) rather
  /// than a single leaf proxy.
  bool get isGroup => all.isNotEmpty;

  int? get latestDelay => history.isEmpty ? null : history.last.delay;

  factory Proxy.fromJson(String name, Map<String, dynamic> json) {
    return Proxy(
      name: name,
      type: json['type'] as String? ?? 'Unknown',
      udp: json['udp'] as bool? ?? false,
      all: (json['all'] as List?)?.cast<String>() ?? const [],
      now: json['now'] as String?,
      history: (json['history'] as List? ?? const [])
          .map((e) => ProxyHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

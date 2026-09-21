/// 代理节点的一次延迟测量。
class ProxyHistoryEntry {
  final DateTime time;
  final int delay;

  const ProxyHistoryEntry({required this.time, required this.delay});

  /// 从 mihomo `/proxies` 响应解析测量记录。
  factory ProxyHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ProxyHistoryEntry(
      time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      delay: (json['delay'] as num?)?.toInt() ?? 0,
    );
  }
}

/// mihomo `/proxies` API 返回的代理或代理组。
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

  /// 当前条目是否为代理组，而不是单个代理节点。
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

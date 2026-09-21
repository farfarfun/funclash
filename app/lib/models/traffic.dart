/// mihomo `/traffic` WebSocket 推送的一次流量采样。
class Traffic {
  final int up;
  final int down;

  const Traffic({required this.up, required this.down});

  /// 从 mihomo 流量消息解析采样。
  factory Traffic.fromJson(Map<String, dynamic> json) {
    return Traffic(
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
    );
  }
}

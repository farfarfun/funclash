/// mihomo 连接的网络元数据。
class ConnectionMetadata {
  final String network;
  final String type;
  final String sourceIP;
  final String destinationIP;
  final String host;
  final String destinationPort;

  const ConnectionMetadata({
    required this.network,
    required this.type,
    required this.sourceIP,
    required this.destinationIP,
    required this.host,
    required this.destinationPort,
  });

  /// 从 mihomo `/connections` 响应解析元数据。
  factory ConnectionMetadata.fromJson(Map<String, dynamic> json) {
    return ConnectionMetadata(
      network: json['network'] as String? ?? '',
      type: json['type'] as String? ?? '',
      sourceIP: json['sourceIP'] as String? ?? '',
      destinationIP: json['destinationIP'] as String? ?? '',
      host: json['host'] as String? ?? '',
      destinationPort: json['destinationPort'] as String? ?? '',
    );
  }

  String get displayTarget => host.isNotEmpty ? host : destinationIP;
}

/// mihomo 当前连接及其流量和规则信息。
class Connection {
  final String id;
  final ConnectionMetadata metadata;
  final int upload;
  final int download;
  final DateTime start;
  final List<String> chains;
  final String rule;

  const Connection({
    required this.id,
    required this.metadata,
    required this.upload,
    required this.download,
    required this.start,
    required this.chains,
    required this.rule,
  });

  /// 从 mihomo `/connections` 响应解析连接。
  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String? ?? '',
      metadata: ConnectionMetadata.fromJson(
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
      chains: (json['chains'] as List?)?.cast<String>() ?? const [],
      rule: json['rule'] as String? ?? '',
    );
  }
}

/// `/connections` 返回的总流量和连接列表。
class ConnectionsSnapshot {
  final int downloadTotal;
  final int uploadTotal;
  final List<Connection> connections;

  const ConnectionsSnapshot({
    required this.downloadTotal,
    required this.uploadTotal,
    required this.connections,
  });

  /// 从 mihomo `/connections` 响应解析快照。
  factory ConnectionsSnapshot.fromJson(Map<String, dynamic> json) {
    return ConnectionsSnapshot(
      downloadTotal: (json['downloadTotal'] as num?)?.toInt() ?? 0,
      uploadTotal: (json['uploadTotal'] as num?)?.toInt() ?? 0,
      connections: (json['connections'] as List? ?? const [])
          .map((e) => Connection.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

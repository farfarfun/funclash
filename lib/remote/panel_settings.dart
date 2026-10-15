import 'dart:convert';
import 'dart:math';

import 'package:funclash/common/constant.dart';

// Outside `Config` on purpose: that one is mirrored to every panel and takes
// writes back, so a panel could widen `allowLan` or read its own token.
class PanelSettings {
  final bool enabled;
  final bool allowLan;
  final int port;
  final String token;

  const PanelSettings({
    this.enabled = false,
    this.allowLan = false,
    this.port = panelPort,
    this.token = '',
  });

  PanelSettings.fresh({this.enabled = false, this.allowLan = false})
    : port = panelPort,
      token = newPanelToken();

  bool get isUsable => enabled && token.isNotEmpty;

  String get bindAddress => allowLan ? anyAddress : localhost;

  PanelSettings copyWith({
    bool? enabled,
    bool? allowLan,
    int? port,
    String? token,
  }) {
    return PanelSettings(
      enabled: enabled ?? this.enabled,
      allowLan: allowLan ?? this.allowLan,
      port: port ?? this.port,
      token: token ?? this.token,
    );
  }

  static PanelSettings? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final port = json['port'];
    final token = json['token'];
    return PanelSettings(
      enabled: json['enabled'] == true,
      allowLan: json['allowLan'] == true,
      port: port is int && port > 0 && port <= 65535 ? port : panelPort,
      token: token is String ? token : '',
    );
  }

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'allowLan': allowLan,
    'port': port,
    'token': token,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelSettings &&
          other.enabled == enabled &&
          other.allowLan == allowLan &&
          other.port == port &&
          other.token == token;

  @override
  int get hashCode => Object.hash(enabled, allowLan, port, token);

  @override
  String toString() =>
      'PanelSettings(${enabled ? 'on' : 'off'}, $bindAddress:$port, '
      'token: ${token.isEmpty ? 'unset' : '${token.length} chars'})';
}

/// `Random()` would be seeded well enough to look random and badly enough to
/// be guessed.
String newPanelToken() {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

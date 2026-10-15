import 'dart:convert';

import 'package:funclash/core/method.dart';

// Spoken by the desktop host and the browser panel alike: no platform imports.

const panelProtocolVersion = 1;

const panelHandshakeTimeout = Duration(seconds: 10);

enum PanelChannel {
  core,
  db,
  config,
  fs;

  static PanelChannel? fromWire(Object? wire) => values.asNameMap()[wire];
}

final class PanelFrame {
  final PanelChannel channel;
  final Object? payload;

  const PanelFrame(this.channel, this.payload);

  Map<String, Object?> toJson() => {'c': channel.name, 'p': payload};

  static PanelFrame? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final channel = PanelChannel.fromWire(json['c']);
    if (channel == null) {
      return null;
    }
    return PanelFrame(channel, json['p']);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PanelFrame &&
          other.channel == channel &&
          _sameJson(other.payload, payload);

  @override
  int get hashCode => Object.hash(channel, json.encode(payload));

  @override
  String toString() => 'PanelFrame(${channel.name}, $payload)';
}

bool _sameJson(Object? a, Object? b) =>
    identical(a, b) || json.encode(a) == json.encode(b);

/// What a channel that answers carries: the id pairs a reply with its call,
/// and the method is the channel's own vocabulary rather than this layer's.
final class PanelCall {
  final String id;
  final String method;
  final Object? arguments;

  const PanelCall({required this.id, required this.method, this.arguments});

  Map<String, Object?> toJson() => {
    'id': id,
    'method': method,
    'arguments': arguments,
  };

  static PanelCall? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    final method = json['method'];
    if (id is! String || method is! String) {
      return null;
    }
    return PanelCall(id: id, method: method, arguments: json['arguments']);
  }
}

final class PanelReply {
  final String id;
  final Object? result;
  final CoreMethodError? error;

  const PanelReply({required this.id, this.result, this.error});

  PanelReply.failed(this.id, {required String code, required String message})
    : result = null,
      error = CoreMethodError(code: code, message: message);

  Map<String, Object?> toJson() => {
    'id': id,
    'result': result,
    if (error != null) 'error': error!.toJson(),
  };

  static PanelReply? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final id = json['id'];
    if (id is! String) {
      return null;
    }
    final error = json['error'];
    return PanelReply(
      id: id,
      result: json['result'],
      error: error is Map
          ? CoreMethodError.fromJson(Map<String, Object?>.from(error))
          : null,
    );
  }
}

/// The one payload on an answering channel that nobody asked for, so it
/// carries no id. The data stays raw here: what an event means belongs to the
/// channel, not to the envelope.
final class PanelEvent {
  final Object? data;

  const PanelEvent(this.data);

  Map<String, Object?> toJson() => {'event': data};

  static PanelEvent? fromJson(Object? json) {
    if (json is! Map || !json.containsKey('event')) {
      return null;
    }
    return PanelEvent(json['event']);
  }
}

enum PanelRejectReason {
  badToken,
  protocolMismatch,
  malformed,
  timeout;

  static PanelRejectReason fromWire(Object? wire) =>
      values.asNameMap()[wire] ?? malformed;
}

/// Travels in band because a browser cannot set headers on a WebSocket, and a
/// token in the query string lands in logs and in `Referer`.
final class PanelHello {
  final int protocol;
  final String token;

  const PanelHello({required this.protocol, required this.token});

  Map<String, Object?> toJson() => {
    'hello': {'protocol': protocol, 'token': token},
  };

  static PanelHello? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final hello = json['hello'];
    if (hello is! Map) {
      return null;
    }
    final protocol = hello['protocol'];
    final token = hello['token'];
    if (protocol is! int || token is! String) {
      return null;
    }
    return PanelHello(protocol: protocol, token: token);
  }
}

final class PanelWelcome {
  final int protocol;
  final Map<String, Object?> config;

  const PanelWelcome({required this.protocol, required this.config});

  Map<String, Object?> toJson() => {
    'welcome': {'protocol': protocol, 'config': config},
  };

  static PanelWelcome? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final welcome = json['welcome'];
    if (welcome is! Map) {
      return null;
    }
    final protocol = welcome['protocol'];
    final config = welcome['config'];
    if (protocol is! int || config is! Map) {
      return null;
    }
    return PanelWelcome(
      protocol: protocol,
      config: config.cast<String, Object?>(),
    );
  }
}

final class PanelReject {
  final PanelRejectReason reason;

  const PanelReject(this.reason);

  Map<String, Object?> toJson() => {
    'reject': {'reason': reason.name},
  };

  static PanelReject? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final reject = json['reject'];
    if (reject is! Map) {
      return null;
    }
    return PanelReject(PanelRejectReason.fromWire(reject['reason']));
  }
}

PanelRejectReason? rejectHello(PanelHello? hello, String expectedToken) {
  if (hello == null) {
    return PanelRejectReason.malformed;
  }
  if (hello.protocol != panelProtocolVersion) {
    return PanelRejectReason.protocolMismatch;
  }
  if (expectedToken.isEmpty ||
      !_constantTimeEquals(hello.token, expectedToken)) {
    return PanelRejectReason.badToken;
  }
  return null;
}

/// The bridge hands out full control of the application, and a loopback
/// attacker can time a reply closely enough for an early return to leak the
/// token a byte at a time.
bool _constantTimeEquals(String a, String b) {
  final left = utf8.encode(a);
  final right = utf8.encode(b);
  var difference = left.length ^ right.length;
  for (var i = 0; i < left.length; i++) {
    difference |= left[i] ^ right[i % right.length];
  }
  return difference == 0;
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_protocol.dart';

const _token = 'EJ4nVwqkqUJb4v0Wn0kcBp2ZptMXAOO8gN1MbcG2Mcc';

PanelHello _hello({int? protocol, String? token}) => PanelHello(
  protocol: protocol ?? panelProtocolVersion,
  token: token ?? _token,
);

Object? _roundTrip(Object value) => json.decode(json.encode(value));

void main() {
  group('PanelFrame', () {
    test('survives a round trip on every channel', () {
      for (final channel in PanelChannel.values) {
        final frame = PanelFrame(channel, {'id': 1, 'method': channel.name});
        expect(PanelFrame.fromJson(_roundTrip(frame)), frame);
      }
    });

    test('carries a payload of any json shape', () {
      for (final payload in <Object?>[
        null,
        7,
        'text',
        [1, 'two', null],
        {
          'nested': {'deep': true},
        },
      ]) {
        final frame = PanelFrame(PanelChannel.core, payload);
        expect(PanelFrame.fromJson(_roundTrip(frame))?.payload, payload);
      }
    });

    test('reads nothing out of a frame it cannot place', () {
      for (final json in <Object?>[
        null,
        'text',
        [],
        <String, Object?>{},
        {'p': 1},
        {'c': 'nosuchchannel', 'p': 1},
      ]) {
        expect(PanelFrame.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('PanelCall', () {
    test('survives a round trip', () {
      const call = PanelCall(
        id: 'c1',
        method: 'getTraffic',
        arguments: {'path': 'a'},
      );

      final decoded = PanelCall.fromJson(_roundTrip(call));
      expect(decoded?.id, 'c1');
      expect(decoded?.method, 'getTraffic');
      expect(decoded?.arguments, {'path': 'a'});
    });

    test('carries arguments of any json shape, absent included', () {
      for (final arguments in <Object?>[
        null,
        7,
        'text',
        [1, null],
        {'k': 'v'},
      ]) {
        final call = PanelCall(id: 'c', method: 'm', arguments: arguments);
        expect(PanelCall.fromJson(_roundTrip(call))?.arguments, arguments);
      }
    });

    test('reads nothing out of a payload it cannot place', () {
      for (final json in <Object?>[
        null,
        'text',
        <String, Object?>{},
        {'method': 'getTraffic'},
        {'id': 'c1'},
        {'id': 1, 'method': 'getTraffic'},
        {'id': 'c1', 'method': 2},
      ]) {
        expect(PanelCall.fromJson(json), isNull, reason: '$json');
      }
    });
  });

  group('PanelEvent', () {
    test('survives a round trip, one event or a batch', () {
      for (final data in <Object?>[
        {'type': 'loaded', 'data': 'p'},
        [
          {'type': 'loaded', 'data': 'a'},
        ],
        null,
      ]) {
        final event = PanelEvent(data);
        expect(PanelEvent.fromJson(_roundTrip(event))?.data, data);
      }
    });

    test('reads nothing out of a payload that names no event', () {
      for (final json in <Object?>[
        null,
        'text',
        <String, Object?>{},
        {'id': 'c1', 'result': 1},
      ]) {
        expect(PanelEvent.fromJson(json), isNull, reason: '$json');
      }
    });

    test('an event and a reply never read as each other', () {
      final event = _roundTrip(const PanelEvent({'type': 'loaded'}));
      final reply = _roundTrip(const PanelReply(id: 'c1', result: 1));

      expect(PanelReply.fromJson(event), isNull);
      expect(PanelEvent.fromJson(reply), isNull);
    });
  });

  group('PanelReply', () {
    test('survives a round trip carrying a result', () {
      const reply = PanelReply(id: 'c1', result: [1, 2]);

      final decoded = PanelReply.fromJson(_roundTrip(reply));
      expect(decoded?.id, 'c1');
      expect(decoded?.result, [1, 2]);
      expect(decoded?.error, isNull);
    });

    test('survives a round trip carrying an error', () {
      const reply = PanelReply(
        id: 'c1',
        error: CoreMethodError(
          code: 'transport_disconnected',
          message: 'no core',
          details: {'tries': 2},
        ),
      );

      final decoded = PanelReply.fromJson(_roundTrip(reply));
      expect(decoded?.error?.code, 'transport_disconnected');
      expect(decoded?.error?.message, 'no core');
      expect(decoded?.error?.details, {'tries': 2});
    });

    test('a null result is a result, not a missing one', () {
      const reply = PanelReply(id: 'c1');

      final decoded = PanelReply.fromJson(_roundTrip(reply));
      expect(decoded?.result, isNull);
      expect(decoded?.error, isNull);
    });

    test('failed says the code and the message and holds no result', () {
      final reply = PanelReply.failed('c1', code: 'oops', message: 'why');

      final decoded = PanelReply.fromJson(_roundTrip(reply));
      expect(decoded?.error?.code, 'oops');
      expect(decoded?.error?.message, 'why');
      expect(decoded?.result, isNull);
    });

    test('reads nothing out of a payload with no id', () {
      for (final json in <Object?>[
        null,
        'text',
        <String, Object?>{},
        {'result': 1},
        {'id': 1},
      ]) {
        expect(PanelReply.fromJson(json), isNull, reason: '$json');
      }
    });

    test('a reply is no call, holding no method', () {
      expect(
        PanelCall.fromJson(_roundTrip(const PanelReply(id: 'c1'))),
        isNull,
      );
    });

    test('a call read as a reply is an empty one, never a failure', () {
      final call = _roundTrip(const PanelCall(id: 'c1', method: 'getTraffic'));

      final asReply = PanelReply.fromJson(call);
      expect(asReply?.result, isNull);
      expect(asReply?.error, isNull);
    });
  });

  group('rejectHello', () {
    test('accepts the host token at the current protocol', () {
      expect(rejectHello(_hello(), _token), isNull);
    });

    test('names the reason it refused', () {
      expect(
        rejectHello(_hello(token: 'wrong'), _token),
        PanelRejectReason.badToken,
      );
      expect(
        rejectHello(_hello(protocol: panelProtocolVersion + 1), _token),
        PanelRejectReason.protocolMismatch,
      );
      expect(rejectHello(null, _token), PanelRejectReason.malformed);
    });

    test('refuses every token while the host has none', () {
      expect(rejectHello(_hello(token: ''), ''), PanelRejectReason.badToken);
      expect(rejectHello(_hello(), ''), PanelRejectReason.badToken);
    });

    test('refuses a token that is only a prefix of the host token', () {
      expect(
        rejectHello(_hello(token: _token.substring(0, 8)), _token),
        PanelRejectReason.badToken,
      );
      expect(
        rejectHello(_hello(token: '$_token-extra'), _token),
        PanelRejectReason.badToken,
      );
    });

    test('checks the protocol before the token', () {
      expect(
        rejectHello(
          _hello(protocol: panelProtocolVersion + 1, token: 'wrong'),
          _token,
        ),
        PanelRejectReason.protocolMismatch,
      );
    });
  });

  group('handshake messages', () {
    test('a hello survives a round trip', () {
      final hello = PanelHello.fromJson(_roundTrip(_hello()));
      expect(hello?.protocol, panelProtocolVersion);
      expect(hello?.token, _token);
    });

    test('a welcome carries the config it was given', () {
      const welcome = PanelWelcome(
        protocol: panelProtocolVersion,
        config: {
          'appSettingProps': {'openLogs': true},
        },
      );
      final decoded = PanelWelcome.fromJson(_roundTrip(welcome));
      expect(decoded?.protocol, panelProtocolVersion);
      expect(decoded?.config, welcome.config);
    });

    test('a reject carries its reason', () {
      for (final reason in PanelRejectReason.values) {
        expect(
          PanelReject.fromJson(_roundTrip(PanelReject(reason)))?.reason,
          reason,
        );
      }
    });

    test('an unknown reason reads as malformed rather than throwing', () {
      expect(
        PanelReject.fromJson({
          'reject': {'reason': 'invented'},
        })?.reason,
        PanelRejectReason.malformed,
      );
    });

    test('the three messages never read as each other', () {
      final hello = _roundTrip(_hello());
      final welcome = _roundTrip(
        const PanelWelcome(protocol: panelProtocolVersion, config: {}),
      );
      final reject = _roundTrip(const PanelReject(PanelRejectReason.timeout));

      expect(PanelHello.fromJson(welcome), isNull);
      expect(PanelHello.fromJson(reject), isNull);
      expect(PanelWelcome.fromJson(hello), isNull);
      expect(PanelWelcome.fromJson(reject), isNull);
      expect(PanelReject.fromJson(hello), isNull);
      expect(PanelReject.fromJson(welcome), isNull);
    });

    test('a hello missing either field reads as nothing', () {
      expect(
        PanelHello.fromJson({
          'hello': {'token': _token},
        }),
        isNull,
      );
      expect(
        PanelHello.fromJson({
          'hello': {'protocol': 1},
        }),
        isNull,
      );
      expect(
        PanelHello.fromJson({
          'hello': {'protocol': '1', 'token': _token},
        }),
        isNull,
      );
    });
  });
}

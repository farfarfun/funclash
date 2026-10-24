import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/constant.dart';
import 'package:funclash/remote/panel_settings.dart';

void main() {
  group('PanelSettings', () {
    test('starts off, on the loopback, with no token to let anyone in', () {
      const settings = PanelSettings();

      expect(settings.enabled, isFalse);
      expect(settings.allowLan, isFalse);
      expect(settings.port, panelPort);
      expect(settings.token, isEmpty);
      expect(settings.isUsable, isFalse);
      expect(settings.bindAddress, localhost);
    });

    test('a fresh installation enables authenticated LAN access', () {
      final settings = PanelSettings.fresh();

      expect(settings.token, isNotEmpty);
      expect(settings.enabled, isTrue);
      expect(settings.allowLan, isTrue);
      expect(settings.isUsable, isTrue);
      expect(settings.port, panelPort);
    });

    test('is unusable until it is both on and holds a token', () {
      const token = 'a-token';

      expect(const PanelSettings(enabled: true).isUsable, isFalse);
      expect(const PanelSettings(token: token).isUsable, isFalse);
      expect(const PanelSettings(enabled: true, token: token).isUsable, isTrue);
    });

    test('keeps the loopback until it is told to allow the LAN', () {
      expect(const PanelSettings().bindAddress, localhost);
      expect(const PanelSettings(allowLan: true).bindAddress, anyAddress);
    });

    test('copyWith replaces one field and keeps the rest', () {
      final settings = PanelSettings.fresh(enabled: true, allowLan: true);

      final moved = settings.copyWith(port: 1080);
      expect(moved.port, 1080);
      expect(moved.enabled, isTrue);
      expect(moved.allowLan, isTrue);
      expect(moved.token, settings.token);

      expect(settings.copyWith(), settings);
    });

    test('reads back everything it wrote', () {
      final settings = PanelSettings.fresh(
        enabled: true,
        allowLan: true,
      ).copyWith(port: 1080);

      expect(
        PanelSettings.fromJson(json.decode(json.encode(settings))),
        settings,
      );
    });

    test('reads nothing out of a value that is not a map', () {
      for (final value in <Object?>[null, 7, 'text', <Object?>[]]) {
        expect(PanelSettings.fromJson(value), isNull, reason: '$value');
      }
    });

    test('reads a field it cannot use as the default', () {
      expect(
        PanelSettings.fromJson(<String, Object?>{}),
        const PanelSettings(),
      );
      expect(
        PanelSettings.fromJson({'enabled': 'yes', 'allowLan': 1, 'token': 42}),
        const PanelSettings(),
      );
    });

    test('refuses a port no socket could bind', () {
      for (final port in <Object?>[0, -1, 65536, '1080', 1.5, null]) {
        expect(
          PanelSettings.fromJson({'port': port})?.port,
          panelPort,
          reason: '$port',
        );
      }
      expect(PanelSettings.fromJson({'port': 65535})?.port, 65535);
      expect(PanelSettings.fromJson({'port': 1})?.port, 1);
    });

    test('never prints the token it holds', () {
      final settings = PanelSettings.fresh(enabled: true);

      expect(settings.toString(), isNot(contains(settings.token)));
      expect(settings.toString(), contains('${settings.token.length} chars'));
      expect(const PanelSettings().toString(), contains('unset'));
    });

    test('two with the same fields are the same settings', () {
      final settings = PanelSettings.fresh(enabled: true);
      final same = settings.copyWith();

      expect(same, settings);
      expect(same.hashCode, settings.hashCode);
      expect(settings.copyWith(allowLan: false), isNot(settings));
      expect(settings.copyWith(token: 'other'), isNot(settings));
    });
  });

  group('newPanelToken', () {
    test('is url safe, unpadded, and long enough to be unguessable', () {
      final token = newPanelToken();

      expect(token, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(base64Url.decode(base64Url.normalize(token)), hasLength(32));
    });

    test('differs every time', () {
      expect({for (var i = 0; i < 32; i++) newPanelToken()}, hasLength(32));
    });
  });
}

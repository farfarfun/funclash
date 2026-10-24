import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/bootstrap.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/common/desktop_startup.dart';
import 'package:funclash/state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'headless first run rejects missing consent before mounting UI',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'headless-consent-',
      );
      final resolveLock = SingleInstanceLock.resolvePath;
      SingleInstanceLock.resolvePath = () async => '${directory.path}/app.lock';
      desktopStartup = const DesktopStartup(headless: true);
      SharedPreferences.setMockInitialValues({'version': 1});
      PackageInfo.setMockInitialValues(
        appName: 'FunClash',
        packageName: 'com.farfarfun.funclash',
        version: '1.0.10',
        buildNumber: '1',
        buildSignature: '',
      );
      addTearDown(() async {
        desktopStartup = const DesktopStartup();
        SingleInstanceLock.resolvePath = resolveLock;
        await singleInstanceLock.release();
        directory.deleteSync(recursive: true);
      });

      await expectLater(
        bootstrap.init(1),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'terminal instructions',
            allOf(
              contains('--show-disclaimer'),
              contains('--accept-disclaimer'),
            ),
          ),
        ),
      );

      expect(await preferences.getConfigMap(), isNull);
      expect(await preferences.getPanelSettings(), isNull);
      expect(globalState.isAttach, isFalse);
    },
  );
}

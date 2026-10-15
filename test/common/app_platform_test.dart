import 'dart:io';

import 'package:funclash/common/app_platform.dart';
import 'package:funclash/common/system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('answers for the host it is compiled against', () {
    expect(AppPlatform.isWindows, Platform.isWindows);
    expect(AppPlatform.isMacOS, Platform.isMacOS);
    expect(AppPlatform.isLinux, Platform.isLinux);
    expect(AppPlatform.isAndroid, Platform.isAndroid);
    expect(AppPlatform.operatingSystem, Platform.operatingSystem);
    expect(AppPlatform.executablePath, Platform.resolvedExecutable);
    expect(AppPlatform.environment, Platform.environment);
    expect(AppPlatform.currentRss, greaterThan(0));
    expect(AppPlatform.isWeb, isFalse);
  });

  test('at most one family answers true', () {
    expect(
      [
        AppPlatform.isWindows,
        AppPlatform.isMacOS,
        AppPlatform.isLinux,
        AppPlatform.isAndroid,
        AppPlatform.isWeb,
      ].where((answer) => answer).length,
      lessThanOrEqualTo(1),
      reason:
          'Two getters wired to the same `Platform` member is the mistake this '
          'catches. `isWeb` is the fifth family rather than the absence of the '
          'other four, which is what lets `SupportPlatform.currentPlatform` '
          'answer for a browser tab instead of throwing.',
    );
  });

  test('system forwards to it rather than keeping its own answer', () {
    expect(system.isWindows, AppPlatform.isWindows);
    expect(system.isMacOS, AppPlatform.isMacOS);
    expect(system.isLinux, AppPlatform.isLinux);
    expect(system.isAndroid, AppPlatform.isAndroid);
    expect(system.isWeb, AppPlatform.isWeb);
    expect(
      system.isDesktop,
      AppPlatform.isWindows || AppPlatform.isMacOS || AppPlatform.isLinux,
    );
  });
}

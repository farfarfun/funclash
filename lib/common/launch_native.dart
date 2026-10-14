import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'app_platform.dart';
import 'constant.dart';
import 'system.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launcher.setup(appName: appName, appPath: AppPlatform.executablePath);
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  @visibleForTesting
  static LaunchAtStartup launcher = launchAtStartup;

  Future<bool> get isEnable async {
    return launcher.isEnabled();
  }

  Future<bool> enable() async {
    return launcher.enable();
  }

  Future<bool> disable() async {
    return launcher.disable();
  }

  Future<void> updateStatus(bool isAutoLaunch) async {
    if (kDebugMode) {
      return;
    }
    if (await isEnable == isAutoLaunch) return;
    if (isAutoLaunch == true) {
      unawaited(enable());
    } else {
      unawaited(disable());
    }
  }
}

final _autoLaunch = system.isDesktop && !safeModeBuild ? AutoLaunch() : null;

Future<void> syncAutoLaunch(bool isAutoLaunch) async =>
    _autoLaunch?.updateStatus(isAutoLaunch);

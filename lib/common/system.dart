import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_clash/common/boot_record.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:flutter/services.dart';

class System {
  static System? _instance;
  bool _isTV = false;

  System._internal();

  factory System() {
    _instance ??= System._internal();
    return _instance!;
  }

  bool get isDesktop => isWindows || isMacOS || isLinux;

  bool get isWindows => AppPlatform.isWindows;

  bool get isMacOS => AppPlatform.isMacOS;

  bool get isAndroid => AppPlatform.isAndroid;

  bool get isLinux => AppPlatform.isLinux;

  bool get isWeb => AppPlatform.isWeb;

  bool get isTV => _isTV;

  Future<int> init() async {
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    _isTV = switch (deviceInfo) {
      AndroidDeviceInfo(:final systemFeatures) => systemFeatures.any(
        const {
          'android.hardware.type.television',
          'android.software.leanback',
        }.contains,
      ),
      _ => false,
    };
    return switch (AppPlatform.operatingSystem) {
      'macos' => (deviceInfo as MacOsDeviceInfo).majorVersion,
      'android' => (deviceInfo as AndroidDeviceInfo).version.sdkInt,
      'windows' => (deviceInfo as WindowsDeviceInfo).majorVersion,
      String() => 0,
    };
  }

  Future<bool> didCrashOnPreviousExecution() async {
    if (!isAndroid) return false;
    return await app?.didCrashOnPreviousExecution() ?? false;
  }

  Future<AppExitInfo?> lastExitInfo() async {
    if (!isAndroid) return null;
    return app?.getLastExitInfo();
  }

  Future<void> back() async {
    await app?.moveTaskToBack();
  }

  Future<void> exit() async {
    if (system.isAndroid) {
      await SystemNavigator.pop();
    }
  }

  /// Windows can only watch SIGINT and SIGHUP.
  Stream<void>? watchTerminateSignals() =>
      isDesktop && !isWindows ? AppPlatform.watchTerminateSignal() : null;

  Never forceExit() => AppPlatform.exitProcess();
}

final system = System();

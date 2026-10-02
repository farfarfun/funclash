import 'dart:async';
import 'dart:io';

import 'core_launcher.dart';
import 'noop_launcher.dart';

/// 在支持 `dart:io` 的平台上由 `core_launcher_factory.dart` 条件导入。
CoreLauncher createPlatformLauncher() {
  final launcher = DesktopCoreLauncher();
  return launcher.canLaunch ? launcher : NoopCoreLauncher();
}

/// 在桌面平台将 mihomo 作为子进程启动，并通过 external-controller REST API 通信。
class DesktopCoreLauncher implements CoreLauncher {
  Process? _process;
  bool _stopRequested = false;
  final _unexpectedExitController = StreamController<int>.broadcast();

  @override
  bool get canLaunch => Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  bool get isRunning => _process != null;

  @override
  Stream<int> get onUnexpectedExit => _unexpectedExitController.stream;

  @override
  Future<void> start({required String corePath, required String homeDir, required String configFile}) async {
    if (_process != null) return;
    if (!canLaunch) {
      throw UnsupportedError('DesktopCoreLauncher is not supported on this platform.');
    }
    _stopRequested = false;
    final process = await Process.start(
      corePath,
      ['-d', homeDir, '-f', configFile],
      mode: ProcessStartMode.normal,
    );
    _process = process;
    unawaited(process.exitCode.then((code) {
      _process = null;
      if (!_stopRequested) {
        _unexpectedExitController.add(code);
      }
    }));
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    _stopRequested = true;
    process.kill(ProcessSignal.sigterm);
    await process.exitCode;
    _process = null;
  }
}

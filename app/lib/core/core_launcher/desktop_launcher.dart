import 'dart:async';
import 'dart:io';

import 'core_launcher.dart';
import 'noop_launcher.dart';

/// Selected via conditional import by `core_launcher_factory.dart` on
/// platforms where dart:io is available.
CoreLauncher createPlatformLauncher() {
  final launcher = DesktopCoreLauncher();
  return launcher.canLaunch ? launcher : NoopCoreLauncher();
}

/// Linux desktop: launches mihomo as a subprocess, mirroring FlClash's
/// `DirectCoreLauncher` (`Process.start(corePath, [...])`), except we talk to
/// it over the external-controller REST API instead of an RPC socket.
class DesktopCoreLauncher implements CoreLauncher {
  Process? _process;

  @override
  bool get canLaunch => Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  bool get isRunning => _process != null;

  @override
  Future<void> start({required String corePath, required String homeDir, required String configFile}) async {
    if (_process != null) return;
    if (!canLaunch) {
      throw UnsupportedError('DesktopCoreLauncher is not supported on this platform.');
    }
    final process = await Process.start(
      corePath,
      ['-d', homeDir, '-f', configFile],
      mode: ProcessStartMode.normal,
    );
    _process = process;
    unawaited(process.exitCode.then((_) => _process = null));
  }

  @override
  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    process.kill(ProcessSignal.sigterm);
    await process.exitCode;
    _process = null;
  }
}

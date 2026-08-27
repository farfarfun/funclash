import 'core_launcher.dart';

/// Used on Web (and Android/iOS until Phase 1/2 add native core embedding):
/// this platform cannot spawn the mihomo process itself, so the app just
/// connects to a controller URL the user points it at (e.g. one started via
/// the `funclash` CLI launcher).
class NoopCoreLauncher implements CoreLauncher {
  @override
  bool get canLaunch => false;

  @override
  bool get isRunning => false;

  @override
  Stream<int> get onUnexpectedExit => const Stream.empty();

  @override
  Future<void> start({required String corePath, required String homeDir, required String configFile}) async {
    throw UnsupportedError('This platform cannot launch a mihomo core process directly. '
        'Connect to an already-running core instead (see Settings).');
  }

  @override
  Future<void> stop() async {}
}

/// Manages the lifecycle of a mihomo core process, when this platform is
/// able to launch one itself (see [DesktopCoreLauncher]). Platforms that
/// cannot spawn processes (Web, and Android/iOS until Phase 1/2 land) use
/// [NoopCoreLauncher] and rely on a core that is already running elsewhere.
abstract class CoreLauncher {
  bool get canLaunch;

  bool get isRunning;

  Future<void> start({required String corePath, required String homeDir, required String configFile});

  Future<void> stop();
}

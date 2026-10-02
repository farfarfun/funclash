import 'core_launcher.dart';

/// 用于无法直接启动 mihomo 进程的平台，仅连接用户指定的控制器地址。
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

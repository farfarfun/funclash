/// 管理 mihomo 内核进程的生命周期。
///
/// 支持启动子进程的平台使用 [DesktopCoreLauncher]；Web 以及尚未实现原生内核的
/// Android/iOS 使用 [NoopCoreLauncher]，连接其他位置已经运行的内核。
abstract class CoreLauncher {
  bool get canLaunch;

  bool get isRunning;

  Future<void> start({required String corePath, required String homeDir, required String configFile});

  Future<void> stop();

  /// 当 [start] 启动的进程未经 [stop] 主动停止便退出时发送退出码。
  ///
  /// 例如进程崩溃或被外部终止；由 [stop] 发起的退出不会发送事件。
  Stream<int> get onUnexpectedExit;
}

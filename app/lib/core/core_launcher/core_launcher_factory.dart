import 'core_launcher.dart';
import 'platform_launcher_stub.dart' if (dart.library.io) 'desktop_launcher.dart';

/// 为当前平台选择 [CoreLauncher]：Linux/macOS/Windows 使用子进程启动器，
/// 其他平台使用 [NoopCoreLauncher]。
CoreLauncher createCoreLauncher() => createPlatformLauncher();

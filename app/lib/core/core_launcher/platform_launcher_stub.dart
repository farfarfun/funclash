import 'core_launcher.dart';
import 'noop_launcher.dart';

/// Web 构建不支持 `dart:io`，因此使用不可启动内核的实现。
CoreLauncher createPlatformLauncher() => NoopCoreLauncher();

import 'core_launcher.dart';
import 'platform_launcher_stub.dart' if (dart.library.io) 'desktop_launcher.dart';

/// Picks the right [CoreLauncher] for the current platform: a subprocess
/// launcher on Linux/macOS/Windows, [NoopCoreLauncher] everywhere else
/// (Web today; Android/iOS until Phase 1/2 add native core embedding).
CoreLauncher createCoreLauncher() => createPlatformLauncher();

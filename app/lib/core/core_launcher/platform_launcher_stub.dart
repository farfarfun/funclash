import 'core_launcher.dart';
import 'noop_launcher.dart';

/// Web build: dart:io is unavailable, so there is never a launchable core.
CoreLauncher createPlatformLauncher() => NoopCoreLauncher();

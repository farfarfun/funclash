import 'package:fl_clash/core/desktop/launch_policy.dart';

/// A panel launches nothing, so a refusal it hears about was already classified
/// by the desktop that hit it and arrives as a `HelperException`.
SmartAppControlState readSmartAppControlState() =>
    SmartAppControlState.unknown;

int? hostLaunchOsError(Object? error) => null;

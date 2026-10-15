import 'dart:io';

import 'package:funclash/core/desktop/launch_policy.dart';
import 'package:win32_registry/win32_registry.dart';

SmartAppControlState readSmartAppControlState() {
  if (!Platform.isWindows) {
    return SmartAppControlState.unknown;
  }
  try {
    final key = LOCAL_MACHINE.open(
      r'SYSTEM\CurrentControlSet\Control\CI\Policy',
    );
    try {
      return switch (key.getInt('VerifiedAndReputablePolicyState')) {
        0 => SmartAppControlState.off,
        1 => SmartAppControlState.on,
        2 => SmartAppControlState.evaluation,
        _ => SmartAppControlState.unknown,
      };
    } finally {
      key.close();
    }
  } catch (_) {
    return SmartAppControlState.unknown;
  }
}

/// A zero is the platform reporting no code at all, not error zero.
int? hostLaunchOsError(Object? error) {
  return switch (error) {
    ProcessException(:final errorCode) => errorCode == 0 ? null : errorCode,
    _ => null,
  };
}

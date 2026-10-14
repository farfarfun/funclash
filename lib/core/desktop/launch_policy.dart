import 'package:fl_clash/core/desktop/launch_host.dart';
import 'package:fl_clash/core/desktop/model.dart';

/// CreateProcess reports these when a policy, not the file, refused the image:
/// ERROR_VIRUS_INFECTED, ERROR_INVALID_IMAGE_HASH, ERROR_ACCESS_DISABLED_BY_POLICY.
const policyBlockedOsErrors = {225, 577, 1260};

enum SmartAppControlState { off, on, evaluation, unknown }

typedef SmartAppControlStateReader = SmartAppControlState Function();

/// Swapped out by tests; the real reader needs a Windows registry.
SmartAppControlStateReader smartAppControlStateReader =
    readSmartAppControlState;

/// The OS error behind a failed Core launch, whether the Helper spawned it
/// (the code travels in the response details, older Helpers only in the
/// message) or the app did, which only the host that owns the exception type
/// can say.
int? launchOsError(Object? error) {
  return switch (error) {
    DesktopCoreFailure(:final cause) => launchOsError(cause),
    HelperException(code: 'processLaunchFailed') => _helperOsError(error),
    _ => hostLaunchOsError(error),
  };
}

bool isPolicyBlockedLaunch(Object? error) {
  return policyBlockedOsErrors.contains(launchOsError(error));
}

int? _helperOsError(HelperException error) {
  final details = error.details;
  if (details is Map && details['osError'] is int) {
    return details['osError'] as int;
  }
  final match = RegExp(r'os error (\d+)').firstMatch(error.message);
  return match == null ? null : int.tryParse(match.group(1)!);
}

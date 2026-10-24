import 'package:funclash/common/system_dns.dart';
import 'package:funclash/enum/enum.dart';

Never _noHostShell(String what) =>
    throw UnsupportedError('a browser tab cannot run $what');

abstract final class SystemShell {
  static bool get hasHelperService => false;

  static Future<bool> checkIsAdmin() async => false;

  /// The desktop granted its own Core access long before a panel connected.
  static Future<void> grantHomeDirAccess(String homeDirPath) async {}

  static Future<AuthorizeCode> authorizeCore() async => AuthorizeCode.error;
}

class Windows {
  bool runas(String command, String arguments, {bool showWindow = true}) =>
      _noHostShell('a shell verb');
}

const Windows? windows = null;

class MacOS implements SystemDnsPort {
  @override
  Future<String?> resolveDefaultService() async => _noHostShell('route');

  @override
  Future<List<String>?> readDnsServers(String service) async =>
      _noHostShell('networksetup');

  @override
  Future<bool> writeDnsServers(String service, List<String> servers) async =>
      _noHostShell('networksetup');
}

const MacOS? macOS = null;

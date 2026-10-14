import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/system.dart';
import 'package:proxy/proxy.dart';

final _proxy = system.isDesktop && !safeModeBuild ? Proxy() : null;

/// Null is a platform with no system proxy to set, which is not a failure the
/// caller should report; false is one that had it and refused.
Future<bool?> startSystemProxy(int port, List<String> bypassDomain) async =>
    _proxy?.startProxy(port, bypassDomain);

Future<bool?> stopSystemProxy() async => _proxy?.stopProxy();

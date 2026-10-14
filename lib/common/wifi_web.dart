import 'package:fl_clash/common/wifi_permission.dart';

/// A tab has no network of its own to name and no prompt to raise about one:
/// on-demand belongs to the desktop host, so these answer instead of throwing.
Future<String?> readWifiSsid() async => null;

Future<WifiPermission> checkWifiPermission() async => WifiPermission.denied;

Future<WifiPermission> requestWifiPermission() async => WifiPermission.denied;

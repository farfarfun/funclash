import 'package:fl_clash/common/wifi_permission.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

Future<String?> readWifiSsid() => wifiSsidManager.getSsid();

Future<WifiPermission> checkWifiPermission() async =>
    _permissionOf(await wifiSsidManager.checkPermission());

Future<WifiPermission> requestWifiPermission() async =>
    _permissionOf(await wifiSsidManager.requestPermission());

WifiPermission _permissionOf(WifiSsidPermission permission) {
  return switch (permission) {
    WifiSsidPermission.granted => WifiPermission.granted,
    WifiSsidPermission.denied => WifiPermission.denied,
    WifiSsidPermission.permanentlyDenied => WifiPermission.permanentlyDenied,
  };
}

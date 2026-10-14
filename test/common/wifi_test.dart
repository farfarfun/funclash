import 'package:fl_clash/common/wifi_native.dart';
import 'package:fl_clash/common/wifi_permission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wifi_ssid');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answers(Object? state) {
    messenger.setMockMethodCallHandler(channel, (_) async => state);
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('every state the plugin reports has a name the app owns', () async {
    answers(0);
    expect(await checkWifiPermission(), WifiPermission.granted);
    expect(await requestWifiPermission(), WifiPermission.granted);

    answers(1);
    expect(await checkWifiPermission(), WifiPermission.denied);

    answers(2);
    expect(await requestWifiPermission(), WifiPermission.permanentlyDenied);
  });

  test('a state the plugin leaves out reads as a denial', () async {
    answers(null);

    expect(await checkWifiPermission(), WifiPermission.denied);
  });

  test('the SSID passes through, absent or not', () async {
    answers('Office Wi-Fi');
    expect(await readWifiSsid(), 'Office Wi-Fi');

    answers(null);
    expect(await readWifiSsid(), isNull);
  });
}

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/preferences.dart';
import 'package:funclash/providers/panel.dart';
import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:funclash/state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('installs the bundled panel without a network download', () async {
    SharedPreferences.setMockInitialValues({});
    await preferences.savePanelSettings(const PanelSettings());
    globalState.packageInfo = PackageInfo(
      appName: 'FunClash',
      packageName: 'funclash',
      version: '1.0.10',
      buildNumber: '1',
    );
    final root = Directory.systemTemp.createTempSync('panel-bundle-');
    addTearDown(() => root.deleteSync(recursive: true));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => root.path,
    );
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        null,
      );
    });
    final host = panelHost!;
    addTearDown(host.shutdown);
    await host.load(config: () => {}, pageRoot: root.path);
    final archive = Archive()
      ..add(ArchiveFile.string('index.html', 'offline panel'))
      ..add(ArchiveFile.string('.funclash-panel', '1.0.10'));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    binding.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (
      message,
    ) async {
      expect(
        const StringCodec().decodeMessage(message),
        'assets/panel/panel.zip',
      );
      return ByteData.sublistView(bytes);
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
      rootBundle.evict('assets/panel/panel.zip');
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(panelInstallProvider.notifier).install();

    expect(container.read(panelInstallProvider).phase, PanelPhase.ready);
    expect(File('${root.path}/index.html').readAsStringSync(), 'offline panel');
  });
}

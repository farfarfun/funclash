import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/app_dirs_web.dart' as web;
import 'package:funclash/common/file_web.dart' as files;
import 'package:funclash/core/method.dart';
import 'package:funclash/remote/panel_core_bridge.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_file_bridge.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/remote/panel_linker.dart';
import 'package:funclash/remote/panel_server.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:path/path.dart' as p;

import 'fakes.dart';

void main() {
  test('browser file and Core calls use the same host directory', () async {
    final root = Directory.systemTemp.createTempSync('panel_paths');
    addTearDown(() => root.deleteSync(recursive: true));
    final core = FakeCore(
      answer: (_, path) => File(path! as String).readAsStringSync(),
    );
    final server = PanelServer(config: () => {});
    addTearDown(server.dispose);
    final fileBridge = PanelFileBridge(root: Future.value(root.path));
    final coreBridge = PanelCoreBridge(core: core);
    server.sessions.listen((session) {
      fileBridge.attach(session);
      coreBridge.attach(session);
    });
    await server.start(
      const PanelSettings(enabled: true, port: 0, token: 'paths-test'),
    );
    final client = PanelCoreClient();
    addTearDown(client.unbind);
    final link =
        await PanelLinker(
              client,
              page: server.address!.replace(fragment: 'token=paths-test'),
            ).link()
            as PanelLinked;
    reportPanelLinked(link.session);
    addTearDown(link.session.close);

    expect(await web.resolveSupportDir(), root.path);
    expect(await web.resolveTemporaryDir(), root.path);
    expect(await web.resolveCacheDir(), root.path);
    final profile = p.join(
      await web.resolveSupportDir(),
      'profiles',
      '369053277628665860.yaml',
    );
    const config = 'proxies: []';
    await files.safeWritePathAsString(profile, config);
    expect(await files.pathExists(profile), isTrue);
    expect(
      await client.invokeMethod<String>(
        method: CoreMethod.getConfig,
        arguments: profile,
      ),
      config,
    );
    final staging = p.join(await web.resolveTemporaryDir(), 'temp-profile');
    await files.safeWritePathAsString(staging, config);
    expect(await files.readPathAsStringOrEmpty(staging), config);
    await files.safeDeletePath(staging);
    expect(File(staging).existsSync(), isFalse);
  });
}

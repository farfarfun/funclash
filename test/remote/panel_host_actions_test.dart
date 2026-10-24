import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/core/method.dart';
import 'package:funclash/manager/app_manager.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/remote/panel_core_bridge.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/remote/panel_linker.dart';
import 'package:funclash/remote/panel_server.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/test_profiles.dart';

class _Setup extends SetupAction {
  final listenerCalls = <bool>[];
  bool failStart = false;
  int applies = 0;

  @override
  Future<bool> setCoreRunning(bool running) async {
    listenerCalls.add(running);
    if (running && failStart) throw StateError('listener failed');
    return true;
  }

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {}

  @override
  void resetCoreTraffic() {}

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applies++;
    return true;
  }
}

class _Common extends CommonAction {
  @override
  Future<void> updateTraffic() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Setup setup;
  late PanelCoreClient client;
  late PanelLinked linked;

  setUp(() async {
    setup = _Setup();
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(TestProfiles.new),
        setupActionProvider.overrideWith(() => setup),
        commonActionProvider.overrideWith(_Common.new),
      ],
    );
    addTearDown(container.dispose);
    container.read(initProvider.notifier).value = true;
    final bridge = PanelCoreBridge(
      hostAction: (method, arguments) =>
          handlePanelHostAction(container.read, method, arguments),
    );
    container.listen(isStartProvider, (_, _) {
      bridge.pushStartTime(setup.startTime?.millisecondsSinceEpoch);
    });
    final server = PanelServer(
      config: () => {'currentProfileId': 369053277628665856},
    );
    addTearDown(server.dispose);
    server.sessions.listen(bridge.attach);
    await server.start(
      const PanelSettings(enabled: true, port: 0, token: 'host-actions'),
    );
    client = PanelCoreClient();
    addTearDown(client.close);
    linked =
        await PanelLinker(
              client,
              page: server.address!.replace(fragment: 'token=host-actions'),
            ).link()
            as PanelLinked;
    addTearDown(linked.session.close);
  });

  test('a panel starts and stops through the host running state', () async {
    reportPanelLinked(linked.session, config: linked.config);
    expect((await linkedPanelConfig)['currentProfileId'], 369053277628665856);
    expect(await client.getStartTime(), isNull);

    final started = client.startTimes.first;
    expect(await client.setRunning(true), isTrue);
    expect(await started, setup.startTime!.millisecondsSinceEpoch);
    expect(container.read(isStartProvider), isTrue);
    expect(container.read(proxyStateProvider).isStart, isTrue);
    expect(
      await client.getStartTime(),
      setup.startTime!.millisecondsSinceEpoch,
    );

    final stopped = client.startTimes.first;
    expect(await client.setRunning(false), isTrue);
    expect(await stopped, isNull);
    expect(container.read(proxyStateProvider).isStart, isFalse);
    expect(setup.listenerCalls, [true, false]);
  });

  test(
    'a failed host start rolls back and reaches the panel as an error',
    () async {
      setup.failStart = true;

      await expectLater(
        client.setRunning(true),
        throwsA(isA<CoreMethodException>()),
      );

      expect(container.read(isStartProvider), isFalse);
      expect(await client.getStartTime(), isNull);
    },
  );

  test(
    'profile application runs on the host and malformed actions are refused',
    () async {
      expect(await client.applyProfile(), isTrue);
      expect(setup.applies, 1);
      await expectLater(
        handlePanelHostAction(container.read, 'panel.setRunning', 'true'),
        throwsArgumentError,
      );
      expect(setup.listenerCalls, isEmpty);
    },
  );
}

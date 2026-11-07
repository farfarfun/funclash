import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/core/controller.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/action.dart';
import 'package:funclash/providers/config.dart';
import 'package:funclash/providers/core.dart';
import 'package:funclash/providers/database.dart';
import 'package:funclash/state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';

import '../helpers/test_profiles.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationCachePath() async => root;
}

class _Core extends Mock implements CoreHandlerInterface {}

class _Setup extends SetupAction {
  int applies = 0;

  @override
  void build() {}

  @override
  void applyProfileDebounce({bool silence = false, bool force = false}) {
    applies++;
  }

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) async =>
      true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HttpOverrides? previousOverrides;
  late PathProviderPlatform previousPaths;
  late HttpServer server;
  late StreamIterator<HttpRequest> requests;
  late Profile profile;
  late _Core core;
  late ProviderContainer container;

  setUpAll(() {
    directory = Directory.systemTemp.createTempSync('profile-update-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    previousOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    globalState.packageInfo = PackageInfo(
      appName: 'test',
      packageName: 'test',
      version: '1.0.0',
      buildNumber: '1',
    );
  });

  tearDownAll(() async {
    HttpOverrides.global = previousOverrides;
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = StreamIterator(server);
    profile = Profile.normal(
      label: 'Original',
      url: 'http://127.0.0.1:${server.port}/profile',
    );
    core = _Core();
    when(() => core.validateConfig(any())).thenAnswer((_) async => '');
    when(() => core.clearEffect(any())).thenAnswer((_) async => '');
    container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
        setupActionProvider.overrideWith(_Setup.new),
      ],
    );
    globalState.container = container;
  });

  tearDown(() async {
    container.dispose();
    await requests.cancel();
    await server.close(force: true);
  });

  ProfilesAction action() => container.read(profilesActionProvider.notifier);

  Future<HttpRequest> nextRequest() async {
    expect(await requests.moveNext(), isTrue);
    return requests.current;
  }

  Future<void> answer(HttpRequest request, String body) async {
    request.response.headers.set('subscription-userinfo', 'total=1024');
    request.response.write(body);
    await request.response.close();
  }

  test(
    'merges downloaded metadata into edits made while downloading',
    () async {
      final pending = action().updateProfile(profile);
      final request = await nextRequest();
      container
          .read(profilesProvider.notifier)
          .updateProfile(
            profile.id,
            (p) => p.copyWith(
              label: 'Edited',
              selectedMap: {'Group': 'New node'},
              autoUpdate: false,
            ),
          );
      await answer(request, 'proxies: []');
      await pending;

      final saved = container.read(profilesProvider).single;
      expect(saved.label, 'Edited');
      expect(saved.selectedMap, {'Group': 'New node'});
      expect(saved.autoUpdate, isFalse);
      expect(saved.subscriptionInfo?.total, 1024);
      expect(saved.lastUpdateDate, isNotNull);
      expect(await readPathAsStringOrEmpty(await profile.path), 'proxies: []');
      expect(
        (container.read(setupActionProvider.notifier) as _Setup).applies,
        1,
      );
    },
  );

  test(
    'a newer refresh wins even when the older response arrives last',
    () async {
      final older = action().updateProfile(profile);
      final first = await nextRequest();
      final newer = action().updateProfile(profile);
      final second = await nextRequest();
      await answer(second, 'new content');
      await newer;
      final saved = container.read(profilesProvider).single;
      await answer(first, 'old content');
      await older;

      expect(await readPathAsStringOrEmpty(await profile.path), 'new content');
      expect(container.read(profilesProvider).single, saved);
      expect(
        (container.read(setupActionProvider.notifier) as _Setup).applies,
        1,
      );
    },
  );

  test(
    'deleting during validation prevents the row and file returning',
    () async {
      final validating = Completer<void>();
      final validation = Completer<String>();
      when(() => core.validateConfig(any())).thenAnswer((_) {
        validating.complete();
        return validation.future;
      });
      final pending = action().updateProfile(profile);
      await answer(await nextRequest(), 'proxies: []');
      await validating.future;
      await action().deleteProfile(profile.id);
      validation.complete('');
      await pending;

      expect(container.read(profilesProvider), isEmpty);
      expect(await pathExists(await profile.path), isFalse);
    },
  );

  test('a changed subscription URL rejects the old download', () async {
    await safeWritePathAsString(await profile.path, 'saved content');
    final pending = action().updateProfile(profile);
    final request = await nextRequest();
    container
        .read(profilesProvider.notifier)
        .updateProfile(profile.id, (p) => p.copyWith(url: '${p.url}/edited'));
    await answer(request, 'old subscription');
    await pending;

    expect(await readPathAsStringOrEmpty(await profile.path), 'saved content');
    expect(container.read(profilesProvider).single.subscriptionInfo, isNull);
  });

  test('a file edited during a download stays saved', () async {
    final pending = action().updateProfile(profile);
    final request = await nextRequest();
    await safeWritePathAsString(await profile.path, 'manual edit');
    container
        .read(profilesProvider.notifier)
        .updateProfile(
          profile.id,
          (p) => p.copyWith(lastUpdateDate: DateTime.now()),
        );
    await answer(request, 'download');
    await pending;

    expect(await readPathAsStringOrEmpty(await profile.path), 'manual edit');
  });

  test(
    'setup can refresh without scheduling another profile application',
    () async {
      final pending = action().updateProfile(profile, apply: false);
      await answer(await nextRequest(), 'proxies: []');
      await pending;

      expect(container.read(profilesProvider).single.lastUpdateDate, isNotNull);
      expect(
        (container.read(setupActionProvider.notifier) as _Setup).applies,
        0,
      );
    },
  );
}

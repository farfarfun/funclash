import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/l10n/l10n.dart';
import 'package:funclash/manager/theme_manager.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/pages/home.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/state.dart';
import 'package:funclash/views/navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'helpers/test_database_providers.dart';
import 'helpers/test_profiles.dart';

/// Written only when asked for, so a normal `flutter test` run stays read-only.
const _writing = bool.fromEnvironment('SNAPSHOTS');

const _output = 'docs/snapshots';
const _size = Size(1280, 800);

/// `preview` is the name the landing page in `farfarfun/packages` fetches.
const _pages = <String, PageLabel>{
  'preview': PageLabel.dashboard,
  'proxies': PageLabel.proxies,
  'profiles': PageLabel.profiles,
  'tools': PageLabel.tools,
};

const _dashboardWidgets = [
  DashboardWidget.networkSpeed,
  DashboardWidget.systemProxyButton,
  DashboardWidget.tunButton,
  DashboardWidget.outboundMode,
  DashboardWidget.trafficUsage,
  DashboardWidget.intranetIp,
  DashboardWidget.runTime,
  DashboardWidget.proxyGroups,
  DashboardWidget.profiles,
  DashboardWidget.requests,
  DashboardWidget.dnsQueries,
];

/// The cards show a relative time, so a fixed date would render differently on
/// every run and leave a diff behind that says nothing.
DateTime _ago(Duration age) => DateTime.now().subtract(age);

final _profile =
    Profile.normal(
      label: 'Home nodes',
      url: 'https://example.com/clash.yaml',
    ).copyWith(
      currentGroupName: 'Proxy',
      selectedMap: const {'Proxy': 'Tokyo 01', 'Streaming': 'Los Angeles 02'},
      unfoldSet: const {'Proxy'},
      lastUpdateDate: _ago(const Duration(hours: 3)),
      subscriptionInfo: const SubscriptionInfo(
        upload: 21474836480,
        download: 182536110080,
        total: 1099511627776,
        expire: 1798761600,
      ),
    );

final _profiles = [
  _profile,
  Profile.normal(
    label: 'Backup nodes',
    url: 'https://example.net/backup.yaml',
  ).copyWith(
    lastUpdateDate: _ago(const Duration(hours: 15)),
    subscriptionInfo: const SubscriptionInfo(
      upload: 5368709120,
      download: 41231686144,
      total: 549755813888,
      expire: 1790985600,
    ),
  ),
  Profile.normal(
    label: 'Streaming',
    url: 'https://example.org/stream.yaml',
  ).copyWith(lastUpdateDate: _ago(const Duration(hours: 5))),
  Profile.custom(
    label: 'Lab rules',
  ).copyWith(lastUpdateDate: _ago(const Duration(minutes: 20))),
  Profile.normal(
    label: 'Office',
    url: 'https://example.com/office.yaml',
  ).copyWith(lastUpdateDate: _ago(const Duration(days: 1))),
];

const _regions = [
  'Tokyo',
  'Osaka',
  'Singapore',
  'Hong Kong',
  'Taipei',
  'Seoul',
  'Los Angeles',
  'San Jose',
  'Frankfurt',
  'London',
];

final _proxyNames = [
  for (final region in _regions)
    for (var index = 1; index <= 3; index++)
      '$region ${index.toString().padLeft(2, '0')}',
];

final _groups = [
  Group(
    name: 'Proxy',
    type: GroupType.Selector,
    hidden: false,
    now: 'Tokyo 01',
    all: [for (final name in _proxyNames) Proxy(name: name, type: 'Trojan')],
  ),
  Group(
    name: 'Streaming',
    type: GroupType.URLTest,
    hidden: false,
    now: 'Los Angeles 02',
    all: [
      for (final name in _proxyNames.take(4))
        Proxy(name: name, type: 'Shadowsocks'),
    ],
  ),
];

/// Spread so the cards show the whole range the delay colours cover.
int _delayOf(int index) => 56 + (index * 73) % 420;

final _traffics = [
  for (var index = 0; index < trafficSampleLength; index++)
    Traffic(
      up: 180000 + ((index * 37) % 11) * 42000,
      down: 1400000 + ((index * 53) % 13) * 320000,
    ),
];

/// The test binding ships Ahem, which draws every glyph as a box. The real
/// fonts are the ones the engine itself carries, plus the app's own.
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final material = Directory(
      p.join(root, 'bin', 'cache', 'artifacts', 'material_fonts'),
    );
    if (material.existsSync()) {
      final roboto = FontLoader('Roboto');
      for (final file in material.listSync().whereType<File>()) {
        final name = p.basename(file.path);
        if (const [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ].contains(name)) {
          roboto.addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          );
        }
      }
      await roboto.load();
    }
  }
  final manifest =
      json.decode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(family['family']! as String);
    for (final font
        in (family['fonts']! as List).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(font['asset']! as String));
    }
    await loader.load();
  }
}

ProviderContainer _seeded(PageLabel page) {
  final container = ProviderContainer(
    overrides: [
      profilesProvider.overrideWith(() => TestProfiles(_profiles)),
      scriptsProvider.overrideWith(TestScripts.new),
      globalRulesProvider.overrideWith(TestGlobalRules.new),
      iconSetsProvider.overrideWith(TestIconSets.new),
      clashProvidersProvider.overrideWith(TestClashProviders.new),
      currentProfileIdProvider.overrideWithBuild((_, _) => _profile.id),
      groupsProvider.overrideWithValue(_groups),
    ],
  );
  container.read(currentPageLabelProvider.notifier).toPage(page);
  container.read(viewSizeProvider.notifier).update((_) => _size);
  container.read(runTimeProvider.notifier).value = 7325000;
  container.read(localIpProvider.notifier).value = '192.168.1.24';
  container.read(coreStatusProvider.notifier).value = CoreStatus.connected;
  container.read(totalTrafficProvider.notifier).value = const Traffic(
    up: 3221225472,
    down: 24696061952,
  );
  final traffics = container.read(trafficsProvider.notifier);
  for (final traffic in _traffics) {
    traffics.addTraffic(traffic);
  }
  container.read(requestCountProvider.notifier).value = 1842;
  container.read(dnsQueryCountProvider.notifier).value = 5376;
  final url = container.read(realTestUrlProvider());
  container.read(delayDataSourceProvider.notifier).setDelays([
    for (final (index, name) in _proxyNames.indexed)
      Delay(url: url, name: name, value: _delayOf(index)),
  ]);
  container
      .read(appSettingProvider.notifier)
      .update((state) => state.copyWith(dashboardWidgets: _dashboardWidgets));
  return container;
}

/// Rasterising is real work, so it runs outside the fake clock the test binding
/// otherwise holds the frame on.
Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final encoded = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return encoded;
  });
  final file = File(p.join(_output, '$name.png'));
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    navigationPort = navigation;
    addTearDown(() => navigationPort = null);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    final suffix = mode == ThemeMode.dark ? '-dark' : '';
    for (final entry in _pages.entries) {
      testWidgets('${entry.key}$suffix', (tester) async {
        tester.view.physicalSize = _size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = _seeded(entry.value);
        addTearDown(container.dispose);
        globalState.container = container;

        final focus = FocusNode();
        addTearDown(focus.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Focus(
              focusNode: focus,
              child: RepaintBoundary(
                key: key,
                child: _SnapshotApp(mode: mode),
              ),
            ),
          ),
        );
        await tester.pump();
        // The binding hands the first focusable widget the focus, which a
        // desktop window does not; holding it here keeps the focus rings off.
        focus.requestFocus();
        await tester.pump(const Duration(milliseconds: 500));

        await _capture(tester, key, '${entry.key}$suffix');

        await tester.pumpWidget(const SizedBox.shrink());
      }, skip: !_writing);
    }
  }
}

class _SnapshotApp extends ConsumerWidget {
  const _SnapshotApp({required this.mode});

  final ThemeMode mode;

  /// The software rasteriser the test binding uses draws an elevation shadow
  /// as a hard black edge, which no window ever shows.
  ThemeData _theme(WidgetRef ref, Brightness brightness) =>
      ThemeData(
        useMaterial3: true,
        colorScheme: ref.read(genColorSchemeProvider(brightness)),
        // A window falls back to the system fonts for the glyphs Roboto lacks,
        // which a test binding has none of; the bundled one covers them.
        fontFamilyFallback: const ['JetBrainsMono'],
      ).withAppShapes.copyWith(
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: globalState.navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.delegate.supportedLocales,
      themeMode: mode,
      theme: _theme(ref, Brightness.light),
      darkTheme: _theme(ref, Brightness.dark),
      builder: (_, child) => ThemeManager(child: child!),
      home: const HomePage(),
    );
  }
}

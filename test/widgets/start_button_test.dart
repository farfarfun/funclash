import 'package:funclash/common/common.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/state.dart';
import 'package:funclash/views/dashboard/widgets/start_button.dart';
import 'package:funclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/glyph_finders.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('RunTimeText styles every hour digit alike', (tester) async {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF6750A4),
      onPrimaryContainer: Color(0xFF21005D),
    );
    for (final (hours, expected) in [(99, '99:00:00'), (100, '100:00:00')]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: colorScheme),
          home: RunTimeText(timeStamp: hours * 60 * 60 * 1000),
        ),
      );

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(RunTimeText),
          matching: find.byType(Text),
        ),
      );

      expect(text.data, expected);
      expect(text.textSpan, isNull);
      expect(text.style?.color, colorScheme.onPrimaryContainer);
      expect(
        text.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    }
  });

  testWidgets('StartButton animates its width when hours reach three digits', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWithValue([
          const Profile(id: 1, autoUpdateDuration: Duration.zero),
        ]),
        suspendProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(runTimeProvider.notifier).value = 99 * 60 * 60 * 1000;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          setTheme: false,
          homeBuilder: (child) => Scaffold(floatingActionButton: child),
          child: const StartButton(),
        ),
      ),
    );
    await tester.pump();

    final button = find.byType(FloatingActionButton);
    expect(tester.getSize(button).height, 56);
    final twoDigitWidth = tester.getSize(button).width;

    container.read(runTimeProvider.notifier).value = 100 * 60 * 60 * 1000;
    await tester.pump();
    expect(tester.getSize(button).width, twoDigitWidth);

    await tester.pump(const Duration(milliseconds: 100));
    final animatedWidth = tester.getSize(button).width;
    expect(animatedWidth, greaterThan(twoDigitWidth));

    await tester.pumpAndSettle();
    expect(tester.getSize(button).width, greaterThan(animatedWidth));
  });

  testWidgets('StartButton resets its text after the close animation', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        profilesProvider.overrideWithValue([
          const Profile(id: 1, autoUpdateDuration: Duration.zero),
        ]),
        suspendProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(runTimeProvider.notifier).value = const Duration(
      hours: 100,
      minutes: 2,
      seconds: 3,
    ).inMilliseconds;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          setTheme: false,
          homeBuilder: (child) => Scaffold(floatingActionButton: child),
          child: const StartButton(),
        ),
      ),
    );
    await tester.pump();

    final button = find.byType(FloatingActionButton);
    String runTimeText() {
      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(RunTimeText),
          matching: find.byType(Text),
        ),
      );
      return text.data ?? text.textSpan!.toPlainText();
    }

    final expandedTextWidth = tester
        .widget<AnimatedContainer>(find.byType(AnimatedContainer))
        .constraints
        ?.maxWidth;
    final expandedButtonWidth = tester.getSize(button).width;
    expect(runTimeText(), '100:02:03');

    container.read(runTimeProvider.notifier).value = null;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getSize(button).width, greaterThan(expandedButtonWidth));
    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .constraints
          ?.maxWidth,
      expandedTextWidth,
    );
    expect(runTimeText(), '100:02:03');

    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getSize(button).width, 56);
    expect(runTimeText(), '100:02:03');

    await tester.pumpAndSettle();

    expect(tester.getSize(button).width, 56);
    expect(runTimeText(), '00:00:00');
  });

  testWidgets('dispatches each toggle through the shared running state', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        profilesProvider.overrideWithValue([
          const Profile(id: 1, autoUpdateDuration: Duration.zero),
        ]),
        setupActionProvider.overrideWith(_RecordingSetupAction.new),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(runTimeProvider.notifier).value = 1;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          setTheme: false,
          homeBuilder: (child) => Scaffold(floatingActionButton: child),
          child: const StartButton(),
        ),
      ),
    );

    final action =
        container.read(setupActionProvider.notifier) as _RecordingSetupAction;
    final button = find.byType(FloatingActionButton);

    await tester.tap(button);
    expect(action.requests, [false]);
    expect(container.read(isStartProvider), isFalse);

    await tester.tap(button);
    expect(action.requests, [false, true]);
    expect(container.read(isStartProvider), isTrue);
  });
  group('docked', () {
    Future<ProviderContainer> pumpDocked(
      WidgetTester tester, {
      bool suspend = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          profilesProvider.overrideWithValue([
            const Profile(id: 1, autoUpdateDuration: Duration.zero),
          ]),
          suspendProvider.overrideWithValue(suspend),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(runTimeProvider.notifier).value = 1;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            includeNavigatorKey: false,
            setTheme: false,
            homeBuilder: (child) => Scaffold(
              body: Align(alignment: .bottomCenter, child: child),
            ),
            child: NavigationDock(
              destinations: const [
                NavigationDockDestination(
                  glyph: AppGlyphs.dashboard,
                  label: 'a',
                ),
                NavigationDockDestination(glyph: AppGlyphs.tools, label: 'b'),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
              trailing: const StartButton(),
            ),
          ),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('swaps in the Wi-Fi off glyph and a tooltip when suspended', (
      tester,
    ) async {
      await pumpDocked(tester, suspend: true);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(StartButton));
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .tooltip,
        context.appLocalizations.suspended,
      );
      expect(find.byGlyph(AppGlyphs.wifiOff), findsOneWidget);
    });

    testWidgets('keeps the pause glyph and running colors while running', (
      tester,
    ) async {
      await pumpDocked(tester);

      final context = tester.element(find.byType(StartButton));
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, context.appLocalizations.stop);
      expect(fab.backgroundColor, context.colorScheme.primary);
      expect(fab.foregroundColor, context.colorScheme.onPrimary);
      expect(find.byGlyph(AppGlyphs.wifiOff), findsNothing);
    });

    testWidgets('uses container colors when stopped', (tester) async {
      final container = await pumpDocked(tester);
      container.read(runTimeProvider.notifier).value = null;
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(StartButton));
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.tooltip, context.appLocalizations.start);
      expect(fab.backgroundColor, context.colorScheme.primaryContainer);
      expect(fab.foregroundColor, context.colorScheme.onPrimaryContainer);
    });

    testWidgets('uses tertiary container colors when suspended', (
      tester,
    ) async {
      await pumpDocked(tester, suspend: true);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(StartButton));
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.backgroundColor, context.colorScheme.tertiaryContainer);
      expect(fab.foregroundColor, context.colorScheme.onTertiaryContainer);
    });
  });

  group('sidebar', () {
    Future<ProviderContainer> pumpInSidebar(
      WidgetTester tester, {
      required bool expanded,
      int? runTime,
      bool suspend = false,
    }) async {
      final container = ProviderContainer(
        overrides: [
          initProvider.overrideWithBuild((_, _) => true),
          profilesProvider.overrideWithValue([
            const Profile(id: 1, autoUpdateDuration: Duration.zero),
          ]),
          suspendProvider.overrideWithValue(suspend),
          setupActionProvider.overrideWith(_RecordingSetupAction.new),
        ],
      );
      addTearDown(container.dispose);
      globalState.container = container;
      container.read(runTimeProvider.notifier).value = runTime;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TestApp(
            includeNavigatorKey: false,
            setTheme: false,
            homeBuilder: (child) => Scaffold(
              body: Align(
                alignment: AlignmentDirectional.centerStart,
                child: child,
              ),
            ),
            child: NavigationSidebar(
              destinations: const [
                SidebarDestination(glyph: AppGlyphs.dashboard, label: 'Home'),
              ],
              selectedIndex: 0,
              expanded: expanded,
              onSelected: (_) {},
              onToggle: () {},
              footer: const StartButton(),
            ),
          ),
        ),
      );
      await tester.pump();
      return container;
    }

    testWidgets('shows label, runtime, and toggles on tap', (tester) async {
      final container = await pumpInSidebar(tester, expanded: true);
      final context = tester.element(find.byType(StartButton));
      final action =
          container.read(setupActionProvider.notifier) as _RecordingSetupAction;

      expect(find.text(context.appLocalizations.start), findsOneWidget);
      var material = tester.widget<Material>(
        find.descendant(
          of: find.byType(StartButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, context.colorScheme.primaryContainer);

      await tester.tap(find.byType(StartButton));
      await tester.pumpAndSettle();
      expect(action.requests, [true]);

      container.read(runTimeProvider.notifier).value = const Duration(
        hours: 2,
        minutes: 13,
        seconds: 8,
      ).inMilliseconds;
      await tester.pumpAndSettle();

      expect(find.text('02:13:08'), findsOneWidget);
      material = tester.widget<Material>(
        find.descendant(
          of: find.byType(StartButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, context.colorScheme.primary);
    });

    testWidgets('shows suspended state in expanded sidebar', (tester) async {
      await pumpInSidebar(
        tester,
        expanded: true,
        runTime: 1000,
        suspend: true,
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(StartButton));
      expect(find.text(context.appLocalizations.suspended), findsOneWidget);
      expect(find.byGlyph(AppGlyphs.wifiOff), findsOneWidget);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(StartButton),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, context.colorScheme.tertiaryContainer);
    });

    testWidgets('uses status tooltips when collapsed', (tester) async {
      await pumpInSidebar(
        tester,
        expanded: false,
        runTime: const Duration(
          hours: 1,
          minutes: 2,
          seconds: 3,
        ).inMilliseconds,
      );
      final context = tester.element(find.byType(StartButton));
      final tooltip = tester.widget<Tooltip>(
        find.descendant(
          of: find.byType(StartButton),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, '${context.appLocalizations.stop} · 01:02:03');
    });
  });
}

class _RecordingSetupAction extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) {
    requests.add(running);
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return Future.value(true);
  }
}

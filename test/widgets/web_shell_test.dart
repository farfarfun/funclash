import 'package:funclash/common/common.dart';
import 'package:funclash/widgets/web_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MediaQueryData inside;

  final canvas = find.byKey(webCanvasKey);

  Future<void> pumpShell(WidgetTester tester, Size page) async {
    tester.view
      ..physicalSize = page
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: WebShell(
          child: Builder(
            builder: (context) {
              inside = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  testWidgets('the canvas is the size the desktop window opens at', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1600, 1000));

    expect(tester.getSize(canvas), defaultWindowSize);
    expect(tester.getRect(canvas).size, defaultWindowSize);
  });

  testWidgets('the app measures the canvas, not the page around it', (
    tester,
  ) async {
    await pumpShell(tester, const Size(1600, 1000));

    final outside = MediaQuery.of(tester.element(find.byType(WebShell)));

    expect(outside.padding.top, 48);
    expect(inside.size, defaultWindowSize);
    expect(inside.padding, EdgeInsets.zero);
    expect(inside.viewInsets, EdgeInsets.zero);
  });

  testWidgets('a page too small to hold it scales the whole canvas down', (
    tester,
  ) async {
    await pumpShell(tester, const Size(400, 400));

    final painted = tester.getRect(canvas);

    expect(tester.getSize(canvas), defaultWindowSize);
    expect(inside.size, defaultWindowSize);
    expect(painted.width, lessThanOrEqualTo(400));
    expect(painted.height, lessThanOrEqualTo(400));
    expect(
      painted.width / painted.height,
      closeTo(defaultWindowSize.aspectRatio, 0.001),
      reason: 'a canvas that no longer fits is scaled, never reshaped',
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclash_app/main.dart';

void main() {
  testWidgets('App boots to the dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FunclashApp()));
    await tester.pump();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Proxies'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/core/service_web.dart';

void main() {
  test('panel refuses a runtime that cannot preserve 64-bit IDs', () async {
    await expectLater(connectPanel(), throwsUnsupportedError);
  });
}

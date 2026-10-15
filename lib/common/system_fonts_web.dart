import 'package:funclash/enum/enum.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'print.dart';

/// A tab enumerates nothing: the engine resolves a family against whatever the
/// browser already has, and the host's own list belongs to the host.
@visibleForTesting
Future<List<String>> Function() systemFontFamiliesReader = () async => const [];

Future<List<String>> loadSystemFontFamilies() async {
  try {
    return await systemFontFamiliesReader();
  } catch (e) {
    commonPrint.log('loadSystemFontFamilies: $e', logLevel: LogLevel.warning);
    return const [];
  }
}

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// `flutter test` runs against the host's bare Dart VM, without the
/// `sqlite3_flutter_libs`-bundled native library the real app ships with —
/// only the unversioned `libsqlite3.so` the `sqlite3` package looks for by
/// default may be missing (a `libsqlite3-dev` symlink), even though the
/// runtime `libsqlite3.so.<N>` most systems already have is perfectly usable.
/// Fall back to it here so tests don't depend on that dev package being
/// installed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(OperatingSystem.linux, _openLinuxSqlite3);
  }
  await testMain();
}

DynamicLibrary _openLinuxSqlite3() {
  for (final candidate in ['libsqlite3.so', 'libsqlite3.so.0']) {
    try {
      return DynamicLibrary.open(candidate);
    } catch (_) {
      // Try the next candidate.
    }
  }
  return DynamicLibrary.open('libsqlite3.so');
}

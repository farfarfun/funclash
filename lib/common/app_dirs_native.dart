import 'dart:io';

import 'package:funclash/common/desktop_startup.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> resolveSupportDir() async {
  final override = desktopStartup.dataDirectory;
  if (override != null) {
    final directory = Directory(p.absolute(override));
    await directory.create(recursive: true);
    return directory.path;
  }
  return (await getApplicationSupportDirectory()).path;
}

Future<String> resolveTemporaryDir() async =>
    (await getTemporaryDirectory()).path;

Future<String> resolveCacheDir() async =>
    (await getApplicationCacheDirectory()).path;

Future<String?> resolveDownloadsDir() async =>
    (await getDownloadsDirectory())?.path;

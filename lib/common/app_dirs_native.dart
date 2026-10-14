import 'package:path_provider/path_provider.dart';

Future<String> resolveSupportDir() async =>
    (await getApplicationSupportDirectory()).path;

Future<String> resolveTemporaryDir() async =>
    (await getTemporaryDirectory()).path;

Future<String> resolveCacheDir() async =>
    (await getApplicationCacheDirectory()).path;

Future<String?> resolveDownloadsDir() async =>
    (await getDownloadsDirectory())?.path;

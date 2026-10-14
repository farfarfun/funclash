/// Naming a path is arithmetic a tab can still do; reaching one is what
/// `file_web.dart` refuses, which is where the reach actually happens.
const _virtualRoot = '/flclash';

Future<String> resolveSupportDir() async => _virtualRoot;

Future<String> resolveTemporaryDir() async => _virtualRoot;

Future<String> resolveCacheDir() async => _virtualRoot;

Future<String?> resolveDownloadsDir() async => null;

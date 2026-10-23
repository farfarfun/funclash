import 'package:funclash/remote/panel_file_client.dart';

final _supportDir = _resolveSupportDir();

Future<String> _resolveSupportDir() async {
  final root = await panelFiles.call<String>('resolveSupportDir', const {});
  if (root == null || root.isEmpty) {
    throw StateError('the panel host supplied no data directory');
  }
  return root;
}

Future<String> resolveSupportDir() => _supportDir;

Future<String> resolveTemporaryDir() => _supportDir;

Future<String> resolveCacheDir() => _supportDir;

Future<String?> resolveDownloadsDir() async => null;

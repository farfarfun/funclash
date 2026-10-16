import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:funclash/common/constant.dart';
import 'package:path/path.dart' as p;

typedef PanelFetch =
    Future<Uint8List> Function(
      String url, {
      void Function(int received, int total)? onProgress,
    });

/// Written last, so a half-finished install is never read as a usable one.
const panelVersionStamp = '.funclash-panel';

const entryPoint = 'index.html';

String panelArchiveUrl(String version) =>
    'https://github.com/$repository/releases/download/v$version/'
    '$appName-$version-panel.zip';

bool isPanelInstalled({required String root, required String version}) {
  final stamp = File(p.join(root, panelVersionStamp));
  return stamp.existsSync() && stamp.readAsStringSync().trim() == version;
}

Future<void> installPanel({
  required String root,
  required String version,
  required PanelFetch fetch,
  void Function(double fraction)? onProgress,
}) async {
  final bytes = await fetch(
    panelArchiveUrl(version),
    onProgress: (received, total) =>
        onProgress?.call(total <= 0 ? 0 : received / total),
  );
  final archive = ZipDecoder().decodeBytes(bytes);
  // A truncated download decodes to an empty archive rather than throwing.
  if (!archive.files.any((entry) => entry.isFile && entry.name == entryPoint)) {
    throw const FormatException('the panel archive carries no $entryPoint');
  }
  final directory = Directory(root);
  if (directory.existsSync()) {
    directory.deleteSync(recursive: true);
  }
  directory.createSync(recursive: true);
  for (final entry in archive.files) {
    final target = _entryPath(root, entry.name);
    if (target == null || !entry.isFile) {
      continue;
    }
    File(target)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(entry.readBytes() ?? const []);
  }
  File(p.join(root, panelVersionStamp)).writeAsStringSync(version);
}

/// Null for a name that would write outside [root]. Archives are untrusted.
String? _entryPath(String root, String name) {
  final normalized = p.posix.normalize(name.replaceAll('\\', '/'));
  if (normalized.isEmpty ||
      p.posix.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    return null;
  }
  final target = p.normalize(p.join(root, normalized));
  return p.isWithin(root, target) ? target : null;
}

import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:funclash/remote/panel_file_bridge.dart';
import 'package:funclash/remote/panel_file_client.dart';
import 'package:funclash/remote/panel_image.dart';

/// The two the bridge cannot carry: a synchronous call has nowhere to wait for
/// an answer, and both of these are driven synchronously by the config
/// pipeline, which a panel does not run.
Never _noSyncFileSystem(String path) =>
    throw UnsupportedError('no synchronous file system for $path');

ImageProvider pathImage(String path) => PanelImage(path);

Future<bool> pathExists(String path) async =>
    await panelFiles.call<bool>('pathExists', {'path': path}) ?? false;

Future<void> safeWritePathAsString(String path, String content) => panelFiles
    .call<void>('safeWritePathAsString', {'path': path, 'content': content});

Future<void> safeWritePathAsBytes(
  String path,
  List<int> bytes, {
  bool flush = false,
}) => panelFiles.call<void>('safeWritePathAsBytes', {
  'path': path,
  'bytes': bytes,
  'flush': flush,
});

Future<void> writePathAsStringAtomically(String path, String content) =>
    panelFiles.call<void>('writePathAsStringAtomically', {
      'path': path,
      'content': content,
    });

Future<void> safeCopyPath(String path, String newPath) =>
    panelFiles.call<void>('safeCopyPath', {'path': path, 'to': newPath});

Future<void> renamePath(String path, String newPath) =>
    panelFiles.call<void>('renamePath', {'path': path, 'to': newPath});

void movePathSync(String path, String newPath) => _noSyncFileSystem(path);

Future<Uint8List> readPathAsBytes(String path) async => panelBytes(
  await panelFiles.call<Object>('readPathAsBytes', {'path': path}),
);

Future<Uint8List> readPathAsBytesOrEmpty(String path) async => panelBytes(
  await panelFiles.call<Object>('readPathAsBytesOrEmpty', {'path': path}),
);

Future<Uint8List?> readPathAsBytesOrNull(String path) async {
  final bytes = await panelFiles.call<Object>('readPathAsBytesOrNull', {
    'path': path,
  });
  return bytes == null ? null : panelBytes(bytes);
}

Future<String> readPathAsStringOrEmpty(String path) async =>
    await panelFiles.call<String>('readPathAsStringOrEmpty', {'path': path}) ??
    '';

Future<List<int>?> readPathHead(String path, int length) async {
  final head = await panelFiles.call<List<Object?>>('readPathHead', {
    'path': path,
    'length': length,
  });
  return head?.cast<int>();
}

Future<({int size, DateTime? lastModified})?> readPathStat(String path) async {
  final stat = await panelFiles.call<Map<String, Object?>>('readPathStat', {
    'path': path,
  });
  if (stat == null) {
    return null;
  }
  final modified = stat['lastModified'];
  return (
    size: stat['size']! as int,
    lastModified: modified is String ? DateTime.tryParse(modified) : null,
  );
}

Future<bool> isPathAgeEncrypted(String path) async =>
    await panelFiles.call<bool>('isPathAgeEncrypted', {'path': path}) ?? false;

Future<void> ensurePathDir(String path) =>
    panelFiles.call<void>('ensurePathDir', {'path': path});

List<({String path, bool isDirectory})> listPathEntriesSync(String path) =>
    _noSyncFileSystem(path);

Future<void> safeDeletePath(String path) =>
    panelFiles.call<void>('safeDeletePath', {'path': path});

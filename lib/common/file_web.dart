import 'dart:typed_data';

import 'package:flutter/painting.dart';

/// No file system in a browser tab; the desktop this panel controls has one.
Never _noFileSystem(String path) =>
    throw UnsupportedError('no file system for $path');

ImageProvider pathImage(String path) => _noFileSystem(path);

Future<bool> pathExists(String path) async => _noFileSystem(path);

Future<void> safeWritePathAsString(String path, String content) async =>
    _noFileSystem(path);

Future<void> safeWritePathAsBytes(
  String path,
  List<int> bytes, {
  bool flush = false,
}) async => _noFileSystem(path);

Future<void> writePathAsStringAtomically(String path, String content) async =>
    _noFileSystem(path);

Future<void> safeCopyPath(String path, String newPath) async =>
    _noFileSystem(path);

Future<void> renamePath(String path, String newPath) async =>
    _noFileSystem(path);

void movePathSync(String path, String newPath) => _noFileSystem(path);

Future<Uint8List> readPathAsBytes(String path) async => _noFileSystem(path);

Future<Uint8List> readPathAsBytesOrEmpty(String path) async =>
    _noFileSystem(path);

Future<Uint8List?> readPathAsBytesOrNull(String path) async =>
    _noFileSystem(path);

Future<String> readPathAsStringOrEmpty(String path) async =>
    _noFileSystem(path);

Future<List<int>?> readPathHead(String path, int length) async =>
    _noFileSystem(path);

Future<({int size, DateTime? lastModified})?> readPathStat(String path) async =>
    _noFileSystem(path);

Future<bool> isPathAgeEncrypted(String path) async => _noFileSystem(path);

Future<void> ensurePathDir(String path) async => _noFileSystem(path);

List<({String path, bool isDirectory})> listPathEntriesSync(String path) =>
    _noFileSystem(path);

Future<void> safeDeletePath(String path) async => _noFileSystem(path);

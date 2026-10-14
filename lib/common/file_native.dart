import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';

const _replaceAttempts = 10;
const _replaceRetryDelay = Duration(milliseconds: 50);

/// The prefix mihomo's `age.DecryptBytes` tells an encrypted config by.
const _ageArmorHeader = '-----BEGIN AGE ENCRYPTED FILE-----';

extension FileExt on File {
  Future<void> safeCopy(String newPath) async {
    if (!await exists()) {
      await create(recursive: true);
      return;
    }
    final targetFile = File(newPath);
    if (!await targetFile.exists()) {
      await targetFile.create(recursive: true);
    }
    await copy(newPath);
  }

  Future<File> safeWriteAsString(String str) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsString(str);
  }

  Future<File> safeWriteAsBytes(List<int> bytes, {bool flush = false}) async {
    if (!await exists()) {
      await create(recursive: true);
    }
    return writeAsBytes(bytes, flush: flush);
  }

  /// Writes to one file must not overlap: they share the temporary sibling.
  Future<void> writeAsStringAtomically(String content) async {
    final temp = File('$path.$pid.tmp');
    try {
      await temp.parent.create(recursive: true);
      await temp.writeAsString(content, flush: true);
      await temp._renameRetryingWhileHeldOpen(path);
    } catch (_) {
      await temp.delete().then((_) {}, onError: (_) {});
      rethrow;
    }
  }

  Future<void> _renameRetryingWhileHeldOpen(String target) async {
    for (var attempt = 1; ; attempt++) {
      try {
        await rename(target);
        return;
      } on FileSystemException {
        if (attempt == _replaceAttempts) rethrow;
        await Future<void>.delayed(_replaceRetryDelay);
      }
    }
  }
}

extension FileSystemEntityExt on FileSystemEntity {
  Future<void> safeDelete({bool recursive = false}) async {
    if (!await exists()) {
      return;
    }
    await delete(recursive: recursive);
  }
}

Future<void> safeWritePathAsString(String path, String content) async {
  await File(path).safeWriteAsString(content);
}

Future<void> safeWritePathAsBytes(
  String path,
  List<int> bytes, {
  bool flush = false,
}) async {
  await File(path).safeWriteAsBytes(bytes, flush: flush);
}

Future<void> writePathAsStringAtomically(String path, String content) async {
  await File(path).writeAsStringAtomically(content);
}

Future<void> safeCopyPath(String path, String newPath) async {
  await File(path).safeCopy(newPath);
}

/// Replaces the target, the way a staged compile takes over the old file.
Future<void> renamePath(String path, String newPath) async {
  await File(path).rename(newPath);
}

void movePathSync(String path, String newPath) {
  final target = File(newPath);
  if (path == newPath || target.existsSync()) {
    return;
  }
  final file = File(path);
  if (!file.existsSync()) {
    return;
  }
  target.parent.createSync(recursive: true);
  file.renameSync(newPath);
}

ImageProvider pathImage(String path) => FileImage(File(path));

Future<bool> pathExists(String path) => File(path).exists();

Future<Uint8List> readPathAsBytes(String path) => File(path).readAsBytes();

Future<Uint8List> readPathAsBytesOrEmpty(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : Uint8List(0);
}

Future<Uint8List?> readPathAsBytesOrNull(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<String> readPathAsStringOrEmpty(String path) async {
  final file = File(path);
  return await file.exists() ? file.readAsString() : '';
}

/// Null for a missing file, which a caller tells from an empty head.
Future<List<int>?> readPathHead(String path, int length) async {
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return file.openRead(0, length).expand((chunk) => chunk).toList();
}

/// Null for a missing file. A last-modified in 1970 is a file system with no
/// answer rather than a date, which is what an extracted archive reports.
Future<({int size, DateTime? lastModified})?> readPathStat(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return (size: await file.length(), lastModified: await _modified(file));
}

Future<DateTime?> _modified(File file) async {
  try {
    final value = await file.lastModified();
    return value.year > 1970 ? value : null;
  } on FileSystemException {
    return null;
  }
}

/// A file that is not there is not an age file; the Core reports the absence
/// when it reads the same path for the validation that follows.
Future<bool> isPathAgeEncrypted(String path) async {
  final head = await readPathHead(path, _ageArmorHeader.length);
  return head != null && String.fromCharCodes(head) == _ageArmorHeader;
}

Future<void> ensurePathDir(String path) async {
  await Directory(path).create(recursive: true);
}

/// A link is neither a file nor a directory; a missing directory is empty.
List<({String path, bool isDirectory})> listPathEntriesSync(String path) {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    return const [];
  }
  final entities = directory.listSync(recursive: false, followLinks: false);
  return [
    for (final entity in entities)
      if (entity is File || entity is Directory)
        (path: entity.path, isDirectory: entity is Directory),
  ];
}

Future<void> safeDeletePath(String path) async {
  final entity = switch (FileSystemEntity.typeSync(path)) {
    FileSystemEntityType.directory => Directory(path),
    _ => File(path),
  };
  await entity.safeDelete(recursive: true);
}

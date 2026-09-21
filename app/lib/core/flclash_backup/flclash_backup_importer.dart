import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../database/profiles_database.dart';
import '../funclash_paths.dart';

/// Thrown when a file doesn't look like a FlClash `backup.zip`.
class InvalidFlClashBackupException implements Exception {
  final String message;
  const InvalidFlClashBackupException(this.message);

  @override
  String toString() => message;
}

class FlClashImportResult {
  final List<int> importedProfileIds;
  const FlClashImportResult(this.importedProfileIds);

  int get count => importedProfileIds.length;
}

/// Imports a FlClash `backup.zip` into funclash's own [ProfilesDatabase].
///
/// FlClash's backup.zip bundles a raw copy of its `database.sqlite` plus the
/// `profiles/<id>.yaml` (and `scripts/<id>.js`) files it references — see
/// `lib/common/task.dart` (`_backupTask`/`_restoreTask`) in FlClash. Because
/// funclash's `profiles` table schema matches FlClash's column-for-column,
/// the bundled database can be merged in directly via
/// [ProfilesDatabase.importFromFlClashDatabase], with the referenced
/// profile/script files copied alongside it — the same approach FlClash's
/// own restore uses on itself.
///
/// [homeDir] defaults to [FunclashPaths.root]; tests should pass a temp
/// directory so they never touch the real `~/.funclash`.
Future<FlClashImportResult> importFlClashBackupZip(
  String zipFilePath, {
  required ProfilesDatabase db,
  String? homeDir,
}) async {
  final root = homeDir ?? FunclashPaths.root;
  final scratchDir = Directory(p.join(root, 'import-tmp'));
  if (scratchDir.existsSync()) {
    await scratchDir.delete(recursive: true);
  }
  await scratchDir.create(recursive: true);
  try {
    await extractFileToDisk(zipFilePath, scratchDir.path);

    final extractedDbFile = File(p.join(scratchDir.path, 'database.sqlite'));
    if (!extractedDbFile.existsSync()) {
      throw const InvalidFlClashBackupException(
        'Not a valid FlClash backup: missing database.sqlite.',
      );
    }

    final importedIds = db.importFromFlClashDatabase(extractedDbFile.path);

    await _copyIfPresent(
      p.join(scratchDir.path, 'profiles'),
      p.join(root, 'profiles'),
    );
    await _copyIfPresent(
      p.join(scratchDir.path, 'scripts'),
      p.join(root, 'scripts'),
    );

    return FlClashImportResult(importedIds);
  } finally {
    if (scratchDir.existsSync()) {
      await scratchDir.delete(recursive: true);
    }
  }
}

Future<void> _copyIfPresent(String sourceDir, String targetDir) async {
  final source = Directory(sourceDir);
  if (!source.existsSync()) return;
  await Directory(targetDir).create(recursive: true);
  for (final entity in source.listSync()) {
    if (entity is! File) continue;
    await entity.copy(p.join(targetDir, p.basename(entity.path)));
  }
}

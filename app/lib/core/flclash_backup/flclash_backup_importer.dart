import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../database/profiles_store.dart';
import '../funclash_paths.dart';

/// 文件不是有效的 FlClash `backup.zip` 时抛出的异常。
class InvalidFlClashBackupException implements Exception {
  final String message;
  const InvalidFlClashBackupException(this.message);

  @override
  String toString() => message;
}

/// FlClash 备份导入结果。
class FlClashImportResult {
  final List<int> importedProfileIds;
  const FlClashImportResult(this.importedProfileIds);

  int get count => importedProfileIds.length;
}

/// 将 FlClash `backup.zip` 导入 funclash 的 [ProfilesStore]。
///
/// 备份包含 `database.sqlite` 及其引用的 `profiles/<id>.yaml` 和
/// `scripts/<id>.js`。funclash 的 `profiles` 表与 FlClash 逐列一致，因此可通过
/// [ProfilesStore.importFromFlClashDatabase] 直接合并数据库并复制引用文件。
///
/// [homeDir] 默认为 [FunclashPaths.root]；测试应传入临时目录。
Future<FlClashImportResult> importFlClashBackupZip(
  String zipFilePath, {
  required ProfilesStore db,
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

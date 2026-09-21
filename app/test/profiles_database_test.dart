import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'package:funclash_app/core/flclash_backup/flclash_backup_importer.dart';
import 'package:funclash_app/database/profiles_database.dart';

/// Builds a `backup.zip` shaped exactly like a real FlClash backup (see
/// `lib/common/task.dart`'s `_backupTask` in FlClash): a `database.sqlite`
/// with a FlClash-schema `profiles` table, plus `profiles/<id>.yaml`.
Future<File> _buildFakeFlClashBackup(Directory tempDir) async {
  final stageDir = Directory(p.join(tempDir.path, 'stage'))..createSync();

  final db = sqlite3.open(p.join(stageDir.path, 'database.sqlite'));
  db.execute('''
    CREATE TABLE profiles (
      id INTEGER PRIMARY KEY,
      label TEXT NOT NULL,
      current_group_name TEXT,
      url TEXT NOT NULL,
      last_update_date INTEGER,
      overwrite_type TEXT NOT NULL DEFAULT 'none',
      script_id INTEGER,
      auto_update_duration_millis INTEGER NOT NULL DEFAULT 0,
      subscription_info TEXT,
      auto_update INTEGER NOT NULL DEFAULT 0,
      selected_map TEXT NOT NULL DEFAULT '{}',
      unfold_set TEXT NOT NULL DEFAULT '[]',
      "order" INTEGER
    );
  ''');
  db.execute('''
    INSERT INTO profiles (
      id, label, current_group_name, url, last_update_date, overwrite_type,
      script_id, auto_update_duration_millis, subscription_info, auto_update,
      selected_map, unfold_set, "order"
    ) VALUES (42, 'My FlClash profile', NULL, 'https://example.com/sub', 1700000000,
      'none', NULL, 0, NULL, 0, '{}', '[]', 0);
  ''');
  db.dispose();

  final profilesDir = Directory(p.join(stageDir.path, 'profiles'))..createSync();
  File(p.join(profilesDir.path, '42.yaml')).writeAsStringSync('proxies: []\n');

  final zipPath = p.join(tempDir.path, 'backup.zip');
  await ZipFileEncoder().zipDirectory(stageDir, filename: zipPath);
  return File(zipPath);
}

void main() {
  test('importing a FlClash backup.zip merges its profiles table and files', () async {
    final tempDir = await Directory.systemTemp.createTemp('funclash_flclash_import_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final backupZip = await _buildFakeFlClashBackup(tempDir);
    final homeDir = Directory(p.join(tempDir.path, 'home'))..createSync();
    final db = ProfilesDatabase.open(path: p.join(homeDir.path, 'database.sqlite'));
    addTearDown(db.close);

    final result = await importFlClashBackupZip(
      backupZip.path,
      db: db,
      homeDir: homeDir.path,
    );

    expect(result.count, 1);
    expect(result.importedProfileIds, contains(42));

    final profiles = db.listProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 42);
    expect(profiles.single.label, 'My FlClash profile');
    expect(profiles.single.url, 'https://example.com/sub');

    final importedYaml = File(p.join(homeDir.path, 'profiles', '42.yaml'));
    expect(importedYaml.existsSync(), isTrue);
    expect(importedYaml.readAsStringSync(), contains('proxies'));
  });

  test('importing a non-backup zip throws an actionable error', () async {
    final tempDir = await Directory.systemTemp.createTemp('funclash_flclash_import_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final stageDir = Directory(p.join(tempDir.path, 'stage'))..createSync();
    File(p.join(stageDir.path, 'not_a_database.txt')).writeAsStringSync('hello');
    final zipPath = p.join(tempDir.path, 'not_a_backup.zip');
    await ZipFileEncoder().zipDirectory(stageDir, filename: zipPath);

    final homeDir = Directory(p.join(tempDir.path, 'home'))..createSync();
    final db = ProfilesDatabase.open(path: p.join(homeDir.path, 'database.sqlite'));
    addTearDown(db.close);

    expect(
      () => importFlClashBackupZip(zipPath, db: db, homeDir: homeDir.path),
      throwsA(isA<InvalidFlClashBackupException>()),
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/common/migration.dart';
import 'package:funclash/database/database.dart';
import 'package:funclash/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

Future<void> uploadBackupFile(
  DAVTransport transport,
  String remotePath,
  String localPath,
) async {
  final file = File(localPath);
  await transport.put(remotePath, file.openRead, await file.length());
}

Future<void> downloadBackupFile(
  DAVTransport transport,
  String remotePath,
  String localPath,
) async {
  final file = File(localPath);
  await file.parent.create(recursive: true);
  final stream = await transport.get(remotePath);
  final sink = file.openWrite();
  try {
    await sink.addStream(stream);
  } finally {
    await sink.close();
  }
}

Future<void> backupTask(BackupArchiveRequest request) {
  return compute(_backupTask, request);
}

Future<void> _backupTask(BackupArchiveRequest request) {
  return writeBackupArchive(
    archivePath: request.archivePath,
    configMap: request.configMap,
    databaseSnapshotPath: request.databaseSnapshotPath,
    homeDirPath: request.homeDirPath,
  );
}

Future<MigrationData> restoreTask(RestoreArchiveRequest request) {
  return compute(_restoreTask, request);
}

Future<MigrationData> _restoreTask(RestoreArchiveRequest request) {
  return readBackupArchive(
    archivePath: request.archivePath,
    stagingDirPath: request.stagingDirPath,
  );
}

@visibleForTesting
Future<void> writeBackupArchive({
  required String archivePath,
  required Map<String, Object?> configMap,
  required String databaseSnapshotPath,
  required String homeDirPath,
}) async {
  final snapshot = Database(NativeDatabase(File(databaseSnapshotPath)));
  final Map<String, bool> requiredFiles;
  try {
    final profiles = snapshot.profiles;
    final profileRows = await (snapshot.selectOnly(
      profiles,
    )..addColumns([profiles.id, profiles.type])).get();
    requiredFiles = {
      for (final row in profileRows)
        BackupEntries.profile(row.read(profiles.id)!):
            row.read(profiles.type) == ProfileType.file.name,
      for (final id in await snapshot.scriptsDao.ids().get())
        BackupEntries.script(id): true,
      for (final provider in await snapshot.clashProvidersDao.query().get())
        if (!provider.isRemote) BackupEntries.provider(provider): true,
    };
  } finally {
    await snapshot.close();
  }
  final encoder = ZipFileEncoder()..create(archivePath);
  try {
    encoder.addArchiveFile(
      ArchiveFile.string(configJsonName, json.encode(configMap)),
    );
    await encoder.addFile(File(databaseSnapshotPath), backupDatabaseName);
    for (final MapEntry(key: entry, value: required) in requiredFiles.entries) {
      final file = File(BackupEntries.resolve(homeDirPath, entry));
      if (required || await file.exists()) {
        await encoder.addFile(file, entry);
      }
    }
  } finally {
    await encoder.close();
  }
}

/// Writes nothing outside [stagingDirPath]; the files the result names are left
/// there at their [BackupEntries] paths.
@visibleForTesting
Future<MigrationData> readBackupArchive({
  required String archivePath,
  required String stagingDirPath,
}) async {
  await _extract(archivePath, stagingDirPath);
  final configFile = File(join(stagingDirPath, configJsonName));
  if (!await configFile.exists()) {
    throw const BackupException(BackupFailure.invalid);
  }
  final configMap = _decodeConfig(await configFile.readAsString());
  final version = configMap['version'] ?? 0;
  if (version is! int) {
    throw const BackupException(BackupFailure.invalid);
  }
  if (version > Migration.currentVersion) {
    throw const BackupException(BackupFailure.newerVersion);
  }
  if (version == 0) {
    return migrateLegacyConfig(
      configMap: configMap,
      sourcePath: stagingDirPath,
      targetPath: stagingDirPath,
    );
  }
  final databaseFile = File(join(stagingDirPath, backupDatabaseName));
  if (!await databaseFile.exists()) {
    return MigrationData(configMap: configMap);
  }
  final schemaVersion = await _readSchemaVersion(databaseFile);
  final database = Database(NativeDatabase(databaseFile));
  try {
    if (schemaVersion > database.schemaVersion) {
      throw const BackupException(BackupFailure.newerVersion);
    }
    final results = await Future.wait([
      database.profilesDao.query().get(),
      database.scriptsDao.query().get(),
      (database.select(database.rules)..orderBy([
            (t) => OrderingTerm(expression: t.order, nulls: NullsOrder.last),
          ]))
          .map((item) => item.toRule())
          .get(),
      database
          .select(database.disabledRules)
          .map((item) => item.toDisabledRule())
          .get(),
      (database.select(database.proxyGroups)..orderBy([
            (t) => OrderingTerm(expression: t.order, nulls: NullsOrder.last),
          ]))
          .map((item) => item.toProxyGroup())
          .get(),
      database.clashProvidersDao.query().get(),
      database.customProxiesDao.query().get(),
      database.proxyDialers.readable((row) => row.toProxyDialer()).get(),
      database.iconSetsDao.query().get(),
    ]);
    return MigrationData(
      configMap: configMap,
      profiles: results[0].cast<Profile>(),
      scripts: results[1].cast<Script>(),
      rules: results[2].cast<Rule>(),
      disabledRules: results[3].cast<DisabledRule>(),
      proxyGroups: results[4].cast<ProxyGroup>(),
      clashProviders: results[5].cast<ClashProvider>(),
      customProxies: results[6].cast<CustomProxy>(),
      proxyDialers: results[7].cast<ProxyDialer>(),
      iconSets: schemaVersion >= 17 || results[8].isNotEmpty
          ? results[8].cast<IconSet>()
          : null,
    );
  } finally {
    await database.close();
  }
}

Future<void> _extract(String archivePath, String stagingDirPath) async {
  await Directory(stagingDirPath).create(recursive: true);
  final input = InputFileStream(archivePath);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } on Exception {
      throw const BackupException(BackupFailure.invalid);
    }
    for (final file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      final outPath = _stagedEntryPath(stagingDirPath, file.name);
      if (outPath == null) {
        continue;
      }
      await Directory(dirname(outPath)).create(recursive: true);
      final output = OutputFileStream(outPath);
      try {
        file.writeContent(output);
      } finally {
        await output.close();
      }
    }
  } finally {
    await input.close();
  }
}

/// `posix.normalize` collapses `a/../b`, but a name that starts with `../`
/// normalizes to itself and an absolute one stays absolute, so either would
/// write wherever the archive asks. A backup file is untrusted input.
String? _stagedEntryPath(String stagingDirPath, String name) {
  final normalized = posix.normalize(name.replaceAll('\\', '/'));
  if (normalized.isEmpty ||
      posix.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    return null;
  }
  final outPath = normalize(BackupEntries.resolve(stagingDirPath, normalized));
  if (!isWithin(stagingDirPath, outPath)) {
    return null;
  }
  return outPath;
}

Map<String, Object?> _decodeConfig(String source) {
  final Object? decoded;
  try {
    decoded = json.decode(source);
  } on FormatException {
    throw const BackupException(BackupFailure.invalid);
  }
  if (decoded is! Map<String, Object?>) {
    throw const BackupException(BackupFailure.invalid);
  }
  return decoded;
}

/// Opening the database through drift would already run its migrations, so the
/// version is read from the file header: SQLite keeps `user_version` as a
/// big-endian integer at byte 60.
Future<int> _readSchemaVersion(File databaseFile) async {
  final handle = await databaseFile.open();
  try {
    final header = await handle.read(64);
    if (header.length < 64) {
      throw const BackupException(BackupFailure.invalid);
    }
    return ByteData.sublistView(header).getInt32(60);
  } finally {
    await handle.close();
  }
}

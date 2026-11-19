import 'package:funclash/common/backup.dart';
import 'package:funclash/common/webdav.dart';
import 'package:funclash/models/models.dart';

/// The archive is written beside the data it holds, on the desktop this panel
/// controls; nothing carries the request there yet.
Never _noArchive(String verb) =>
    throw UnsupportedError('a browser tab cannot $verb a backup archive');

Future<void> backupTask(BackupArchiveRequest request) async =>
    _noArchive('write');

Future<MigrationData> restoreTask(RestoreArchiveRequest request) async =>
    _noArchive('read');

Future<void> uploadBackupFile(
  DAVTransport transport,
  String remotePath,
  String localPath,
) async => _noArchive('upload');

Future<void> downloadBackupFile(
  DAVTransport transport,
  String remotePath,
  String localPath,
) async => _noArchive('download');

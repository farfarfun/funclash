import 'package:funclash/common/common.dart';
import 'package:funclash/models/models.dart';
import 'package:path/path.dart';

enum BackupFailure { invalid, newerVersion }

final class BackupException implements Exception {
  final BackupFailure failure;

  const BackupException(this.failure);

  @override
  String toString() => 'BackupException(${failure.name})';
}

/// Archive entries mirror the data directory, so an entry name is also the
/// file's path relative to the home directory.
abstract final class BackupEntries {
  static String profile(Object id) => '$profilesDirectoryName/$id.yaml';

  static String script(Object id) => 'scripts/$id.js';

  static String provider(ClashProvider provider) =>
      '$providersDirectoryName/$rulesProviderDirectoryName/${provider.fileName}';

  /// A remote provider's cache belongs to the Core and downloads again.
  static List<String> of({
    required Iterable<int> profileIds,
    required Iterable<int> scriptIds,
    required Iterable<ClashProvider> providers,
  }) {
    return [
      ...profileIds.map(profile),
      ...scriptIds.map(script),
      ...providers.where((item) => !item.isRemote).map(provider),
    ];
  }

  static List<String> ofData(MigrationData data) {
    return of(
      profileIds: data.profiles.map((item) => item.id),
      scriptIds: data.scripts.map((item) => item.id),
      providers: data.clashProviders,
    );
  }

  static String resolve(String root, String entry) {
    return joinAll([root, ...posix.split(entry)]);
  }
}

typedef BackupArchiveRequest = ({
  String archivePath,
  Map<String, Object?> configMap,
  String databaseSnapshotPath,
  String homeDirPath,
  List<String> entries,
});

typedef RestoreArchiveRequest = ({String archivePath, String stagingDirPath});

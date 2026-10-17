part of '../action.dart';

typedef BackupDelivery = Future<bool> Function(String archivePath);

/// Returns the archive to restore, or null when the user backed out. A source
/// that downloads writes to [downloadPath], which is removed afterwards.
typedef BackupFetch = Future<String?> Function(String downloadPath);

@Riverpod(keepAlive: true)
class BackupAction extends _$BackupAction {
  @override
  void build() {}

  Future<bool> backup(BackupDelivery deliver) {
    return _withWorkDir((workDir) async {
      return deliver(await _createArchive(workDir));
    });
  }

  Future<bool> restore(RestoreOption option, BackupFetch fetch) {
    return _withWorkDir((workDir) async {
      final archivePath = await fetch(join(workDir, 'download.zip'));
      if (archivePath == null) {
        return false;
      }
      final stagingDirPath = join(workDir, 'staging');
      final MigrationData data;
      try {
        data = await restoreTask((
          archivePath: archivePath,
          stagingDirPath: stagingDirPath,
        ));
      } on BackupException catch (e) {
        throw MessageException(switch (e.failure) {
          BackupFailure.invalid => currentAppLocalizations.invalidBackupFile,
          BackupFailure.newerVersion =>
            currentAppLocalizations.backupFromNewerVersion,
        });
      }
      await applyRestore(data, option, stagingDirPath: stagingDirPath);
      return true;
    });
  }

  Future<bool> _withWorkDir(Future<bool> Function(String workDir) run) async {
    final workDir = join(await appPath.tempPath, 'backup$uniqueId');
    await ensurePathDir(workDir);
    try {
      return await run(workDir);
    } finally {
      await safeDeletePath(workDir);
      await _discardLegacyStaging();
    }
  }

  /// Earlier versions staged restores in the home directory and never removed
  /// the downloaded archive.
  Future<void> _discardLegacyStaging() async {
    final homeDirPath = await appPath.homeDirPath;
    await safeDeletePath(join(homeDirPath, 'backup.zip'));
    await safeDeletePath(join(homeDirPath, 'restore'));
  }

  Future<String> _createArchive(String workDir) async {
    final databaseSnapshotPath = join(workDir, backupDatabaseName);
    await database.customStatement('VACUUM INTO ?', [databaseSnapshotPath]);
    final (profileIds, scriptIds, providers) = await (
      database.profilesDao.query().map((item) => item.id).get(),
      database.scriptsDao.query().map((item) => item.id).get(),
      database.clashProvidersDao.query().get(),
    ).wait;
    final configMap = ref.read(configProvider).toJson();
    configMap['version'] = await preferences.getVersion();
    final archivePath = join(workDir, 'backup.zip');
    await backupTask((
      archivePath: archivePath,
      configMap: configMap,
      databaseSnapshotPath: databaseSnapshotPath,
      homeDirPath: await appPath.homeDirPath,
      entries: BackupEntries.of(
        profileIds: profileIds,
        scriptIds: scriptIds,
        providers: providers,
      ),
    ));
    return archivePath;
  }

  @visibleForTesting
  Future<void> applyRestore(
    MigrationData data,
    RestoreOption option, {
    String? stagingDirPath,
  }) async {
    final configMap = data.configMap;
    final config = option == RestoreOption.onlyProfiles || configMap == null
        ? null
        : Config.fromJson(configMap);
    final isOverride =
        ref.read(appSettingProvider).restoreStrategy ==
        RestoreStrategy.override;
    final previousProviders = await database.clashProvidersDao.query().get();
    final putBack = stagingDirPath == null
        ? null
        : await _copyStagedFiles(data, stagingDirPath);
    try {
      await database.restore(
        data.profiles,
        data.scripts,
        data.rules,
        data.disabledRules,
        data.proxyGroups,
        clashProviders: data.clashProviders,
        customProxies: data.customProxies,
        proxyDialers: data.proxyDialers,
        isOverride: isOverride,
      );
    } catch (_) {
      await putBack?.call();
      rethrow;
    }
    await _clearReplacedProviderCaches(previousProviders);
    await _clearOutdatedCompiledRuleSets(data.clashProviders);
    if (config == null) {
      return;
    }
    // A desktop backup carries no package lists; the apps picked here stay.
    final accessControlProps = config.vpnProps.accessControlProps.hasPackages
        ? config.vpnProps.accessControlProps
        : ref.read(vpnSettingProvider).accessControlProps;
    writeConfig(
      ref.read,
      config.copyWith(
        davProps: config.davProps ?? ref.read(davSettingProvider),
        vpnProps: config.vpnProps.copyWith(
          accessControlProps: accessControlProps,
        ),
      ),
    );
  }

  /// The files go in before the rows that name them, so the returned callback
  /// is how a restore whose rows fail takes them back out.
  Future<Future<void> Function()> _copyStagedFiles(
    MigrationData data,
    String stagingDirPath,
  ) async {
    final homeDirPath = await appPath.homeDirPath;
    final replacedDirPath = join(stagingDirPath, 'replaced');
    final copied = <String, bool>{};
    Future<void> putBack() async {
      for (final MapEntry(key: entry, value: replaced) in copied.entries) {
        final target = BackupEntries.resolve(homeDirPath, entry);
        if (replaced) {
          await safeCopyPath(
            BackupEntries.resolve(replacedDirPath, entry),
            target,
          );
        } else {
          await safeDeletePath(target);
        }
      }
    }

    try {
      for (final entry in BackupEntries.ofData(data)) {
        final staged = BackupEntries.resolve(stagingDirPath, entry);
        if (!await pathExists(staged)) {
          continue;
        }
        final target = BackupEntries.resolve(homeDirPath, entry);
        final replaced = await pathExists(target);
        if (replaced) {
          await safeCopyPath(
            target,
            BackupEntries.resolve(replacedDirPath, entry),
          );
        }
        copied[entry] = replaced;
        await safeCopyPath(staged, target);
      }
    } catch (_) {
      await putBack();
      rethrow;
    }
    return putBack;
  }

  Future<void> _clearReplacedProviderCaches(
    List<ClashProvider> previousProviders,
  ) async {
    final kept = (await database.clashProvidersDao.fileNames().get()).toSet();
    for (final provider in previousProviders) {
      if (kept.contains(provider.fileName)) {
        continue;
      }
      await safeDeletePath(await provider.path);
      await safeDeletePath(await provider.compiledPath);
    }
  }

  /// A restored source outdates the mrs compiled from the one it replaced.
  Future<void> _clearOutdatedCompiledRuleSets(
    List<ClashProvider> restored,
  ) async {
    for (final provider in restored) {
      if (!provider.isRemote) {
        await safeDeletePath(await provider.compiledPath);
      }
    }
  }
}

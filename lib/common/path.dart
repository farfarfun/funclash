import 'dart:async';

import 'package:fl_clash/common/app_dirs.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';

class AppPath {
  static AppPath? _instance;
  Completer<String> dataDir = Completer();
  late final Future<String?> _downloadDir = downloadDirectory();
  Completer<String> tempDir = Completer();
  Completer<String> cacheDir = Completer();

  @visibleForTesting
  static Future<String> Function() supportDirectory = resolveSupportDir;

  @visibleForTesting
  static Future<String> Function() temporaryDirectory = resolveTemporaryDir;

  @visibleForTesting
  static Future<String> Function() cacheDirectory = resolveCacheDir;

  @visibleForTesting
  static Future<String?> Function() downloadDirectory = resolveDownloadsDir;

  AppPath._internal() {
    supportDirectory().then((value) {
      dataDir.complete(value);
    });
    temporaryDirectory().then((value) {
      tempDir.complete(value);
    });
    cacheDirectory().then((value) {
      cacheDir.complete(value);
    });
  }

  factory AppPath() {
    _instance ??= AppPath._internal();
    return _instance!;
  }

  String get executableExtension {
    return system.isWindows ? '.exe' : '';
  }

  String get executableDirPath {
    return dirname(AppPlatform.executablePath);
  }

  String get corePath {
    return join(executableDirPath, 'FlClashCore$executableExtension');
  }

  String get helperPath {
    return join(executableDirPath, '$appHelperService$executableExtension');
  }

  Future<String> get downloadDirPath async {
    final directory = await _downloadDir;
    return directory ?? await homeDirPath;
  }

  Future<String> get homeDirPath => dataDir.future;

  Future<String> get databasePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'database.sqlite');
  }

  Future<String> get tempFilePath async {
    final mTempDir = await tempDir.future;
    return join(mTempDir, 'temp$uniqueId');
  }

  Future<String> get lockFilePath async {
    final homeDirPath = await appPath.homeDirPath;
    return join(homeDirPath, 'FlClash.lock');
  }

  Future<String> get configFilePath async {
    final mHomeDirPath = await homeDirPath;
    return join(mHomeDirPath, 'config.yaml');
  }

  Future<String> get sharedPreferencesPath async {
    final directory = await dataDir.future;
    return join(directory, 'shared_preferences.json');
  }

  Future<String> get profilesPath async {
    final directory = await dataDir.future;
    return join(directory, profilesDirectoryName);
  }

  Future<String> getProfilePath(String fileName) async {
    return join(await profilesPath, '$fileName.yaml');
  }

  Future<String> get scriptsDirPath async {
    final path = await homeDirPath;
    return join(path, 'scripts');
  }

  Future<String> getScriptPath(String fileName) async {
    final path = await scriptsDirPath;
    return join(path, '$fileName.js');
  }

  Future<String> get providerCacheRootPath async {
    final directory = await homeDirPath;
    return join(directory, providersDirectoryName);
  }

  Future<String> getProviderCachePath(String fileName) async {
    return join(
      await providerCacheRootPath,
      rulesProviderDirectoryName,
      fileName,
    );
  }

  Future<String> getProvidersRootPath() async {
    final directory = await profilesPath;
    return join(directory, providersDirectoryName);
  }

  Future<String> getProviderDirPath(int profileId, String type) async {
    final directory = await getProvidersRootPath();
    return join(directory, profileId.toString(), type);
  }

  Future<void> ensureProviderDirs(int profileId) async {
    for (final type in const [
      proxiesProviderDirectoryName,
      rulesProviderDirectoryName,
    ]) {
      await ensurePathDir(await getProviderDirPath(profileId, type));
    }
  }

  Future<String> get tempPath => tempDir.future;
}

final appPath = AppPath();

String getBackupFileName() {
  return '${appName}_backup_${DateTime.now().show}.zip';
}

String get logFileName {
  return '${appName}_${DateTime.now().show}.log';
}

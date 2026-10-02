import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:funclash_app/core/app_settings_store.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('funclash_app_settings_test');
  });

  tearDown(() => tempDir.delete(recursive: true));

  // 不带 override 的用例显式传空串，避免跑测试的机器上恰好设了 FUNCLASH_SECRET 时结果漂移。
  AppSettingsStore openWithoutOverride(String path) =>
      AppSettingsStore.open(path: path, secretOverride: '');

  test('load() returns defaults when no settings file exists yet', () {
    final store = openWithoutOverride(p.join(tempDir.path, 'app_settings.json'));
    expect(store.load(), AppSettingsStore.defaults);
  });

  test('save() then load() round-trips the settings', () {
    final path = p.join(tempDir.path, 'app_settings.json');
    openWithoutOverride(path).save(host: '10.0.0.5', port: 9999, secret: 's3cret');

    expect(openWithoutOverride(path).load(), (host: '10.0.0.5', port: 9999, secret: 's3cret'));
  });

  test('load() falls back to defaults on corrupt JSON', () {
    final path = p.join(tempDir.path, 'app_settings.json');
    File(path).writeAsStringSync('not valid json');

    expect(openWithoutOverride(path).load(), AppSettingsStore.defaults);
  });

  test('FUNCLASH_SECRET 覆盖文件里的 secret，并且不会被写回文件', () {
    final path = p.join(tempDir.path, 'app_settings.json');
    openWithoutOverride(path).save(host: '10.0.0.5', port: 9999, secret: 'from-file');

    final overridden = AppSettingsStore.open(path: path, secretOverride: 'from-env');
    expect(overridden.hasSecretOverride, isTrue);
    expect(overridden.load(), (host: '10.0.0.5', port: 9999, secret: 'from-env'));

    overridden.save(host: '10.0.0.5', port: 9999, secret: 'from-env');
    final persisted = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    expect(persisted['secret'], '');
    expect(persisted['host'], '10.0.0.5');
  });

  test('没有配置文件时 secret 同样走环境变量', () {
    final store = AppSettingsStore.open(
      path: p.join(tempDir.path, 'missing.json'),
      secretOverride: 'from-env',
    );
    expect(store.load(), (host: '127.0.0.1', port: 9090, secret: 'from-env'));
  });

  test('空的环境变量视为未设置', () {
    final path = p.join(tempDir.path, 'app_settings.json');
    openWithoutOverride(path).save(host: '127.0.0.1', port: 9090, secret: 'from-file');

    final store = AppSettingsStore.open(path: path, secretOverride: '');
    expect(store.hasSecretOverride, isFalse);
    expect(store.load().secret, 'from-file');
  });

  test(
    'save() 把设置文件权限收紧到 0600',
    () {
      final path = p.join(tempDir.path, 'app_settings.json');
      File(path).writeAsStringSync('{}');
      Process.runSync('chmod', ['644', path]);

      openWithoutOverride(path).save(host: '127.0.0.1', port: 9090, secret: 's3cret');

      expect(File(path).statSync().modeString(), 'rw-------');
    },
    skip: Platform.isWindows,
  );
}

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

  test('load() returns defaults when no settings file exists yet', () {
    final store = AppSettingsStore.open(path: p.join(tempDir.path, 'app_settings.json'));
    expect(store.load(), AppSettingsStore.defaults);
  });

  test('save() then load() round-trips the settings', () {
    final store = AppSettingsStore.open(path: p.join(tempDir.path, 'app_settings.json'));
    store.save(host: '10.0.0.5', port: 9999, secret: 's3cret');

    final reloaded = AppSettingsStore.open(path: p.join(tempDir.path, 'app_settings.json'));
    expect(reloaded.load(), (host: '10.0.0.5', port: 9999, secret: 's3cret'));
  });

  test('load() falls back to defaults on corrupt JSON', () {
    final path = p.join(tempDir.path, 'app_settings.json');
    File(path).writeAsStringSync('not valid json');

    final store = AppSettingsStore.open(path: path);
    expect(store.load(), AppSettingsStore.defaults);
  });
}

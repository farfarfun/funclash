import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive_io.dart';
import 'package:yaml/yaml.dart';

import '../../tool/setup.dart';
import '../../tool/build_panel.dart';

void main() {
  test(
    'the panel keeps runtime files and omits renderer debug symbols',
    () async {
      final directory = Directory.systemTemp.createTempSync('panel-package-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final root = Directory('${directory.path}/web')..createSync();
      final files = {
        'index.html': '<html></html>',
        'main.dart.wasm': 'application',
        'main.dart.js': 'fallback',
        'canvaskit/skwasm.wasm': 'renderer',
        'canvaskit/skwasm_heavy.wasm': 'renderer fallback',
        'canvaskit/skwasm.js.symbols': 'debug symbols',
        'assets/NOTICES': 'licenses',
      };
      for (final entry in files.entries) {
        File('${root.path}/${entry.key}')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(entry.value);
      }
      final output = '${directory.path}/panel.zip';

      await archivePanelBundle(root, output, version: '1.0.12');

      final archive = ZipDecoder().decodeBytes(File(output).readAsBytesSync());
      for (final entry in files.entries) {
        final file = archive.findFile(entry.key);
        if (entry.key.endsWith('.symbols')) {
          expect(file, isNull);
          expect(File('${root.path}/${entry.key}').existsSync(), isFalse);
        } else {
          expect(String.fromCharCodes(file!.readBytes()!), entry.value);
        }
      }
      expect(
        String.fromCharCodes(archive.findFile('.funclash-panel')!.readBytes()!),
        '1.0.12',
      );
    },
  );

  group('Debian naming', () {
    test('apt accepts the package name', () {
      final config =
          loadYaml(
                File('linux/packaging/deb/make_config.yaml').readAsStringSync(),
              )
              as YamlMap;

      expect(
        config['package_name'],
        matches(RegExp(r'^[a-z0-9][a-z0-9+.-]+$')),
        reason: 'Debian package names are lower case',
      );
    });

    test('the built file is the one dpkg-scanpackages globs for', () {
      final name = debianArtifactName(
        pubspec: File('pubspec.yaml').readAsStringSync(),
        makeConfig: File(
          'linux/packaging/deb/make_config.yaml',
        ).readAsStringSync(),
        arch: 'amd64',
      );

      expect(name, matches(RegExp(r'^funclash_\d+\.\d+\.\d+_amd64\.deb$')));
    });
  });

  group('Linux packaging teardown', () {
    for (final format in ['deb', 'rpm']) {
      test('$format removes the Helper unit only on a real uninstall', () {
        final config =
            loadYaml(
                  File(
                    'linux/packaging/$format/make_config.yaml',
                  ).readAsStringSync(),
                )
                as YamlMap;
        final scripts = (config['postuninstall_scripts'] as YamlList)
            .cast<String>();

        expect(scripts.first, contains('exit 0'));
        expect(
          scripts,
          contains('rm -f /etc/systemd/system/funclash-helper.service'),
        );
        expect(
          scripts.any((script) => script.contains('systemctl daemon-reload')),
          isTrue,
        );
      });
    }
  });

  test('every Linux package names the GTK application id as its window '
      'class', () {
    final applicationId = RegExp(
      r'set\(APPLICATION_ID "([^"]+)"\)',
    ).firstMatch(File('linux/CMakeLists.txt').readAsStringSync())!.group(1);

    for (final format in ['deb', 'rpm', 'appimage']) {
      final config =
          loadYaml(
                File(
                  'linux/packaging/$format/make_config.yaml',
                ).readAsStringSync(),
              )
              as YamlMap;
      expect(config['startup_wm_class'], applicationId, reason: format);
    }
  });

  test('rpm keeps the Core bytes the Helper was built against', () {
    final config =
        loadYaml(
              File('linux/packaging/rpm/make_config.yaml').readAsStringSync(),
            )
            as YamlMap;
    final macros = (config['spec_macros'] as YamlList).cast<String>();

    expect(macros, contains('%global debug_package %{nil}'));
    expect(macros, contains('%global __os_install_post %{nil}'));
  });
}

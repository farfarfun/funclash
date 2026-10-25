import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive_io.dart';
import 'package:yaml/yaml.dart';

import '../../tool/setup.dart';
import '../../tool/build_panel.dart';

void main() {
  test(
    'Windows ZIP compression preserves the complete release bundle',
    () async {
      final root = Directory.systemTemp.createTempSync('windows-package-');
      addTearDown(() => root.deleteSync(recursive: true));
      final output = File('${root.path}/dist/package.zip');
      output.parent.createSync();
      final files = {
        'FunClash.exe': List.generate(65536, (index) => index % 256),
        'data/flutter_assets/assets/panel/panel.zip': [0, 255, 80, 75, 1, 2],
        'manifest.json': '{"coreSha256":"test"}'.codeUnits,
        '.hidden': <int>[],
      };
      for (final arch in ['amd64', 'arm64']) {
        final target = arch == 'amd64' ? 'x64' : arch;
        final bundle = Directory(
          '${root.path}/build/windows/$target/runner/Release',
        );
        for (final entry in files.entries) {
          File('${bundle.path}/${entry.key}')
            ..parent.createSync(recursive: true)
            ..writeAsBytesSync(entry.value);
        }
        Directory('${bundle.path}/empty').createSync();
        await ZipFileEncoder().zipDirectory(bundle, filename: output.path);
        final before = output.lengthSync();

        await compressWindowsZip(root, arch);

        final archive = ZipDecoder().decodeBytes(output.readAsBytesSync());
        expect(output.lengthSync(), lessThan(before));
        expect(
          archive.files.where((file) => file.isFile),
          hasLength(files.length),
        );
        for (final entry in files.entries) {
          expect(archive.findFile(entry.key)!.readBytes(), entry.value);
        }
        expect(archive.findFile('empty/')!.isDirectory, isTrue);
        expect(File('${output.path}.tmp').existsSync(), isFalse);
      }
    },
  );

  test('Windows packaging refuses missing or ambiguous inputs', () async {
    final root = Directory.systemTemp.createTempSync('windows-package-');
    addTearDown(() => root.deleteSync(recursive: true));
    final output = File('${root.path}/dist/package.zip');
    output.parent.createSync();
    output.writeAsStringSync('original');

    await expectLater(compressWindowsZip(root, 'amd64'), throwsStateError);
    expect(output.readAsStringSync(), 'original');

    File('${root.path}/dist/old.zip').writeAsStringSync('old');
    await expectLater(compressWindowsZip(root, 'amd64'), throwsStateError);
    expect(output.readAsStringSync(), 'original');
    expect(File('${output.path}.tmp').existsSync(), isFalse);
  });

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

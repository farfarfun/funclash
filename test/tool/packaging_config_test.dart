import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import '../../tool/setup.dart';

void main() {
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
          contains('rm -f /etc/systemd/system/flclash-helper.service'),
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

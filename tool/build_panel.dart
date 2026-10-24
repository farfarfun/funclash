import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const panelBundlePath = 'assets/panel/panel.zip';

String get panelVersion =>
    (loadYaml(File('pubspec.yaml').readAsStringSync())['version'] as String)
        .split('+')
        .first;

Future<void> buildPanelBundle() async {
  final build = await Process.start(
    'flutter',
    ['build', 'web', '--release', '--wasm'],
    mode: ProcessStartMode.inheritStdio,
    runInShell: Platform.isWindows,
  );
  if (await build.exitCode != 0) throw StateError('The Web panel build failed');
  final root = Directory('build/web');
  File(p.join(root.path, '.funclash-panel')).writeAsStringSync(panelVersion);
  File(panelBundlePath).parent.createSync(recursive: true);
  final encoder = ZipFileEncoder();
  await encoder.zipDirectory(root, filename: panelBundlePath);
}

void stagePanelBundle(String archivePath) {
  final file = File(archivePath);
  final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  final stamp = archive.findFile('.funclash-panel');
  if (archive.findFile('index.html') == null ||
      stamp == null ||
      String.fromCharCodes(stamp.readBytes() ?? []).trim() != panelVersion) {
    throw StateError(
      'The panel archive must match application version $panelVersion',
    );
  }
  if (p.absolute(archivePath) != p.absolute(panelBundlePath)) {
    File(panelBundlePath).parent.createSync(recursive: true);
    file.copySync(panelBundlePath);
  }
}

Future<void> main() => buildPanelBundle();

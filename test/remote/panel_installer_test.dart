import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/remote/panel_installer_native.dart';
import 'package:path/path.dart' as p;

Uint8List _zip(Map<String, String> entries) {
  final archive = Archive();
  for (final MapEntry(key: name, value: body) in entries.entries) {
    final bytes = body.codeUnits;
    archive.add(ArchiveFile.bytes(name, bytes));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _root() {
  final directory = Directory.systemTemp.createTempSync('panel_install');
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return p.join(directory.path, 'panel');
}

PanelFetch _serving(Uint8List archive, {List<String>? asked}) {
  return (url, {onProgress}) async {
    asked?.add(url);
    onProgress?.call(archive.length, archive.length);
    return archive;
  };
}

void main() {
  group('panelArchiveUrl', () {
    test('names the archive that release publishes', () {
      expect(
        panelArchiveUrl('1.0.1'),
        'https://github.com/farfarfun/funclash/releases/download/v1.0.1/'
        'FunClash-1.0.1-panel.zip',
      );
    });
  });

  group('installPanel', () {
    test('unpacks the build and stamps the version it is', () async {
      final root = _root();
      final asked = <String>[];

      await installPanel(
        root: root,
        version: '1.0.1',
        fetch: _serving(
          _zip({'index.html': '<html>panel</html>', 'assets/a.json': '{}'}),
          asked: asked,
        ),
      );

      expect(asked.single, contains('FunClash-1.0.1-panel.zip'));
      expect(
        File(p.join(root, 'index.html')).readAsStringSync(),
        '<html>panel</html>',
      );
      expect(File(p.join(root, 'assets', 'a.json')).existsSync(), isTrue);
      expect(isPanelInstalled(root: root, version: '1.0.1'), isTrue);
    });

    test('reports the fraction it has taken', () async {
      final root = _root();
      final seen = <double>[];

      await installPanel(
        root: root,
        version: '1.0.1',
        fetch: (url, {onProgress}) async {
          final bytes = _zip({'index.html': 'x'});
          onProgress?.call(0, bytes.length);
          onProgress?.call(bytes.length ~/ 2, bytes.length);
          onProgress?.call(bytes.length, bytes.length);
          return bytes;
        },
        onProgress: seen.add,
      );

      expect(seen.first, 0);
      expect(seen.last, 1);
    });

    test('reads a length it was not told as no progress', () async {
      final root = _root();
      final seen = <double>[];

      await installPanel(
        root: root,
        version: '1.0.1',
        fetch: (url, {onProgress}) async {
          onProgress?.call(10, -1);
          return _zip({'index.html': 'x'});
        },
        onProgress: seen.add,
      );

      expect(seen, [0]);
    });

    test('an install of another version is not this one', () async {
      final root = _root();

      await installPanel(
        root: root,
        version: '1.0.0',
        fetch: _serving(_zip({'index.html': 'old'})),
      );

      expect(isPanelInstalled(root: root, version: '1.0.0'), isTrue);
      expect(isPanelInstalled(root: root, version: '1.0.1'), isFalse);
    });

    test('replaces what an older install left behind', () async {
      final root = _root();
      await installPanel(
        root: root,
        version: '1.0.0',
        fetch: _serving(_zip({'index.html': 'old', 'gone.js': 'stale'})),
      );

      await installPanel(
        root: root,
        version: '1.0.1',
        fetch: _serving(_zip({'index.html': 'new'})),
      );

      expect(File(p.join(root, 'index.html')).readAsStringSync(), 'new');
      expect(File(p.join(root, 'gone.js')).existsSync(), isFalse);
      expect(isPanelInstalled(root: root, version: '1.0.1'), isTrue);
    });

    test('writes nothing outside the folder it was given', () async {
      final root = _root();

      await installPanel(
        root: root,
        version: '1.0.1',
        fetch: _serving(
          _zip({
            '../escaped.txt': 'no',
            'assets/../../escaped.txt': 'no',
            'index.html': 'yes',
          }),
        ),
      );

      expect(File(p.join(root, 'index.html')).existsSync(), isTrue);
      expect(
        File(p.join(p.dirname(root), 'escaped.txt')).existsSync(),
        isFalse,
      );
    });

    test('a failed download leaves nothing claiming to be installed', () async {
      final root = _root();

      await expectLater(
        installPanel(
          root: root,
          version: '1.0.1',
          fetch: (url, {onProgress}) async =>
              throw const SocketException('offline'),
        ),
        throwsA(isA<SocketException>()),
      );
      expect(isPanelInstalled(root: root, version: '1.0.1'), isFalse);
    });

    test('an archive with no entry point installs nothing', () async {
      for (final bytes in [
        Uint8List.fromList([1, 2, 3]),
        _zip({'assets/a.json': '{}'}),
      ]) {
        final root = _root();

        await expectLater(
          installPanel(
            root: root,
            version: '1.0.1',
            fetch: (url, {onProgress}) async => bytes,
          ),
          throwsA(isA<FormatException>()),
        );
        expect(isPanelInstalled(root: root, version: '1.0.1'), isFalse);
      }
    });

    test('says nothing is installed for a folder that is not there', () {
      expect(isPanelInstalled(root: _root(), version: '1.0.1'), isFalse);
    });
  });
}

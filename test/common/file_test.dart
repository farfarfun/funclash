import 'dart:io';

import 'package:funclash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('file_test');
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  group('safeDeletePath', () {
    test('removes a file', () async {
      final path = join(root.path, 'config.yaml');
      File(path).writeAsStringSync('mixed-port: 7890');

      await safeDeletePath(path);

      expect(File(path).existsSync(), isFalse);
    });

    test('removes a directory along with everything under it', () async {
      final path = join(root.path, '42');
      File(join(path, 'proxies', 'abc'))
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: []');

      await safeDeletePath(path);

      expect(Directory(path).existsSync(), isFalse);
    });

    test('accepts a path that is already gone', () async {
      await expectLater(safeDeletePath(join(root.path, 'missing')), completes);
    });
  });

  group('readPathHead', () {
    test('stops after the requested length', () async {
      final path = join(root.path, 'rule.mrs');
      File(path).writeAsBytesSync([1, 2, 3, 4, 5]);

      expect(await readPathHead(path, 3), [1, 2, 3]);
    });

    test('tells a missing file from an empty one', () async {
      final path = join(root.path, 'empty');
      File(path).writeAsBytesSync(const []);

      expect(await readPathHead(path, 8), isEmpty);
      expect(await readPathHead(join(root.path, 'missing'), 8), isNull);
    });
  });

  group('readPathStat', () {
    test('reads the size and the last-modified date', () async {
      final path = join(root.path, 'config.yaml');
      final modified = DateTime(2026, 7, 29);
      File(path)
        ..writeAsStringSync('mixed-port: 7890')
        ..setLastModifiedSync(modified);

      expect(await readPathStat(path), (size: 16, lastModified: modified));
    });

    test('takes a date inside the epoch year as no date at all', () async {
      final path = join(root.path, 'extracted.yaml');
      File(path)
        ..writeAsStringSync('mode: rule')
        ..setLastModifiedSync(DateTime(1970, 12, 31, 23, 59, 59));

      expect(await readPathStat(path), (size: 10, lastModified: null));
    });

    test('answers null for a missing file', () async {
      expect(await readPathStat(join(root.path, 'missing')), isNull);
    });
  });

  group('isPathAgeEncrypted', () {
    test('tells an armor header from a plain config', () async {
      final encrypted = join(root.path, 'secret.yaml');
      File(encrypted).writeAsStringSync(
        '-----BEGIN AGE ENCRYPTED FILE-----\nYWdlLWVuY3J5cHRpb24ub3Jn\n',
      );
      final plain = join(root.path, 'config.yaml');
      File(plain).writeAsStringSync('mixed-port: 7890');

      expect(await isPathAgeEncrypted(encrypted), isTrue);
      expect(await isPathAgeEncrypted(plain), isFalse);
    });

    test('takes a missing file as not encrypted', () async {
      expect(await isPathAgeEncrypted(join(root.path, 'missing')), isFalse);
    });
  });

  group('pathExists', () {
    test('answers for a file and not for what is gone', () async {
      final path = join(root.path, 'config.yaml');
      File(path).writeAsStringSync('mode: rule');

      expect(await pathExists(path), isTrue);
      expect(await pathExists(join(root.path, 'missing')), isFalse);
    });
  });

  group('safeWritePath', () {
    test('creates the directory a string write needs', () async {
      final path = join(root.path, 'home', 'config.yaml');

      await safeWritePathAsString(path, 'mode: rule');

      expect(File(path).readAsStringSync(), 'mode: rule');
    });

    test('creates the directory a byte write needs', () async {
      final path = join(root.path, 'providers', 'rule.mrs');

      await safeWritePathAsBytes(path, [40, 181, 47, 253]);

      expect(File(path).readAsBytesSync(), [40, 181, 47, 253]);
    });
  });

  group('readPathAsBytes', () {
    test('reads a whole file', () async {
      final path = join(root.path, 'backup.zip');
      File(path).writeAsBytesSync([80, 75, 3, 4]);

      expect(await readPathAsBytes(path), [80, 75, 3, 4]);
    });

    test('refuses a missing file the way a byte read does', () async {
      await expectLater(
        readPathAsBytes(join(root.path, 'missing')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('readPathOrEmpty', () {
    test('takes a missing file as empty bytes', () async {
      final path = join(root.path, 'missing');

      expect(await readPathAsBytesOrEmpty(path), isEmpty);
    });

    test('takes a missing file as an empty string', () async {
      final path = join(root.path, 'preferences.json');
      File(path).writeAsStringSync('{"flutter.mode":"rule"}');

      expect(await readPathAsStringOrEmpty(path), '{"flutter.mode":"rule"}');
      expect(await readPathAsStringOrEmpty(join(root.path, 'gone')), isEmpty);
    });
  });

  group('readPathAsBytesOrNull', () {
    test('tells a missing file from an empty one', () async {
      final path = join(root.path, 'empty');
      File(path).writeAsBytesSync(const []);

      expect(await readPathAsBytesOrNull(path), isEmpty);
      expect(await readPathAsBytesOrNull(join(root.path, 'missing')), isNull);
    });
  });

  group('ensurePathDir', () {
    test('creates the missing parents and accepts an existing dir', () async {
      final path = join(root.path, 'providers', '7', 'rules');

      await ensurePathDir(path);
      await expectLater(ensurePathDir(path), completes);

      expect(Directory(path).existsSync(), isTrue);
    });
  });

  group('listPathEntriesSync', () {
    test('tells a directory entry from a file entry', () {
      File(join(root.path, 'config.yaml')).writeAsStringSync('mode: rule');
      Directory(join(root.path, 'providers')).createSync();

      final entries = {
        for (final entry in listPathEntriesSync(root.path))
          basename(entry.path): entry.isDirectory,
      };

      expect(entries, {'config.yaml': false, 'providers': true});
    });

    test('leaves out a link and takes a missing directory as empty', () {
      final target = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mode: rule');
      Link(join(root.path, 'current.yaml')).createSync(target.path);

      expect(listPathEntriesSync(root.path).map((e) => basename(e.path)), [
        'config.yaml',
      ]);
      expect(listPathEntriesSync(join(root.path, 'missing')), isEmpty);
    });

    test('names the directory itself, not what it holds', () {
      File(join(root.path, 'providers', 'rules', 'abc'))
        ..createSync(recursive: true)
        ..writeAsStringSync('payload: []');

      expect(listPathEntriesSync(root.path).map((e) => basename(e.path)), [
        'providers',
      ]);
    });
  });

  group('movePathSync', () {
    test('creates the directory the target needs', () {
      final from = join(root.path, 'proxies', 'legacy');
      File(from)
        ..createSync(recursive: true)
        ..writeAsStringSync('proxies: []');
      final to = join(root.path, 'proxies', 'abc', 'named');

      movePathSync(from, to);

      expect(File(to).readAsStringSync(), 'proxies: []');
      expect(File(from).existsSync(), isFalse);
    });

    test('keeps a target that is already there', () {
      final from = join(root.path, 'legacy');
      File(from).writeAsStringSync('legacy');
      final to = join(root.path, 'named');
      File(to).writeAsStringSync('named');

      movePathSync(from, to);

      expect(File(to).readAsStringSync(), 'named');
      expect(File(from).readAsStringSync(), 'legacy');
    });

    test('accepts a source that is gone', () {
      expect(
        () => movePathSync(join(root.path, 'missing'), join(root.path, 'to')),
        returnsNormally,
      );
    });
  });

  group('renamePath', () {
    test('replaces a target that is already there', () async {
      final from = join(root.path, 'abc.new');
      File(from).writeAsStringSync('payload: next');
      final to = join(root.path, 'abc');
      File(to).writeAsStringSync('payload: previous');

      await renamePath(from, to);

      expect(File(to).readAsStringSync(), 'payload: next');
      expect(File(from).existsSync(), isFalse);
    });

    test('refuses a source that is gone', () async {
      await expectLater(
        renamePath(join(root.path, 'missing'), join(root.path, 'abc')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('safeCopyPath', () {
    test('creates the directory the copy needs', () async {
      final from = join(root.path, 'config.yaml');
      File(from).writeAsStringSync('mode: rule');
      final to = join(root.path, 'restore', 'config.yaml');

      await safeCopyPath(from, to);

      expect(File(to).readAsStringSync(), 'mode: rule');
    });
  });

  group('writePathAsStringAtomically', () {
    test('creates the directory a first write needs', () async {
      final path = join(root.path, 'home', 'preferences.json');

      await writePathAsStringAtomically(path, '{}');

      expect(File(path).readAsStringSync(), '{}');
    });
  });

  group('writeAsStringAtomically', () {
    test('replaces the file and leaves nothing beside it', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mixed-port: 7890');

      await file.writeAsStringAtomically('mixed-port: 7891');

      expect(file.readAsStringSync(), 'mixed-port: 7891');
      expect(root.listSync().map((entry) => basename(entry.path)), [
        'config.yaml',
      ]);
    });

    test('creates the directory a first write needs', () async {
      final file = File(join(root.path, 'home', 'config.yaml'));

      await file.writeAsStringAtomically('mode: rule');

      expect(file.readAsStringSync(), 'mode: rule');
    });

    test('keeps the old file when the new one cannot be written', () async {
      final file = File(join(root.path, 'config.yaml'))
        ..writeAsStringSync('mode: rule');
      Directory('${file.path}.$pid.tmp').createSync();

      await expectLater(
        file.writeAsStringAtomically('mode: global'),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.readAsStringSync(), 'mode: rule');
    });
  });
}

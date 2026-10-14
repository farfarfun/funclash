import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _platformPackages = [
  'tray',
  'window',
  'launch_at_startup',
  'screen_retriever',
];

const _uiRoots = ['lib/views', 'lib/widgets', 'lib/pages', 'lib/features'];

const _nativeSuffix = '_native.dart';

const _platformModules = [
  'lib/common/tray.dart',
  'lib/common/window.dart',
  'lib/common/launch.dart',
  'lib/common/system_dns.dart',
  'lib/common/wifi.dart',
];

// Splitting a module for the web target moves the platform import down into
// the native half, which is then the file allowed to name the package.
const _platformImporters = [
  ..._platformModules,
  'lib/common/launch_native.dart',
  'lib/common/tray_native.dart',
  'lib/common/window_native.dart',
];

final _platformImport = RegExp(
  "^import 'package:(${_platformPackages.join('|')})/",
  multiLine: true,
);

// Emptying both ratchets is what finishes the web target; the walk they
// measure is the web build's own graph, not a listing of `lib`.
const _webIncompatibleInWebBuild = {
  'dart:ffi': <String>[],
  'dart:io': <String>[],
  'dart:isolate': <String>[],
};

// A package with no web implementation breaks the build exactly as `dart:io`
// does, and the two do not have to travel together.
const _webIncompatiblePackagesInWebBuild = {
  'package:archive/archive_io.dart': <String>[],
  'package:dio/io.dart': <String>[],
  'package:drift/native.dart': <String>[],
  'package:ffi/ffi.dart': <String>[],
  'package:launch_at_startup/': <String>[],
  'package:proxy/': <String>[],
  'package:rust_api/': <String>[],
  'package:screen_retriever/': <String>[],
  'package:tray/': <String>[],
  'package:wifi_ssid/': <String>[],
  'package:win32_registry/': <String>[],
  'package:window/': <String>[],
};

// The libraries whose presence tells a conditional directive it is the web
// build; `dart.library.io` is how the same directive names the other side.
const _webOnlyLibraries = {
  'dart.library.js_interop',
  'dart.library.js',
  'dart.library.html',
};

final _directive = RegExp(
  r'^\s*(?:import|export|part)\s+(?!of\b)([^;]*);',
  multiLine: true,
);

final _conditionalUri = RegExp(r'''if\s*\(([^)]*)\)\s*['"]([^'"]+)['"]''');

final _anyUri = RegExp('''['"]([^'"]+)['"]''');

String? _uriChosenBy(String directive, {required bool web}) {
  if (web) {
    for (final match in _conditionalUri.allMatches(directive)) {
      if (_webOnlyLibraries.contains(match.group(1)!.trim())) {
        return match.group(2);
      }
    }
  }
  return _anyUri.firstMatch(directive)?.group(1);
}

Set<String> _closureFrom(String entryPoint, {required bool web}) {
  String resolve(String uri, String from) {
    if (uri.startsWith('package:fl_clash/')) {
      return 'lib/${uri.substring('package:fl_clash/'.length)}';
    }
    if (uri.startsWith('dart:') || uri.startsWith('package:')) return uri;
    return p.normalize(p.join(p.dirname(from), uri));
  }

  final reached = <String>{entryPoint};
  final queue = <String>[...reached];

  while (queue.isNotEmpty) {
    final current = queue.removeLast();
    final file = File(current);
    if (!file.existsSync()) continue;
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final uri = _uriChosenBy(match.group(1)!, web: web);
      if (uri == null) continue;
      final next = resolve(uri, current);
      if (!reached.add(next)) continue;
      queue.add(next);
    }
  }

  return reached;
}

Set<String> _closureOfCommonBarrel() =>
    _closureFrom('lib/common/common.dart', web: false);

List<String> _filesInWebBuild() {
  final files = [
    for (final path in _closureFrom('lib/main.dart', web: true))
      if (path.startsWith('lib/') &&
          path.endsWith('.dart') &&
          File(path).existsSync())
        path,
  ];
  files.sort();
  return files;
}

const _quote = '''['"]''';

// A key ending in `/` matches any entry point of that package; anything else
// has to be the whole URI, so `dart:io` does not also catch `dart:io_extra`.
RegExp _reaching(String uri) => RegExp(
  '^\\s*(?:import|export)\\s+$_quote${RegExp.escape(uri)}'
  '${uri.endsWith('/') ? '' : _quote}',
  multiLine: true,
);

void _expectRatchet(
  Map<String, List<String>> ratchet,
  String name,
  String advice,
) {
  final sources = _filesInWebBuild();

  for (final MapEntry(key: uri, value: expected) in ratchet.entries) {
    final reaching = _reaching(uri);
    final actual = [
      for (final path in sources)
        if (reaching.hasMatch(File(path).readAsStringSync())) path,
    ];
    final added = actual.where((f) => !expected.contains(f)).toList();
    final fixed = expected.where((f) => !actual.contains(f)).toList();
    final gained =
        'These files reach $uri, which the web target cannot compile. '
        '$advice:\n${added.join('\n')}';
    final lost =
        'These no longer reach $uri. Strike them off `$name` so the ratchet '
        'holds the ground they gained:\n${fixed.join('\n')}';

    expect(
      actual,
      expected,
      reason: [
        if (added.isNotEmpty) gained,
        if (fixed.isNotEmpty) lost,
      ].join('\n\n'),
    );
  }
}

Iterable<File> _dartFilesIn(String root) sync* {
  final directory = Directory(root);
  if (!directory.existsSync()) {
    fail('$root no longer exists; update this test.');
  }
  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File &&
        entity.path.endsWith('.dart') &&
        !entity.path.contains('/generated/')) {
      yield entity;
    }
  }
}

void main() {
  test('the common barrel never re-exports a platform module', () {
    final exports = File('lib/common/common.dart').readAsLinesSync();
    final leaked = <String>[];

    for (final module in _platformModules) {
      final line = "export '${p.basename(module)}';";
      if (exports.contains(line)) {
        leaked.add(
          '$line — importing the barrel would pull the platform package into '
          'every one of its consumers',
        );
      }
    }

    expect(leaked, isEmpty, reason: leaked.join('\n'));
  });

  test('only the designated modules reach a desktop platform package', () {
    final offenders = <String>[];

    for (final root in ['lib/common', 'lib/enum', 'lib/models']) {
      for (final file in _dartFilesIn(root)) {
        final relative = p.relative(file.path);
        if (_platformImporters.contains(relative)) {
          continue;
        }
        final match = _platformImport.firstMatch(file.readAsStringSync());
        if (match != null) {
          offenders.add('$relative imports ${match.group(1)}');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('nothing the common barrel reaches imports a platform package', () {
    final reached = _closureOfCommonBarrel();
    final offenders = [
      for (final package in _platformPackages)
        if (reached.any((uri) => uri.startsWith('package:$package/'))) package,
    ];

    expect(
      offenders,
      isEmpty,
      reason:
          'A file the common barrel transitively reaches pulls a desktop '
          'platform package into all ${reached.where((f) => f.startsWith('lib/')).length} '
          'of its dependencies:\n${offenders.join('\n')}',
    );
  });

  test('no new file in the web build imports a web-only-hostile library', () {
    _expectRatchet(
      _webIncompatibleInWebBuild,
      '_webIncompatibleInWebBuild',
      'Split the module so the import sits behind a conditional export — '
          '`common/app_platform.dart` is the pattern — or reach the platform '
          'through a port in `common/app_ports.dart`, as `WindowPort` and '
          '`TrayPort` do',
    );
  });

  test('no new file in the web build reaches a package without web', () {
    _expectRatchet(
      _webIncompatiblePackagesInWebBuild,
      '_webIncompatiblePackagesInWebBuild',
      'Confine it to the native side of a conditional export, the way '
          '`common/app_dirs.dart` keeps `path_provider` out of the walk, or '
          'give the plugin a web implementation',
    );
  });

  test('the web build takes the web side of every conditional export', () {
    final sources = _filesInWebBuild().toSet();
    final seams = [
      for (final file in _dartFilesIn('lib'))
        if (file.path.endsWith(_nativeSuffix)) p.relative(file.path),
    ]..sort();
    final offenders = <String>[];

    for (final native in seams) {
      if (!sources.contains(native.replaceFirst(_nativeSuffix, '.dart'))) {
        continue;
      }
      final web = native.replaceFirst(_nativeSuffix, '_web.dart');
      if (sources.contains(native)) {
        offenders.add('$native is in the walk, so its seam was not followed');
      }
      if (!sources.contains(web)) {
        offenders.add('$web is missing from the walk');
      }
    }

    expect(
      seams,
      isNotEmpty,
      reason:
          'No `*_native.dart` left in `lib`, so this test measures nothing. '
          'Either the seams were renamed or the walk is broken.',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'The walk has to follow a conditional export the way the web build '
          'does. Resolving only the first URI makes every web-only variant '
          'invisible and counts a native variant the web build never compiles, '
          'so the ratchet would then measure a graph nothing builds and park '
          'files on the list that no amount of work can take '
          'off:\n${offenders.join('\n')}',
    );
  });

  test('the UI layer never imports a web-incompatible library', () {
    final offenders = <String>[];

    for (final root in _uiRoots) {
      for (final file in _dartFilesIn(root)) {
        final source = file.readAsStringSync();
        for (final library in _webIncompatibleInWebBuild.keys) {
          if (_reaching(library).hasMatch(source)) {
            offenders.add('${p.relative(file.path)} imports $library');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A widget reaches the platform directly. The file system is reached '
          'through the path-taking functions in `common/file.dart`, the '
          'operating system through `AppPlatform`; both keep the web half of '
          'the split to one conditional export instead of one per '
          'caller:\n${offenders.join('\n')}',
    );
  });

  test('the common barrel never reaches the view tree', () {
    final reached = _closureOfCommonBarrel();
    final views =
        reached.where((file) => file.startsWith('lib/views/')).toList()..sort();

    expect(
      views,
      isEmpty,
      reason:
          'A widget is reachable from `lib/common/common.dart`, so every file '
          'that imports the barrel for a string helper now compiles the UI. '
          'This is how `common/navigation.dart` and the widget on '
          '`DashboardWidget` each put ~60 view files in the closure. Data the '
          'provider layer needs is passed through a port in '
          '`common/app_ports.dart`; the layer that owns the widgets binds '
          'it:\n${views.join('\n')}',
    );
  });

  test('common never depends on the manager barrel', () {
    final offenders = <String>[];

    for (final file in _dartFilesIn('lib/common')) {
      if (file.readAsStringSync().contains(
        "import 'package:fl_clash/manager/manager.dart';",
      )) {
        offenders.add(
          '${p.relative(file.path)} — import the one manager it needs, not the '
          'barrel that reaches every platform manager',
        );
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

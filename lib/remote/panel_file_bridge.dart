import 'dart:async';
import 'dart:typed_data';

import 'package:funclash/common/file.dart';
import 'package:funclash/common/path.dart';
import 'package:funclash/common/print.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';
import 'package:path/path.dart' as p;

/// Reads and writes under the host's data directory on a panel's behalf, and
/// nowhere else: a panel names paths, and a named path is untrusted.
final class PanelFileBridge implements PanelChannelHandler {
  PanelFileBridge({Future<String>? root}) : _root = root ?? appPath.homeDirPath;

  final Future<String> _root;

  @override
  void attach(PanelSession session) {
    session.frames
        .where((frame) => frame.channel == PanelChannel.fs)
        .listen((frame) => unawaited(_serve(session, frame)));
  }

  Future<void> _serve(PanelSession session, PanelFrame frame) async {
    final call = PanelCall.fromJson(frame.payload);
    if (call == null) {
      return;
    }
    session.send(PanelFrame(PanelChannel.fs, (await _answer(call)).toJson()));
  }

  Future<PanelReply> _answer(PanelCall call) async {
    if (call.method == 'resolveSupportDir') {
      return PanelReply(id: call.id, result: await _root);
    }
    final arguments = call.arguments;
    final path = arguments is Map ? arguments['path'] : null;
    if (path is! String) {
      return PanelReply.failed(
        call.id,
        code: 'panel_bad_path',
        message: '${call.method} names no path',
      );
    }
    if (!await _within(path)) {
      return PanelReply.failed(
        call.id,
        code: 'panel_path_refused',
        message: 'outside the data directory',
      );
    }
    try {
      return PanelReply(
        id: call.id,
        result: await _run(call.method, path, (arguments as Map).cast()),
      );
    } catch (failure) {
      return PanelReply.failed(
        call.id,
        code: 'panel_file_failed',
        message: compactError(failure),
      );
    }
  }

  Future<bool> _within(String path) async {
    final root = p.normalize(p.absolute(await _root));
    final target = p.normalize(p.absolute(path));
    return target == root || p.isWithin(root, target);
  }

  Future<Object?> _run(
    String method,
    String path,
    Map<String, Object?> arguments,
  ) async {
    String other() => arguments['to']! as String;
    String text() => arguments['content']! as String;
    List<int> bytes() => (arguments['bytes']! as List).cast<int>();

    switch (method) {
      case 'pathExists':
        return pathExists(path);
      case 'ensurePathDir':
        return ensurePathDir(path).then((_) => null);
      case 'safeDeletePath':
        return safeDeletePath(path).then((_) => null);
      case 'isPathAgeEncrypted':
        return isPathAgeEncrypted(path);
      case 'readPathAsBytes':
        return (await readPathAsBytes(path)).toList(growable: false);
      case 'readPathAsBytesOrEmpty':
        return (await readPathAsBytesOrEmpty(path)).toList(growable: false);
      case 'readPathAsBytesOrNull':
        return (await readPathAsBytesOrNull(path))?.toList(growable: false);
      case 'readPathAsStringOrEmpty':
        return readPathAsStringOrEmpty(path);
      case 'readPathHead':
        return readPathHead(path, arguments['length']! as int);
      case 'readPathStat':
        return _stat(await readPathStat(path));
      case 'safeWritePathAsString':
        return safeWritePathAsString(path, text()).then((_) => null);
      case 'writePathAsStringAtomically':
        return writePathAsStringAtomically(path, text()).then((_) => null);
      case 'safeWritePathAsBytes':
        return safeWritePathAsBytes(
          path,
          bytes(),
          flush: arguments['flush'] == true,
        ).then((_) => null);
      case 'safeCopyPath':
        return _toward(path, other(), safeCopyPath);
      case 'renamePath':
        return _toward(path, other(), renamePath);
      default:
        throw UnsupportedError('$method is no file operation');
    }
  }

  /// The destination is a path the panel named too, so it is checked as one.
  Future<Object?> _toward(
    String path,
    String to,
    Future<void> Function(String, String) run,
  ) async {
    if (!await _within(to)) {
      throw UnsupportedError('$to is outside the data directory');
    }
    await run(path, to);
    return null;
  }

  Map<String, Object?>? _stat(({int size, DateTime? lastModified})? stat) {
    if (stat == null) {
      return null;
    }
    return {
      'size': stat.size,
      'lastModified': stat.lastModified?.toIso8601String(),
    };
  }
}

Uint8List panelBytes(Object? result) =>
    Uint8List.fromList((result as List? ?? const []).cast<int>());

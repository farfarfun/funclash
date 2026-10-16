import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:funclash/common/path.dart';

Future<DriftIsolate>? _background;

/// One background database with clients on it, rather than an executor owned
/// by whoever opened it: drift refuses to serve an executor a local database
/// is already using, and the panel bridge has to serve this one.
Future<DriftIsolate> _shared() => _background ??= _spawn();

Future<DriftIsolate> _spawn() async {
  final path = await appPath.databasePath;
  return DriftIsolate.spawn(() => NativeDatabase(File(path)));
}

QueryExecutor openDatabaseExecutor() =>
    DatabaseConnection.delayed(openSharedDatabaseConnection());

Future<DatabaseConnection> openSharedDatabaseConnection() async =>
    (await _shared()).connect();

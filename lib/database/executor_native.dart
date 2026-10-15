import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:funclash/common/path.dart';

QueryExecutor openDatabaseExecutor() => LazyDatabase(() async {
  final databaseFile = File(await appPath.databasePath);
  return NativeDatabase.createInBackground(databaseFile);
});

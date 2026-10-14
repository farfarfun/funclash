import 'package:drift/drift.dart';

/// Lazy so that holding the database is not itself the failure: the rows a
/// panel shows belong to the desktop host, and a query is where it finds out.
QueryExecutor openDatabaseExecutor() => LazyDatabase(
  () async => throw UnsupportedError('no local database in a browser tab'),
);

import 'package:drift/drift.dart';
// ignore: experimental_member_use, a panel runs the drift its host shipped.
import 'package:drift/remote.dart';
import 'package:funclash/remote/panel_db_channel.dart';
import 'package:funclash/remote/panel_link_state.dart';

/// A connection rather than a bare executor, and delayed rather than lazy:
/// drift reuses the stream queries of a `DatabaseConnection` it is handed, and
/// that is what carries the host's own writes back to a watching panel.
QueryExecutor openDatabaseExecutor() => DatabaseConnection.delayed(
  Future(() async {
    final session = await linkedPanelSession;
    return connectToRemoteAndInitialize(panelDatabaseChannel(session));
  }),
);

Future<DatabaseConnection> openSharedDatabaseConnection() =>
    throw UnsupportedError('a panel serves no database');

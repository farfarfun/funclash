import 'package:drift/drift.dart';
// ignore: experimental_member_use, a panel runs the drift its host shipped.
import 'package:drift/remote.dart';
import 'package:funclash/database/executor.dart';
import 'package:funclash/remote/panel_db_channel.dart';
import 'package:funclash/remote/panel_session.dart';

typedef PanelDatabaseConnect = Future<DatabaseConnection> Function();

/// Another client on the host's database, opened when a panel first arrives.
final class PanelDatabaseBridge implements PanelChannelHandler {
  PanelDatabaseBridge({PanelDatabaseConnect? connect})
    : _connect = connect ?? openSharedDatabaseConnection;

  final PanelDatabaseConnect _connect;

  Future<DatabaseConnection>? _opened;
  DriftServer? _server;

  @override
  void attach(PanelSession session) {
    final channel = panelDatabaseChannel(session);
    (_opened ??= _connect()).then((connection) {
      (_server ??= DriftServer(connection)).serve(channel);
    }).ignore();
  }

  Future<void> shutdown() async => _server?.shutdown();
}

import 'package:funclash/common/print.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/remote/panel_linker.dart';
import 'package:funclash/remote/panel_session.dart';

/// A panel's Core is the host's, over the bridge beside its own page.
final CoreHandlerInterface? coreService = _linkedPanelClient();

Future<void> connectPanel() async {
  final _ = coreService;
  await linkedPanelSession;
}

CoreHandlerInterface? _linkedPanelClient() {
  final client = PanelCoreClient();
  PanelLinker(
    client,
  ).link().then(_report).onError<Object>(_reportFailure).ignore();
  return client;
}

void _report(PanelLinkResult result) {
  commonPrint.log('panel link: $result');
  if (result case PanelLinked(:final session)) {
    reportPanelLinked(session);
  } else {
    reportPanelRefused(StateError('$result'));
  }
}

void _reportFailure(Object error, StackTrace stackTrace) {
  commonPrint.log('panel could not link: $error', logLevel: LogLevel.warning);
  reportPanelRefused(error);
}

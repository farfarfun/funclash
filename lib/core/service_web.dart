import 'package:flutter/foundation.dart';
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
  if (!kIsWasm) {
    throw UnsupportedError(
      'The remote panel requires WebAssembly to preserve 64-bit profile IDs. '
      'Open it in an up-to-date Chrome or Edge browser.',
    );
  }
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

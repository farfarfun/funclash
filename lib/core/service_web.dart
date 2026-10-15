import 'package:funclash/common/print.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_linker.dart';

/// A panel's Core is the host's, over the bridge beside its own page.
final CoreHandlerInterface? coreService = _linkedPanelClient();

PanelCoreClient _linkedPanelClient() {
  final client = PanelCoreClient();
  PanelLinker(client)
      .link()
      .then((result) => commonPrint.log('panel link: $result'))
      .onError<Object>(
        (error, _) => commonPrint.log(
          'panel could not link: $error',
          logLevel: LogLevel.warning,
        ),
      )
      .ignore();
  return client;
}

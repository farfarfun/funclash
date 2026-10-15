import 'package:funclash/remote/panel_address.dart';
import 'package:funclash/remote/panel_core_client.dart';
import 'package:funclash/remote/panel_dialer.dart';
import 'package:funclash/remote/panel_protocol.dart';
import 'package:funclash/remote/panel_session.dart';

typedef PanelDial = Future<PanelSocket> Function(Uri bridge);

/// Takes a panel from the page it was served on to a linked Core client.
final class PanelLinker {
  PanelLinker(this._client, {PanelDial? dial, Uri? page})
    : _dial = dial ?? dialPanel,
      _page = page;

  final PanelCoreClient _client;
  final PanelDial _dial;
  final Uri? _page;

  Future<PanelLinkResult> link() async {
    final page = _page ?? Uri.base;
    final token = tokenInFragment(page.fragment);
    if (token.isEmpty) {
      return const PanelRefused(PanelRejectReason.badToken);
    }
    final socket = await _dial(bridgeBeside(page));
    final result = await linkPanel(socket, token: token);
    if (result case PanelLinked(:final session)) {
      await _client.bind(session);
    }
    return result;
  }
}

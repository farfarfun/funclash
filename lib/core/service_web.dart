import 'package:funclash/core/interface.dart';
import 'package:funclash/remote/panel_core_client.dart';

/// The desktop host owns the Core, so a panel gets a client that speaks to it
/// over the bridge. Until one is linked every call reports a dead link, which
/// is an answer the caller already handles — where a null handler here was a
/// `coreService!` away from taking the panel down at startup.
final CoreHandlerInterface? coreService = PanelCoreClient();

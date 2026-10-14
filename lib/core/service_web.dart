import 'package:fl_clash/core/interface.dart';

/// The desktop host owns the Core, so a panel gets a client that speaks to it
/// over the wire; until that exists, there is no local handler at all — the
/// same answer `coreLib` gives off Android.
const CoreHandlerInterface? coreService = null;

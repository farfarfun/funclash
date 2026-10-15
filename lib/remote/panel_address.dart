import 'package:funclash/common/constant.dart';

/// The bridge beside the page the panel was served from, which is the only one
/// the host's origin check accepts.
Uri bridgeBeside(Uri page) => Uri(
  scheme: page.isScheme('https') ? 'wss' : 'ws',
  host: page.host,
  port: page.hasPort ? page.port : null,
  path: panelBridgePath,
);

/// A token in the fragment reaches no server and lands in no `Referer`, which
/// a query string does both of.
String tokenInFragment(String fragment) =>
    Uri.splitQueryString(fragment)['token'] ?? '';

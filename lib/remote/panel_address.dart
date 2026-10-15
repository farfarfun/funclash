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

/// What a person opens to reach a panel. Always the loopback, whatever the
/// bridge is bound to: this is the link the host itself hands out.
Uri panelLink({required int port, required String token}) => Uri(
  scheme: 'http',
  host: localhost,
  port: port,
  path: '/',
  fragment: 'token=$token',
);

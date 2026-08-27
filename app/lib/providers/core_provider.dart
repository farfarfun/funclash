import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/core_launcher/core_launcher.dart';
import '../core/core_launcher/core_launcher_factory.dart';
import '../core/mihomo_api_client.dart';

/// Where to reach the mihomo external-controller API. Defaults match what
/// `funclash start` exposes locally.
class CoreSettings {
  final String host;
  final int port;
  final String secret;

  const CoreSettings({this.host = '127.0.0.1', this.port = 9090, this.secret = ''});

  CoreSettings copyWith({String? host, int? port, String? secret}) => CoreSettings(
        host: host ?? this.host,
        port: port ?? this.port,
        secret: secret ?? this.secret,
      );
}

class CoreSettingsNotifier extends Notifier<CoreSettings> {
  @override
  CoreSettings build() => const CoreSettings();

  void update({String? host, int? port, String? secret}) {
    state = state.copyWith(host: host, port: port, secret: secret);
  }
}

final coreSettingsProvider = NotifierProvider<CoreSettingsNotifier, CoreSettings>(CoreSettingsNotifier.new);

/// One [CoreLauncher] per app lifetime — Linux/macOS/Windows can spawn the
/// mihomo subprocess themselves, Web/Android/iOS fall back to
/// [NoopCoreLauncher] and expect a core running elsewhere.
final coreLauncherProvider = Provider<CoreLauncher>((ref) => createCoreLauncher());

final mihomoApiClientProvider = Provider<MihomoApiClient>((ref) {
  final settings = ref.watch(coreSettingsProvider);
  final client = MihomoApiClient(
    MihomoEndpoint(host: settings.host, port: settings.port, secret: settings.secret),
  );
  ref.onDispose(client.close);
  return client;
});

final coreVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  final client = ref.watch(mihomoApiClientProvider);
  return client.getVersion();
});

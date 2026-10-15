import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/panel.g.dart';

/// Reads through to [panelHost], which owns the stored settings and the socket.
@Riverpod(keepAlive: true)
class PanelSetting extends _$PanelSetting {
  @override
  PanelSettings build() => panelHost?.settings ?? const PanelSettings();

  Future<void> apply(PanelSettings settings) async {
    final host = panelHost;
    if (host == null) {
      return;
    }
    await host.apply(settings);
    state = host.settings;
  }

  Future<void> update(PanelSettings Function(PanelSettings state) change) =>
      apply(change(state));

  Future<void> replaceToken() => apply(state.copyWith(token: newPanelToken()));

  void syncFromHost() {
    final host = panelHost;
    if (host != null) {
      state = host.settings;
    }
  }
}

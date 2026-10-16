import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/remote/panel_installer.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:funclash/state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generated/panel.g.dart';

enum PanelPhase { missing, installing, ready, failed }

final class PanelStatus {
  final PanelPhase phase;
  final double progress;
  final String? failure;

  const PanelStatus(this.phase, {this.progress = 0, this.failure});
}

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

/// The panel build is fetched rather than bundled: an installer carrying it
/// would hand every user a CanvasKit payload for a feature that is off.
@Riverpod(keepAlive: true)
class PanelInstall extends _$PanelInstall {
  @override
  PanelStatus build() => _onDisk();

  String get _version => globalState.packageInfo.version;

  PanelStatus _onDisk() {
    final root = panelHost?.pageRoot;
    final ready =
        root != null && isPanelInstalled(root: root, version: _version);
    return PanelStatus(ready ? PanelPhase.ready : PanelPhase.missing);
  }

  void syncFromHost() => state = _onDisk();

  Future<void> install() async {
    final root = panelHost?.pageRoot;
    if (root == null || state.phase == PanelPhase.installing) {
      return;
    }
    if (isPanelInstalled(root: root, version: _version)) {
      state = const PanelStatus(PanelPhase.ready);
      return;
    }
    state = const PanelStatus(PanelPhase.installing);
    try {
      await installPanel(
        root: root,
        version: _version,
        fetch: (url, {onProgress}) =>
            request.getLargeFile(url, onProgress: onProgress),
        onProgress: (fraction) =>
            state = PanelStatus(PanelPhase.installing, progress: fraction),
      );
      state = const PanelStatus(PanelPhase.ready);
    } catch (error) {
      commonPrint.log(
        'panel install failed ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      state = PanelStatus(
        PanelPhase.failed,
        failure: userFacingErrorMessage(error, currentAppLocalizations),
      );
    }
  }
}

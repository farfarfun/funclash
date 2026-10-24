// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../panel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reads through to [panelHost], which owns the stored settings and the socket.

@ProviderFor(PanelSetting)
final panelSettingProvider = PanelSettingProvider._();

/// Reads through to [panelHost], which owns the stored settings and the socket.
final class PanelSettingProvider
    extends $NotifierProvider<PanelSetting, PanelSettings> {
  /// Reads through to [panelHost], which owns the stored settings and the socket.
  PanelSettingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'panelSettingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$panelSettingHash();

  @$internal
  @override
  PanelSetting create() => PanelSetting();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PanelSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PanelSettings>(value),
    );
  }
}

String _$panelSettingHash() => r'a69edd559f7cd6b8a7e232d4e6aeaf86a0a65bae';

/// Reads through to [panelHost], which owns the stored settings and the socket.

abstract class _$PanelSetting extends $Notifier<PanelSettings> {
  PanelSettings build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PanelSettings, PanelSettings>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PanelSettings, PanelSettings>,
              PanelSettings,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PanelInstall)
final panelInstallProvider = PanelInstallProvider._();

final class PanelInstallProvider
    extends $NotifierProvider<PanelInstall, PanelStatus> {
  PanelInstallProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'panelInstallProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$panelInstallHash();

  @$internal
  @override
  PanelInstall create() => PanelInstall();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PanelStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PanelStatus>(value),
    );
  }
}

String _$panelInstallHash() => r'cbc9225f8ebda22438e8dda1cbcb17980012a1df';

abstract class _$PanelInstall extends $Notifier<PanelStatus> {
  PanelStatus build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PanelStatus, PanelStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PanelStatus, PanelStatus>,
              PanelStatus,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

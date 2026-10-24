import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:funclash/common/boot_guard.dart';
import 'package:funclash/common/boot_record.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/common/launch.dart';
import 'package:funclash/common/desktop_startup.dart';
import 'package:funclash/remote/panel_settings.dart';
import 'package:funclash/common/migration.dart';
import 'package:funclash/common/tray.dart';
import 'package:funclash/common/window.dart';
import 'package:funclash/core/service.dart';
import 'package:funclash/database/database.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/l10n/l10n.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/state.dart';
import 'package:funclash/views/disclaimer.dart';
import 'package:funclash/views/navigation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_color_utilities/palettes/tonal_palette.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Bootstrap {
  static Bootstrap? _instance;

  Bootstrap._internal();

  factory Bootstrap() {
    _instance ??= Bootstrap._internal();
    return _instance!;
  }

  BootDecision _bootDecision = const BootDecision();

  Future<ProviderContainer> init(int version) async {
    if (system.isWeb) {
      await connectPanel();
    }
    globalState.appEnv = system.isWeb
        ? 'stable'
        : const String.fromEnvironment('APP_ENV', defaultValue: 'pre');
    windowPort = window;
    trayPort = appTray;
    navigationPort = navigation;
    final dynamicColor = await _initDynamicColor();
    return _initData(version, dynamicColor);
  }

  Future<DynamicColorSeeds> _initDynamicColor() async {
    TonalPalette? primaryPalette;
    Color? accentColor;
    try {
      primaryPalette = await _getSystemPrimaryPalette();
    } catch (error) {
      commonPrint.log(
        'Failed to get core palette: $error',
        logLevel: LogLevel.warning,
      );
    }
    try {
      accentColor = await DynamicColorPlugin.getAccentColor();
    } catch (error) {
      commonPrint.log(
        'Failed to get accent color: $error',
        logLevel: LogLevel.warning,
      );
    }
    return (
      lightSeed: primaryPalette != null ? Color(primaryPalette.get(40)) : null,
      darkSeed: primaryPalette != null ? Color(primaryPalette.get(80)) : null,
      accentColor: accentColor ?? const Color(defaultPrimaryColor),
    );
  }

  /// Runs before migration and the database: a copy started from another
  /// install path gets past the platform's single-instance hand-off.
  Future<void> _claimDataDirectory() async {
    if (!system.isDesktop || await singleInstanceLock.acquire()) {
      return;
    }
    commonPrint.log('another instance owns the data directory, exiting');
    system.forceExit();
  }

  Future<TonalPalette?> _getSystemPrimaryPalette() async {
    final raw = await DynamicColorPlugin.channel.invokeMethod<List<dynamic>>(
      DynamicColorPlugin.methodName,
    );
    if (raw == null || raw.length < TonalPalette.commonSize) {
      return null;
    }
    return TonalPalette.fromList(
      raw.sublist(0, TonalPalette.commonSize).cast<int>(),
    );
  }

  Future<ProviderContainer> _initData(
    int version,
    DynamicColorSeeds dynamicColor,
  ) async {
    await _claimDataDirectory();
    globalState.packageInfo = await PackageInfo.fromPlatform();
    var config = system.isWeb
        ? Config.realFromJson(await linkedPanelConfig)
        : await migration.run();
    await AppLocalizations.load(
      getLocaleForString(config.appSettingProps.locale) ??
          WidgetsBinding.instance.platformDispatcher.locale,
    );
    if (desktopStartup.showDisclaimer) {
      final l = currentAppLocalizations;
      commonPrint.log(
        [
          l.disclaimerSoftwareContent,
          l.disclaimerNoServiceStatement,
          l.disclaimerUsageContent,
          l.disclaimerResponsibilityContent,
          l.disclaimerThirdPartyContent,
          l.disclaimerWarrantyContent,
          l.disclaimerLiabilityContent,
          l.disclaimerLicenseContent,
          l.disclaimerChangesContent,
          l.disclaimerAcceptContent,
        ].join('\n\n'),
      );
      system.forceExit();
    }
    if (desktopStartup.headless &&
        config.appSettingProps.acceptedDisclaimerVersion < disclaimerVersion) {
      if (!desktopStartup.acceptDisclaimer) {
        throw StateError(
          'Read the terms with --show-disclaimer, then start with --accept-disclaimer to accept them.',
        );
      }
      config = config.copyWith.appSettingProps(
        acceptedDisclaimerVersion: disclaimerVersion,
      );
      await preferences.saveConfig(config);
    }
    if (desktopStartup.changesPanel) {
      final settings =
          await preferences.getPanelSettings() ?? PanelSettings.fresh();
      await preferences.savePanelSettings(
        settings.copyWith(
          enabled: desktopStartup.panelEnabled,
          allowLan: desktopStartup.allowLan,
          port: desktopStartup.panelPort,
        ),
      );
    }
    _bootDecision = system.isWeb
        ? const BootDecision()
        : await bootGuard.evaluate(
            profileId: config.currentProfileId,
            crashlyticsEnabled: config.appSettingProps.crashlytics,
          );
    if (_bootDecision.recovery == BootRecovery.clearProfile) {
      config = config.copyWith(currentProfileId: null);
      await preferences.saveConfig(config);
    }
    final patchClashConfig = config.patchClashConfig.ensureControllerSecret();
    if (!system.isWeb && patchClashConfig != config.patchClashConfig) {
      config = config.copyWith(patchClashConfig: patchClashConfig);
      await preferences.saveConfig(config);
    }
    final appState = AppState(
      brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
      version: version,
      viewSize: Size.zero,
      requests: FixedList(maxRequestsLength),
      logs: FixedList(maxLogsLength),
      traffics: FixedList(trafficSampleLength),
      totalTraffic: const Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    final appStateOverrides = buildAppStateOverrides(appState);
    final configOverrides = buildConfigOverrides(config);
    final container = ProviderContainer(
      overrides: [...appStateOverrides, ...configOverrides],
    );
    globalState.container = container;
    container
        .read(dynamicColorProvider.notifier)
        .seed(
          lightSeed: dynamicColor.lightSeed,
          darkSeed: dynamicColor.darkSeed,
          accentColor: dynamicColor.accentColor,
        );
    final profiles = await database.profilesDao.query().get();
    container.read(profilesProvider.notifier).reorder(profiles);

    await window?.init(version, config.windowProps);
    if (system.isAndroid) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    return container;
  }

  Future<void> attach() async {
    if (globalState.isAttach == true) {
      return;
    }
    try {
      await _initApp();
      globalState.isAttach = true;
    } catch (error) {
      if (!desktopStartup.headless) rethrow;
      commonPrint.log('Headless initialization failed: $error');
      await _container.read(systemActionProvider.notifier).handleExit();
      system.forceExit(1);
    }
  }

  ProviderContainer get _container => globalState.container;

  Future<void> _initApp() async {
    if (system.isWeb) {
      await _container.read(coreActionProvider.notifier).startCore();
      await _container.read(setupActionProvider.notifier).initStatus();
      _container.read(initProvider.notifier).value = true;
      return;
    }
    if (!desktopStartup.headless) {
      unawaited(_container.read(systemActionProvider.notifier).updateTray());
    }
    unawaited(
      _container.read(profilesActionProvider.notifier).autoUpdateProfiles(),
    );
    unawaited(_container.read(commonActionProvider.notifier).autoCheckUpdate());
    unawaited(syncAutoLaunch(_container.read(appSettingProvider).autoLaunch));
    if (desktopStartup.headless ||
        !_container.read(appSettingProvider).silentLaunch) {
      unawaited(window?.show());
    } else {
      unawaited(window?.hide());
    }
    await _handleFailedPreference();
    if (!await _handlerDisclaimer()) {
      return;
    }
    if (desktopStartup.headless) {
      if (_bootDecision.isDegraded) {
        commonPrint.log(
          'Startup recovery: automatic profile setup was skipped. Select and start a profile from the panel.',
        );
      }
    } else {
      await _showCrashRecoveryTip();
    }
    await _showCrashlyticsTip();
    await _container.read(coreActionProvider.notifier).startCore();
    if (!_bootDecision.isDegraded) {
      if (desktopStartup.headless) {
        await globalState.safeRun(
          () => _container.read(setupActionProvider.notifier).initStatus(),
        );
      } else {
        await _container.read(setupActionProvider.notifier).initStatus();
      }
    }
    _container.read(initProvider.notifier).value = true;
    if (desktopStartup.headless) {
      commonPrint.log('Headless startup ready');
    }
    unawaited(_container.read(resourcesActionProvider.notifier).autoUpdate());
    await bootGuard.markRunning();
    unawaited(_container.read(locationPermissionsProvider.notifier).refresh());
  }

  Future<void> _showCrashRecoveryTip() async {
    switch (_bootDecision.recovery) {
      case BootRecovery.none:
        return;
      case BootRecovery.skipAutoSetup:
        await dialogs.showMessage(
          title: currentAppLocalizations.launchInterrupted,
          cancelable: false,
          dismissible: false,
          message: TextSpan(text: currentAppLocalizations.launchInterruptedTip),
        );
      case BootRecovery.clearProfile:
        await dialogs.showMessage(
          title: currentAppLocalizations.crashDetected,
          cancelable: false,
          dismissible: false,
          message: TextSpan(
            text: currentAppLocalizations.crashDetectedTip(_failedProfileLabel),
          ),
        );
    }
  }

  String get _failedProfileLabel {
    final profileId = _bootDecision.failedProfileId;
    if (profileId == null) {
      return '';
    }
    final profile = _container.read(profilesProvider).getProfile(profileId);
    return profile?.label.takeFirstValid(['$profileId']) ?? '$profileId';
  }

  Future<void> _handleFailedPreference() async {
    if (await preferences.isInit) return;
    if (desktopStartup.headless) {
      throw StateError(
        'Could not read preferences. Restore a backup before restarting.',
      );
    }
    final res = await dialogs.showMessage(
      title: currentAppLocalizations.tip,
      message: TextSpan(text: currentAppLocalizations.cacheCorrupt),
    );
    if (res == true) {
      await safeDeletePath(await appPath.sharedPreferencesPath);
    }
    // Saving here would rewrite the preferences file the user just chose to delete.
    await _container.read(systemActionProvider.notifier).handleExit(false);
  }

  Future<void> _showCrashlyticsTip() async {
    if (!system.isAndroid) return;
    if (_container.read(
      appSettingProvider.select((state) => state.crashlyticsTip),
    )) {
      return;
    }
    await dialogs.showMessage(
      title: currentAppLocalizations.dataCollectionTip,
      cancelable: false,
      message: TextSpan(text: currentAppLocalizations.dataCollectionContent),
    );
    _container
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(crashlyticsTip: true));
  }

  /// Android's exit only finishes the activity, so Dart keeps running after
  /// [SystemAction.handleExit] returns and must not go on to start the app.
  Future<bool> _handlerDisclaimer() async {
    final acceptedVersion = _container.read(
      appSettingProvider.select((state) => state.acceptedDisclaimerVersion),
    );
    if (acceptedVersion >= disclaimerVersion) {
      return true;
    }
    final isDisclaimerAccepted = await requestDisclaimerConsent();
    if (!isDisclaimerAccepted) {
      await _container.read(systemActionProvider.notifier).handleExit();
      return false;
    }
    _container
        .read(appSettingProvider.notifier)
        .update(
          (state) =>
              state.copyWith(acceptedDisclaimerVersion: disclaimerVersion),
        );
    return true;
  }
}

final bootstrap = Bootstrap();

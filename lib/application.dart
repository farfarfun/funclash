import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/common/window.dart';
import 'package:funclash/bootstrap.dart';
import 'package:funclash/common/system_dns.dart';
import 'package:funclash/icons/icons.dart';
import 'package:funclash/l10n/l10n.dart';
import 'package:funclash/manager/app_manager.dart';
import 'package:funclash/manager/connectivity_manager.dart';
import 'package:funclash/manager/core_manager.dart';
import 'package:funclash/manager/locale_manager.dart';
import 'package:funclash/manager/platform_managers.dart';
import 'package:funclash/manager/status_manager.dart';
import 'package:funclash/manager/theme_manager.dart';
import 'package:funclash/plugins/app.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/state.dart';
import 'package:funclash/widgets/focus.dart';
import 'package:funclash/widgets/keyboard_inset_hold.dart';
import 'package:funclash/widgets/web_shell.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/pages.dart';

Widget buildManagerStack({
  required bool isDesktop,
  required Future<void> Function(List<ConnectivityResult> results)
  onConnectivityChanged,
  Stream<void>? terminateSignals,
  required Widget child,
}) {
  final state = AppStateManager(
    child: CoreManager(
      child: ConnectivityManager(
        onConnectivityChanged: onConnectivityChanged,
        child: buildPlatformApp(isDesktop: isDesktop, child: child),
      ),
    ),
  );
  final platformState = buildPlatformManagers(
    isDesktop: isDesktop,
    terminateSignals: terminateSignals,
    child: state,
  );
  return AppEnvManager(
    child: LocaleManager(
      child: StatusManager(child: ThemeManager(child: platformState)),
    ),
  );
}

class Application extends ConsumerStatefulWidget {
  const Application({super.key});

  @override
  ConsumerState<Application> createState() => ApplicationState();
}

const _actionIconTheme = ActionIconThemeData(
  backButtonIconBuilder: _backButtonIcon,
  closeButtonIconBuilder: _closeButtonIcon,
);

Widget _backButtonIcon(BuildContext context) =>
    GlyphIcon(AppGlyphs.backFor(Theme.of(context).platform));

Widget _closeButtonIcon(BuildContext context) =>
    const GlyphIcon(AppGlyphs.close);

class ApplicationState extends ConsumerState<Application> {
  Timer? _autoUpdateProfilesTaskTimer;
  bool _preHasVpn = false;
  final _terminateSignals = system.watchTerminateSignals();

  final _pageTransitionsTheme = const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: commonSharedXPageTransitions,
      TargetPlatform.windows: commonSharedXPageTransitions,
      TargetPlatform.linux: commonSharedXPageTransitions,
      TargetPlatform.macOS: commonSharedXPageTransitions,
    },
  );

  ColorScheme _getAppColorScheme({required Brightness brightness}) {
    return ref.read(genColorSchemeProvider(brightness));
  }

  @override
  void initState() {
    super.initState();
    SystemNavigator.setFrameworkHandlesBack(true);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      if (globalState.navigatorKey.currentContext != null) {
        await bootstrap.attach();
      } else {
        system.forceExit();
      }
      _autoUpdateProfilesTask();
      _initLink();
      if (!safeModeBuild) {
        unawaited(app?.initShortcuts());
      }
    });
  }

  void _initLink() {
    linkManager.initAppLinksListen((url) async {
      unawaited(window?.show());
      final message = currentAppLocalizations.createProfileFromUrlTip(url);
      final parts = message.split(url);
      final res = await dialogs.showMessage(
        title: currentAppLocalizations.addProfile,
        message: TextSpan(
          children: [
            TextSpan(text: parts.first),
            TextSpan(
              text: url,
              style: TextStyle(
                color: context.colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: context.colorScheme.primary,
              ),
            ),
            if (parts.length > 1) TextSpan(text: parts.last),
          ],
        ),
      );
      if (res != true) return;
      unawaited(
        ref.read(profilesActionProvider.notifier).addProfileFromLink(url),
      );
    });
  }

  void _autoUpdateProfilesTask() {
    _autoUpdateProfilesTaskTimer = Timer(const Duration(minutes: 20), () async {
      await ref.read(profilesActionProvider.notifier).autoUpdateProfiles();
      await ref.read(resourcesActionProvider.notifier).autoUpdate();
      if (!mounted) {
        return;
      }
      _autoUpdateProfilesTask();
    });
  }

  Future<void> _handleConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    commonPrint.log('connectivityChanged ${results.toString()}');
    unawaited(systemDnsCoordinator?.resync() ?? Future.value());
    unawaited(ref.read(systemActionProvider.notifier).updateLocalIp());
    final hasVpn = results.contains(ConnectivityResult.vpn);
    if (_preHasVpn == hasVpn) {
      ref.read(routeTrackerProvider.notifier).bumpHostEpoch();
    }
    _preHasVpn = hasVpn;
  }

  @override
  Widget build(context) {
    return Consumer(
      builder: (_, ref, child) {
        final locale = ref.watch(
          appSettingProvider.select((state) => state.locale),
        );
        final themeProps = ref.watch(themeSettingProvider);
        final fontFamilyFallback = appFontFamilyFallback(
          platform: defaultTargetPlatform,
          locales: [
            ?getLocaleForString(locale),
            ...WidgetsBinding.instance.platformDispatcher.locales,
          ],
          fontFamily: themeProps.fontFamily,
        );
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          navigatorKey: globalState.navigatorKey,
          onNavigationNotification: (_) => true,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          builder: (context, child) {
            final app = buildManagerStack(
              isDesktop: system.isDesktop,
              onConnectivityChanged: _handleConnectivityChanged,
              terminateSignals: _terminateSignals,
              child: RemoteFocusAdapter(enabled: system.isTV, child: child!),
            );
            return system.isWeb ? WebShell(child: app) : app;
          },
          scrollBehavior: const BaseScrollBehavior(),
          title: appName,
          locale: getLocaleForString(locale),
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          themeMode: themeProps.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            actionIconTheme: _actionIconTheme,
            colorScheme: _getAppColorScheme(brightness: Brightness.light),
            fontFamily: themeProps.fontFamily,
            fontFamilyFallback: fontFamilyFallback,
          ).withAppShapes,
          darkTheme: ThemeData(
            useMaterial3: true,
            pageTransitionsTheme: _pageTransitionsTheme,
            actionIconTheme: _actionIconTheme,
            colorScheme: _getAppColorScheme(brightness: Brightness.dark),
            fontFamily: themeProps.fontFamily,
            fontFamilyFallback: fontFamilyFallback,
          ).withAppShapes,
          home: KeyboardInsetHold(child: child!),
        );
      },
      child: const HomePage(),
    );
  }

  @override
  void dispose() {
    linkManager.destroy();
    _autoUpdateProfilesTaskTimer?.cancel();
    super.dispose();
  }
}

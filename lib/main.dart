import 'dart:async';

import 'package:funclash/enum/enum.dart';
import 'package:funclash/pages/error.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'application.dart';
import 'bootstrap.dart';
import 'common/app_data.dart';
import 'common/desktop_startup.dart';
import 'remote/panel_address.dart';
import 'remote/panel_settings.dart';
import 'common/common.dart';
import 'common/preferences_store.dart';
import 'common/rust_runtime.dart';
import 'common/window.dart';

void main(List<String> args) {
  runZonedGuarded(
    () async {
      if (system.isLinux) {
        try {
          desktopStartup = DesktopStartup.parse(
            args,
            headless: AppPlatform.environment['FUNCLASH_HEADLESS'] == '1',
          );
        } catch (error) {
          commonPrint.log('$error');
          system.forceExit(64);
        }
      }
      WidgetsFlutterBinding.ensureInitialized();
      if (system.isWindows || system.isLinux) {
        SharedPreferencesStorePlatform.instance = AtomicFilePreferencesStore(
          appPath.sharedPreferencesPath,
        );
      }
      if (system.isLinux) {
        linkManager.seedInitialLink(args);
      }
      FlutterError.onError = (details) {
        Future.microtask(() {
          commonPrint.log(
            'exception: ${details.exception} stack: ${details.stack}',
            logLevel: LogLevel.warning,
          );
        });
      };
      try {
        if (desktopStartup.panelUrl) {
          var settings = await preferences.getPanelSettings();
          if (desktopStartup.changesPanel) {
            if (!await singleInstanceLock.acquire()) {
              throw StateError(
                'Stop FunClash before changing panel settings from the command line.',
              );
            }
            settings = (settings ?? PanelSettings.fresh()).copyWith(
              enabled: desktopStartup.panelEnabled,
              allowLan: desktopStartup.allowLan,
              port: desktopStartup.panelPort,
            );
            await preferences.savePanelSettings(settings);
          }
          if (settings == null) {
            throw StateError(
              'Start FunClash once before requesting its panel link.',
            );
          }
          commonPrint.log(
            panelLink(port: settings.port, token: settings.token).toString(),
          );
          if (!settings.enabled) {
            commonPrint.log(
              'The panel is disabled. Use --panel --panel-url while FunClash is stopped to enable it.',
            );
          }
          system.forceExit();
        }
        await initRustRuntime();
        final version = await system.init();
        final container = await bootstrap.init(version);
        attachHttpOverrides(container);
        request.attach(container.read);
        runApp(
          UncontrolledProviderScope(
            container: container,
            child: const Application(),
          ),
        );
      } catch (e, s) {
        if (desktopStartup.headless || desktopStartup.panelUrl) {
          commonPrint.log('Startup failed: $e');
          system.forceExit(1);
        }
        runApp(
          InitErrorApp(
            error: e,
            stack: s,
            onClearData: clearAppData,
            onExit: _exitAfterInitFailure,
          ),
        );
        unawaited(window?.showInitFailure(onExit: _exitAfterInitFailure));
      }
    },
    (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
}

Future<void> _exitAfterInitFailure() async {
  await system.exit();
  window?.forceExit();
}

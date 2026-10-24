import 'dart:async';

import 'package:funclash/common/common.dart';
import 'package:funclash/common/desktop_startup.dart';
import 'package:funclash/remote/panel_address.dart';
import 'package:funclash/common/system_dns.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/remote/panel_config_bridge.dart';
import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/remote/panel_link_state.dart';
import 'package:funclash/state.dart';
import 'package:funclash/widgets/animated_visibility.dart';
import 'package:funclash/widgets/icon.dart';
import 'package:funclash/widgets/sidebar.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<Object?> handlePanelHostAction(
  ProviderReader read,
  String method,
  Object? arguments,
) async {
  return switch ((method, arguments)) {
    ('panel.getStartTime', null) => read(
      setupActionProvider.notifier,
    ).startTime?.millisecondsSinceEpoch,
    ('panel.setRunning', final bool running) => await read(
      setupActionProvider.notifier,
    ).setRunning(running),
    ('panel.applyProfile', null) => await read(
      setupActionProvider.notifier,
    ).applyProfile(force: true),
    ('panel.restartCore', null) => await read(
      coreActionProvider.notifier,
    ).restartCore(),
    _ => throw ArgumentError('invalid panel action: $method'),
  };
}

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  StreamSubscription<Config>? _panelConfigWrites;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A desktop build started to the tray mounts while hidden, and a paused
    // render never runs a post-frame callback.
    scheduleMicrotask(() {
      if (mounted) {
        _updateVisible(WidgetsBinding.instance.lifecycleState);
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        ref.read(storeActionProvider.notifier).savePreferencesDebounce();
      }
    });
    ref.listenManual(groupsProvider, (prev, next) {
      if (prev != next) {
        unawaited(precacheTargetIcons(next.map((group) => group.icon)));
      }
    }, fireImmediately: true);
    ref.listenManual(iconSetsProvider, (_, next) {
      if (next.value case final iconSets?) {
        unawaited(
          precacheTargetIcons(iconSets.map((iconSet) => iconSet.cover)),
        );
      }
    }, fireImmediately: true);
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        ref.read(proxiesActionProvider.notifier).updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      if (prev != next) {
        ref.read(setupActionProvider.notifier).syncSuspend();
      }
    });
    final systemDns = systemDnsCoordinator;
    if (systemDns != null) {
      ref.listenManual(shouldPatchSystemDnsProvider, (prev, next) {
        unawaited(systemDns.sync(next));
      }, fireImmediately: true);
    }
    final panel = panelHost;
    if (panel != null) {
      panelCoreBridge!.hostAction = (method, arguments) =>
          handlePanelHostAction(ref.read, method, arguments);
      ref.listenManual(isStartProvider, (_, _) {
        panelCoreBridge!.pushStartTime(
          ref
              .read(setupActionProvider.notifier)
              .startTime
              ?.millisecondsSinceEpoch,
        );
      });
      unawaited(_openPanelBridge(panel));
    }
    final configBridge = panelConfigBridge;
    if (configBridge != null) {
      ref.listenManual(configProvider, (prev, next) {
        if (prev != next) {
          configBridge.push(next);
        }
      }, fireImmediately: true);
      _panelConfigWrites = configBridge.writes.listen(
        (config) => writeConfig(ref.read, config),
      );
    }
    if (system.isWeb) {
      unawaited(_followHostConfig());
    }
  }

  /// A panel's config is the host's, and the echo of its own write is dropped.
  Future<void> _followHostConfig() async {
    final session = await linkedPanelSession;
    if (!mounted) {
      return;
    }
    final client = PanelConfigClient();
    client.bind(session, apply: (config) => writeConfig(ref.read, config));
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        client.push(session, next);
      }
    });
  }

  Future<void> _openPanelBridge(PanelHost panel) async {
    await panel.load(
      config: () => ref.read(configProvider).toJson(),
      pageRoot: await appPath.panelDirPath,
    );
    if (mounted) {
      ref.read(panelSettingProvider.notifier).syncFromHost();
      ref.read(panelInstallProvider.notifier).syncFromHost();
      if (panel.settings.enabled) {
        await ref.read(panelInstallProvider.notifier).install();
      }
      if (desktopStartup.headless) {
        commonPrint.log(
          panel.isRunning
              ? 'Remote panel: ${panelLink(port: panel.settings.port, token: panel.settings.token)} (LAN: ${panel.settings.allowLan}; use the host IP from another device)'
              : 'Remote panel is not listening. Check its port or restart with --panel.',
        );
      }
    }
  }

  @override
  void dispose() {
    panelCoreBridge?.hostAction = null;
    unawaited(_panelConfigWrites?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _updateVisible(AppLifecycleState? state) {
    ref.read(appVisibleProvider.notifier).value = switch (state) {
      null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => false,
    };
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    _updateVisible(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(locationPermissionsProvider.notifier).refresh());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(routeTrackerProvider.notifier).markResumed();
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    ref.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AppEnvManager extends ConsumerWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  String? _bannerMessage({required bool safeMode}) {
    if (safeMode) {
      return 'SAFE MODE';
    }
    if (!globalState.isPre) {
      return null;
    }
    return kDebugMode ? 'DEBUG' : globalState.appEnv.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = _bannerMessage(safeMode: ref.watch(safeModeProvider));
    if (message == null) {
      return child;
    }
    return Banner(
      message: message,
      location: BannerLocation.topEnd,
      child: child,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.items,
    required this.currentIndex,
    required this.viewMode,
    required this.onSelected,
  });

  final List<NavigationItem> items;
  final int currentIndex;
  final ViewMode viewMode;
  final void Function(int index) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canExpand = canExpandSidebar(viewMode);
    final sidebarExpanded = ref.watch(
      appSettingProvider.select((state) => state.sidebarExpanded),
    );
    final version = ref.watch(versionProvider);
    return NavigationSidebar(
      destinations: [
        for (final item in items)
          SidebarDestination(glyph: item.glyph, label: item.label.label),
      ],
      selectedIndex: currentIndex,
      expanded: canExpand && sidebarExpanded,
      onSelected: onSelected,
      onToggle: canExpand
          ? () {
              ref
                  .read(appSettingProvider.notifier)
                  .update(
                    (state) =>
                        state.copyWith(sidebarExpanded: !state.sidebarExpanded),
                  );
            }
          : null,
      windowControls: windowControlsOverSidebar(
        isMacOS: system.isMacOS,
        version: version,
      ),
    );
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  Widget _buildBackground({
    required Color color,
    required Color edge,
    required Widget child,
  }) {
    return Material(
      color: color,
      shape: BorderDirectional(end: BorderSide(color: edge)),
      child: child,
    );
  }

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(WidgetRef ref, PageLabel pageLabel) {
    final focusNode = FocusManager.instance.primaryFocus;
    final focusContext = focusNode?.context;
    final preserveNavigationFocus =
        focusContext?.findAncestorWidgetOfExactType<NavigationSidebar>() !=
        null;
    ref.read(currentPageLabelProvider.notifier).toPage(pageLabel);
    if (!preserveNavigationFocus || focusNode == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (focusNode.context != null && focusNode.canRequestFocus) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final viewMode = navigationState.viewMode;
    final currentIndex = navigationState.currentIndex;
    final blur = ref.watch(windowBlurProvider);
    final colorScheme = context.colorScheme;
    final surfaceContainer = colorScheme.surfaceContainer;
    void onSelected(int index) {
      _handleToPage(ref, navigationItems[index].label);
    }

    final hasSidebar = viewMode != ViewMode.mobile;
    final isLtr = Directionality.of(context) == TextDirection.ltr;
    return Container(
      color: blur ? Colors.transparent : surfaceContainer,
      child: Row(
        children: [
          AnimatedVisibility.sidebar(
            visible: hasSidebar,
            child: _buildBackground(
              color: blur
                  ? surfaceContainer.withValues(alpha: kSidebarBlurOpacity)
                  : surfaceContainer,
              edge: colorScheme.outlineVariant,
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: !isLtr,
                removeRight: isLtr,
                child: _Sidebar(
                  items: navigationItems,
                  currentIndex: currentIndex,
                  viewMode: viewMode,
                  onSelected: onSelected,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  _updateSideBarWidth(ref, constraints.maxWidth);
                  return MediaQuery.removePadding(
                    context: context,
                    removeLeft: hasSidebar && isLtr,
                    removeRight: hasSidebar && !isLtr,
                    child: child,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

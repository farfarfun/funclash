import 'dart:async';

import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/l10n/l10n.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/providers.dart';
import 'package:funclash/remote/panel_address.dart';
import 'package:funclash/remote/panel_host.dart';
import 'package:funclash/views/config/on_demand.dart';
import 'package:funclash/views/config/user_agents.dart';
import 'package:funclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'general/port_dialog.dart';

class LogLevelItem extends ConsumerWidget {
  const LogLevelItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigOptionsItem<LogLevel>(
      title: (l) => l.logLevel,
      options: LogLevel.values,
      textBuilder: (logLevel) => logLevel.name,
      selector: patchClashConfigProvider.select((state) => state.logLevel),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(logLevel: value)),
    );
  }
}

class UaItem extends ConsumerWidget {
  const UaItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final globalUa = ref.watch(
      patchClashConfigProvider.select((state) => state.globalUa),
    );
    return ListItem.open(
      title: Text(appLocalizations.userAgent),
      subtitle: Text(globalUa ?? appLocalizations.defaultText),
      widget: const UserAgentsView(),
    );
  }
}

class TestUrlItem extends ConsumerWidget {
  const TestUrlItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final testUrl = ref.watch(
      appSettingProvider.select((state) => state.testUrl),
    );
    return ListItem.input(
      title: Text(appLocalizations.testUrl),
      subtitle: Text(testUrl),
      resetValue: defaultTestUrl,
      dialogTitle: appLocalizations.testUrl,
      value: testUrl,
      maxLength: TextInputLimits.url,
      validator: (String? value) {
        if (value == null || value.isEmpty) {
          return appLocalizations.emptyTip(appLocalizations.testUrl);
        }
        if (!value.isUrl) {
          return appLocalizations.urlTip(appLocalizations.testUrl);
        }
        return null;
      },
      onChanged: (String? value) {
        if (value == null) {
          return;
        }
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(testUrl: value));
      },
    );
  }
}

class PortItem extends ConsumerWidget {
  const PortItem({super.key});

  Future<void> handleShowPortDialog() async {
    await dialogs.showCommonDialog(child: const _PortDialog());
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final mixedPort = ref.watch(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    return ListItem(
      title: Text(appLocalizations.port),
      subtitle: Text('$mixedPort'),
      onTap: () {
        handleShowPortDialog();
      },
    );
  }
}

class HostsItem extends ConsumerWidget {
  const HostsItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final hosts = ref.watch(
      patchClashConfigProvider.select((state) => state.hosts),
    );
    return ListItem.open(
      title: const Text('Hosts'),
      subtitle: Text(
        hosts.isEmpty
            ? appLocalizations.none
            : appLocalizations.itemsCount(hosts.length),
      ),
      widget: MapEditView(
        title: 'Hosts',
        entries: hosts,
        keyMaxLength: TextInputLimits.domain,
        valueMaxLength: TextInputLimits.hostValue,
        titleBuilder: (item) => Text(item.key),
        subtitleBuilder: (item) => Text(item.value),
      ),
      onChanged: (value) {
        ref
            .read(patchClashConfigProvider.notifier)
            .update((state) => state.copyWith(hosts: value));
      },
    );
  }
}

class AuthenticationItem extends ConsumerWidget {
  const AuthenticationItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigToggleItem(
      title: (l) => l.authentication,
      selector: networkSettingProvider.select(
        (state) => state.authentication.enable,
      ),
      onChanged: (ref, value) =>
          ref.read(networkSettingProvider.notifier).update((state) {
            var authentication = state.authentication.copyWith(enable: value);
            if (value && authentication.username.isEmpty) {
              authentication = authentication.copyWith(
                username: generateRandomSecret(8),
                password: generateRandomSecret(16),
              );
            }
            return state.copyWith(authentication: authentication);
          }),
    );
  }
}

class AuthenticationAccountItem extends ConsumerWidget {
  const AuthenticationAccountItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.account,
      maxLength: TextInputLimits.userName,
      selector: networkSettingProvider.select(
        (state) => state.authentication.username,
      ),
      // mihomo and the Dart proxy string both split user:pass on the first
      // colon, so a colon in the username breaks authentication.
      normalize: (value) => value.trim().replaceAll(':', ''),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(username: value)),
    );
  }
}

class AuthenticationPasswordItem extends ConsumerWidget {
  const AuthenticationPasswordItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.password,
      maxLength: TextInputLimits.password,
      selector: networkSettingProvider.select(
        (state) => state.authentication.password,
      ),
      normalize: (value) => value.trim(),
      onChanged: (ref, value) => ref
          .read(networkSettingProvider.notifier)
          .update((state) => state.copyWith.authentication(password: value)),
    );
  }
}

class ExternalControllerSecretItem extends ConsumerWidget {
  const ExternalControllerSecretItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    return ConfigTextItem(
      title: (l) => l.externalControllerSecret,
      maxLength: TextInputLimits.password,
      selector: patchClashConfigProvider.select((state) => state.secret),
      normalize: (value) => value.trim(),
      onChanged: (ref, value) => ref
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(secret: value)),
    );
  }
}

ConfigToggleItem _clashToggle({
  required ConfigLabel title,
  required bool Function(PatchClashConfig state) select,
  required PatchClashConfig Function(PatchClashConfig state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: patchClashConfigProvider.select(select),
    onChanged: (ref, value) => ref
        .read(patchClashConfigProvider.notifier)
        .update((state) => update(state, value)),
  );
}

ConfigToggleItem _appSettingToggle({
  required ConfigLabel title,
  required bool Function(AppSettingProps state) select,
  required AppSettingProps Function(AppSettingProps state, bool value) update,
}) {
  return ConfigToggleItem(
    title: title,
    selector: appSettingProvider.select(select),
    onChanged: (ref, value) => ref
        .read(appSettingProvider.notifier)
        .update((state) => update(state, value)),
  );
}

String? _validatePanelPort(String? value, AppLocalizations appLocalizations) {
  final port = int.tryParse(value ?? '');
  return port != null && port >= 1024 && port <= 49151
      ? null
      : appLocalizations.portTip(appLocalizations.port);
}

class PanelLinkItem extends ConsumerWidget {
  const PanelLinkItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final settings = ref.watch(panelSettingProvider);
    final link = panelLink(
      port: settings.port,
      token: settings.token,
    ).toString();
    return ListItem(
      title: Text(context.appLocalizations.copyLink),
      subtitle: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        unawaited(_copyToClipboard(context, link));
      },
    );
  }
}

class PanelInstallItem extends ConsumerWidget {
  const PanelInstallItem({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final status = ref.watch(panelInstallProvider);
    final appLocalizations = context.appLocalizations;
    final failed = status.phase == PanelPhase.failed;
    return ListItem(
      title: Text(
        failed
            ? appLocalizations.remotePanelInstallFailed
            : appLocalizations.remotePanelInstalling,
      ),
      subtitle: Text(
        failed ? status.failure ?? '' : '${(status.progress * 100).round()}%',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: failed
          ? () {
              unawaited(ref.read(panelInstallProvider.notifier).install());
            }
          : null,
    );
  }
}

class PanelFolderItem extends StatelessWidget {
  const PanelFolderItem({required this.root, super.key});

  final String root;

  @override
  Widget build(BuildContext context) {
    return ListItem(
      title: Text(context.appLocalizations.remotePanelFolder),
      subtitle: Text(root, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        unawaited(_copyToClipboard(context, root));
      },
    );
  }
}

Future<void> _copyToClipboard(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    context.showNotifier(
      context.appLocalizations.copySuccess,
      level: MessageLevel.success,
    );
  }
}

class PanelNewLinkItem extends ConsumerWidget {
  const PanelNewLinkItem({super.key});

  Future<void> _replace(WidgetRef ref) async {
    final appLocalizations = currentAppLocalizations;
    final confirmed = await dialogs.showMessage(
      title: appLocalizations.remotePanelNewLink,
      message: TextSpan(text: appLocalizations.remotePanelNewLinkTip),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(panelSettingProvider.notifier).replaceToken();
  }

  @override
  Widget build(BuildContext context, ref) {
    return ListItem(
      title: Text(context.appLocalizations.remotePanelNewLink),
      onTap: () {
        unawaited(_replace(ref));
      },
    );
  }
}

class GeneralView extends ConsumerWidget {
  const GeneralView({super.key});

  List<Widget> _panelItems({
    required bool panelEnabled,
    required PanelPhase phase,
  }) {
    return [
      ConfigToggleItem(
        title: (l) => l.enabled,
        selector: panelSettingProvider.select((state) => state.enabled),
        onChanged: (ref, value) => unawaited(_togglePanel(ref, value)),
      ),
      if (panelEnabled) ...[
        ConfigToggleItem(
          title: (l) => l.remotePanelLan,
          selector: panelSettingProvider.select((state) => state.allowLan),
          onChanged: (ref, value) => unawaited(
            ref
                .read(panelSettingProvider.notifier)
                .update((state) => state.copyWith(allowLan: value)),
          ),
        ),
        ConfigTextItem(
          title: (l) => l.port,
          maxLength: TextInputLimits.port,
          keyboardType: TextInputType.number,
          validator: _validatePanelPort,
          selector: panelSettingProvider.select((state) => '${state.port}'),
          onChanged: (ref, value) => unawaited(
            ref
                .read(panelSettingProvider.notifier)
                .update(
                  (state) =>
                      state.copyWith(port: int.tryParse(value) ?? state.port),
                ),
          ),
        ),
        if (phase == PanelPhase.ready)
          const PanelLinkItem()
        else
          const PanelInstallItem(),
        const PanelNewLinkItem(),
        if (panelHost?.pageRoot case final root?) PanelFolderItem(root: root),
      ],
    ];
  }

  /// Turning it on is all a person should have to do, so the build it needs
  /// is fetched here rather than asked for.
  Future<void> _togglePanel(WidgetRef ref, bool enabled) async {
    await ref
        .read(panelSettingProvider.notifier)
        .update((state) => state.copyWith(enabled: enabled));
    if (enabled) {
      await ref.read(panelInstallProvider.notifier).install();
    }
  }

  List<Widget> _startupItems(AppLocalizations appLocalizations) {
    return [
      if (system.isDesktop) ...[
        _appSettingToggle(
          title: (l) => l.autoLaunch,
          select: (state) => state.autoLaunch,
          update: (state, value) => state.copyWith(autoLaunch: value),
        ),
        _appSettingToggle(
          title: (l) => l.silentLaunch,
          select: (state) => state.silentLaunch,
          update: (state, value) => state.copyWith(silentLaunch: value),
        ),
      ],
      _appSettingToggle(
        title: (l) => l.autoRun,
        select: (state) => state.autoRun,
        update: (state, value) => state.copyWith(autoRun: value),
      ),
      ListItem.open(
        title: Text(appLocalizations.onDemand),
        widget: const OnDemandView(),
      ),
      _appSettingToggle(
        title: (l) => l.minimizeOnExit,
        select: (state) => state.minimizeOnExit,
        update: (state, value) => state.copyWith(minimizeOnExit: value),
      ),
      if (system.isAndroid) ...[
        _appSettingToggle(
          title: (l) => l.exclude,
          select: (state) => state.hidden,
          update: (state, value) => state.copyWith(hidden: value),
        ),
        _appSettingToggle(
          title: (l) => l.showNotificationStopAction,
          select: (state) => state.showNotificationStopAction,
          update: (state, value) =>
              state.copyWith(showNotificationStopAction: value),
        ),
      ],
    ];
  }

  List<Widget> _inboundItems({
    required bool authentication,
    required bool externalController,
  }) {
    return [
      const PortItem(),
      _clashToggle(
        title: (l) => l.allowLan,
        select: (state) => state.allowLan,
        update: (state, value) => state.copyWith(allowLan: value),
      ),
      _clashToggle(
        title: (l) => l.externalController,
        select: (state) =>
            state.externalController == ExternalControllerStatus.open,
        update: (state, value) => state
            .copyWith(
              externalController: value
                  ? ExternalControllerStatus.open
                  : ExternalControllerStatus.close,
            )
            .ensureControllerSecret(),
      ),
      if (externalController) const ExternalControllerSecretItem(),
      const AuthenticationItem(),
      if (authentication) ...const [
        AuthenticationAccountItem(),
        AuthenticationPasswordItem(),
      ],
    ];
  }

  List<Widget> _connectionItems() {
    return [
      const TestUrlItem(),
      _clashToggle(
        title: (l) => l.unifiedDelay,
        select: (state) => state.unifiedDelay,
        update: (state, value) => state.copyWith(unifiedDelay: value),
      ),
      _clashToggle(
        title: (l) => l.tcpConcurrent,
        select: (state) => state.tcpConcurrent,
        update: (state, value) => state.copyWith(tcpConcurrent: value),
      ),
      _clashToggle(
        title: (l) => l.findProcessMode,
        select: (state) => state.findProcessMode == FindProcessMode.always,
        update: (state, value) => state.copyWith(
          findProcessMode: value ? FindProcessMode.always : FindProcessMode.off,
        ),
      ),
      _appSettingToggle(
        title: (l) => l.autoCloseConnections,
        select: (state) => state.closeConnections,
        update: (state, value) => state.copyWith(closeConnections: value),
      ),
      _appSettingToggle(
        title: (l) => l.onlyStatisticsProxy,
        select: (state) => state.onlyStatisticsProxy,
        update: (state, value) => state.copyWith(onlyStatisticsProxy: value),
      ),
    ];
  }

  List<Widget> _requestItems() {
    return [
      const UaItem(),
      _appSettingToggle(
        title: (l) => l.checkCertificate,
        select: (state) => state.checkCertificate,
        update: (state, value) => state.copyWith(checkCertificate: value),
      ),
      _appSettingToggle(
        title: (l) => l.autoCheckUpdate,
        select: (state) => state.autoCheckUpdate,
        update: (state, value) => state.copyWith(autoCheckUpdate: value),
      ),
    ];
  }

  List<Widget> _coreItems() {
    return [
      _clashToggle(
        title: (l) => 'IPv6',
        select: (state) => state.ipv6,
        update: (state, value) => state.copyWith(ipv6: value),
      ),
      const HostsItem(),
      ConfigToggleItem(
        title: (l) => l.appendSystemDns,
        selector: networkSettingProvider.select(
          (state) => state.appendSystemDns,
        ),
        onChanged: (ref, value) => ref
            .read(networkSettingProvider.notifier)
            .update((state) => state.copyWith(appendSystemDns: value)),
      ),
      _clashToggle(
        title: (l) => l.geodataLoader,
        select: (state) => state.geodataLoader == GeodataLoader.memconservative,
        update: (state, value) => state.copyWith(
          geodataLoader: value
              ? GeodataLoader.memconservative
              : GeodataLoader.standard,
        ),
      ),
    ];
  }

  List<Widget> _logItems() {
    return [
      const LogLevelItem(),
      _appSettingToggle(
        title: (l) => l.logcat,
        select: (state) => state.openLogs,
        update: (state, value) => state.copyWith(openLogs: value),
      ),
      if (system.isAndroid)
        _appSettingToggle(
          title: (l) => l.crashlytics,
          select: (state) => state.crashlytics,
          update: (state, value) => state.copyWith(crashlytics: value),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, ref) {
    final appLocalizations = context.appLocalizations;
    final authentication = ref.watch(
      networkSettingProvider.select((state) => state.authentication.enable),
    );
    final externalController = ref.watch(
      patchClashConfigProvider.select(
        (state) => state.externalController == ExternalControllerStatus.open,
      ),
    );
    final panelEnabled = ref.watch(
      panelSettingProvider.select((state) => state.enabled),
    );
    return BaseScaffold(
      title: appLocalizations.general,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
        ).copyWith(top: context.appBarInset, bottom: 16),
        children: [
          generateSectionV3(
            title: appLocalizations.startupAndBackground,
            items: _startupItems(appLocalizations),
            footer: [
              if (system.isDesktop) appLocalizations.silentLaunchDesc,
              appLocalizations.autoRunDesc,
              appLocalizations.onDemandDesc,
            ].join('\n'),
          ),
          generateSectionV3(
            title: appLocalizations.requestsAndUpdates,
            items: _requestItems(),
            footer: appLocalizations.checkCertificateDesc,
          ),
          generateSectionV3(
            title: appLocalizations.inbound,
            items: _inboundItems(
              authentication: authentication,
              externalController: externalController,
            ),
            footer: [
              appLocalizations.externalControllerDesc,
              appLocalizations.authenticationDesc,
            ].join('\n'),
          ),
          generateSectionV3(
            title: appLocalizations.connection,
            items: _connectionItems(),
            footer: appLocalizations.autoCloseConnectionsDesc,
          ),
          generateSectionV3(
            title: appLocalizations.core,
            items: _coreItems(),
            footer: appLocalizations.ipv6Desc,
          ),
          generateSectionV3(
            title: appLocalizations.logsAndDiagnostics,
            items: _logItems(),
            footer: [
              appLocalizations.logcatDesc,
              if (system.isAndroid) appLocalizations.crashlyticsTip,
            ].join('\n'),
          ),
          if (panelSupported)
            generateSectionV3(
              title: appLocalizations.remotePanel,
              items: _panelItems(
                panelEnabled: panelEnabled,
                phase: ref.watch(
                  panelInstallProvider.select((status) => status.phase),
                ),
              ),
              footer: [
                appLocalizations.remotePanelDesc,
                if (panelEnabled) appLocalizations.remotePanelLanDesc,
              ].join('\n'),
            ),
        ],
      ),
    );
  }
}

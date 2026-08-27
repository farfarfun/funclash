import 'package:flutter/material.dart';

import '../enum/page_label.dart';
import 'connections_page.dart';
import 'dashboard_page.dart';
import 'logs_page.dart';
import 'profiles_page.dart';
import 'proxies_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  PageLabel _current = PageLabel.dashboard;

  static const _pages = <PageLabel, Widget>{
    PageLabel.dashboard: DashboardPage(),
    PageLabel.proxies: ProxiesPage(),
    PageLabel.profiles: ProfilesPage(),
    PageLabel.connections: ConnectionsPage(),
    PageLabel.logs: LogsPage(),
    PageLabel.settings: SettingsPage(),
  };

  static const _icons = <PageLabel, IconData>{
    PageLabel.dashboard: Icons.speed,
    PageLabel.proxies: Icons.hub,
    PageLabel.profiles: Icons.subscriptions,
    PageLabel.connections: Icons.swap_horiz,
    PageLabel.logs: Icons.article,
    PageLabel.settings: Icons.settings,
  };

  @override
  Widget build(BuildContext context) {
    final destinations = PageLabel.values
        .map((label) => NavigationRailDestination(
              icon: Icon(_icons[label]),
              label: Text(label.label),
            ))
        .toList();

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _current.index,
            onDestinationSelected: (index) => setState(() => _current = PageLabel.values[index]),
            labelType: NavigationRailLabelType.all,
            destinations: destinations,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pages[_current]!),
        ],
      ),
    );
  }
}

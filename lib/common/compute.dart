import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';

List<Group> computeSort({
  required List<Group> groups,
  required ProxiesSortType sortType,
  required DelayMap delayMap,
  required Map<String, String> selectedMap,
  required String defaultTestUrl,
}) {
  final resolver = SelectedProxyResolver(
    groups: groups,
    selectedMap: selectedMap,
  );

  List<Proxy> sortOfDelay(List<Proxy> proxies, String testUrl) {
    final delayStates = {
      for (final proxy in proxies)
        proxy.name: resolver.delayStateOf(
          proxy.name,
          testUrl: testUrl,
          delayMap: delayMap,
        ),
    };
    return List.of(proxies)
      ..sort((a, b) => delayStates[a.name]!.compareTo(delayStates[b.name]!));
  }

  List<Proxy> sortOfName(List<Proxy> proxies) {
    return List.of(proxies)..sort((a, b) => a.name.compareTo(b.name));
  }

  return groups.map((group) {
    final proxies = group.all;
    final newProxies = switch (sortType) {
      ProxiesSortType.none => proxies,
      ProxiesSortType.delay => sortOfDelay(
        proxies,
        group.testUrl.takeFirstValid([defaultTestUrl]),
      ),
      ProxiesSortType.name => sortOfName(proxies),
    };
    return group.copyWith(all: newProxies);
  }).toList();
}

/// Built-in adapters whose delay probe always fails, so a timeout says nothing.
const _unprobeableProxyTypes = {
  'Reject',
  'RejectDrop',
  'Pass',
  'PassRule',
  'Rematch',
  'Compatible',
  'Dns',
};

List<Group> computeHideTimeout({
  required List<Group> groups,
  required List<Group> allGroups,
  required DelayMap delayMap,
  required Map<String, String> selectedMap,
  required String defaultTestUrl,
}) {
  final resolver = SelectedProxyResolver(
    groups: allGroups,
    selectedMap: selectedMap,
  );
  final proxyTypes = {
    for (final group in allGroups)
      for (final proxy in group.all) proxy.name: proxy.type,
  };
  return groups.map((group) {
    final groupTestUrl = group.testUrl.takeFirstValid([defaultTestUrl]);
    final groupWithNow = resolver.groupOf(group.name) ?? group;
    final selectedName = groupWithNow.getCurrentSelectedName(
      selectedMap[group.name] ?? '',
    );
    final visible = group.all.where((proxy) {
      if (proxy.name == selectedName) {
        return true;
      }
      final state = resolver.stateOf(proxy.name);
      if (_unprobeableProxyTypes.contains(proxyTypes[state.proxyName])) {
        return true;
      }
      final testUrl = state.testUrl.takeFirstValid([groupTestUrl]);
      final delay = delayMap[testUrl]?[state.proxyName];
      return delay == null || delay > 0;
    }).toList();
    return group.copyWith(all: visible.isEmpty ? group.all : visible);
  }).toList();
}

/// Build one per pass and reuse it for every name: a scan of the group list
/// per hop is quadratic over a profile's groups.
final class SelectedProxyResolver {
  SelectedProxyResolver({
    required Iterable<Group> groups,
    required Map<String, String> selectedMap,
  }) : _groups = {for (final group in groups) group.name: group},
       _selectedMap = selectedMap;

  final Map<String, Group> _groups;
  final Map<String, String> _selectedMap;
  final Map<String, SelectedProxyState> _states = {};

  Group? groupOf(String groupName) => _groups[groupName];

  SelectedProxyState stateOf(String proxyName) => _states.putIfAbsent(
    proxyName,
    () => _resolve(SelectedProxyState(proxyName: proxyName)),
  );

  DelayState delayStateOf(
    String proxyName, {
    required String testUrl,
    required DelayMap delayMap,
  }) {
    final state = stateOf(proxyName);
    final delays =
        delayMap[state.testUrl.takeFirstValid([testUrl])] ?? const {};
    return DelayState(delay: delays[state.proxyName] ?? 0, group: state.group);
  }

  SelectedProxyState _resolve(SelectedProxyState state) {
    if (state.proxyName.isEmpty) return state;
    final group = _groups[state.proxyName];
    final newState = state.copyWith(group: true);
    if (group == null) return newState;
    final currentSelectedName = group.getCurrentSelectedName(
      _selectedMap[newState.proxyName] ?? '',
    );
    if (currentSelectedName.isEmpty) {
      return newState;
    }
    return _resolve(
      newState.copyWith(proxyName: currentSelectedName, testUrl: group.testUrl),
    );
  }
}

SelectedProxyState computeRealSelectedProxyState(
  String proxyName, {
  required List<Group> groups,
  required Map<String, String> selectedMap,
}) {
  return SelectedProxyResolver(
    groups: groups,
    selectedMap: selectedMap,
  ).stateOf(proxyName);
}

String delayTestKey(String testUrl, String proxyName) {
  return '$testUrl\u0000$proxyName';
}

DelayState computeProxyDelayState({
  required String proxyName,
  required String testUrl,
  required List<Group> groups,
  required Map<String, String> selectedMap,
  required DelayMap delayMap,
}) {
  return SelectedProxyResolver(
    groups: groups,
    selectedMap: selectedMap,
  ).delayStateOf(proxyName, testUrl: testUrl, delayMap: delayMap);
}

/// 对齐 FlClash 的 `PageLabel` 集合；tools/requests/resources 暂未实现。
enum PageLabel {
  dashboard('Dashboard'),
  proxies('Proxies'),
  profiles('Profiles'),
  connections('Connections'),
  logs('Logs'),
  settings('Settings');

  final String label;

  const PageLabel(this.label);
}

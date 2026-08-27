/// Mirrors FlClash's `PageLabel` set (minus tools/requests/resources, which
/// are deferred — see the Phase 0 scope note in the project plan).
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

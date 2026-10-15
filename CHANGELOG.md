# Changelog

## v1.0.0 (2026-10-15)

**Breaking Changes**

- Rename the binaries, services and sockets to FunClash. An install of the project this one was renamed from does not migrate: the bundle id, the Windows service name, the systemd unit and the data directory all change, so profiles do not carry over. Remove the old privileged Helper by hand before installing — FlClashHelperService uninstall on Windows, systemctl disable --now flclash-helper on Linux. (b90568f)
- **android** Move the app to com.farfarfun.funclash, which Android treats as a different application: install this one alongside, or uninstall the old one first. (70ab975)
- Rename the Dart package to funclash (47dd568)
- **changelog** Restart the changelog at 1.0.0; nothing before it is kept here. (2930f61)

**Bug Fixes**

- **site** Look the Debian package up under the name it ships as (e1526f2)

<!-- changelog:frozen -->
<!-- Nothing is kept below: the releases before funclash 1.0.0 belong to the project this one was renamed from. -->


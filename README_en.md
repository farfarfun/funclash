# FunClash

A multi-platform proxy client based on ClashMeta. Simple to use, open source and ad-free.

<div align="center">

<img src="assets/images/icon.png" alt="FunClash" width="88">

[简体中文](README.md) · **English**

[![Release](https://img.shields.io/github/v/release/farfarfun/funclash?style=flat-square&label=release)](https://github.com/farfarfun/funclash/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/farfarfun/funclash/total?style=flat-square&logo=github)](https://github.com/farfarfun/funclash/releases)
[![License](https://img.shields.io/github/license/farfarfun/funclash?style=flat-square)](LICENSE)

[Website](https://farfarfun.github.io/packages/funclash/) · [Download](#download) · [Web panel](#web-panel) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/preview-dark.png">
    <img alt="The FunClash dashboard" src="docs/snapshots/preview.png" width="92%">
  </picture>
</p>

## Features

- **One app for Android, Windows, macOS and Linux**, with x64 and ARM64 builds on the desktop.
- **mihomo (Clash.Meta) core** with rule routing, proxy groups, latency tests, system proxy and TUN mode.
- **Profiles** from a subscription link or a file, with a built-in editor, override scripts, and custom rules,
  proxies and proxy groups.
- **Web remote panel**: manage the running desktop client from a browser, with shared profiles, settings and running state.
- **Live views** of connections, requests, DNS queries and logs.
- **Material You design with Apple-style interaction**: dynamic color, light and dark themes, continuous corners,
  sheets that snap between heights, and layouts that adapt from phones to desktops.
- **Backup and restore** through WebDAV or a local file.
- **Platform touches**: a Quick Settings tile, per-app proxy and Android TV support on Android; a tray menu and
  global hotkeys on the desktop.
- **Open source and ad-free**, licensed under GPL-3.0.

## Web panel

FunClash includes a browser panel for a running Windows, macOS or Linux client. You can start and stop the host,
select profiles and proxy nodes, and view connections, traffic and logs. The desktop client must remain running;
closing the browser leaves the host running. The project website above provides downloads and documentation.

### Open the panel

1. Install the latest desktop release and open **Settings → General → Remote panel**.
2. Fresh installations enable the panel and LAN access by default. Matching Web assets are bundled with the desktop
   package, so no download or separate deployment is needed. Saved settings, including disabled switches, are preserved.
3. Use **Copy link** and open the complete link in a current Chrome or Edge browser with WebAssembly support.
4. To access it from another device, check **Reachable from the network** is enabled, replace `127.0.0.1` in the copied link
   with the host's LAN IP, and keep the port and `#token=…` fragment. The host firewall must allow that port.

The link grants access to the panel. Share it only with people who may control the host; **Replace link** revokes
the old link and disconnects existing panels.

### Do Web and desktop need separate configuration?

**No. Profiles, selected nodes and synchronized settings come from the desktop host.** Changes in the panel affect
that host too. Start/stop, profile application and Core restart run through the desktop client, which owns system
proxy and TUN operation. Opening the panel on a second device does not route that device's traffic through the host;
using the host as its proxy requires configuring that device's network proxy separately.

The two clients share Flutter pages and components, with some differences in how they are displayed:

| Area | Desktop | Web panel |
| --- | --- | --- |
| Layout | Adapts to the actual window width. | Uses a centered 680 × 580 logical-pixel canvas, scaled down in smaller browser windows. Enlarging the browser does not expand it into the desktop wide layout. |
| Navigation and cards | Sidebar labels and column counts change with available width. | The fixed canvas generally uses the compact sidebar and fewer columns than a large desktop window. |
| System integration | Native window controls, tray, global hotkeys and platform-specific settings. | Browser window controls; some desktop-only settings are hidden. System operations remain on the host. |
| Appearance | Uses the desktop's fonts, rendering and platform theme support. | Browser fonts, rendering and platform theme support can produce small visual differences. |

There is no separate “desktop components” switch to configure in the panel. If the same business component behaves
differently with matching versions, theme and content width, that needs a Web adaptation fix. Report the page,
component and browser so the difference can be reproduced.

### Updates and reconnecting

After a desktop upgrade, restart the client. An enabled panel automatically installs its matching bundled Web
assets; reload the page after that finishes. If installation fails, retry from the Remote panel settings. This also
updates old page resources and logos. Refreshing an open tab preserves its connection token within that browser
session; use the complete copied link when opening a new session.

### Linux servers without a desktop

Install the same desktop package. With neither `DISPLAY` nor `WAYLAND_DISPLAY`, FunClash automatically runs the
app inside an Xvfb virtual display. `--headless` forces this mode even in a desktop session. Flutter and the Core
still run; this is not a separate lightweight Web server.

DEB/RPM declare the virtual-display dependencies. Install a DEB with `sudo apt install ./funclash_*.deb` so APT
resolves them. AppImage users must install runtime dependencies themselves; on Ubuntu/Debian:

```bash
sudo apt install xvfb xauth dbus util-linux libgtk-3-0 libgl1-mesa-dri libsecret-1-0 libayatana-appindicator3-1
```

Replace `FunClash` below with the installed executable or AppImage path:

```bash
FunClash --show-disclaimer
# After reading and accepting the terms; acceptance is saved for subsequent launches
FunClash --headless --accept-disclaimer
# In another terminal, print the full panel link
FunClash --panel-url
```

The default port is `47891`. Replace `127.0.0.1` in the printed link with the server IP, retain `#token=…`, and
open it in current Chrome/Edge. Allow TCP 47891 through the host firewall as needed. Panel and LAN defaults apply
only to fresh settings; upgrades preserve your choices. Stop FunClash before changing saved settings from the CLI:

```bash
FunClash --panel --allow-lan --panel-port 47891 --panel-url
FunClash --no-allow-lan --panel-url
FunClash --no-panel --panel-url
```

Use `--data-dir /absolute/path` for a separate data directory; startup and link commands must use the same user
and path. Headless mode omits desktop autostart, tray, hotkeys and desktop system proxy integration. Configure proxy
ports or TUN through the panel. For TUN, use a DEB/RPM installation with systemd and follow the startup log's instruction to run
`sudo "/installation/path/FunClashHelperService" install` in a terminal, avoiding an invisible authorization dialog.

For startup at boot, create `/etc/systemd/system/funclash.service`, replacing the user and paths below. First complete
consent using that same user and data directory:

```ini
[Unit]
Description=FunClash Web panel host
After=network-online.target
Wants=network-online.target

[Service]
User=your-user
ExecStart=/absolute/path/FunClash --headless --data-dir /home/your-user/.local/share/funclash-server
Restart=on-failure
KillMode=mixed
TimeoutStopSec=20

[Install]
WantedBy=multi-user.target
```

Run `sudo systemctl daemon-reload` and `sudo systemctl enable --now funclash`. Read logs with
`journalctl -u funclash`; stop it with `sudo systemctl stop funclash`. Packages do not enable this service automatically.

## Screenshots

<table>
  <tr>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/proxies-dark.png">
        <img alt="Proxy groups with latency tests" src="docs/snapshots/proxies.png">
      </picture>
    </td>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/profiles-dark.png">
        <img alt="Profiles from subscriptions and files" src="docs/snapshots/profiles.png">
      </picture>
    </td>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/tools-dark.png">
        <img alt="Tools and settings" src="docs/snapshots/tools.png">
      </picture>
    </td>
  </tr>
</table>

## Download

Get the latest build from [GitHub Releases](https://github.com/farfarfun/funclash/releases/latest), or open the
[website](https://farfarfun.github.io/packages/funclash/#download), which picks the right file for your device.

| Platform | Packages | Notes |
| --- | --- | --- |
| Android | APK for `arm64-v8a`, `armeabi-v7a` and `x86_64` | Most phones use `arm64-v8a`. |
| Windows 10 and later | Installer (`.exe`) or portable `.zip`, for x64 and ARM64 | Pick ARM64 on Snapdragon and other ARM laptops. |
| macOS 12 and later | DMG for Apple Silicon and Intel | Also on Homebrew. |
| Linux | `.deb`, `.rpm` and AppImage, for x64 and ARM64 | The `.deb` is also on the APT source below. See the tray note too. |

<p>
  <a href="https://github.com/farfarfun/funclash/releases/latest"><img alt="Get it on GitHub" src="docs/snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Homebrew** (macOS)

```bash
brew tap farfarfun/packages https://github.com/farfarfun/packages
brew trust farfarfun/packages
brew install funclash
```

The tap URL has to be spelled out: `brew tap farfarfun/packages` on its own looks for a `homebrew-packages`
repository, and that one repository is also the APT source below. `brew trust` is what Homebrew 6.0 and later want
before a third-party tap's casks will install under their bare name.

**APT** (Debian and Ubuntu)

```bash
curl -fsSL https://farfarfun.github.io/packages/farfarfun.gpg \
  | sudo tee /usr/share/keyrings/farfarfun.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/farfarfun.gpg] https://farfarfun.github.io/packages/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/farfarfun.list
sudo apt update && sudo apt install funclash
```

Both channels are served by [farfarfun/packages](https://github.com/farfarfun/packages) from this repository's
releases, and both index one package per repository, which is why the package name is the lower-case `funclash`.
`apt` keeps the last two versions — `apt-cache madison funclash` lists the one you can downgrade to; Homebrew
carries the latest only.

**Linux tray icon**

The `.deb` package installs its own dependencies. With the AppImage or the `.rpm`, install the AyatanaAppIndicator
library so the tray icon can show:

```bash
sudo apt-get install libayatana-appindicator3-1   # Debian and Ubuntu
sudo dnf install libayatana-appindicator-gtk3     # Fedora
```

## Usage

**Import a profile from a link.** Opening a link in this form imports the subscription into FunClash. The `clashmeta://`
and `funclash://` schemes work the same way.

```text
clash://install-config?url=<URL-encoded subscription link>
```

**Automate on Android.** Tasker, MacroDroid and similar apps can start, stop or toggle the proxy by starting an
activity with one of these actions:

```text
com.farfarfun.funclash.action.START
com.farfarfun.funclash.action.STOP
com.farfarfun.funclash.action.TOGGLE
```

From a computer, the same works over adb:

```bash
adb shell am start -a com.farfarfun.funclash.action.TOGGLE
```

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.47 (release builds use 3.47.6),
[Go](https://go.dev/dl/) 1.27 and [Rust](https://rustup.rs/) installed through rustup. Each platform builds on its own
host, except Android, which builds anywhere.

```bash
git clone --recursive https://github.com/farfarfun/funclash.git
cd funclash
flutter pub get
dart tool/setup.dart android   # or windows, macos, linux
```

Packages land in `dist/`. The Go core and the Rust libraries are compiled as part of the Flutter build.

| Platform | Also needed |
| --- | --- |
| Android | Android SDK with the NDK. Add `--arch arm64` to build a single ABI. |
| Windows | GCC (MinGW-w64) for the core and [Inno Setup](https://jrsoftware.org/isinfo.php) 6 for the installer. |
| macOS | Xcode and Node.js. The script installs `appdmg` through npm. |
| Linux | Debian or Ubuntu. The script installs the build packages with apt and downloads `appimagetool`. |

Run `dart tool/setup.dart --help` for the remaining options, such as `--targets` to build only some package formats.

## Support

Starring the repository is the easiest way to support the project. Bugs and feature requests go to
[GitHub Issues](https://github.com/farfarfun/funclash/issues).

## License

FunClash is released under the [GPL-3.0 license](LICENSE). It started as a fork of
[FlClash](https://github.com/chen08209/FlClash) and keeps that licence.

---

## About farfarfun

[farfarfun](https://github.com/farfarfun) is an open-source organization building practical tools for cloud storage,
data processing, AI, multimedia and developer workflows.

- Organization: <https://github.com/farfarfun>
- Contact: farfarfun@qq.com

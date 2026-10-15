<div align="center">

<img src="assets/images/icon.png" alt="FunClash" width="88">

# FunClash

A multi-platform proxy client based on ClashMeta. Simple to use, open source and ad-free.

**English** · [简体中文](README_zh_CN.md)

[![Release](https://img.shields.io/github/v/release/farfarfun/funclash?style=flat-square&label=release)](https://github.com/farfarfun/funclash/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/farfarfun/funclash/total?style=flat-square&logo=github)](https://github.com/farfarfun/funclash/releases)
[![License](https://img.shields.io/github/license/farfarfun/funclash?style=flat-square)](LICENSE)

[Website](https://farfarfun.github.io/funclash) · [Download](#download) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/preview-dark.png">
    <img alt="FunClash dashboard on a MacBook and a phone" src="docs/snapshots/preview.png" width="92%">
  </picture>
</p>

## Features

- **One app for Android, Windows, macOS and Linux**, with x64 and ARM64 builds on the desktop.
- **mihomo (Clash.Meta) core** with rule routing, proxy groups, latency tests, system proxy and TUN mode.
- **Profiles** from a subscription link or a file, with a built-in editor, override scripts, and custom rules,
  proxies and proxy groups.
- **Live views** of connections, requests, DNS queries and logs.
- **Material You design with Apple-style interaction**: dynamic color, light and dark themes, continuous corners,
  sheets that snap between heights, and layouts that adapt from phones to desktops.
- **Backup and restore** through WebDAV or a local file.
- **Platform touches**: a Quick Settings tile, per-app proxy and Android TV support on Android; a tray menu and
  global hotkeys on the desktop.
- **Open source and ad-free**, licensed under GPL-3.0.

## Download

Get the latest build from [GitHub Releases](https://github.com/farfarfun/funclash/releases/latest), or open the
[website](https://farfarfun.github.io/funclash#download), which picks the right file for your device.

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

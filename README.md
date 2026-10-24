<div align="center">

<img src="assets/images/icon.png" alt="FunClash" width="88">

# FunClash

基于 ClashMeta 的多平台代理客户端，简单易用，开源无广告。

**简体中文** · [English](README_en.md)

[![Release](https://img.shields.io/github/v/release/farfarfun/funclash?style=flat-square&label=release)](https://github.com/farfarfun/funclash/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/farfarfun/funclash/total?style=flat-square&logo=github)](https://github.com/farfarfun/funclash/releases)
[![License](https://img.shields.io/github/license/farfarfun/funclash?style=flat-square)](LICENSE)

[官网](https://farfarfun.github.io/packages/funclash/) · [下载](#下载) · [网页远程面板](#网页远程面板) · [更新日志](CHANGELOG.md) · [从源码构建](#从源码构建)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/preview-dark.png">
    <img alt="FunClash 仪表盘" src="docs/snapshots/preview.png" width="92%">
  </picture>
</p>

## 功能

- **一个应用覆盖 Android、Windows、macOS 和 Linux**，桌面端同时提供 x64 与 ARM64 版本。
- **mihomo（Clash.Meta）内核**：规则分流、代理组、延迟测试、系统代理与 TUN 模式。
- **配置管理**：通过订阅链接或文件导入配置，内置编辑器，支持覆写脚本以及自定义规则、代理和代理组。
- **网页远程面板**：通过浏览器管理正在运行的桌面端，共享配置、节点选择和运行状态。
- **实时查看**连接、请求、DNS 查询和日志。
- **Material You 设计，融合 Apple 式交互**：支持动态取色、浅色与深色主题，连续曲率圆角，弹出面板可在几档高度间吸附，布局随屏幕从手机到桌面自适应。
- **备份与恢复**：通过 WebDAV 或本地文件。
- **平台细节**：Android 上有快捷设置磁贴、分应用代理和 Android TV 支持；桌面端有托盘菜单和全局快捷键。
- **开源无广告**，以 GPL-3.0 协议发布。

## 网页远程面板

FunClash 自带网页面板，可通过浏览器控制正在运行的 Windows、macOS 或 Linux 客户端，执行启动、停止、
切换配置和节点，以及查看连接、流量和日志。使用时需要保持桌面端运行；关闭浏览器不会停止桌面端。
上方的项目官网用于下载和查看项目介绍，远程面板由你自己的桌面客户端提供。

### 如何开启

1. 安装最新版桌面客户端，进入 **设置 → 常规 → 远程面板**。
2. 开启远程面板，等待应用自动下载对应版本的网页资源，无需单独部署。
3. 点击 **复制链接**，在支持 WebAssembly 的新版 Chrome 或 Edge 中打开完整链接。
4. 从其他设备访问时，开启 **允许局域网访问**，把链接中的 `127.0.0.1` 换成桌面主机的局域网 IP，
   保留端口和 `#token=…` 部分，并确保主机防火墙允许访问该端口。

链接包含访问凭据，请仅分享给可以控制该主机的人。点击 **更换链接** 会使旧链接立即失效，并断开已连接的面板。

### 网页版和桌面版需要分别配置吗？

**不需要。网页面板直接使用桌面主机的配置文件、节点选择和同步设置，修改也会作用于桌面端。**
启动、停止、应用配置和重启内核均由桌面端执行，系统代理与 TUN 也由桌面主机管理。
在另一台设备上打开面板，仅表示可以远程控制主机；若要让那台设备的网络流量通过主机代理，仍需单独设置该设备的网络代理。

两端共用 Flutter 页面和组件，但当前呈现方式存在以下差异：

| 项目 | 桌面版 | 网页面板 |
| --- | --- | --- |
| 布局大小 | 随实际窗口宽度调整布局。 | 居中显示固定的 680 × 580 逻辑像素区域，浏览器窗口较小时整体缩小；放大浏览器不会展开为桌面宽屏布局。 |
| 导航和卡片 | 侧栏文字、卡片列数随可用宽度变化。 | 固定区域通常使用紧凑侧栏，卡片列数可能少于大窗口的桌面版。 |
| 系统功能 | 提供原生窗口按钮、托盘、全局快捷键及平台专属设置。 | 使用浏览器窗口按钮，部分桌面专属设置不显示；系统操作仍由主机执行。 |
| 外观细节 | 使用桌面系统的字体、渲染和平台主题支持。 | 浏览器的字体、渲染和平台主题支持可能带来细微差异。 |

网页面板没有需要另行开启的“桌面组件”开关。如果版本、主题和内容宽度一致时，同一业务组件仍然表现不同，
需要排查 Web 适配问题。反馈时请说明具体页面、组件和浏览器，便于复现。

### 升级与重新连接

升级桌面客户端后重启应用，已开启的面板会自动检查并下载对应版本的网页资源，完成后刷新网页即可。
下载失败时，可在远程面板设置中点击重试；更新也会替换旧页面资源和 Logo。
刷新已打开的标签页时，会在当前浏览器会话内保留连接令牌；新会话请使用复制的完整链接进入。

## 截图

<table>
  <tr>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/proxies-dark.png">
        <img alt="代理组与延迟测试" src="docs/snapshots/proxies.png">
      </picture>
    </td>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/profiles-dark.png">
        <img alt="订阅与文件配置" src="docs/snapshots/profiles.png">
      </picture>
    </td>
    <td width="33%">
      <picture>
        <source media="(prefers-color-scheme: dark)" srcset="docs/snapshots/tools-dark.png">
        <img alt="工具与设置" src="docs/snapshots/tools.png">
      </picture>
    </td>
  </tr>
</table>

## 下载

从 [GitHub Releases](https://github.com/farfarfun/funclash/releases/latest) 获取最新版本，或打开
[官网](https://farfarfun.github.io/packages/funclash/#download)，它会自动为你的设备选好安装包。

| 平台 | 安装包 | 说明 |
| --- | --- | --- |
| Android | `arm64-v8a`、`armeabi-v7a`、`x86_64` 三种 APK | 绝大多数手机选 `arm64-v8a`。 |
| Windows 10 及以上 | 安装版（`.exe`）或便携版（`.zip`），分 x64 与 ARM64 | 骁龙等 ARM 架构笔记本选 ARM64。 |
| macOS 12 及以上 | Apple Silicon 与 Intel 两种 DMG | 也可以通过 Homebrew 安装。 |
| Linux | `.deb`、`.rpm` 和 AppImage，分 x64 与 ARM64 | `.deb` 也可以通过下方的 APT 源安装。托盘依赖见下方说明。 |

<p>
  <a href="https://github.com/farfarfun/funclash/releases/latest"><img alt="Get it on GitHub" src="docs/snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Homebrew**（macOS）

```bash
brew tap farfarfun/packages https://github.com/farfarfun/packages
brew trust farfarfun/packages
brew install funclash
```

`tap` 那行要把 URL 写出来：`brew tap farfarfun/packages` 默认去找名为 `homebrew-packages` 的仓库，而那一个仓库同时
还是下面的 APT 源。`trust` 那行也不能省，Homebrew 6.0 起第三方 tap 默认不可信，不 trust 的话裸名字会被直接拒绝。

**APT**（Debian 与 Ubuntu）

```bash
curl -fsSL https://farfarfun.github.io/packages/farfarfun.gpg \
  | sudo tee /usr/share/keyrings/farfarfun.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/farfarfun.gpg] https://farfarfun.github.io/packages/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/farfarfun.list
sudo apt update && sudo apt install funclash
```

两条渠道都由 [farfarfun/packages](https://github.com/farfarfun/packages) 按本仓库的 release 生成，而它一个仓库只收
一个包名，所以包名用的是全小写的 `funclash`。apt 那边留着最近两版，`apt-cache madison funclash` 能看到可以退回去的
那一版；Homebrew 只有最新版。

**Linux 托盘图标**

`.deb` 安装包会自动安装所需依赖。使用 AppImage 或 `.rpm` 时，需要先安装 AyatanaAppIndicator 库，托盘图标才能显示：

```bash
sudo apt-get install libayatana-appindicator3-1   # Debian 与 Ubuntu
sudo dnf install libayatana-appindicator-gtk3     # Fedora
```

## 使用

**通过链接导入配置。** 打开下面格式的链接，即可把订阅导入 FunClash。`clashmeta://` 和 `funclash://` 开头的链接同样可用。

```text
clash://install-config?url=<经过 URL 编码的订阅链接>
```

**Android 自动化。** Tasker、MacroDroid 等应用可以用下面的 Action 启动 Activity，从而启动、停止或切换代理：

```text
com.farfarfun.funclash.action.START
com.farfarfun.funclash.action.STOP
com.farfarfun.funclash.action.TOGGLE
```

在电脑上也可以通过 adb 触发：

```bash
adb shell am start -a com.farfarfun.funclash.action.TOGGLE
```

## 从源码构建

需要 [Flutter](https://docs.flutter.dev/get-started/install) 3.47（正式版构建使用 3.47.6）、[Go](https://go.dev/dl/) 1.27，
以及通过 rustup 安装的 [Rust](https://rustup.rs/)。桌面端需要在对应系统上构建，Android 在任意系统上都能构建。

```bash
git clone --recursive https://github.com/farfarfun/funclash.git
cd funclash
flutter pub get
dart tool/setup.dart android   # 或 windows、macos、linux
```

安装包输出到 `dist/`。Go 内核和 Rust 库会在 Flutter 构建过程中一并编译。

| 平台 | 额外依赖 |
| --- | --- |
| Android | 带 NDK 的 Android SDK。加上 `--arch arm64` 可以只构建单个 ABI。 |
| Windows | 编译内核用的 GCC（MinGW-w64），以及打包安装程序用的 [Inno Setup](https://jrsoftware.org/isinfo.php) 6。 |
| macOS | Xcode 与 Node.js。脚本会通过 npm 安装 `appdmg`。 |
| Linux | Debian 或 Ubuntu。脚本会用 apt 安装构建所需的软件包，并下载 `appimagetool`。 |

其余选项可以运行 `dart tool/setup.dart --help` 查看，例如用 `--targets` 只构建部分安装包格式。

## 支持

给仓库点一个 Star 是支持项目最简单的方式。Bug 与功能建议请提交到
[GitHub Issues](https://github.com/farfarfun/funclash/issues)。

## 许可证

FunClash 以 [GPL-3.0 协议](LICENSE)发布，代码源自 [FlClash](https://github.com/chen08209/FlClash)，沿用同一协议。

---

## 关于 farfarfun

[farfarfun](https://github.com/farfarfun) 是一个专注于实用工具库的开源组织，
涵盖云存储、数据处理、AI、多媒体与开发工具链等方向。

- 组织主页：<https://github.com/farfarfun>
- 联系：farfarfun@qq.com

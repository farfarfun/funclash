# funclash

参考 [FlClash](https://github.com/chen08209/FlClash) 的架构（Flutter + Riverpod + mihomo 内核）重新实现的开源代理客户端，**不是 fork**，未复用其任何 GPL-3.0 代码，本仓库保持 MIT 协议。

在 FlClash 的基础上做了两点扩展：
1. **补全了 Web 端** —— FlClash 官方没有做 Web 支持，本项目的 Flutter 应用同时支持 Web、Linux 桌面（Android / iOS 见下方路线图）。
2. **提供命令行安装/启动能力** —— `launcher/` 是一个独立的 Node.js CLI，一条命令即可下载并运行 [mihomo](https://github.com/MetaCubeX/mihomo)（Clash Meta）内核，适合服务器/无图形界面环境。

仓库包含两个相互独立的子项目：

```
funclash/
  launcher/   # Node.js CLI：安装、启动、管理 mihomo 内核
  app/        # Flutter 客户端：Dashboard / Proxies / Profiles / Connections / Logs
```

两者都通过 mihomo 的 `external-controller` REST API 交互，互不依赖：可以只用 CLI 把内核跑在服务器上，也可以只用 Flutter 客户端连接一个已经在运行的内核。

## launcher —— 命令行安装启动

```bash
cd launcher
npm install
npm link          # 全局安装 funclash 命令，或直接用 node bin/funclash.js

funclash install                # 下载 mihomo 内核到 ~/.funclash，并尝试安装 Web 控制台
funclash start -d               # 后台启动
funclash status                 # 查看运行状态 + 内核版本
funclash dashboard --print      # 打印控制台访问地址
funclash logs -f                # 实时查看日志
funclash config pull <sub-url>  # 拉取订阅并写入配置
funclash stop                   # 停止
funclash uninstall --purge      # 卸载并清除 ~/.funclash
```

内核与配置统一存放在 `~/.funclash/`（`bin/`、`config/`、`dashboard/`、`run/`）。`external-ui` 默认指向 `~/.funclash/dashboard`，由 mihomo 直接提供静态文件服务，无需额外起一个 Node HTTP 服务。

Web 控制台目前需要单独提供：
- 本地已有 `app/` 的 Web 构建产物时，用 `funclash install --web-dir ../app/build/web` 指定；
- 或者等本仓库发布 `funclash-web-*.tar.gz` release 资产后自动下载（尚未发布，`install` 命令在拿不到时会给出明确的提示并继续完成内核安装，不会中断整个流程）。

该 CLI 已在本机针对真实的 mihomo 二进制完整验证过 install/start/status/dashboard/logs/stop/uninstall 全流程。

## app —— Flutter 客户端

```bash
cd app
flutter pub get
flutter run -d chrome    # Web
flutter run -d linux     # Linux 桌面（需要系统装好 cmake / ninja / GTK3 开发库）
```

已实现（对齐 FlClash 的 `PageLabel` 页面结构，去掉了 tools/requests/resources 三个次要页面）：
- **Dashboard**：内核版本、连接状态、实时流量
- **Proxies**：代理分组展开、切换节点、测速
- **Profiles**：添加订阅链接，通过 mihomo `PUT /configs`（payload 模式）直接下发配置，无需落盘
- **Connections**：实时连接列表
- **Logs**：内核日志流
- **Settings**：控制台地址 / secret 配置

架构上参考了 FlClash 对内核启动方式按平台拆分的做法：
- Linux/macOS/Windows 桌面：`CoreLauncher` 通过 `Process.start` 把 mihomo 作为子进程拉起（`lib/core/core_launcher/desktop_launcher.dart`），但沟通方式简化为 mihomo 官方文档化的 `external-controller` REST API，而不是复刻 FlClash 内部的 RPC-over-socket 协议——两者对外表现一致，但更简单、可用 `curl` 直接验证。
- Web（以及尚未实现内核嵌入的 Android/iOS）：`NoopCoreLauncher`，客户端只是连接一个已经在运行的内核（例如由 `launcher` 启动的那个），在 Settings 页填写控制台地址即可。

**验证状态**：`flutter analyze` 无警告、`flutter test` 通过、`flutter build web` 编译成功。Linux 桌面构建在本沙盒中因缺少系统级 `cmake`/`ninja` 未能实际跑一遍 `flutter build linux`，但相关 Dart 代码已随 `flutter analyze` 一并做过类型检查，逻辑侧没有已知问题；建议使用者在本地装好 Linux 桌面构建依赖后自行跑一遍 `flutter run -d linux` 做最终确认。

## 路线图 / 尚未实现

对齐 FlClash 完整能力是一个跨多个阶段的工程，当前只完成了 Phase 0：

- **Phase 0（已完成）**：Flutter 客户端（Web + Linux 桌面可用）+ CLI 内核安装启动。
- **Phase 1（未开始）**：Android —— 需要把 mihomo 编译为 cgo `.so` 并通过 JNI 在进程内加载（对齐 FlClash 的 `android/core/.../Core.kt`），再实现 `VpnService` 建立 TUN 设备接管系统流量。目前 `flutter create` 已生成 `app/android` 目录，但没有任何原生代码，装到 Android 上只能当远程控制台用，不能建立 VPN。
- **Phase 2（未开始，需要用户提供 Apple Developer 账号）**：iOS —— **FlClash 官方本身就没有 iOS 支持**（没有 `ios/` 目录，没有 NetworkExtension 代码），这部分是全新开发，不是移植。需要付费 Apple Developer Program 账号 + 真机才能做 NetworkExtension/PacketTunnelProvider 的调试和授权，无法在自动化环境里完成。

其余未实现：Windows/macOS 桌面内核启动、规则编辑器、DNS/脚本配置页、WebDAV 订阅同步等 FlClash 拥有但本项目尚未覆盖的功能。

## License

MIT，见 [LICENSE](LICENSE)。本项目为参考 FlClash 架构的独立实现，未包含其 GPL-3.0 代码。

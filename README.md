# funclash

参考 [FlClash](https://github.com/chen08209/FlClash) 的架构（Flutter + Riverpod + mihomo 内核）重新实现的开源代理客户端，**不是 fork**，未复用其任何 GPL-3.0 代码，本仓库保持 MIT 协议。

在 FlClash 的基础上做了两点扩展：
1. **补全了 Web 端** —— FlClash 官方没有做 Web 支持，本项目的 Flutter 应用同时支持 Web、Linux/Windows/macOS 桌面（Android / iOS 见下方路线图）。
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
# 开发：直接跑源码，无需安装
cd launcher && npm install && cd ..
scripts/setup.sh run dev        # 前台启动
scripts/setup.sh start dev      # 后台启动
scripts/setup.sh stop dev       # 停止

# 生产：先把 launcher 作为正式包安装到全局
cd launcher && npm pack && npm install -g ./funclash-*.tgz && cd ..
funclash install                # 下载 mihomo 内核到 ~/.funclash，并尝试安装 Web 控制台
scripts/setup.sh start prod     # 后台启动（只会执行已安装的正式包）
scripts/setup.sh status         # 报告 dev/prod 两个环境的运行状态 + 内核版本
scripts/setup.sh stop prod      # 停止

funclash dashboard --print      # 打印控制台访问地址
funclash logs -f                # 实时查看日志
funclash config pull <sub-url>  # 拉取订阅并写入配置
funclash uninstall --purge      # 卸载并清除 ~/.funclash
```

`start`/`run`/`stop`/`restart` 必须显式带 `dev` 或 `prod`；只有 `status` 可以省略环境，省略时逐个报告所有环境。`start prod` / `run prod` 只接受**已安装的正式 funclash 包**：`command -v funclash` 的结果会被 `realpath` 还原，落在本仓库目录内（例如 `npm link` 建出来的软链）时直接报错退出，不会悄悄回退到源码。

内核与配置统一存放在 `~/.funclash/`（`bin/`、`config/`、`dashboard/`），直接使用 CLI 时运行文件位于 `~/.funclash/.run/`；通过 `scripts/setup.sh` 启动时，开发和生产环境分别使用仓库下的 `.run/dev/`、`.run/prod/`。`external-ui` 默认指向 `~/.funclash/dashboard`，由 mihomo 直接提供静态文件服务，无需额外起一个 Node HTTP 服务。

PID 文件里记录了进程的可执行文件路径与内核启动时刻，`status`/`stop` 会先核对这两项再动手，因此陈旧或被系统复用的 PID 不会被误判成自己的服务去 kill。

### 控制器 secret

mihomo 只能从它自己的 `config.yaml` 读取 `external-controller` 的 secret，这份凭据无法做到完全不落盘。funclash 的处理方式是：

- 环境变量 `FUNCLASH_SECRET` 优先级最高，高于配置文件里已有的值；没设置时沿用配置文件里那份，仍然没有就随机生成一个 32 位十六进制串。
- `~/.funclash/config/config.yaml` 和 Flutter 客户端的 `~/.funclash/app_settings.json` 都会被收紧为 `0600`，同机其他账号读不到。
- Flutter 客户端在 `FUNCLASH_SECRET` 已设置时**不会**把 secret 写进 `app_settings.json`，这样部署方可以做到凭据完全不落盘。
- 订阅链接常常自带 token/secret 查询参数，日志里只打印脱敏后的 `origin + path`。

Web 控制台目前需要单独提供：
- 本地已有 `app/` 的 Web 构建产物时，用 `funclash install --web-dir ../app/build/web` 指定；
- 或者等本仓库发布 `funclash-web-*.tar.gz` release 资产后自动下载（尚未发布，`install` 命令在拿不到时会给出明确的提示并继续完成内核安装，不会中断整个流程）。

该 CLI 已在本机针对真实的 mihomo 二进制完整验证过 install/start/status/dashboard/logs/stop/uninstall 全流程。

## app —— Flutter 客户端

```bash
cd app
flutter pub get
flutter run -d chrome     # Web
flutter run -d linux      # Linux 桌面（需要系统装好 cmake / ninja / GTK3 开发库）
flutter run -d windows    # Windows 桌面
flutter run -d macos      # macOS 桌面
```

已实现（对齐 FlClash 的 `PageLabel` 页面结构，去掉了 tools/requests/resources 三个次要页面）：
- **Dashboard**：内核版本、连接状态、实时流量
- **Proxies**：代理分组展开、切换节点、测速
- **Profiles**：添加订阅链接，通过 mihomo `PUT /configs`（payload 模式）直接下发配置，无需落盘；支持导入 FlClash 的 `backup.zip` 备份文件
- **Connections**：实时连接列表（`/connections` 轮询、`/traffic` WebSocket 在内核重启等瞬时故障后会自动重试，不会永久卡在错误页——只有首次连接失败才会展示错误）
- **Logs**：内核日志流（`/logs` WebSocket 断开后自动重连，同上，避免内核重启后日志静默停更）
- **Settings**：控制台地址 / secret 配置（保存后写入 `~/.funclash/app_settings.json`，文件权限 `0600`；设置了 `FUNCLASH_SECRET` 时 secret 不落盘，详见[控制器 secret](#控制器-secret)），重启 App 不会再重置回默认值；桌面平台上还可以直接 Start/Stop 内核进程

架构上参考了 FlClash 对内核启动方式按平台拆分的做法：
- Linux/macOS/Windows 桌面：`CoreLauncher` 通过 `Process.start` 把 mihomo 作为子进程拉起（`lib/core/core_launcher/desktop_launcher.dart`），但沟通方式简化为 mihomo 官方文档化的 `external-controller` REST API，而不是复刻 FlClash 内部的 RPC-over-socket 协议——两者对外表现一致，但更简单、可用 `curl` 直接验证。二进制路径通过 `lib/core/funclash_paths.dart` 解析 `~/.funclash`（Windows 下取 `USERPROFILE`，二进制名为 `mihomo.exe`），与 `launcher/src/core/paths.js` 保持一致，因此 `funclash install`（CLI）装好的内核可以直接被 Settings 页的 Start core 拉起，无需额外配置。
- Web（以及尚未实现内核嵌入的 Android/iOS）：`NoopCoreLauncher`，客户端只是连接一个已经在运行的内核（例如由 `launcher` 启动的那个），在 Settings 页填写控制台地址即可。

订阅存储按平台拆分（`app/lib/database/profiles_store.dart` 定义接口，`profiles_store_factory.dart` 用 `dart.library.ffi` 条件导入选择实现）：原生平台用 `profiles_database.dart`，Web 用 `profiles_store_memory.dart` 的内存实现——`package:sqlite3` 走 `dart:ffi`，不能进入 Web 的编译图，因此 Web 端订阅只存在当前会话里、刷新后清空，导入 FlClash 备份会明确报不支持（Web 版的定位是连接一个已在运行的内核）。

原生平台的订阅存储格式刻意与 FlClash 保持一致，以便读取用户已有的 FlClash 备份数据：`app/lib/database/profiles_database.dart` 用 `package:sqlite3` 手写了一个与 FlClash `profiles` 表（`lib/database/profiles.dart`）逐列对齐的 SQLite 表（不依赖 Drift 代码生成，保持独立 MIT 实现），存放在 `~/.funclash/database.sqlite`；订阅 YAML 单独存成 `~/.funclash/profiles/<id>.yaml`，同样对齐 FlClash 的文件布局。Profiles 页新增的“Import FlClash backup”按钮（`app/lib/core/flclash_backup/flclash_backup_importer.dart`）解压一份 FlClash 导出的 `backup.zip`（内部就是 FlClash 自己的 `database.sqlite` + `config.json` + `profiles/*.yaml`，参考其 `lib/common/task.dart` 的 `_backupTask`/`_restoreTask`），通过 `ATTACH DATABASE` 把里面的 `profiles` 表直接合并进本地数据库，再把引用到的 `profiles/*.yaml`（及 `scripts/*.js`）文件复制过来——不解析、不转换字段，因为两边表结构本就一致。当前只覆盖 `profiles` 表，`rules`/`proxy_groups` 等 FlClash 独有的表暂不需要（本项目还没有对应功能）。点击 Apply 时（`ProfilesController.apply`）会先尝试从订阅 URL 拉取最新 YAML 并写回本地缓存文件，拉取失败（无网络，或从旧 FlClash 备份导入的订阅链接已经失效）时回退读取本地已导入/已缓存的那份 YAML，这样导入的历史订阅在链接失效后依然可用，而不是必须每次联网重新拉取才能生效。

**验证状态**：`flutter analyze` 无警告、`flutter test` 全部通过（含 `profiles_database_test.dart` 里构造的一份假 FlClash `backup.zip` 端到端导入验证）、`flutter build web` 编译成功。`app/windows`、`app/macos` 已通过 `flutter create --platforms=windows,macos` 生成官方脚手架（此前只有 `linux`/`android`/`ios`/`web`）。内核启动/停止的 Dart 逻辑在本沙盒（Linux）里用一个假 `mihomo` 可执行文件做了端到端验证：Start 确实 `Process.start` 出子进程、Stop 确实发 `SIGTERM` 并等待退出。但 Windows/macOS 的原生构建（`flutter build windows` / `flutter build macos`）本沙盒没有对应系统，未实际跑通，需要使用者在真机上自行验证一遍 `flutter run -d windows`/`-d macos`。Linux 桌面构建同样因缺少系统级 `cmake`/`ninja` 未能跑 `flutter build linux`。

## 路线图 / 尚未实现

对齐 FlClash 完整能力是一个跨多个阶段的工程，当前只完成了 Phase 0：

- **Phase 0（已完成）**：Flutter 客户端（Web + Linux 桌面可用）+ CLI 内核安装启动。
- **Phase 1（未开始）**：Android —— 需要把 mihomo 编译为 cgo `.so` 并通过 JNI 在进程内加载（对齐 FlClash 的 `android/core/.../Core.kt`），再实现 `VpnService` 建立 TUN 设备接管系统流量。目前 `flutter create` 已生成 `app/android` 目录，但没有任何原生代码，装到 Android 上只能当远程控制台用，不能建立 VPN。
- **Phase 2（未开始，需要用户提供 Apple Developer 账号）**：iOS —— **FlClash 官方本身就没有 iOS 支持**（没有 `ios/` 目录，没有 NetworkExtension 代码），这部分是全新开发，不是移植。需要付费 Apple Developer Program 账号 + 真机才能做 NetworkExtension/PacketTunnelProvider 的调试和授权，无法在自动化环境里完成。

其余未实现：规则编辑器、DNS/脚本配置页、WebDAV 订阅同步等 FlClash 拥有但本项目尚未覆盖的功能（FlClash 备份文件里的 `profiles` 表已可导入，`rules`/`proxy_groups` 等表暂未覆盖）。

## License

MIT，见 [LICENSE](LICENSE)。本项目为参考 FlClash 架构的独立实现，未包含其 GPL-3.0 代码。

---

## 关于 farfarfun

[farfarfun](https://github.com/farfarfun) 是一个专注于实用工具库的开源组织，
涵盖云存储、数据处理、AI、多媒体与开发工具链等方向。

- 🏠 组织主页：<https://github.com/farfarfun>
- 📧 联系：farfarfun@qq.com

本项目基于 [MIT](LICENSE) 协议开源。

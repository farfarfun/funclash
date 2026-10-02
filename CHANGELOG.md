# Changelog

## [未发布]

### 修复

- `flutter build web` 编译失败：`app/lib/database/profiles_database.dart` 直接 `import 'package:sqlite3/sqlite3.dart'`，而 `package:sqlite3` 走 `dart:ffi`，Web 平台没有该库，整条依赖链都编不过（经由 `profiles_page.dart` → `models/profile.dart` → `profiles_database.dart` 进入 Web 的编译图）。现在把订阅存储按平台拆开：`profiles_store.dart` 定义平台无关接口与 `ProfileRow`，`profiles_store_factory.dart` 按 `dart.library.ffi` 条件导入，原生平台仍用 SQLite（`profiles_database.dart`），Web 用内存实现（`profiles_store_memory.dart`，导入 FlClash 备份会明确抛 `UnsupportedError`）。README 里「Web 支持」和「`flutter build web` 编译成功」的说法重新成立。
- `launcher/src/core/process-manager.js`：启动后的进程身份校验失败时（`/proc/<pid>/exe` 与 `~/.funclash/bin/mihomo` 不一致、或读不到进程信息）只抛错不收尾，detached 的后台子进程会变成既没有 PID 文件、`stop`/`status` 也管不到的孤儿。现在统一走 `verifyLaunchedProcess()`：先 SIGKILL 刚启动的进程再抛错。顺带修掉后台模式每次启动漏一个日志文件句柄的问题（原先为同一个日志文件开了两个 fd 且从不关闭）。
- `scripts/setup.sh`：`status` 现在可以省略环境参数，省略时逐个报告 `dev`/`prod`（SPEC §6.1 要求 `status` 非交互且默认覆盖所有已配置环境）；`start`/`run`/`stop`/`restart` 仍然强制要求 `dev`/`prod`，缺失或非法时报错退出。prod 的「必须是已安装正式包」校验下沉到按环境解析 launcher 的函数里，`run prod`、`status prod` 等路径同样生效。
- `launcher/src/config/config-manager.js`：订阅拉取的错误信息与成功日志改为打印脱敏后的 URL（去掉 query 中可能携带的 token/secret），避免凭据出现在终端日志中。
- README 补充组织介绍固定区块，并修正 launcher 快速开始：`npm link` 装出来的软链不满足 `start prod` 的正式包校验，生产路径改用 `npm pack` + `npm install -g <tgz>`。

### 变更

- 控制器 secret 支持 `FUNCLASH_SECRET` 环境变量，优先级高于配置文件（SPEC §9.3）。mihomo 只能从自己的 `config.yaml` 读 secret，无法完全不落盘，因此补了两道加固：
  - `~/.funclash/config/config.yaml`（launcher）和 `~/.funclash/app_settings.json`（Flutter 客户端）写入后都收紧到 `0600`，已存在的宽权限旧文件也会被重新 chmod；
  - Flutter 客户端在 `FUNCLASH_SECRET` 已设置时不再把 secret 写回 `app_settings.json`。
- 服务运行时文件（PID、日志）从 `~/.funclash/run/` 改到 `.run/`：直接用 CLI 时是 `~/.funclash/.run/`，经 `scripts/setup.sh` 启动时是仓库下的 `.run/<env>/`（通过 `FUNCLASH_RUN_DIR` 传递）。
- PID 文件改为记录可验证的进程身份（可执行文件 realpath + 内核启动时刻），`isRunning`/`getStatus`/`stop` 都会先核对身份再动手，避免陈旧或被系统复用的 PID 被当成自己的服务 kill 掉。
- Flutter 客户端公开 API 的 docstring 与注释统一改为中文（SPEC §7）。

### 新增

- 新增 CHANGELOG.md，按规范记录后续变更。
- 新增 Flutter 客户端测试：FlClash `backup.zip` 导入、设置持久化（含 secret 环境变量优先级与文件权限）、Web 内存订阅存储的排序/去重/不支持导入、日志与连接 WebSocket 断线重连、内核启停状态机。
- `app/pubspec.yaml` 的 `description` 从 `flutter create` 的默认占位 `A new Flutter project.` 改为实际说明。
- 新增 launcher 测试：`launcher/test/process-manager.test.js`（进程身份校验、陈旧 PID 文件清理）、`launcher/test/verify-launched-process.test.js`（身份校验失败必须杀掉子进程）、`launcher/test/config-manager.test.js`（secret 优先级与配置文件权限）。
- Flutter 客户端支持导入 FlClash 的 `backup.zip` 备份，并补齐 Windows/macOS 桌面脚手架与内核启停。

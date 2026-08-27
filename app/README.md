# funclash_app

funclash 的 Flutter 客户端（Web / Linux / Windows / macOS 桌面，Android / iOS 为后续阶段）。

完整说明、架构与开发指南见仓库根目录的 [README.md](../README.md)。

## 常用命令

```bash
flutter pub get
flutter analyze
flutter test

flutter run -d chrome      # Web
flutter run -d linux       # Linux 桌面（需要系统安装 cmake / ninja / GTK3 开发库）
flutter run -d windows     # Windows 桌面
flutter run -d macos       # macOS 桌面
flutter build web
```

import 'profiles_store.dart';
// 原生平台走 SQLite；Web 没有 `dart:ffi`，`package:sqlite3` 整条依赖链都编不过，
// 因此退回内存实现。条件导入保证 sqlite3 不会进入 Web 的编译图。
import 'profiles_store_memory.dart' if (dart.library.ffi) 'profiles_database.dart';

export 'profiles_store.dart';

/// 为当前平台打开订阅存储：原生平台落盘到 `<root>/database.sqlite`，Web 存内存。
///
/// [path] 只对原生平台有意义（测试传临时路径）。
ProfilesStore openProfilesStore({String? path}) => createPlatformProfilesStore(path: path);

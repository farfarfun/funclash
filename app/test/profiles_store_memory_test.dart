import 'package:flutter_test/flutter_test.dart';

import 'package:funclash_app/database/profiles_store.dart';
import 'package:funclash_app/database/profiles_store_memory.dart';

/// Web 端用的内存实现：排序规则必须与 SQLite 实现
/// （`ORDER BY "order" IS NULL, "order", id`）一致，否则两个平台的订阅顺序会不一样。
void main() {
  ProfileRow row(int id, {int? order}) =>
      ProfileRow(id: id, label: 'p$id', url: 'https://example.com/$id', order: order);

  test('upsert 按 id 去重，listProfiles 返回最后写入的值', () {
    final store = InMemoryProfilesStore();
    store.upsertProfile(row(1));
    store.upsertProfile(ProfileRow(id: 1, label: 'renamed', url: 'https://example.com/new'));

    expect(store.listProfiles().length, 1);
    expect(store.listProfiles().single.label, 'renamed');
    expect(store.listProfiles().single.url, 'https://example.com/new');
  });

  test('有 order 的排在前面，order 相同按 id，order 为空的排在最后', () {
    final store = InMemoryProfilesStore();
    store.upsertProfile(row(3));
    store.upsertProfile(row(1, order: 5));
    store.upsertProfile(row(2));
    store.upsertProfile(row(4, order: 1));
    store.upsertProfile(row(5, order: 1));

    expect(store.listProfiles().map((r) => r.id).toList(), [4, 5, 1, 2, 3]);
  });

  test('deleteProfile 只删指定 id，close 清空全部', () {
    final store = InMemoryProfilesStore();
    store.upsertProfile(row(1));
    store.upsertProfile(row(2));

    store.deleteProfile(1);
    expect(store.listProfiles().map((r) => r.id).toList(), [2]);

    store.close();
    expect(store.listProfiles(), isEmpty);
  });

  test('Web 端导入 FlClash 备份数据库必须明确报不支持，而不是静默成功', () {
    final store = InMemoryProfilesStore();
    expect(
      () => store.importFromFlClashDatabase('/tmp/database.sqlite'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('createPlatformProfilesStore 在内存实现里忽略 path', () {
    expect(createPlatformProfilesStore(path: '/tmp/ignored.sqlite'), isA<InMemoryProfilesStore>());
  });
}

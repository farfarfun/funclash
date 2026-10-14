/// Nothing to guard: a tab holds no data directory of its own open.
class SingleInstanceLock {
  Future<bool> acquire() async => true;

  Future<void> release() async {}
}

final singleInstanceLock = SingleInstanceLock();

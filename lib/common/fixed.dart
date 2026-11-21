class _RingBuffer<T> {
  final int maxLength;
  final List<T> _slots;
  int _head = 0;

  _RingBuffer(this.maxLength, [List<T>? items]) : _slots = <T>[] {
    if (items != null && items.isNotEmpty) {
      final start = items.length > maxLength ? items.length - maxLength : 0;
      _slots.addAll(items.getRange(start, items.length));
    }
  }

  int get length => _slots.length;

  void add(T item) {
    if (_slots.length < maxLength) {
      _slots.add(item);
      return;
    }
    _slots[_head] = item;
    _head = (_head + 1) % maxLength;
  }

  void addAll(Iterable<T> items) {
    for (final item in items) {
      add(item);
    }
  }

  void clear() {
    _slots.clear();
    _head = 0;
  }

  T operator [](int index) {
    RangeError.checkValidIndex(index, _slots, 'index', _slots.length);
    if (_head == 0) {
      return _slots[index];
    }
    final slot = _head + index;
    return _slots[slot < maxLength ? slot : slot - maxLength];
  }

  List<T> toUnmodifiableList() {
    if (_head == 0) {
      return List<T>.unmodifiable(_slots);
    }
    return List<T>.unmodifiable(<T>[
      ..._slots.getRange(_head, _slots.length),
      ..._slots.getRange(0, _head),
    ]);
  }

  _RingBuffer<T> copy() {
    final clone = _RingBuffer<T>(maxLength);
    if (_head == 0) {
      clone._slots.addAll(_slots);
    } else {
      clone._slots
        ..addAll(_slots.getRange(_head, _slots.length))
        ..addAll(_slots.getRange(0, _head));
    }
    return clone;
  }
}

class FixedList<T> {
  final int maxLength;
  final _RingBuffer<T> _buffer;

  final int _revision;
  List<T>? _snapshot;

  FixedList(this.maxLength, {List<T>? list})
    : assert(maxLength > 0, 'FixedList without a cap grows without bound'),
      _buffer = _RingBuffer<T>(maxLength, list),
      _revision = 0;

  FixedList._(this.maxLength, this._buffer, this._revision);

  int get revision => _revision;

  void add(T item) {
    _buffer.add(item);
    _snapshot = null;
  }

  void addAll(Iterable<T> items) {
    _buffer.addAll(items);
    _snapshot = null;
  }

  void clear() {
    _buffer.clear();
    _snapshot = null;
  }

  FixedList<T> append(T item) {
    add(item);
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  FixedList<T> appendAll(Iterable<T> items) {
    if (items.isEmpty) {
      return this;
    }
    addAll(items);
    return FixedList._(maxLength, _buffer, _revision + 1);
  }

  List<T> get list => _snapshot ??= _buffer.toUnmodifiableList();

  int get length => _buffer.length;

  T operator [](int index) => _buffer[index];

  FixedList<T> copyWith() {
    return FixedList._(maxLength, _buffer.copy(), 0);
  }

  @override
  bool operator ==(Object other) =>
      other is FixedList<T> &&
      identical(other._buffer, _buffer) &&
      other._revision == _revision;

  @override
  int get hashCode => Object.hash(identityHashCode(_buffer), _revision);
}

/// Restores the head that [latest] trimmed off [current] so a paused view
/// stays anchored; the result is capped at [limit] from the tail.
List<T> retainTrimmedHead<T>(List<T> current, List<T> latest, int limit) {
  if (current.isEmpty || latest.isEmpty) {
    return latest;
  }
  final index = current.indexWhere((item) => identical(item, latest.first));
  if (index == 0) {
    return latest;
  }
  final head = index > 0 ? current.sublist(0, index) : current;
  return List.unmodifiable([...head, ...latest].take(limit));
}

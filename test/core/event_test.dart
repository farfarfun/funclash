import 'package:funclash/core/event.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingListener with CoreEventListener {
  _RecordingListener({this.onLoadedCallback, this.onLogCallback});

  final void Function()? onLoadedCallback;
  final void Function(Log log)? onLogCallback;
  final List<String> loaded = [];
  final List<String> dialerLoops = [];
  final List<Log> logs = [];

  @override
  void onLoaded(String providerName) {
    loaded.add(providerName);
    onLoadedCallback?.call();
  }

  @override
  void onLog(Log log) {
    logs.add(log);
    onLogCallback?.call(log);
  }

  @override
  void onDialerLoop(String proxyName) {
    dialerLoops.add(proxyName);
  }
}

void main() {
  test(
    'a listener may unregister itself while an event is dispatched',
    () async {
      late _RecordingListener first;
      final second = _RecordingListener();
      first = _RecordingListener(
        onLoadedCallback: () => coreEventManager.removeListener(first),
      );

      coreEventManager.addListener(first);
      coreEventManager.addListener(second);
      addTearDown(() {
        coreEventManager.removeListener(first);
        coreEventManager.removeListener(second);
      });

      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.loaded, data: 'provider-a'),
      );
      await pumpEventQueue();

      expect(first.loaded, ['provider-a']);
      expect(second.loaded, ['provider-a']);

      coreEventManager.sendEvent(
        const CoreEvent(type: CoreEventType.loaded, data: 'provider-b'),
      );
      await pumpEventQueue();

      expect(first.loaded, ['provider-a']);
      expect(second.loaded, ['provider-a', 'provider-b']);
    },
  );

  test('a dialer loop the core stopped reaches the listeners', () async {
    final listener = _RecordingListener();
    coreEventManager.addListener(listener);
    addTearDown(() => coreEventManager.removeListener(listener));

    coreEventsFromData({
      'type': 'dialerLoop',
      'data': 'Front',
    }).forEach(coreEventManager.sendEvent);
    await pumpEventQueue();

    expect(listener.dialerLoops, ['Front']);
  });

  test(
    'decodes an event once across listeners and isolates listener failures',
    () async {
      final first = _RecordingListener(
        onLogCallback: (_) => throw StateError('boom'),
      );
      final second = _RecordingListener();
      coreEventManager.addListener(first);
      coreEventManager.addListener(second);
      addTearDown(() {
        coreEventManager.removeListener(first);
        coreEventManager.removeListener(second);
      });

      coreEventManager.sendEvent(
        const CoreEvent(
          type: CoreEventType.log,
          data: {'type': 'info', 'payload': 'hello'},
        ),
      );
      await pumpEventQueue();

      expect(first.logs, hasLength(1));
      expect(second.logs, hasLength(1));
      expect(identical(first.logs.single, second.logs.single), isTrue);
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:funclash_app/core/core_launcher/core_launcher.dart';
import 'package:funclash_app/core/funclash_paths.dart';
import 'package:funclash_app/providers/core_provider.dart';

/// A [CoreLauncher] test double whose [start]/[stop] never touch a real
/// process, so tests can deterministically simulate an unexpected exit via
/// [emitUnexpectedExit].
class _FakeCoreLauncher implements CoreLauncher {
  bool _running = false;
  final _exitController = StreamController<int>.broadcast();

  @override
  bool get canLaunch => true;

  @override
  bool get isRunning => _running;

  @override
  Stream<int> get onUnexpectedExit => _exitController.stream;

  @override
  Future<void> start({required String corePath, required String homeDir, required String configFile}) async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  void emitUnexpectedExit(int code) {
    _running = false;
    _exitController.add(code);
  }
}

void main() {
  test('starting the core without an installed binary surfaces an actionable error', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(coreProcessProvider.notifier).start();
    final state = container.read(coreProcessProvider);

    expect(state.status, CoreProcessStatus.error);
    expect(state.errorMessage, contains(FunclashPaths.coreBinary));
    expect(state.errorMessage, contains('funclash install'));
  });

  test('stopping an already-stopped core is a no-op that leaves status stopped', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(coreProcessProvider.notifier).stop();

    expect(container.read(coreProcessProvider).status, CoreProcessStatus.stopped);
  });

  test('an unexpected core exit flips a running status to an error status', () async {
    // CoreProcessNotifier.start() checks for a real binary on disk before
    // delegating to the launcher, regardless of which launcher is injected —
    // stand one up so this test exercises the exit-handling wiring instead
    // of tripping the "no core installed" branch covered by the test above.
    final coreBinary = File(FunclashPaths.coreBinary);
    final alreadyInstalled = coreBinary.existsSync();
    if (!alreadyInstalled) {
      await coreBinary.parent.create(recursive: true);
      await coreBinary.writeAsString('');
      addTearDown(() => coreBinary.delete());
    }

    final fakeLauncher = _FakeCoreLauncher();
    final container = ProviderContainer(
      overrides: [coreLauncherProvider.overrideWithValue(fakeLauncher)],
    );
    addTearDown(container.dispose);

    await container.read(coreProcessProvider.notifier).start();
    expect(container.read(coreProcessProvider).status, CoreProcessStatus.running);

    fakeLauncher.emitUnexpectedExit(7);
    await pumpEventQueue();

    final state = container.read(coreProcessProvider);
    expect(state.status, CoreProcessStatus.error);
    expect(state.errorMessage, contains('exit code 7'));
  });
}

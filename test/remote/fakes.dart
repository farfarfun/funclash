import 'dart:async';

import 'package:funclash/core/desktop/model.dart';
import 'package:funclash/core/interface.dart';
import 'package:funclash/core/method.dart';

typedef CoreAnswer = Object? Function(CoreMethod method, Object? arguments);

final class FakeCore extends CoreHandlerInterface {
  FakeCore({this.answer, this.failure, this.hold = false});

  final CoreAnswer? answer;
  final Object? failure;

  /// Never answers, so a caller can watch what a lost link does to a call
  /// still in flight.
  final bool hold;

  final calls = <CoreMethod>[];

  Object? lastArguments;
  Duration? lastTimeout;

  @override
  Future<T?> invokeMethod<T>({
    required CoreMethod method,
    Object? arguments,
    Duration? timeout,
  }) async {
    calls.add(method);
    lastArguments = arguments;
    lastTimeout = timeout;
    final thrown = failure;
    if (thrown != null) {
      Error.throwWithStackTrace(thrown, StackTrace.current);
    }
    if (hold) {
      await Completer<void>().future;
    }
    return answer?.call(method, arguments) as T?;
  }

  @override
  Future<CoreLifecycleResult> start() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> restart() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> stop() => throw UnimplementedError();

  @override
  Future<CoreLifecycleResult> close() => throw UnimplementedError();
}

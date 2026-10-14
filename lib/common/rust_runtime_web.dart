/// There is no library to load in a tab, so startup has nothing to do and
/// says so; the two readers below answer for themselves instead of waiting
/// on an init that will never happen.
Future<void> initRustRuntime() async {}

bool get isRustRuntimeReady => false;

Future<String> evaluateScriptSource({
  required String script,
  required String config,
}) => throw UnsupportedError('script evaluation belongs to the desktop host');

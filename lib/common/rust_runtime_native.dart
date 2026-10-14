import 'package:rust_api/rust_api.dart';

Future<void> initRustRuntime() => RustLib.init();

bool get isRustRuntimeReady => isRustLibInitialized;

Future<String> evaluateScriptSource({
  required String script,
  required String config,
}) => evaluateScript(script: script, config: config);

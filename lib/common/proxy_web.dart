/// The desktop host pointed the operating system at its own mixed port before
/// this panel connected and is the one that will clear it, so there is nothing
/// here to set — the same null the native half answers with off the desktop.
Future<bool?> startSystemProxy(int port, List<String> bypassDomain) async =>
    null;

Future<bool?> stopSystemProxy() async => null;

import 'dart:typed_data';

typedef PanelFetch =
    Future<Uint8List> Function(
      String url, {
      void Function(int received, int total)? onProgress,
    });

const panelVersionStamp = '.funclash-panel';

String panelArchiveUrl(String version) => '';

// A panel is what gets installed, never what installs one.
bool isPanelInstalled({required String root, required String version}) => false;

Future<void> installPanel({
  required String root,
  required String version,
  required PanelFetch fetch,
  void Function(double fraction)? onProgress,
}) async => throw UnsupportedError('a panel installs no panel');

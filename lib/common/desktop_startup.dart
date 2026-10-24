import 'package:args/args.dart';

class DesktopStartup {
  const DesktopStartup({
    this.headless = false,
    this.acceptDisclaimer = false,
    this.showDisclaimer = false,
    this.panelUrl = false,
    this.panelEnabled,
    this.allowLan,
    this.panelPort,
    this.dataDirectory,
  });

  final bool headless;
  final bool acceptDisclaimer;
  final bool showDisclaimer;
  final bool panelUrl;
  final bool? panelEnabled;
  final bool? allowLan;
  final int? panelPort;
  final String? dataDirectory;

  bool get changesPanel =>
      panelEnabled != null || allowLan != null || panelPort != null;

  factory DesktopStartup.parse(
    List<String> arguments, {
    bool headless = false,
  }) {
    final parser = ArgParser()
      ..addFlag('headless', negatable: false)
      ..addFlag('accept-disclaimer', negatable: false)
      ..addFlag('show-disclaimer', negatable: false)
      ..addFlag('panel-url', negatable: false)
      ..addFlag('panel')
      ..addFlag('allow-lan')
      ..addOption('panel-port')
      ..addOption('data-dir');
    final args = parser.parse(arguments.where((arg) => arg != '--'));
    final port = args['panel-port'] as String?;
    final portNumber = port == null ? null : int.tryParse(port);
    if (port != null &&
        (portNumber == null || portNumber < 1 || portNumber > 65535)) {
      throw const FormatException('--panel-port must be between 1 and 65535');
    }
    final directory = args['data-dir'] as String?;
    if (directory != null && directory.trim().isEmpty) {
      throw const FormatException('--data-dir must not be empty');
    }
    return DesktopStartup(
      headless: headless || args['headless'] as bool,
      acceptDisclaimer: args['accept-disclaimer'] as bool,
      showDisclaimer: args['show-disclaimer'] as bool,
      panelUrl: args['panel-url'] as bool,
      panelEnabled: args.wasParsed('panel') ? args['panel'] as bool : null,
      allowLan: args.wasParsed('allow-lan') ? args['allow-lan'] as bool : null,
      panelPort: portNumber,
      dataDirectory: directory,
    );
  }
}

var desktopStartup = const DesktopStartup();

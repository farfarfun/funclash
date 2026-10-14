import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

import 'print.dart';
import 'protocol.dart';

class Protocol {
  static Protocol? _instance;

  Protocol._internal();

  factory Protocol() {
    _instance ??= Protocol._internal();
    return _instance!;
  }

  void register(String scheme) {
    final plan = ProtocolRegistrationPlan(
      scheme: scheme,
      executable: Platform.resolvedExecutable,
    );
    final regKey = CURRENT_USER.create(plan.protocolKey);
    try {
      regKey.setValue(
        plan.protocolValueName,
        RegistryValue.string(plan.protocolValue),
      );
      final commandKey = regKey.create(plan.commandKey);
      try {
        commandKey.setValue('', RegistryValue.string(plan.command));
      } finally {
        commandKey.close();
      }
    } finally {
      regKey.close();
    }
  }

  Future<void> registerLinux(List<String> schemes) async {
    final env = Platform.environment;
    final home = env['HOME'];
    if (home == null || home.isEmpty) {
      return;
    }
    final dataHome = env['XDG_DATA_HOME'];
    final plan = LinuxProtocolRegistrationPlan(
      schemes: schemes,
      executable: env['APPIMAGE'] ?? Platform.resolvedExecutable,
      applicationsDir:
          '${dataHome?.isNotEmpty == true ? dataHome : '$home/.local/share'}/applications',
    );
    try {
      final file = File(plan.desktopPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(plan.desktopEntry);
      final result = await Process.run('xdg-mime', plan.xdgMimeArguments);
      if (result.exitCode != 0) {
        commonPrint.log('xdg-mime default failed: ${result.stderr}'.trim());
      }
    } catch (e) {
      commonPrint.log('linux protocol registration failed: $e');
    }
  }
}

final protocol = Protocol();

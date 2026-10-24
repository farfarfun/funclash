import 'package:flutter_test/flutter_test.dart';
import 'package:funclash/common/desktop_startup.dart';

void main() {
  test('ordinary launches preserve saved panel settings', () {
    final options = DesktopStartup.parse(['clash://install-config?url=x']);
    expect(options.changesPanel, isFalse);
    expect(options.headless, isFalse);
  });

  test('explicit CLI choices survive the GTK argument separator', () {
    final options = DesktopStartup.parse([
      '--',
      '--headless',
      '--no-panel',
      '--allow-lan',
      '--panel-port',
      '48500',
      '--data-dir',
      '/tmp/data with spaces',
      '--accept-disclaimer',
      '--panel-url',
    ]);
    expect(options.headless, isTrue);
    expect(options.panelEnabled, isFalse);
    expect(options.allowLan, isTrue);
    expect(options.panelPort, 48500);
    expect(options.dataDirectory, '/tmp/data with spaces');
    expect(options.acceptDisclaimer, isTrue);
    expect(options.panelUrl, isTrue);
    expect(DesktopStartup.parse([], headless: true).headless, isTrue);
  });

  test('invalid ports and incomplete options fail before startup', () {
    for (final port in ['0', '-1', '65536', 'not-a-port']) {
      expect(
        () => DesktopStartup.parse(['--panel-port', port]),
        throwsFormatException,
      );
    }
    expect(
      () => DesktopStartup.parse(['--data-dir', ' ']),
      throwsFormatException,
    );
    expect(() => DesktopStartup.parse(['--unknown']), throwsFormatException);
  });
}

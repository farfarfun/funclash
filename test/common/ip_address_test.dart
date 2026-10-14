import 'dart:typed_data';

import 'package:fl_clash/common/ip_address.dart';
import 'package:test/test.dart';

String? hex(Uint8List? bytes) =>
    bytes?.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

Uint8List bytesOf(String value) => Uint8List.fromList([
  for (var index = 0; index < value.length; index += 2)
    int.parse(value.substring(index, index + 2), radix: 16),
]);

void main() {
  test('parses a dotted quad as strictly as inet_pton', () {
    expect(hex(parseIpv4('0.0.0.0')), '00000000');
    expect(hex(parseIpv4('192.168.1.5')), 'c0a80105');
    expect(hex(parseIpv4('255.255.255.255')), 'ffffffff');

    for (final value in [
      '192.168.01.0',
      '192.168.1',
      '192.168.1.5.6',
      '192.168.1.256',
      '192.168.1.',
      '.1.2.3',
      '192.168.1.0x5',
      '192.168.1.+5',
      ' 192.168.1.5',
      '192.168.1.5 ',
      '::ffff:1.2.3.4',
    ]) {
      expect(parseIpv4(value), isNull, reason: value);
    }
  });

  test('parses every IPv6 form the core accepts', () {
    expect(hex(parseIpv6('::')), '00000000000000000000000000000000');
    expect(hex(parseIpv6('::1')), '00000000000000000000000000000001');
    expect(hex(parseIpv6('fd00::')), 'fd000000000000000000000000000000');
    expect(hex(parseIpv6('FD00::')), 'fd000000000000000000000000000000');
    expect(hex(parseIpv6('fc00::')), 'fc000000000000000000000000000000');
    expect(hex(parseIpv6('ff00::')), 'ff000000000000000000000000000000');
    expect(
      hex(parseIpv6('::ffff:1.2.3.4')),
      '00000000000000000000ffff01020304',
    );
    expect(hex(parseIpv6('::ffff:0:0')), '00000000000000000000ffff00000000');
    expect(
      hex(parseIpv6('1:2:3:4:5:6:7:8')),
      '00010002000300040005000600070008',
    );
    expect(
      hex(parseIpv6('1:2:3:4:5:6:1.2.3.4')),
      '00010002000300040005000601020304',
    );
    expect(
      hex(parseIpv6('2001:db8::8a2e:370:7334')),
      '20010db80000000000008a2e03707334',
    );
  });

  test('rejects every IPv6 form the core refuses', () {
    for (final value in [
      '',
      ':',
      ':::',
      ':1',
      '1:',
      '1:2:3:4:5:6:7',
      '1:2:3:4:5:6:7:8:9',
      '1::2::3',
      '::1:2:3:4:5:6:7:8',
      '1:2:3:4:5:6:7:1.2.3.4',
      '12345::',
      '1.2.3.4',
      '::ffff:1.2.3',
      '::ffff:1.2.3.256',
      '0x1::',
      '1::g',
      '8:cc:: c3',
      ' fd00::',
      'fd00:: ',
      'fd00::\n',
    ]) {
      expect(parseIpv6(value), isNull, reason: value);
    }
  });

  test('takes a zone only when asked, and drops it', () {
    expect(parseIpv6('fe80::1%eth0'), isNull);
    expect(parseIpv6('%eth0', allowZone: true), isNull);

    expect(
      hex(parseIpv6('fe80::1%eth0', allowZone: true)),
      hex(parseIpv6('fe80::1')),
    );
    expect(
      hex(parseIpv6('fe80::1%', allowZone: true)),
      hex(parseIpv6('fe80::1')),
    );
  });

  test('tells the two families apart', () {
    expect(parseIpAddress('192.168.1.5')?.length, 4);
    expect(parseIpAddress('::ffff:192.168.1.5')?.length, 16);
    expect(parseIpAddress('fd00::')?.length, 16);
    expect(parseIpAddress('nope'), isNull);
  });

  test('formats the canonical RFC 5952 text', () {
    expect(formatIpv6(bytesOf('00000000000000000000000000000000')), '::');
    expect(formatIpv6(bytesOf('00000000000000000000000000000001')), '::1');
    expect(formatIpv6(bytesOf('00010000000000000000000000000008')), '1::8');
    expect(formatIpv6(bytesOf('fe800000000000000000000000000000')), 'fe80::');
    expect(
      formatIpv6(bytesOf('00010002000300040005000600070008')),
      '1:2:3:4:5:6:7:8',
    );
    expect(
      formatIpv6(bytesOf('00000001000200030004000500060007')),
      '0:1:2:3:4:5:6:7',
      reason: 'RFC 5952 4.2.2 leaves a lone zero group uncompressed',
    );
    expect(
      formatIpv6(bytesOf('00010000000000020000000000030004')),
      '1::2:0:0:3:4',
      reason: 'RFC 5952 4.2.3 takes the leftmost of two equal runs',
    );
    expect(
      formatIpv6(bytesOf('00010000000200000000000000030004')),
      '1:0:2::3:4',
    );
    expect(formatIpv6(bytesOf('00000000000100000000000000000000')), '0:0:1::');
  });

  test('keeps the IPv4-mapped ranges in hexadecimal', () {
    expect(
      formatIpv6(bytesOf('00000000000000000000ffff01020304')),
      '::ffff:102:304',
      reason:
          'inet_ntop would write `::ffff:1.2.3.4` here, and `InternetAddress.'
          'fromRawAddress().address` called into it, so this is the one place '
          'the text changed when that dependency went away. Both forms parse '
          'back to the same bytes and the core takes either. The divergence is '
          'confined to `::/96` and `::ffff:0:0/96`, which is why every address '
          'FlClash actually formats — the `privateRouteAddress` blocks and the '
          'complement `subtractCidrs` builds from them — is byte for byte what '
          'it was; see test/common/cidr_test.dart. The gain is text that no '
          'longer varies with the host libc.',
    );
    expect(
      formatIpv6(bytesOf('00000000000000000000ffff00000000')),
      '::ffff:0:0',
    );
    expect(
      formatIpv6(bytesOf('00000000000000000000000001020304')),
      '::102:304',
    );
  });

  test('round-trips every address it formats', () {
    for (final value in [
      '::',
      '::1',
      'fc00::',
      'fe80::',
      'ff00::',
      '2001:db8::8a2e:370:7334',
      '1:2:3:4:5:6:7:8',
      '1::2:0:0:3:4',
      '0:1:2:3:4:5:6:7',
      '::ffff:102:304',
    ]) {
      final bytes = parseIpv6(value);
      expect(bytes, isNotNull, reason: value);
      expect(formatIpv6(bytes!), value);
      expect(hex(parseIpv6(formatIpv6(bytes))), hex(bytes));
    }
  });
}

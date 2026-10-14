import 'dart:typed_data';

final _octet = RegExp(r'^(0|[1-9][0-9]{0,2})$');

final _group = RegExp(r'^[0-9a-fA-F]{1,4}$');

/// The four bytes of a dotted quad, or null. As strict as inet_pton.
Uint8List? parseIpv4(String value) {
  final octets = value.split('.');
  if (octets.length != 4) {
    return null;
  }
  final bytes = Uint8List(4);
  for (var index = 0; index < 4; index++) {
    final octet = octets[index];
    if (!_octet.hasMatch(octet)) {
      return null;
    }
    final byte = int.parse(octet);
    if (byte > 255) {
      return null;
    }
    bytes[index] = byte;
  }
  return bytes;
}

/// The sixteen bytes of an IPv6 address, or null. [allowZone] drops a trailing
/// `%interface` the way `InternetAddress.tryParse` does; without it a zone is
/// rejected, as Go's netip.ParsePrefix rejects one in a CIDR.
Uint8List? parseIpv6(String value, {bool allowZone = false}) {
  var address = value;
  if (allowZone) {
    final percent = address.indexOf('%');
    if (percent > 0) {
      address = address.substring(0, percent);
    }
  }
  if (address.contains('%')) {
    return null;
  }
  final gap = address.indexOf('::');
  if (gap != address.lastIndexOf('::')) {
    return null;
  }
  if (gap < 0) {
    final whole = _groups(address);
    if (whole == null || whole.length != 16) {
      return null;
    }
    return Uint8List.fromList(whole);
  }
  final head = _groups(address.substring(0, gap));
  final tail = _groups(address.substring(gap + 2));
  if (head == null || tail == null || head.length + tail.length > 14) {
    return null;
  }
  return Uint8List.fromList([
    ...head,
    ...List.filled(16 - head.length - tail.length, 0),
    ...tail,
  ]);
}

Uint8List? parseIpAddress(String value) {
  return parseIpv4(value) ?? parseIpv6(value);
}

/// The canonical RFC 5952 form, which unlike inet_ntop keeps the `::/96` and
/// `::ffff:0:0/96` ranges in hexadecimal instead of appending a dotted quad.
String formatIpv6(List<int> bytes) {
  final groups = [
    for (var index = 0; index + 1 < bytes.length; index += 2)
      (bytes[index] << 8) | bytes[index + 1],
  ];
  var start = -1;
  var length = 1;
  for (var index = 0; index < groups.length; index++) {
    if (groups[index] != 0) {
      continue;
    }
    var end = index;
    while (end < groups.length && groups[end] == 0) {
      end++;
    }
    if (end - index > length) {
      start = index;
      length = end - index;
    }
    index = end;
  }
  if (start < 0) {
    return _hex(groups);
  }
  return '${_hex(groups.take(start))}::${_hex(groups.skip(start + length))}';
}

String _hex(Iterable<int> groups) =>
    groups.map((group) => group.toRadixString(16)).join(':');

List<int>? _groups(String value) {
  if (value.isEmpty) {
    return const [];
  }
  final items = value.split(':');
  var count = items.length;
  Uint8List? embedded;
  if (items.last.contains('.')) {
    embedded = parseIpv4(items.last);
    if (embedded == null) {
      return null;
    }
    count--;
  }
  final bytes = <int>[];
  for (var index = 0; index < count; index++) {
    final group = items[index];
    if (!_group.hasMatch(group)) {
      return null;
    }
    final word = int.parse(group, radix: 16);
    bytes
      ..add(word >> 8)
      ..add(word & 0xFF);
  }
  return [...bytes, ...?embedded];
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

class Request {
  late final Dio dio;
  late final Dio _clashDio;
  String? userAgent;

  ProviderReader? _read;

  void attach(ProviderReader read) {
    _read = read;
  }

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    final adapter = proxiedHttpClientAdapter(
      reader: () => _read,
      userAgent: () => globalState.ua,
    );
    if (adapter != null) {
      _clashDio.httpClientAdapter = adapter;
    }
  }

  Future<Response<T>> _download<T>(String url, ResponseType responseType) {
    final target = downloadTarget(url);
    final cancelToken = CancelToken();
    return _clashDio
        .getUri<T>(
          target.uri,
          options: Options(responseType: responseType, headers: target.headers),
          cancelToken: cancelToken,
        )
        .timeout(
          downloadTimeoutDuration,
          onTimeout: () {
            cancelToken.cancel();
            throw DioException.receiveTimeout(
              timeout: downloadTimeoutDuration,
              requestOptions: RequestOptions(path: url),
            );
          },
        );
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _download<Uint8List>(url, ResponseType.bytes);
    } catch (e) {
      commonPrint.log(
        'getFileResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    try {
      return await _download<String>(url, ResponseType.plain);
    } catch (e) {
      commonPrint.log(
        'getTextResponseForUrl error ${compactError(e)}',
        logLevel: LogLevel.warning,
      );
      rethrow;
    }
  }

  /// Null when this build is current; throws when GitHub cannot be asked.
  Future<Map<String, dynamic>?> checkForUpdate() async {
    final release = await latestRelease();
    final remoteVersion = release['tag_name'] as String;
    final version = globalState.packageInfo.version;
    final hasUpdate =
        compareVersions(remoteVersion.replaceAll('v', ''), version) > 0;
    return hasUpdate ? release : null;
  }

  /// The release page redirect still answers once the hourly API quota is spent.
  @visibleForTesting
  Future<Map<String, dynamic>> latestRelease() async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://api.github.com/repos/$repository/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      return response.data!;
    } on DioException catch (error) {
      commonPrint.log(
        'latest release API failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
    }
    final response = await dio.get<void>(
      'https://github.com/$repository/releases/latest',
      options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final location = response.headers.value('location');
    final segments = Uri.tryParse(location ?? '')?.pathSegments ?? const [];
    final tagIndex = segments.indexOf('tag') + 1;
    if (tagIndex == 0 || tagIndex >= segments.length) {
      throw FormatException('No release tag in the redirect', location);
    }
    return {'tag_name': segments[tagIndex]};
  }
}

final request = Request();

/// Some subscription servers send a gzip or zlib body without saying so in
/// Content-Encoding, which is the only signal an HTTP client decompresses on.
Uint8List decompressUnlabeled(Uint8List bytes) {
  final inflate = switch (bytes) {
    [0x1f, 0x8b, ...] => () => const GZipDecoder().decodeBytes(bytes),
    [0x78, final flags, ...] when (0x78 << 8 | flags) % 31 == 0 =>
      () => const ZLibDecoder().decodeBytes(bytes),
    _ => null,
  };
  if (inflate == null) {
    return bytes;
  }
  try {
    return inflate();
  } on FormatException {
    return bytes;
  }
}

/// dart:io turns [Uri.userInfo] into Basic credentials still percent-encoded.
@visibleForTesting
({Uri uri, Map<String, Object> headers}) downloadTarget(String url) {
  final uri = url.webUri ?? Uri.parse(url);
  if (uri.userInfo.isEmpty) {
    return (uri: uri, headers: const {});
  }
  final credentials = uri.userInfo.split(':').map(_decodeUserInfo).join(':');
  return (
    uri: uri.replace(userInfo: ''),
    headers: {
      'authorization': 'Basic ${base64.encode(utf8.encode(credentials))}',
    },
  );
}

String _decodeUserInfo(String value) {
  try {
    return Uri.decodeComponent(value);
  } on ArgumentError {
    return value;
  }
}

String? getFileNameForDisposition(String? disposition) {
  if (disposition == null) return null;
  final parameters = _headerParameters(disposition);
  final encoded = parameters['filename*']?.split("''") ?? const [];
  if (encoded.length >= 2) {
    return Uri.decodeComponent(encoded[1]);
  }
  return parameters['filename'];
}

/// `HeaderValue.parse` without dart:io: a quoted value may hold the separator.
Map<String, String> _headerParameters(String header) {
  final parameters = <String, String>{};
  for (final part in _splitUnquoted(header, ';').skip(1)) {
    final separator = part.indexOf('=');
    if (separator < 0) {
      continue;
    }
    final name = part.substring(0, separator).trim().toLowerCase();
    parameters[name] = _unquote(part.substring(separator + 1).trim());
  }
  return parameters;
}

List<String> _splitUnquoted(String value, String separator) {
  final parts = <String>[];
  var start = 0;
  var quoted = false;
  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char == '"') {
      quoted = !quoted;
    } else if (quoted && char == r'\') {
      index++;
    } else if (!quoted && char == separator) {
      parts.add(value.substring(start, index));
      start = index + 1;
    }
  }
  parts.add(value.substring(start));
  return parts;
}

String _unquote(String value) {
  if (value.length < 2 || !value.startsWith('"') || !value.endsWith('"')) {
    return value;
  }
  final body = value.substring(1, value.length - 1);
  final unescaped = StringBuffer();
  for (var index = 0; index < body.length; index++) {
    if (body[index] == r'\' && index + 1 < body.length) {
      index++;
    }
    unescaped.write(body[index]);
  }
  return unescaped.toString();
}

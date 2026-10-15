import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:funclash/common/common.dart';
import 'package:funclash/enum/enum.dart';
import 'package:funclash/models/models.dart';
import 'package:funclash/providers/config.dart';
import 'package:funclash/providers/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void attachHttpOverrides(ProviderContainer container) {
  HttpOverrides.global = FlClashHttpOverrides(container);
}

class FlClashHttpOverrides extends HttpOverrides {
  final ProviderContainer _container;

  FlClashHttpOverrides(this._container);

  static String findProxyFor(ProviderContainer container, Uri url) {
    return findProxyForReader(container.read, url);
  }

  static String findProxyForReader(ProviderReader read, Uri url) {
    if ([localhost].contains(url.host)) {
      return 'DIRECT';
    }
    final isStart = read(isStartProvider);
    final suspend = read(suspendProvider);
    if (!isStart || suspend) return 'DIRECT';
    final mixedPort = read(
      patchClashConfigProvider.select((state) => state.mixedPort),
    );
    final authentication = read(
      networkSettingProvider.select((state) => state.authentication),
    );
    final credentials = authentication.credentials;
    final userInfo = credentials.isNotEmpty ? '${credentials.first}@' : '';
    return 'PROXY ${userInfo}localhost:$mixedPort';
  }

  static bool allowBadCertificate(
    ProviderContainer container,
    X509Certificate certificate,
    String host,
    int port,
  ) {
    return allowBadCertificateForReader(
      container.read,
      certificate,
      host,
      port,
    );
  }

  static bool allowBadCertificateForReader(
    ProviderReader read,
    X509Certificate certificate,
    String host,
    int port,
  ) {
    final checkCertificate = read(
      appSettingProvider.select((state) => state.checkCertificate),
    );
    commonPrint.log(
      'untrusted certificate for $host:$port issued by ${certificate.issuer}, '
      'check: $checkCertificate',
      logLevel: LogLevel.warning,
    );
    return !checkCertificate;
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (certificate, host, port) =>
        allowBadCertificate(_container, certificate, host, port);
    client.findProxy = (url) => findProxyFor(_container, url);
    return client;
  }
}

/// Dio builds its own client instead of going through [HttpOverrides], so the
/// same proxy answer is named again for it.
HttpClientAdapter? proxiedHttpClientAdapter({
  required ProviderReader? Function() reader,
  required String Function() userAgent,
}) {
  return IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient();
      client.findProxy = (Uri uri) {
        client.userAgent = userAgent();
        final read = reader();
        if (read == null) {
          return 'DIRECT';
        }
        return FlClashHttpOverrides.findProxyForReader(read, uri);
      };
      return client;
    },
  );
}

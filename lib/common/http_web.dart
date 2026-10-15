import 'package:dio/dio.dart';
import 'package:funclash/common/provider_reader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tab reaches the network only through the browser, which takes no override
/// and no proxy of ours; Dio's own browser adapter is already the way out.
void attachHttpOverrides(ProviderContainer container) {}

HttpClientAdapter? proxiedHttpClientAdapter({
  required ProviderReader? Function() reader,
  required String Function() userAgent,
}) => null;

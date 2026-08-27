import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/traffic.dart';
import 'core_provider.dart';

final trafficProvider = StreamProvider.autoDispose<Traffic>((ref) {
  final client = ref.watch(mihomoApiClientProvider);
  return client.watchTraffic();
});

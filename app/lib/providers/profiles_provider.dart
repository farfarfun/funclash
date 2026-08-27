import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/mihomo_api_client.dart';
import '../models/profile.dart';
import 'core_provider.dart';

/// Subscription profiles the user has added. Kept in memory for Phase 0 —
/// persisting them to disk is a small follow-up, not core to proving the
/// apply-a-subscription flow works.
class ProfilesController extends Notifier<List<Profile>> {
  @override
  List<Profile> build() => const [];

  void add(Profile profile) {
    state = [...state, profile];
  }

  void remove(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  /// Fetches the profile's subscription YAML and pushes it to the running
  /// core via `PUT /configs` payload mode.
  Future<void> apply(String id) async {
    final profile = state.firstWhere((p) => p.id == id);
    final response = await http.get(Uri.parse(profile.url));
    if (response.statusCode != 200) {
      throw MihomoApiException('Failed to fetch profile YAML', statusCode: response.statusCode);
    }
    final client = ref.read(mihomoApiClientProvider);
    await client.applyConfigPayload(response.body);
    state = [
      for (final p in state)
        if (p.id == id) p.copyWith(lastAppliedAt: DateTime.now()) else p,
    ];
  }
}

final profilesProvider = NotifierProvider<ProfilesController, List<Profile>>(ProfilesController.new);

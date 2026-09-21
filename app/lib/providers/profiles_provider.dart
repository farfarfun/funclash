import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/flclash_backup/flclash_backup_importer.dart';
import '../core/funclash_paths.dart';
import '../core/mihomo_api_client.dart';
import '../database/profiles_database.dart';
import '../models/profile.dart';
import 'core_provider.dart';

/// Subscription profiles the user has added, persisted in a SQLite database
/// (see [ProfilesDatabase]) whose schema matches FlClash's `profiles` table
/// so a FlClash `backup.zip` can be imported directly via
/// [importFlClashBackupZip].
class ProfilesController extends Notifier<List<Profile>> {
  late final ProfilesDatabase _db;

  @override
  List<Profile> build() {
    _db = ProfilesDatabase.open();
    ref.onDispose(_db.close);
    return _load();
  }

  List<Profile> _load() => _db.listProfiles().map(Profile.fromRow).toList();

  void add(Profile profile) {
    _db.upsertProfile(profile.toRow());
    state = _load();
  }

  void remove(int id) {
    _db.deleteProfile(id);
    state = _load();
  }

  /// Imports a FlClash `backup.zip`, merging its profiles into this
  /// database and reloading [state] from disk.
  Future<FlClashImportResult> importFlClashBackup(String zipFilePath) async {
    final result = await importFlClashBackupZip(zipFilePath, db: _db);
    state = _load();
    return result;
  }

  /// Fetches the profile's subscription YAML and pushes it to the running
  /// core via `PUT /configs` payload mode.
  ///
  /// A successful fetch is cached to `<root>/profiles/<id>.yaml` (the same
  /// path FlClash itself uses, and the one a FlClash backup import already
  /// populates — see [importFlClashBackup]). If the network fetch fails —
  /// no connectivity, or a subscription URL imported from an old FlClash
  /// backup that's since gone stale — that local copy is used instead, so
  /// an imported profile stays usable even when its original URL isn't.
  Future<void> apply(int id) async {
    final profile = state.firstWhere((p) => p.id == id);
    final localFile = File(FunclashPaths.profileFile(id));

    String? yaml;
    try {
      final response = await http.get(Uri.parse(profile.url));
      if (response.statusCode == 200) {
        yaml = response.body;
        await localFile.parent.create(recursive: true);
        await localFile.writeAsString(yaml);
      }
    } catch (_) {
      // Network/URL failure — fall back to a local copy below, if any.
    }
    if (yaml == null && await localFile.exists()) {
      yaml = await localFile.readAsString();
    }
    if (yaml == null) {
      throw MihomoApiException('Failed to fetch profile YAML and no local copy is available');
    }

    final client = ref.read(mihomoApiClientProvider);
    await client.applyConfigPayload(yaml);
    final updated = profile.copyWith(lastAppliedAt: DateTime.now());
    _db.upsertProfile(updated.toRow());
    state = _load();
  }
}

final profilesProvider = NotifierProvider<ProfilesController, List<Profile>>(ProfilesController.new);

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../providers/profiles_provider.dart';

class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final controller = ref.read(profilesProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profiles', style: Theme.of(context).textTheme.headlineSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import FlClash backup'),
                    onPressed: () => _importFlClashBackup(context, controller),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    onPressed: () => _showAddProfileDialog(context, controller),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: profiles.isEmpty
                ? const Center(child: Text('No profiles yet. Add a subscription URL to get started.'))
                : ListView.builder(
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      return Card(
                        child: ListTile(
                          title: Text(profile.name),
                          subtitle: Text(
                            profile.lastAppliedAt != null
                                ? '${profile.url}\nLast applied: ${profile.lastAppliedAt}'
                                : profile.url,
                          ),
                          isThreeLine: profile.lastAppliedAt != null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: 'Apply',
                                onPressed: () => _apply(context, controller, profile.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove',
                                onPressed: () => controller.remove(profile.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(BuildContext context, ProfilesController controller, int id) async {
    try {
      await controller.apply(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile applied.')));
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply profile: $err')));
      }
    }
  }

  Future<void> _importFlClashBackup(BuildContext context, ProfilesController controller) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'Select a FlClash backup.zip',
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      final importResult = await controller.importFlClashBackup(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${importResult.count} profile(s) from FlClash backup.')),
        );
      }
    } catch (err) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import backup: $err')));
      }
    }
  }

  Future<void> _showAddProfileDialog(BuildContext context, ProfilesController controller) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Subscription URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && urlController.text.trim().isNotEmpty) {
      controller.add(Profile(
        id: DateTime.now().microsecondsSinceEpoch,
        name: nameController.text.trim().isEmpty ? urlController.text.trim() : nameController.text.trim(),
        url: urlController.text.trim(),
      ));
    }
  }
}

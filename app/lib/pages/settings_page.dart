import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _secretController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(coreSettingsProvider);
    _hostController = TextEditingController(text: settings.host);
    _portController = TextEditingController(text: settings.port.toString());
    _secretController = TextEditingController(text: settings.secret);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final launcher = ref.watch(coreLauncherProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            launcher.canLaunch
                ? 'This platform can launch a mihomo core process directly (desktop).'
                : 'This platform connects to a core running elsewhere — start one with '
                    'the funclash CLI launcher, then point this app at its controller below.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _hostController,
              decoration: const InputDecoration(labelText: 'Controller host'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Controller port'),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _secretController,
              decoration: const InputDecoration(labelText: 'Secret'),
              obscureText: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(coreSettingsProvider.notifier).update(
                    host: _hostController.text.trim(),
                    port: int.tryParse(_portController.text.trim()),
                    secret: _secretController.text,
                  );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

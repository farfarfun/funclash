import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/funclash_paths.dart';
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
    final processState = ref.watch(coreProcessProvider);

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
          if (launcher.canLaunch) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Core process', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      FunclashPaths.coreBinary,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: processState.status == CoreProcessStatus.starting
                              ? null
                              : () => ref.read(coreProcessProvider.notifier).start(),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start core'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: processState.status == CoreProcessStatus.running
                              ? () => ref.read(coreProcessProvider.notifier).stop()
                              : null,
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop core'),
                        ),
                        const SizedBox(width: 12),
                        _CoreProcessStatusLabel(status: processState.status),
                      ],
                    ),
                    if (processState.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        processState.errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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

class _CoreProcessStatusLabel extends StatelessWidget {
  final CoreProcessStatus status;

  const _CoreProcessStatusLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (status) {
      CoreProcessStatus.stopped => (Icons.circle_outlined, Colors.grey, 'Stopped'),
      CoreProcessStatus.starting => (Icons.hourglass_top, Colors.orange, 'Starting…'),
      CoreProcessStatus.running => (Icons.check_circle, Colors.green, 'Running'),
      CoreProcessStatus.error => (Icons.error, Colors.red, 'Error'),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

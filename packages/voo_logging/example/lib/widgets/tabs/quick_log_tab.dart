import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import '../components/section_title.dart';
import '../components/log_button.dart';
import '../components/code_example.dart';

class QuickLogTab extends StatelessWidget {
  final bool toastEnabled;
  final VoidCallback onLogWithMetadata;
  final VoidCallback onLogMultiple;

  const QuickLogTab({
    super.key,
    required this.toastEnabled,
    required this.onLogWithMetadata,
    required this.onLogMultiple,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Log Levels'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              LogButton(
                label: 'Verbose',
                color: Colors.grey,
                onPressed: () => VooLogger.verbose('Verbose trace message'),
              ),
              LogButton(
                label: 'Debug',
                color: Colors.blueGrey,
                onPressed: () => VooLogger.debug('Debug information'),
              ),
              LogButton(
                label: 'Info',
                color: Colors.blue,
                onPressed: () => VooLogger.info('Info message', shouldNotify: toastEnabled),
              ),
              LogButton(
                label: 'Warning',
                color: Colors.orange,
                onPressed: () => VooLogger.warning('Warning alert', shouldNotify: toastEnabled),
              ),
              LogButton(
                label: 'Error',
                color: Colors.red,
                onPressed: () => VooLogger.error(
                  'Error occurred',
                  error: Exception('Sample error'),
                  shouldNotify: toastEnabled,
                ),
              ),
              LogButton(
                label: 'Fatal',
                color: Colors.red.shade900,
                onPressed: () => VooLogger.fatal(
                  'Fatal crash!',
                  error: Exception('Critical failure'),
                  shouldNotify: toastEnabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Quick Actions'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onLogWithMetadata,
                icon: const Icon(Icons.data_object, size: 18),
                label: const Text('Log with Metadata'),
              ),
              FilledButton.tonalIcon(
                onPressed: onLogMultiple,
                icon: const Icon(Icons.burst_mode, size: 18),
                label: const Text('Log 10 Messages'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const CodeExample(
            title: 'Zero-Config Usage',
            code: '''// Just use it - auto-initializes!
VooLogger.info('Hello world');

// With metadata
VooLogger.info('User action',
  category: 'Analytics',
  tag: 'button_click',
  metadata: {'screen': 'home'},
);''',
          ),
        ],
      ),
    );
  }
}

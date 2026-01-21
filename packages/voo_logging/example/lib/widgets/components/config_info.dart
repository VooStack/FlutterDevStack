import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import 'config_row.dart';

class ConfigInfo extends StatelessWidget {
  const ConfigInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final config = VooLogger.config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConfigRow(label: 'Min Level', value: config.minimumLevel.name),
            ConfigRow(label: 'Pretty Logs', value: config.enablePrettyLogs.toString()),
            ConfigRow(label: 'Max Logs', value: config.maxLogs?.toString() ?? 'Unlimited'),
            ConfigRow(label: 'Retention Days', value: config.retentionDays?.toString() ?? 'Forever'),
            ConfigRow(label: 'Auto Cleanup', value: config.autoCleanup.toString()),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import '../components/section_title.dart';
import '../components/stat_card.dart';
import '../components/stat_chip.dart';
import '../components/config_info.dart';

class StatsTab extends StatelessWidget {
  final LogStatistics? stats;

  const StatsTab({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Log Statistics'),
          const SizedBox(height: 8),
          if (stats != null) ...[
            StatCard(
              title: 'Total Logs',
              value: stats!.totalLogs.toString(),
              icon: Icons.list_alt,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            const SectionTitle(title: 'By Level'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: stats!.levelCounts.entries.map((e) {
                return StatChip(
                  label: e.key,
                  count: e.value,
                  color: _getLevelColor(e.key),
                );
              }).toList(),
            ),
            if (stats!.categoryCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionTitle(title: 'By Category'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats!.categoryCounts.entries.map((e) {
                  return StatChip(
                    label: e.key,
                    count: e.value,
                    color: Colors.indigo,
                  );
                }).toList(),
              ),
            ],
          ] else
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Configuration'),
          const SizedBox(height: 8),
          const ConfigInfo(),
        ],
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'verbose':
        return Colors.grey;
      case 'debug':
        return Colors.blueGrey;
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'fatal':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
}

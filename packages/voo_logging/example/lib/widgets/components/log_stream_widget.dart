import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import 'log_entry_widget.dart';

class LogStreamWidget extends StatelessWidget {
  final List<LogEntry> logs;

  const LogStreamWidget({
    super.key,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(Icons.terminal, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Log Stream',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${logs.length} logs',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No logs yet',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      return LogEntryWidget(log: logs[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';

class LogEntryWidget extends StatelessWidget {
  final LogEntry log;

  const LogEntryWidget({
    super.key,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getLevelColor(log.level.name);
    final time =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:'
        '${log.timestamp.minute.toString().padLeft(2, '0')}:'
        '${log.timestamp.second.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.level.name.toUpperCase().substring(0, 3),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (log.category != null) ...[
            Text(
              '[${log.category}]',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              log.message,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

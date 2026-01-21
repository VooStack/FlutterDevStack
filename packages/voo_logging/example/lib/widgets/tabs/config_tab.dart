import 'package:flutter/material.dart';
import 'package:voo_logging/voo_logging.dart';
import '../components/section_title.dart';
import '../components/preset_button.dart';
import '../components/toggle_option.dart';
import '../components/code_example.dart';

class ConfigTab extends StatelessWidget {
  final String selectedPreset;
  final bool enablePrettyLogs;
  final bool showEmojis;
  final bool showTimestamp;
  final bool showBorders;
  final bool showMetadata;
  final LogLevel minimumLevel;
  final ValueChanged<String> onPresetSelected;
  final ValueChanged<bool> onPrettyLogsChanged;
  final ValueChanged<bool> onShowEmojisChanged;
  final ValueChanged<bool> onShowTimestampChanged;
  final ValueChanged<bool> onShowBordersChanged;
  final ValueChanged<bool> onShowMetadataChanged;
  final ValueChanged<LogLevel> onMinimumLevelChanged;
  final VoidCallback onLogAllLevels;

  const ConfigTab({
    super.key,
    required this.selectedPreset,
    required this.enablePrettyLogs,
    required this.showEmojis,
    required this.showTimestamp,
    required this.showBorders,
    required this.showMetadata,
    required this.minimumLevel,
    required this.onPresetSelected,
    required this.onPrettyLogsChanged,
    required this.onShowEmojisChanged,
    required this.onShowTimestampChanged,
    required this.onShowBordersChanged,
    required this.onShowMetadataChanged,
    required this.onMinimumLevelChanged,
    required this.onLogAllLevels,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle(title: 'Configuration Presets'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PresetButton(
                label: 'Default',
                preset: 'default',
                color: Colors.blue,
                isSelected: selectedPreset == 'default',
                onSelected: onPresetSelected,
              ),
              PresetButton(
                label: 'Development',
                preset: 'development',
                color: Colors.green,
                isSelected: selectedPreset == 'development',
                onSelected: onPresetSelected,
              ),
              PresetButton(
                label: 'Production',
                preset: 'production',
                color: Colors.orange,
                isSelected: selectedPreset == 'production',
                onSelected: onPresetSelected,
              ),
              PresetButton(
                label: 'Minimal',
                preset: 'minimal',
                color: Colors.grey,
                isSelected: selectedPreset == 'minimal',
                onSelected: onPresetSelected,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Format Options'),
          const SizedBox(height: 8),
          ToggleOption(
            label: 'Pretty Logs',
            value: enablePrettyLogs,
            onChanged: onPrettyLogsChanged,
          ),
          ToggleOption(
            label: 'Show Emojis',
            value: showEmojis,
            onChanged: onShowEmojisChanged,
          ),
          ToggleOption(
            label: 'Show Timestamp',
            value: showTimestamp,
            onChanged: onShowTimestampChanged,
          ),
          ToggleOption(
            label: 'Show Borders',
            value: showBorders,
            onChanged: onShowBordersChanged,
          ),
          ToggleOption(
            label: 'Show Metadata',
            value: showMetadata,
            onChanged: onShowMetadataChanged,
          ),
          const SizedBox(height: 16),
          const SectionTitle(title: 'Minimum Log Level'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LogLevel.values.map((level) {
              final isSelected = minimumLevel == level;
              return FilterChip(
                label: Text(level.name),
                selected: isSelected,
                onSelected: (_) => onMinimumLevelChanged(level),
                selectedColor: _getLevelColor(level.name).withAlpha(50),
                checkmarkColor: _getLevelColor(level.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const SectionTitle(title: 'Test Current Config'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onLogAllLevels,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Log All Levels'),
          ),
          const SizedBox(height: 24),
          CodeExample(
            title: 'Current Config Code',
            code: _getConfigCode(),
          ),
        ],
      ),
    );
  }

  String _getConfigCode() {
    final buffer = StringBuffer();
    buffer.writeln('LoggingConfig(');
    buffer.writeln('  enablePrettyLogs: $enablePrettyLogs,');
    buffer.writeln('  showEmojis: $showEmojis,');
    buffer.writeln('  showTimestamp: $showTimestamp,');
    buffer.writeln('  showBorders: $showBorders,');
    buffer.writeln('  showMetadata: $showMetadata,');
    buffer.writeln('  minimumLevel: LogLevel.${minimumLevel.name},');
    buffer.writeln(')');
    return buffer.toString();
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

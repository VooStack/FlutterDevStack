import 'package:flutter/material.dart';

class PresetButton extends StatelessWidget {
  final String label;
  final String preset;
  final Color color;
  final bool isSelected;
  final ValueChanged<String> onSelected;

  const PresetButton({
    super.key,
    required this.label,
    required this.preset,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(preset),
      selectedColor: color.withAlpha(50),
      checkmarkColor: color,
      avatar: isSelected ? Icon(Icons.check, size: 18, color: color) : null,
    );
  }
}

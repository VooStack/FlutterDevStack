import 'package:flutter/material.dart';

class LogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const LogButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }
}

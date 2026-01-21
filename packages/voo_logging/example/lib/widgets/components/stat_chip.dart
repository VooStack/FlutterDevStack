import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const StatChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        radius: 10,
        child: Text(
          '$count',
          style: const TextStyle(fontSize: 10, color: Colors.white),
        ),
      ),
      label: Text(label),
    );
  }
}

import 'package:flutter/material.dart';

class LatencyBadge extends StatelessWidget {
  final int? delayMs;

  const LatencyBadge({super.key, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    final delay = delayMs;
    final Color color;
    final String text;
    if (delay == null) {
      color = Colors.grey;
      text = '--';
    } else if (delay <= 0) {
      color = Colors.red;
      text = 'timeout';
    } else if (delay < 200) {
      color = Colors.green;
      text = '${delay}ms';
    } else if (delay < 500) {
      color = Colors.orange;
      text = '${delay}ms';
    } else {
      color = Colors.red;
      text = '${delay}ms';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

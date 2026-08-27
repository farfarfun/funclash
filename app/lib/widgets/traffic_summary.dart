import 'package:flutter/material.dart';

import '../models/traffic.dart';

String formatBytesPerSecond(int bytesPerSecond) {
  const units = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
  double value = bytesPerSecond.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(value < 10 && unitIndex > 0 ? 1 : 0)} ${units[unitIndex]}';
}

class TrafficSummary extends StatelessWidget {
  final Traffic? traffic;

  const TrafficSummary({super.key, required this.traffic});

  @override
  Widget build(BuildContext context) {
    final up = traffic?.up ?? 0;
    final down = traffic?.down ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.arrow_upward, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Text(formatBytesPerSecond(up)),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_downward, size: 16, color: Colors.blue),
        const SizedBox(width: 4),
        Text(formatBytesPerSecond(down)),
      ],
    );
  }
}

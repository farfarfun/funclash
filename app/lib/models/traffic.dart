class Traffic {
  final int up;
  final int down;

  const Traffic({required this.up, required this.down});

  factory Traffic.fromJson(Map<String, dynamic> json) {
    return Traffic(
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
    );
  }
}

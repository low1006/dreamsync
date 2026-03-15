class SleepChartPoint {
  final double hour;
  final double stage;

  const SleepChartPoint(this.hour, this.stage);

  Map<String, dynamic> toJson() {
    return {
      'hour': hour,
      'stage': stage,
    };
  }

  factory SleepChartPoint.fromJson(Map<String, dynamic> json) {
    return SleepChartPoint(
      (json['hour'] as num?)?.toDouble() ?? 0,
      (json['stage'] as num?)?.toDouble() ?? 0,
    );
  }
}
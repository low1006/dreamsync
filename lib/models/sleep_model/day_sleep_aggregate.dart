import 'sleep_chart_point.dart';

class DaySleepAggregate {
  int sessionMinutes;
  int stageTotalMinutes;
  int deepMinutes;
  int lightMinutes;
  int remMinutes;
  int awakeMinutes;
  DateTime? latestWakeTime;
  final List<SleepChartPoint> hypnogram;

  DaySleepAggregate({
    this.sessionMinutes = 0,
    this.stageTotalMinutes = 0,
    this.deepMinutes = 0,
    this.lightMinutes = 0,
    this.remMinutes = 0,
    this.awakeMinutes = 0,
    this.latestWakeTime,
    List<SleepChartPoint>? hypnogram,
  }) : hypnogram = hypnogram ?? [];
}
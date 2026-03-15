import 'dart:convert';

import 'package:health/health.dart';

import 'package:dreamsync/models/sleep_model/day_sleep_aggregate.dart';
import 'package:dreamsync/models/sleep_model/sleep_chart_point.dart';
import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/services/sleep_score_service.dart';

class SleepSummaryResult {
  final bool isDataPendingSync;
  final String dailyTotalSleepDuration;
  final int dailySleepScore;
  final String dailyDeepSleep;
  final String dailyLightSleep;
  final String dailyRemSleep;
  final List<SleepChartPoint> hypnogramData;
  final String weeklyTotalSleepDuration;
  final int weeklySleepScore;
  final Map<String, DateTime> wakeTimeByDay;

  const SleepSummaryResult({
    required this.isDataPendingSync,
    required this.dailyTotalSleepDuration,
    required this.dailySleepScore,
    required this.dailyDeepSleep,
    required this.dailyLightSleep,
    required this.dailyRemSleep,
    required this.hypnogramData,
    required this.weeklyTotalSleepDuration,
    required this.weeklySleepScore,
    required this.wakeTimeByDay,
  });
}

class SleepSummaryService {
  final SleepScoreService _scoreService;

  SleepSummaryService({SleepScoreService? scoreService})
      : _scoreService = scoreService ?? SleepScoreService();

  SleepSummaryResult rebuildDashboardStateFromRawData(
    List<HealthDataPoint> rawHealthData,
  ) {
    if (rawHealthData.isEmpty) {
      return const SleepSummaryResult(
        isDataPendingSync: false,
        dailyTotalSleepDuration: '0h 0m',
        dailySleepScore: 0,
        dailyDeepSleep: '0h 0m',
        dailyLightSleep: '0h 0m',
        dailyRemSleep: '0h 0m',
        hypnogramData: [],
        weeklyTotalSleepDuration: '0h 0m',
        weeklySleepScore: 0,
        wakeTimeByDay: {},
      );
    }

    final bool hasSessions =
        rawHealthData.any((p) => p.type == HealthDataType.SLEEP_SESSION);

    final Map<String, DaySleepAggregate> byDay = buildAggregates(rawHealthData);
    DateTime latestDate = rawHealthData.first.dateTo;

    for (final point in rawHealthData) {
      if (point.dateTo.isAfter(latestDate)) {
        latestDate = point.dateTo;
      }
    }

    final wakeTimeByDay = <String, DateTime>{
      for (final entry in byDay.entries)
        if (entry.value.latestWakeTime != null)
          entry.key: entry.value.latestWakeTime!,
    };

    final latestKey = dateKey(latestDate);
    final latestAgg = byDay[latestKey] ?? DaySleepAggregate();

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final latestMidnight =
        DateTime(latestDate.year, latestDate.month, latestDate.day);
    final yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));

    bool isDataPendingSync = false;
    if (now.hour < 12) {
      if (latestMidnight.isBefore(yesterdayMidnight)) {
        isDataPendingSync = true;
      }
    } else {
      if (latestMidnight.isBefore(todayMidnight)) {
        isDataPendingSync = true;
      }
    }

    final int dailyTotal =
        hasSessions ? latestAgg.sessionMinutes : latestAgg.stageTotalMinutes;

    latestAgg.hypnogram.sort((a, b) => a.hour.compareTo(b.hour));

    final DateTime weeklyCutoff =
        todayMidnight.subtract(const Duration(days: 7));
    int weeklyTotal = 0;
    int weeklyDeep = 0;
    int weeklyRem = 0;
    int weeklyAwake = 0;
    int dayCount = 0;

    for (final entry in byDay.entries) {
      final day = DateTime.parse(entry.key);
      if (day.isBefore(weeklyCutoff)) continue;

      final agg = entry.value;
      final chosenTotal = hasSessions ? agg.sessionMinutes : agg.stageTotalMinutes;

      if (chosenTotal > 0 ||
          agg.deepMinutes > 0 ||
          agg.lightMinutes > 0 ||
          agg.remMinutes > 0 ||
          agg.awakeMinutes > 0) {
        dayCount++;
        weeklyTotal += chosenTotal;
        weeklyDeep += agg.deepMinutes;
        weeklyRem += agg.remMinutes;
        weeklyAwake += agg.awakeMinutes;
      }
    }

    final int weeklyScore;
    final String weeklyTotalSleepDuration;

    if (dayCount == 0) {
      weeklyTotalSleepDuration = '0h 0m';
      weeklyScore = 0;
    } else {
      final avgTotal = weeklyTotal ~/ dayCount;
      final avgDeep = weeklyDeep ~/ dayCount;
      final avgRem = weeklyRem ~/ dayCount;
      final avgAwake = weeklyAwake ~/ dayCount;

      weeklyTotalSleepDuration = formatMinutes(avgTotal);
      weeklyScore = _scoreService.calculateSleepScore(
        totalMinutes: avgTotal,
        deepMinutes: avgDeep,
        remMinutes: avgRem,
        awakeMinutes: avgAwake,
      );
    }

    return SleepSummaryResult(
      isDataPendingSync: isDataPendingSync,
      dailyTotalSleepDuration: formatMinutes(dailyTotal),
      dailySleepScore: _scoreService.calculateSleepScore(
        totalMinutes: dailyTotal,
        deepMinutes: latestAgg.deepMinutes,
        remMinutes: latestAgg.remMinutes,
        awakeMinutes: latestAgg.awakeMinutes,
      ),
      dailyDeepSleep: formatMinutes(latestAgg.deepMinutes),
      dailyLightSleep: formatMinutes(latestAgg.lightMinutes),
      dailyRemSleep: formatMinutes(latestAgg.remMinutes),
      hypnogramData: latestAgg.hypnogram,
      weeklyTotalSleepDuration: weeklyTotalSleepDuration,
      weeklySleepScore: weeklyScore,
      wakeTimeByDay: wakeTimeByDay,
    );
  }

  List<SleepRecordModel> buildDailySummaries(
    List<HealthDataPoint> rawHealthData,
    String userId, {
    Map<String, SleepRecordModel> existingByDate = const {},
  }) {
    if (rawHealthData.isEmpty) return [];

    final bool hasSessions =
        rawHealthData.any((p) => p.type == HealthDataType.SLEEP_SESSION);

    final Map<String, DaySleepAggregate> byDay = buildAggregates(rawHealthData);
    final List<SleepRecordModel> summaries = [];

    for (final entry in byDay.entries) {
      final agg = entry.value;
      final totalMinutes = hasSessions ? agg.sessionMinutes : agg.stageTotalMinutes;

      if (totalMinutes <= 0) continue;

      agg.hypnogram.sort((a, b) => a.hour.compareTo(b.hour));

      final score = _scoreService.calculateSleepScore(
        totalMinutes: totalMinutes,
        deepMinutes: agg.deepMinutes,
        remMinutes: agg.remMinutes,
        awakeMinutes: agg.awakeMinutes,
      );

      final existing = existingByDate[entry.key];

      summaries.add(
        SleepRecordModel(
          id: existing?.id,
          userId: userId,
          date: entry.key,
          totalMinutes: totalMinutes,
          sleepScore: score,
          deepMinutes: agg.deepMinutes,
          lightMinutes: agg.lightMinutes,
          remMinutes: agg.remMinutes,
          awakeMinutes: agg.awakeMinutes,
          hypnogramJson: jsonEncode(
            agg.hypnogram.map((p) => p.toJson()).toList(),
          ),
          moodFeedback: existing?.moodFeedback,
        ),
      );
    }

    summaries.sort((a, b) => a.date.compareTo(b.date));
    return summaries;
  }

  Map<String, DaySleepAggregate> buildAggregates(List<HealthDataPoint> rawHealthData) {
    final Map<String, DaySleepAggregate> byDay = {};

    for (final point in rawHealthData) {
      final dayKey = dateKey(point.dateTo);
      final dayAgg = byDay.putIfAbsent(dayKey, DaySleepAggregate.new);

      final duration = point.dateTo.difference(point.dateFrom).inMinutes;
      if (duration <= 0) continue;

      if (point.type == HealthDataType.SLEEP_SESSION) {
        dayAgg.sessionMinutes += duration;
      } else if (point.type != HealthDataType.SLEEP_AWAKE) {
        dayAgg.stageTotalMinutes += duration;
      }

      if (point.type == HealthDataType.SLEEP_DEEP) {
        dayAgg.deepMinutes += duration;
      } else if (point.type == HealthDataType.SLEEP_LIGHT ||
          point.type == HealthDataType.SLEEP_ASLEEP) {
        dayAgg.lightMinutes += duration;
      } else if (point.type == HealthDataType.SLEEP_REM) {
        dayAgg.remMinutes += duration;
      } else if (point.type == HealthDataType.SLEEP_AWAKE) {
        dayAgg.awakeMinutes += duration;
      }

      if (point.type == HealthDataType.SLEEP_SESSION ||
          point.type == HealthDataType.SLEEP_ASLEEP) {
        if (dayAgg.latestWakeTime == null ||
            point.dateTo.isAfter(dayAgg.latestWakeTime!)) {
          dayAgg.latestWakeTime = point.dateTo;
        }
      }

      final chartPoint = toHypnogramPoint(point);
      if (chartPoint != null) {
        dayAgg.hypnogram.add(chartPoint);
      }
    }

    return byDay;
  }

  SleepChartPoint? toHypnogramPoint(HealthDataPoint point) {
    double stageValue;

    if (point.type == HealthDataType.SLEEP_DEEP) {
      stageValue = 0;
    } else if (point.type == HealthDataType.SLEEP_LIGHT ||
        point.type == HealthDataType.SLEEP_ASLEEP) {
      stageValue = 1;
    } else if (point.type == HealthDataType.SLEEP_REM) {
      stageValue = 2;
    } else if (point.type == HealthDataType.SLEEP_AWAKE) {
      stageValue = 3;
    } else {
      return null;
    }

    double hour = point.dateFrom.hour + (point.dateFrom.minute / 60.0);
    if (hour > 12) hour -= 24;

    return SleepChartPoint(hour, stageValue);
  }

  String formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return '0h 0m';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String normalizeDateKey(String rawDate) {
    return rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
  }
}

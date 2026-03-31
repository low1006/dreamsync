import "package:dreamsync/util/parsers.dart";
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

    final latestKey = Parsers.dateKey(latestDate);
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

    final int dailyScore = _scoreService.calculateSleepScore(
      totalMinutes: dailyTotal,
      deepMinutes: latestAgg.deepMinutes,
      remMinutes: latestAgg.remMinutes,
      awakeMinutes: latestAgg.awakeMinutes,
    );

    final DateTime weeklyCutoff =
    todayMidnight.subtract(const Duration(days: 6));

    int weeklyTotalMinutes = 0;
    int totalDailyScores = 0;
    int dayCount = 0;

    for (final entry in byDay.entries) {
      final day = DateTime.parse(entry.key);
      if (day.isBefore(weeklyCutoff)) continue;

      final agg = entry.value;
      final chosenTotal =
      hasSessions ? agg.sessionMinutes : agg.stageTotalMinutes;

      if (chosenTotal > 0 ||
          agg.deepMinutes > 0 ||
          agg.lightMinutes > 0 ||
          agg.remMinutes > 0 ||
          agg.awakeMinutes > 0) {
        final int dayScore = _scoreService.calculateSleepScore(
          totalMinutes: chosenTotal,
          deepMinutes: agg.deepMinutes,
          remMinutes: agg.remMinutes,
          awakeMinutes: agg.awakeMinutes,
        );

        debugPrint('📅 Weekly include => ${entry.key} | score=$dayScore');

        weeklyTotalMinutes += chosenTotal;
        totalDailyScores += dayScore;
        dayCount++;
      }
    }

    final int weeklyScore;
    final String weeklyTotalSleepDuration;

    if (dayCount == 0) {
      weeklyTotalSleepDuration = '0h 0m';
      weeklyScore = 0;
    } else {
      weeklyTotalSleepDuration = Parsers.formatMinutes(weeklyTotalMinutes ~/ dayCount);
      weeklyScore = (totalDailyScores / dayCount).round();
    }

    debugPrint(
      '📊 Weekly final => totalDailyScores=$totalDailyScores | '
          'dayCount=$dayCount | '
          'avg=${dayCount == 0 ? 0 : (totalDailyScores / dayCount).toStringAsFixed(2)} | '
          'weeklyScore=$weeklyScore',
    );

    return SleepSummaryResult(
      isDataPendingSync: isDataPendingSync,
      dailyTotalSleepDuration: Parsers.formatMinutes(dailyTotal),
      dailySleepScore: dailyScore,
      dailyDeepSleep: Parsers.formatMinutes(latestAgg.deepMinutes),
      dailyLightSleep: Parsers.formatMinutes(latestAgg.lightMinutes),
      dailyRemSleep: Parsers.formatMinutes(latestAgg.remMinutes),
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
      final totalMinutes =
      hasSessions ? agg.sessionMinutes : agg.stageTotalMinutes;

      if (totalMinutes <= 0) continue;

      agg.hypnogram.sort((a, b) => a.hour.compareTo(b.hour));

      final score = _scoreService.calculateSleepScore(
        totalMinutes: totalMinutes,
        deepMinutes: agg.deepMinutes,
        remMinutes: agg.remMinutes,
        awakeMinutes: agg.awakeMinutes,
      );

      debugPrint(
        '🛌 ${entry.key} => '
            'Total: ${(totalMinutes / 60).toStringAsFixed(2)}h | '
            'Light: ${(agg.lightMinutes / 60).toStringAsFixed(2)}h | '
            'Deep: ${(agg.deepMinutes / 60).toStringAsFixed(2)}h | '
            'REM: ${(agg.remMinutes / 60).toStringAsFixed(2)}h | '
            'Score: $score',
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

  Map<String, DaySleepAggregate> buildAggregates(
      List<HealthDataPoint> rawHealthData,
      ) {
    final Map<String, DaySleepAggregate> byDay = {};

    for (final point in rawHealthData) {
      final dayKey = Parsers.dateKey(point.dateTo);
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
}
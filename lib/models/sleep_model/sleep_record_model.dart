import 'dart:convert';

import 'sleep_chart_point.dart';

class SleepRecordModel {
  final String? id;
  final String userId;
  final String date;
  final int totalMinutes;
  final int sleepScore;
  final int deepMinutes;
  final int lightMinutes;
  final int remMinutes;
  final int awakeMinutes;
  final String? hypnogramJson;
  final String? moodFeedback;

  const SleepRecordModel({
    this.id,
    required this.userId,
    required this.date,
    required this.totalMinutes,
    required this.sleepScore,
    this.deepMinutes = 0,
    this.lightMinutes = 0,
    this.remMinutes = 0,
    this.awakeMinutes = 0,
    this.hypnogramJson,
    this.moodFeedback,
  });

  SleepRecordModel copyWith({
    String? id,
    String? userId,
    String? date,
    int? totalMinutes,
    int? sleepScore,
    int? deepMinutes,
    int? lightMinutes,
    int? remMinutes,
    int? awakeMinutes,
    String? hypnogramJson,
    String? moodFeedback,
  }) {
    return SleepRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      sleepScore: sleepScore ?? this.sleepScore,
      deepMinutes: deepMinutes ?? this.deepMinutes,
      lightMinutes: lightMinutes ?? this.lightMinutes,
      remMinutes: remMinutes ?? this.remMinutes,
      awakeMinutes: awakeMinutes ?? this.awakeMinutes,
      hypnogramJson: hypnogramJson ?? this.hypnogramJson,
      moodFeedback: moodFeedback ?? this.moodFeedback,
    );
  }

  factory SleepRecordModel.fromLocalJson(Map<String, dynamic> json) {
    return SleepRecordModel(
      id: json['id']?.toString(),
      userId: (json['user_id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      sleepScore: (json['sleep_score'] as num?)?.toInt() ?? 0,
      deepMinutes: (json['deep_minutes'] as num?)?.toInt() ?? 0,
      lightMinutes: (json['light_minutes'] as num?)?.toInt() ?? 0,
      remMinutes: (json['rem_minutes'] as num?)?.toInt() ?? 0,
      awakeMinutes: (json['awake_minutes'] as num?)?.toInt() ?? 0,
      hypnogramJson: json['hypnogram_json']?.toString(),
      moodFeedback: json['mood_feedback']?.toString(),
    );
  }

  factory SleepRecordModel.fromSupabaseJson(Map<String, dynamic> json) {
    return SleepRecordModel(
      id: json['record_id']?.toString(),
      userId: (json['user_id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
      sleepScore: (json['sleep_score'] as num?)?.toInt() ?? 0,
      moodFeedback: json['mood_feedback']?.toString(),
    );
  }

  factory SleepRecordModel.fromJson(Map<String, dynamic> json) {
    return SleepRecordModel.fromLocalJson(json);
  }

  Map<String, dynamic> toLocalJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'date': date,
      'total_minutes': totalMinutes,
      'sleep_score': sleepScore,
      'deep_minutes': deepMinutes,
      'light_minutes': lightMinutes,
      'rem_minutes': remMinutes,
      'awake_minutes': awakeMinutes,
      'hypnogram_json': hypnogramJson,
      'mood_feedback': moodFeedback,
    };
  }

  Map<String, dynamic> toSupabaseSummaryJson() {
    return {
      if (id != null) 'record_id': id,
      'user_id': userId,
      'date': date,
      'total_minutes': totalMinutes,
      'sleep_score': sleepScore,
      'mood_feedback': moodFeedback,
    };
  }

  Map<String, dynamic> toJson() => toLocalJson();

  List<SleepChartPoint> get hypnogramPoints {
    if (hypnogramJson == null || hypnogramJson!.isEmpty) return const [];

    try {
      final raw = jsonDecode(hypnogramJson!);
      if (raw is! List) return const [];

      return raw
          .map((e) => SleepChartPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  DateTime? get parsedDate {
    try {
      return DateTime.parse(date);
    } catch (_) {
      return null;
    }
  }

  String get shortDayName {
    final parsed = parsedDate;
    if (parsed == null) return '';

    switch (parsed.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  bool get hasMoodFeedback {
    return moodFeedback != null && moodFeedback!.trim().isNotEmpty;
  }
}
import 'dart:convert';

class SleepRecordModel {
  final String? id; // maps to sleep_id in local DB
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

  factory SleepRecordModel.fromJson(Map<String, dynamic> json) {
    return SleepRecordModel(
      id: (json['sleep_id'] ?? json['id'])?.toString(),
      userId: (json['user_id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      totalMinutes: _toInt(json['total_minutes']),
      sleepScore: _toInt(json['sleep_score']),
      deepMinutes: _toInt(json['deep_minutes']),
      lightMinutes: _toInt(json['light_minutes']),
      remMinutes: _toInt(json['rem_minutes']),
      awakeMinutes: _toInt(json['awake_minutes']),
      hypnogramJson: json['hypnogram_json']?.toString(),
      moodFeedback: json['mood_feedback']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'sleep_id': id,
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

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}
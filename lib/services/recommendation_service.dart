import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:dreamsync/util/local_database.dart';

class SleepRecommendation {
  final double recommendedHours;
  final String recommendedLabel;
  final double expectedScore;
  final double simDeepHours;
  final double simRemHours;
  final double simDeepPct;
  final double simRemPct;
  final List<Map<String, dynamic>> candidates;
  final String explanation;
  final String? message;

  SleepRecommendation({
    required this.recommendedHours,
    required this.recommendedLabel,
    required this.expectedScore,
    required this.simDeepHours,
    required this.simRemHours,
    required this.simDeepPct,
    required this.simRemPct,
    required this.candidates,
    required this.explanation,
    this.message,
  });

  factory SleepRecommendation.fromJson(Map<String, dynamic> json) {
    return SleepRecommendation(
      recommendedHours: (json['recommended_hours'] as num).toDouble(),
      recommendedLabel: (json['recommended_label'] ?? '8h 0min') as String,
      expectedScore: (json['expected_score'] as num).toDouble(),
      simDeepHours: (json['sim_deep_h'] as num).toDouble(),
      simRemHours: (json['sim_rem_h'] as num).toDouble(),
      simDeepPct: (json['sim_deep_pct'] as num).toDouble(),
      simRemPct: (json['sim_rem_pct'] as num).toDouble(),
      candidates: List<Map<String, dynamic>>.from(json['candidates'] ?? []),
      explanation: (json['explanation'] ??
          'Based on your recent sleep history, this duration is predicted to give the best sleep score.')
      as String,
      message: json['message'] as String?,
    );
  }

  String get deepLabel =>
      "${simDeepHours.toStringAsFixed(1)}h (${simDeepPct.toStringAsFixed(0)}%)";

  String get remLabel =>
      "${simRemHours.toStringAsFixed(1)}h (${simRemPct.toStringAsFixed(0)}%)";

  int get scoreInt => expectedScore.round();
}

class RecommendationService {
  static String get _baseUrl =>
      dotenv.env['ML_API_BASE_URL'] ?? 'http://10.0.2.2:8000';

  static Future<SleepRecommendation?> getRecommendation({
    required String userId,
    String? hypnogramJson,
    int exerciseMinutes = 0,
    int foodCalories = 0,
    int screenMinutes = 0,
  }) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final startStr = _dateKey(weekAgo);
      final endStr = "${_dateKey(now)} 23:59:59";

      final rows = await LocalDatabase.instance.database.then(
            (db) => db.rawQuery('''
          SELECT
            s.date,
            s.total_minutes,
            s.deep_minutes,
            s.light_minutes,
            s.rem_minutes,
            s.awake_minutes,
            s.sleep_score,
            s.mood_feedback,
            s.hypnogram_json,
            COALESCE(a.exercise_minutes, 0) AS exercise_minutes,
            COALESCE(a.food_calories, 0) AS food_calories,
            COALESCE(a.screen_time_minutes, 0) AS screen_time_minutes
          FROM sleep_record s
          LEFT JOIN daily_activity a
            ON s.user_id = a.user_id AND s.date = a.date
          WHERE s.user_id = ?
            AND s.date >= ?
            AND s.date <= ?
            AND s.total_minutes > 0
          ORDER BY s.date ASC
          LIMIT 7
        ''', [userId, startStr, endStr]),
      );

      if (rows.isEmpty) {
        debugPrint('⚠️ RecommendationService: no history found');
        return null;
      }

      final historyJson = rows.map((row) {
        double bedtime = 23.0;
        final hj = row['hypnogram_json'] as String?;
        if (hj != null && hj.isNotEmpty) {
          try {
            final pts = jsonDecode(hj) as List;
            if (pts.isNotEmpty) {
              final h = (pts.first['hour'] as num).toDouble();
              bedtime = h < 0 ? h + 24 : h;
            }
          } catch (_) {}
        }

        return {
          'date': row['date'] as String,
          'total_minutes': row['total_minutes'] as int,
          'deep_minutes': row['deep_minutes'] as int,
          'light_minutes': row['light_minutes'] as int,
          'rem_minutes': row['rem_minutes'] as int,
          'awake_minutes': row['awake_minutes'] as int,
          'sleep_score': row['sleep_score'] as int,
          'mood_feedback': row['mood_feedback'],
          'exercise_minutes': row['exercise_minutes'] as int,
          'food_calories': row['food_calories'] as int,
          'screen_time_minutes': row['screen_time_minutes'] as int,
          'bedtime_hours': bedtime,
        };
      }).toList();

      double tonightBedtime = 23.0;
      if (hypnogramJson != null && hypnogramJson.isNotEmpty) {
        try {
          final pts = jsonDecode(hypnogramJson) as List;
          if (pts.isNotEmpty) {
            final h = (pts.first['hour'] as num).toDouble();
            tonightBedtime = h < 0 ? h + 24 : h;
          }
        } catch (_) {}
      }

      final response = await http
          .post(
        Uri.parse('$_baseUrl/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'history': historyJson,
          'exercise_minutes': exerciseMinutes,
          'food_calories': foodCalories,
          'screen_time_minutes': screenMinutes,
          'bedtime_hours': tonightBedtime,
        }),
      )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return SleepRecommendation.fromJson(json);
      }

      debugPrint('❌ Recommendation API ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ RecommendationService error: $e');
      return null;
    }
  }

  static String _dateKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
}
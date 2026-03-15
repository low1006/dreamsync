import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/services/sleep_score_service.dart';
import 'package:dreamsync/models/sleep_model/sleep_recommendation_cache_model.dart';
import 'package:dreamsync/repositories/recommendation_cache_repository.dart';

class SleepRecommendation {
  final double recommendedHours;
  final String recommendedLabel;
  final double expectedScore;
  final double simDeepHours;
  final double simRemHours;
  final double simDeepPct;
  final double simRemPct;
  final String explanation;
  final String? message;
  final List<Map<String, dynamic>> candidates;

  SleepRecommendation({
    required this.recommendedHours,
    required this.recommendedLabel,
    required this.expectedScore,
    required this.simDeepHours,
    required this.simRemHours,
    required this.simDeepPct,
    required this.simRemPct,
    required this.explanation,
    this.message,
    required this.candidates,
  });

  String get deepLabel =>
      '${simDeepHours.toStringAsFixed(1)}h (${simDeepPct.toStringAsFixed(0)}%)';

  String get remLabel =>
      '${simRemHours.toStringAsFixed(1)}h (${simRemPct.toStringAsFixed(0)}%)';

  int get scoreInt => expectedScore.round();
}

class RecommendationService {
  static const double _targetMinutes = 480.0;
  static const double _idealDeepRatio = SleepScoreService.idealDeepRatio;
  static const double _idealRemRatio = SleepScoreService.idealRemRatio;
  static const double _eps = 1e-6;

  static Interpreter? _interpreter;
  static List<String>? _featureOrder;
  static List<double>? _imputerMeans;
  static List<double>? _scalerCenter;
  static List<double>? _scalerScale;
  static bool _initialised = false;

  static final RecommendationCacheRepository _cacheRepo =
  RecommendationCacheRepository();

  static Future<void> init() async {
    if (_initialised) return;

    _interpreter = await Interpreter.fromAsset('assets/ml/sleep_model.tflite');

    final raw = await rootBundle.loadString('assets/ml/scaler_stats.json');
    final stats = jsonDecode(raw) as Map<String, dynamic>;

    _featureOrder = List<String>.from(stats['features'] as List);
    _imputerMeans = _toDoubleList(stats['mean'] as List);
    _scalerCenter = _toDoubleList(stats['center'] as List);
    _scalerScale = _toDoubleList(stats['scale'] as List);

    _initialised = true;
    debugPrint(
      '✅ RecommendationService: TFLite loaded — ${_featureOrder!.length} features',
    );
  }

  static Future<SleepRecommendation?> getRecommendation({
    required String userId,
    String? hypnogramJson,
    int exerciseMinutes = 0,
    int foodCalories = 0,
    int screenMinutes = 0,
    bool forceRefresh = false,
  }) async {
    try {
      await init();

      final today = _dateKey(DateTime.now());

      if (!forceRefresh) {
        final cached = await _cacheRepo.getToday(userId: userId, date: today);
        if (cached != null) {
          return SleepRecommendation(
            recommendedHours: cached.recommendedMinutes / 60.0,
            recommendedLabel:
            '${cached.recommendedMinutes ~/ 60}h ${cached.recommendedMinutes % 60}min',
            expectedScore: cached.expectedScore,
            simDeepHours: cached.simDeepMinutes / 60.0,
            simRemHours: cached.simRemMinutes / 60.0,
            simDeepPct: cached.simDeepPct,
            simRemPct: cached.simRemPct,
            explanation: cached.explanation,
            message: cached.message,
            candidates: const [],
          );
        }
      }

      final db = await LocalDatabase.instance.database;
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));

      final rows = await db.rawQuery('''
        SELECT
          s.date,
          s.total_minutes,
          s.deep_minutes,
          s.light_minutes,
          s.rem_minutes,
          s.awake_minutes,
          s.sleep_score,
          s.hypnogram_json,
          COALESCE(a.exercise_minutes, 0) AS exercise_minutes,
          COALESCE(a.food_calories, 0) AS food_calories,
          COALESCE(a.screen_time_minutes, 0) AS screen_time_minutes
        FROM sleep_record s
        LEFT JOIN daily_activity a
          ON s.user_id = a.user_id AND s.date = a.date
        WHERE s.user_id = ?
          AND s.date >= ?
          AND s.total_minutes > 0
        ORDER BY s.date ASC
        LIMIT 7
      ''', [userId, _dateKey(weekAgo)]);

      if (rows.isEmpty) {
        debugPrint('⚠️ RecommendationService: no history for $userId');
        return null;
      }

      final history = rows.map(_parseRow).toList();
      final latest = history.last;

      final baseH = latest['total_h'] as double;
      final deepR = (latest['deep_h'] as double) / max(baseH, _eps);
      final remR = (latest['rem_h'] as double) / max(baseH, _eps);
      final awakeR = (latest['awake_h'] as double) / max(baseH, _eps);

      final exerciseH = exerciseMinutes / 60.0;
      final screenH = screenMinutes / 60.0;
      final calories = foodCalories.toDouble();
      final bedtime = _extractBedtime(hypnogramJson) ?? 23.0;

      final hourRange = [for (int i = 16; i <= 40; i++) i / 4.0];

      double bestScore = -1.0;
      double bestHrs = 8.0;
      final candidates = <Map<String, dynamic>>[];

      for (final hrs in hourRange) {
        final delta =
        ((hrs - baseH) / max(baseH, 1.0)).clamp(-0.3, 0.3).toDouble();
        final nudge = 0.4 * delta;

        final simDeepR = (deepR + nudge * (_idealDeepRatio - deepR))
            .clamp(0.05, 0.40)
            .toDouble();
        final simRemR = (remR + nudge * (_idealRemRatio - remR))
            .clamp(0.05, 0.40)
            .toDouble();
        final simLightR =
        (1.0 - simDeepR - simRemR).clamp(0.10, 0.80).toDouble();
        final simAwakeR =
        (awakeR * (1 - 0.08 * delta)).clamp(0.0, 0.30).toDouble();

        final features = _buildVector(
          history: history,
          hrs: hrs,
          simDeepR: simDeepR,
          simRemR: simRemR,
          simLightR: simLightR,
          simAwakeR: simAwakeR,
          exerciseH: exerciseH,
          calories: calories,
          screenH: screenH,
          bedtime: bedtime,
        );

        final score = _predict(features).clamp(0.0, 100.0);

        candidates.add({
          'hours': hrs,
          'score': double.parse(score.toStringAsFixed(1)),
          'sim_deep_h': double.parse((hrs * simDeepR).toStringAsFixed(2)),
          'sim_rem_h': double.parse((hrs * simRemR).toStringAsFixed(2)),
          'sim_deep_pct': double.parse((simDeepR * 100).toStringAsFixed(1)),
          'sim_rem_pct': double.parse((simRemR * 100).toStringAsFixed(1)),
        });

        if (score > bestScore) {
          bestScore = score;
          bestHrs = hrs;
        }
      }

      final best = candidates.firstWhere((c) => c['hours'] == bestHrs);
      final h = bestHrs.floor();
      final m = ((bestHrs - h) * 60).round();
      final avg7 = _listAvg(history, 'total_h');
      final diff = bestHrs - avg7;

      final explanation = _buildExplanation(
        recHrs: bestHrs,
        avg7: avg7,
        diff: diff,
        deepPct: best['sim_deep_pct'] as double,
        remPct: best['sim_rem_pct'] as double,
        score: bestScore,
      );

      final message = _buildMessage(diff, history.length);

      await _cacheRepo.save(
        SleepRecommendationCacheModel(
          userId: userId,
          date: today,
          recommendedMinutes: (bestHrs * 60).round(),
          expectedScore: bestScore,
          simDeepMinutes: ((best['sim_deep_h'] as double) * 60).round(),
          simRemMinutes: ((best['sim_rem_h'] as double) * 60).round(),
          simDeepPct: best['sim_deep_pct'] as double,
          simRemPct: best['sim_rem_pct'] as double,
          explanation: explanation,
          message: message,
          generatedAt: DateTime.now().toIso8601String(),
        ),
      );

      return SleepRecommendation(
        recommendedHours: bestHrs,
        recommendedLabel: '${h}h ${m}min',
        expectedScore: bestScore,
        simDeepHours: best['sim_deep_h'] as double,
        simRemHours: best['sim_rem_h'] as double,
        simDeepPct: best['sim_deep_pct'] as double,
        simRemPct: best['sim_rem_pct'] as double,
        explanation: explanation,
        message: message,
        candidates: candidates,
      );
    } catch (e, st) {
      debugPrint('❌ RecommendationService: $e\n$st');
      return null;
    }
  }

  static Future<void> invalidateTodayRecommendation({
    required String userId,
  }) async {
    await _cacheRepo.deleteToday(
      userId: userId,
      date: _dateKey(DateTime.now()),
    );
  }

  static double _predict(List<double> features) {
    final input = [features];
    final output = [
      [0.0]
    ];
    _interpreter!.run(input, output);
    return output[0][0];
  }

  static List<double> _buildVector({
    required List<Map<String, dynamic>> history,
    required double hrs,
    required double simDeepR,
    required double simRemR,
    required double simLightR,
    required double simAwakeR,
    required double exerciseH,
    required double calories,
    required double screenH,
    required double bedtime,
  }) {
    final totalMin = hrs * 60.0;
    final simAwakeH = hrs * simAwakeR;
    final tib = hrs + simAwakeH;
    final eff = hrs / max(tib, _eps);
    final bedNorm = bedtime % 24;

    final lag1 = history.last;
    final lag2 = history.length >= 2 ? history[history.length - 2] : lag1;

    double avg(String key, {int tail = 7}) {
      final slice =
      history.length > tail ? history.sublist(history.length - tail) : history;
      return slice.map((r) => r[key] as double).reduce((a, b) => a + b) /
          slice.length;
    }

    final feats = <String, double>{
      'bedtime_hours': bedtime,
      'deep_sleep_hours': hrs * simDeepR,
      'light_sleep_hours': hrs * simLightR,
      'rem_hours': hrs * simRemR,
      'awake_hours': simAwakeH,
      'screentime': screenH,
      'exercise_time': exerciseH,
      'step_count_day': 0.0,
      'total_sleep_hours': hrs,
      'total_sleep_minutes': totalMin,
      'time_in_bed_hours': tib,
      'duration_ratio': (totalMin / _targetMinutes).clamp(0, 1).toDouble(),
      'deep_ratio': simDeepR,
      'rem_ratio': simRemR,
      'light_ratio': simLightR,
      'awake_ratio': simAwakeR,
      'sleep_efficiency': eff,
      'deep_ratio_dev':
      ((simDeepR - _idealDeepRatio).abs() / _idealDeepRatio).toDouble(),
      'rem_ratio_dev':
      ((simRemR - _idealRemRatio).abs() / _idealRemRatio).toDouble(),
      'bedtime_sin': sin(2 * pi * bedNorm / 24),
      'bedtime_cos': cos(2 * pi * bedNorm / 24),
      'day_of_week': 0.0,
      'day_of_week_sin': 0.0,
      'day_of_week_cos': 1.0,
      'is_weekend': 0.0,
      'late_screen': screenH * (bedtime > 23 ? 1.0 : 0.0),
      'exercise_benefit': exerciseH.clamp(0, 2).toDouble(),

      'total_sleep_hours_lag1': lag1['total_h'] as double,
      'total_sleep_hours_lag2': lag2['total_h'] as double,
      'sleep_score_lag1': lag1['score'] as double,
      'sleep_score_lag2': lag2['score'] as double,
      'blended_score_lag1': lag1['score'] as double,
      'blended_score_lag2': lag2['score'] as double,
      'deep_ratio_lag1': lag1['deep_r'] as double,
      'deep_ratio_lag2': lag2['deep_r'] as double,
      'rem_ratio_lag1': lag1['rem_r'] as double,
      'rem_ratio_lag2': lag2['rem_r'] as double,
      'awake_ratio_lag1': lag1['awake_r'] as double,
      'awake_ratio_lag2': lag2['awake_r'] as double,
      'duration_ratio_lag1': lag1['dur_ratio'] as double,
      'duration_ratio_lag2': lag2['dur_ratio'] as double,
      'deep_ratio_dev_lag1': lag1['deep_dev'] as double,
      'deep_ratio_dev_lag2': lag2['deep_dev'] as double,
      'rem_ratio_dev_lag1': lag1['rem_dev'] as double,
      'rem_ratio_dev_lag2': lag2['rem_dev'] as double,
      'rem_hours_lag1': lag1['rem_h'] as double,
      'rem_hours_lag2': lag2['rem_h'] as double,
      'deep_sleep_hours_lag1': lag1['deep_h'] as double,
      'deep_sleep_hours_lag2': lag2['deep_h'] as double,
      'awake_hours_lag1': lag1['awake_h'] as double,
      'awake_hours_lag2': lag2['awake_h'] as double,
      'screentime_lag1': lag1['screen_h'] as double,
      'screentime_lag2': lag2['screen_h'] as double,
      'exercise_time_lag1': lag1['exercise_h'] as double,
      'exercise_time_lag2': lag2['exercise_h'] as double,
      'step_count_day_lag1': 0.0,
      'step_count_day_lag2': 0.0,
      'sleep_efficiency_lag1': lag1['eff'] as double,
      'sleep_efficiency_lag2': lag2['eff'] as double,

      'total_sleep_hours_roll3': avg('total_h', tail: 3),
      'total_sleep_hours_roll7': avg('total_h'),
      'sleep_score_roll3': avg('score', tail: 3),
      'sleep_score_roll7': avg('score'),
      'blended_score_roll3': avg('score', tail: 3),
      'blended_score_roll7': avg('score'),
      'deep_ratio_roll3': avg('deep_r', tail: 3),
      'deep_ratio_roll7': avg('deep_r'),
      'rem_ratio_roll3': avg('rem_r', tail: 3),
      'rem_ratio_roll7': avg('rem_r'),
      'duration_ratio_roll3': avg('dur_ratio', tail: 3),
      'duration_ratio_roll7': avg('dur_ratio'),
      'sleep_efficiency_roll3': avg('eff', tail: 3),
      'sleep_efficiency_roll7': avg('eff'),

      'sleep_debt': avg('total_h') - (lag1['total_h'] as double),
    };

    return List.generate(_featureOrder!.length, (i) {
      final name = _featureOrder![i];
      double v = feats[name] ?? _imputerMeans![i];
      if (v.isNaN || v.isInfinite) v = _imputerMeans![i];
      return (v - _scalerCenter![i]) / max(_scalerScale![i], _eps);
    });
  }

  static Map<String, dynamic> _parseRow(Map<String, dynamic> r) {
    final totalH = (r['total_minutes'] as int) / 60.0;
    final deepH = (r['deep_minutes'] as int) / 60.0;
    final remH = (r['rem_minutes'] as int) / 60.0;
    final lightH = (r['light_minutes'] as int) / 60.0;
    final awakeH = (r['awake_minutes'] as int) / 60.0;
    final score = (r['sleep_score'] as int).toDouble();
    final tib = totalH + awakeH;
    final deepR = deepH / max(totalH, _eps);
    final remR = remH / max(totalH, _eps);
    final awakeR = awakeH / max(totalH, _eps);

    return {
      'total_h': totalH,
      'deep_h': deepH,
      'rem_h': remH,
      'light_h': lightH,
      'awake_h': awakeH,
      'score': score,
      'eff': totalH / max(tib, _eps),
      'deep_r': deepR,
      'rem_r': remR,
      'awake_r': awakeR,
      'dur_ratio': (totalH * 60 / _targetMinutes).clamp(0.0, 1.0),
      'deep_dev': (deepR - _idealDeepRatio).abs() / _idealDeepRatio,
      'rem_dev': (remR - _idealRemRatio).abs() / _idealRemRatio,
      'exercise_h': (r['exercise_minutes'] as int) / 60.0,
      'calories': (r['food_calories'] as int).toDouble(),
      'screen_h': (r['screen_time_minutes'] as int) / 60.0,
    };
  }

  static String _buildExplanation({
    required double recHrs,
    required double avg7,
    required double diff,
    required double deepPct,
    required double remPct,
    required double score,
  }) {
    final h = recHrs.floor();
    final m = ((recHrs - h) * 60).round();

    final trend = diff.abs() < 0.25
        ? 'similar to your recent average'
        : diff > 0
        ? '${diff.abs().toStringAsFixed(1)}h more than your recent average'
        : '${diff.abs().toStringAsFixed(1)}h less than your recent average';

    return 'Based on your last 7 nights, sleeping ${h}h ${m}min should give '
        'you a score around ${score.round()}. That\'s $trend. '
        'Aim for ${deepPct.toStringAsFixed(0)}% deep sleep and '
        '${remPct.toStringAsFixed(0)}% REM for best recovery.';
  }

  static String? _buildMessage(double diff, int historyDays) {
    if (historyDays < 3) {
      return 'Sync more nights for a more personalised recommendation.';
    }
    if (diff > 1.0) {
      return 'You\'ve been running a sleep deficit — try to catch up tonight!';
    }
    if (diff < -1.0) {
      return 'You\'ve been sleeping more than usual — a shorter night is fine.';
    }
    return null;
  }

  static double _listAvg(List<Map<String, dynamic>> rows, String key) {
    if (rows.isEmpty) return 0.0;
    return rows.map((r) => r[key] as double).reduce((a, b) => a + b) /
        rows.length;
  }

  static double? _extractBedtime(String? hj) {
    if (hj == null || hj.isEmpty) return null;
    try {
      final pts = jsonDecode(hj) as List;
      if (pts.isEmpty) return null;
      final h = (pts.first['hour'] as num).toDouble();
      return h < 0 ? h + 24 : h;
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static List<double> _toDoubleList(List list) =>
      list.map((e) => (e as num).toDouble()).toList();
}
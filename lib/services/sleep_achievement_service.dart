import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';

class SleepAchievementService {
  static const int streakScoreThreshold = 70;

  /// Updates all achievement progress and returns the current streak count.
  Future<int> updateAchievements({
    required List<SleepRecordModel> allRecords,
    required Map<String, DateTime> wakeTimeByDay,
    required int dailySleepScore,
    required AchievementViewModel achievementVM,
    // Optional — wire these up when data sources are available
    bool bedtimeConsistentToday = false,
    bool noScreenTimeToday = false,
  }) async {
    int totalLogs = 0;
    int totalLifetimeMinutes = 0;

    final Map<String, int> scoreByDate = {};
    final Map<String, int> minutesByDate = {};

    for (final record in allRecords) {
      final normalizedKey = normalizeDateKey(record.date);

      if (record.totalMinutes > 0) {
        totalLogs++;
        totalLifetimeMinutes += record.totalMinutes;

        // keep latest value for that date
        scoreByDate[normalizedKey] = record.sleepScore;
        minutesByDate[normalizedKey] = record.totalMinutes;
      }
    }

    final currentStreak = computeStreak(scoreByDate);
    final totalLifetimeHours = totalLifetimeMinutes / 60.0;

    final todayKey = dateKey(DateTime.now());
    final hasTodayRecord =
        scoreByDate.containsKey(todayKey) && minutesByDate.containsKey(todayKey);

    final todayScore = hasTodayRecord ? (scoreByDate[todayKey] ?? 0) : 0;
    final todayMinutes = hasTodayRecord ? (minutesByDate[todayKey] ?? 0) : 0;
    final todayHours = todayMinutes / 60.0;
    final todayWakeTime = hasTodayRecord ? wakeTimeByDay[todayKey] : null;

    // latest available score for permanent “sleep_score” achievements
    int latestSleepScore = 0;
    if (allRecords.isNotEmpty) {
      final validRecords =
      allRecords.where((r) => r.totalMinutes > 0).toList()
        ..sort((a, b) => normalizeDateKey(a.date).compareTo(normalizeDateKey(b.date)));
      if (validRecords.isNotEmpty) {
        latestSleepScore = validRecords.last.sleepScore;
      }
    }

    // ─────────────────────────────────────────────────────────
    // PERMANENT achievements
    // ─────────────────────────────────────────────────────────

    // total_logs — Dream Beginner (1), Goal Crusher (100)
    for (final a in achievementVM.getByType('total_logs')) {
      await achievementVM.setProgress(a.userAchievementId, totalLogs.toDouble());
    }

    // sleep_score — Good Night (80), Deep Dreamer (90), Sleep Elite (95), Perfect Rest (100)
    // Use latest available valid score, not forced "today only".
    for (final a in achievementVM.getByType('sleep_score')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        latestSleepScore.toDouble(),
      );
    }

    // total_hours — Nap Snatcher (10), Hibernator (100), Sleep Marathon (500), Sleep Collector (1000)
    for (final a in achievementVM.getByType('total_hours')) {
      await achievementVM.setProgress(a.userAchievementId, totalLifetimeHours);
    }

    // streak_days — Three Peat (3), Week Warrior (7), Monthly Master (30), Consistency King (60)
    for (final a in achievementVM.getByType('streak_days')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        currentStreak.toDouble(),
      );
    }

    // ─────────────────────────────────────────────────────────
    // DAILY achievements
    // IMPORTANT:
    // Only evaluate daily achievements if there is an actual record for today.
    // This prevents yesterday's good result from being claimed again tomorrow.
    // ─────────────────────────────────────────────────────────

    // early_wake_daily — Early Bird: wake before 7 AM
    for (final a in achievementVM.getByType('early_wake_daily')) {
      final wokeEarly = hasTodayRecord &&
          todayWakeTime != null &&
          todayWakeTime.hour < 7;

      await achievementVM.setProgress(
        a.userAchievementId,
        wokeEarly ? 1.0 : 0.0,
      );
    }

    // sleep_score_daily — Healthy Rhythm: score >= 80 today
    for (final a in achievementVM.getByType('sleep_score_daily')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        hasTodayRecord ? todayScore.toDouble() : 0.0,
      );
    }

    // sleep_hours_daily — Full Recharge: sleep >= 8 hours today
    for (final a in achievementVM.getByType('sleep_hours_daily')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        hasTodayRecord ? todayHours : 0.0,
      );
    }

    // bedtime_consistency_daily — On The Dot: bed within 30 min of target
    for (final a in achievementVM.getByType('bedtime_consistency_daily')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        hasTodayRecord && bedtimeConsistentToday ? 1.0 : 0.0,
      );
    }

    // no_screen_time_daily — Phone Down: no phone 30 min before sleep
    for (final a in achievementVM.getByType('no_screen_time_daily')) {
      await achievementVM.setProgress(
        a.userAchievementId,
        hasTodayRecord && noScreenTimeToday ? 1.0 : 0.0,
      );
    }

    return currentStreak;
  }

  /// Walks backwards from today. Breaks on bad score or missing record.
  /// Today with no data gets a grace period (not yet synced).
  int computeStreak(Map<String, int> scoreByDate) {
    if (scoreByDate.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final day = dateKey(now.subtract(Duration(days: i)));
      final score = scoreByDate[day];

      if (score != null && score >= streakScoreThreshold) {
        streak++;
      } else if (i == 0 && score == null) {
        continue; // today, not yet synced
      } else {
        break; // bad score or missing record
      }
    }

    return streak;
  }

  int computeEarlyWakeStreak(Map<String, DateTime> wakeTimeByDay) {
    if (wakeTimeByDay.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final day = dateKey(now.subtract(Duration(days: i)));
      final wakeTime = wakeTimeByDay[day];

      if (wakeTime != null && wakeTime.hour < 7) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String normalizeDateKey(String rawDate) =>
      rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
}
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
      final dateKey = normalizeDateKey(record.date);

      if (record.totalMinutes > 0) {
        totalLogs++;
        totalLifetimeMinutes += record.totalMinutes;
      }

      scoreByDate[dateKey] = record.sleepScore;
      minutesByDate[dateKey] = record.totalMinutes;
    }

    final currentStreak = computeStreak(scoreByDate);
    final totalLifetimeHours = totalLifetimeMinutes / 60.0;
    final todayKey = dateKey(DateTime.now());
    final todayMinutes = minutesByDate[todayKey] ?? 0;
    final todayHours = todayMinutes / 60.0;
    final todayWakeTime = wakeTimeByDay[todayKey];

    // ─────────────────────────────────────────────────────────
    // PERMANENT achievements
    // ─────────────────────────────────────────────────────────

    // total_logs — Dream Beginner (1), Goal Crusher (100)
    for (final a in achievementVM.getByType('total_logs')) {
      await achievementVM.setProgress(a.userAchievementId, totalLogs.toDouble());
    }

    // sleep_score — Good Night (80), Deep Dreamer (90), Sleep Elite (95), Perfect Rest (100)
    for (final a in achievementVM.getByType('sleep_score')) {
      await achievementVM.setProgress(a.userAchievementId, dailySleepScore.toDouble());
    }

    // total_hours — Nap Snatcher (10), Hibernator (100), Sleep Marathon (500), Sleep Collector (1000)
    for (final a in achievementVM.getByType('total_hours')) {
      await achievementVM.setProgress(a.userAchievementId, totalLifetimeHours);
    }

    // streak_days — Three Peat (3), Week Warrior (7), Monthly Master (30), Consistency King (60)
    for (final a in achievementVM.getByType('streak_days')) {
      await achievementVM.setProgress(a.userAchievementId, currentStreak.toDouble());
    }

    // friends_count is handled in FriendViewModel.acceptRequest()

    // ─────────────────────────────────────────────────────────
    // DAILY achievements (reset each day by the repo)
    // ─────────────────────────────────────────────────────────

    // early_wake_daily — Early Bird: wake before 7 AM
    for (final a in achievementVM.getByType('early_wake_daily')) {
      final wokeEarly = todayWakeTime != null && todayWakeTime.hour < 7;
      await achievementVM.setProgress(a.userAchievementId, wokeEarly ? 1.0 : 0.0);
    }

    // sleep_score_daily — Healthy Rhythm: score >= 80 today
    for (final a in achievementVM.getByType('sleep_score_daily')) {
      await achievementVM.setProgress(a.userAchievementId, dailySleepScore.toDouble());
    }

    // sleep_hours_daily — Full Recharge: sleep >= 8 hours
    for (final a in achievementVM.getByType('sleep_hours_daily')) {
      await achievementVM.setProgress(a.userAchievementId, todayHours);
    }

    // bedtime_consistency_daily — On The Dot: bed within 30 min of target
    // TODO: Wire up when schedule comparison data is available
    for (final a in achievementVM.getByType('bedtime_consistency_daily')) {
      await achievementVM.setProgress(a.userAchievementId, bedtimeConsistentToday ? 1.0 : 0.0);
    }

    // no_screen_time_daily — Phone Down: no phone 30 min before sleep
    // TODO: Wire up when screen time tracking data is available
    for (final a in achievementVM.getByType('no_screen_time_daily')) {
      await achievementVM.setProgress(a.userAchievementId, noScreenTimeToday ? 1.0 : 0.0);
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
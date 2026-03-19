import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';

class SleepAchievementService {
  // Only nights with score >= this threshold count toward streak
  static const int streakScoreThreshold = 70;

  /// Updates all achievement progress and returns the current streak count.
  /// Streak is returned so the caller (SleepViewModel) can update profile.streak.
  Future<int> updateAchievements({
    required List<SleepRecordModel>  allRecords,
    required Map<String, DateTime>   wakeTimeByDay,
    required int                     dailySleepScore,
    required AchievementViewModel    achievementVM,
  }) async {
    int totalLogs            = 0;
    int totalLifetimeMinutes = 0;
    final Set<String> streakDates = {};  // score >= threshold only

    for (final record in allRecords) {
      if (record.totalMinutes > 0) {
        totalLogs++;
        totalLifetimeMinutes += record.totalMinutes;

        // Only count toward streak if score meets threshold
        if (record.sleepScore >= streakScoreThreshold) {
          streakDates.add(normalizeDateKey(record.date));
        }
      }
    }

    final currentStreak       = computeStreakFromDates(streakDates);
    final totalLifetimeHours  = totalLifetimeMinutes / 60.0;
    final earlyWakeStreak     = computeEarlyWakeStreak(wakeTimeByDay).toDouble();
    final score               = dailySleepScore.toDouble();

    // Update achievement progress (no streak_days here — stored in profile.streak)
    for (final a in achievementVM.getByType('total_logs')) {
      await achievementVM.setProgress(a.userAchievementId, totalLogs.toDouble());
    }

    for (final a in achievementVM.getByType('sleep_score')) {
      await achievementVM.setProgress(a.userAchievementId, score);
    }

    for (final a in achievementVM.getByType('total_hours')) {
      await achievementVM.setProgress(a.userAchievementId, totalLifetimeHours);
    }

    for (final a in achievementVM.getByType('early_wake_streak')) {
      await achievementVM.setProgress(a.userAchievementId, earlyWakeStreak);
    }

    return currentStreak;
  }

  int computeStreakFromDates(Set<String> dates) {
    if (dates.isEmpty) return 0;

    int streak    = 0;
    final now     = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final dayKey = dateKey(now.subtract(Duration(days: i)));
      if (dates.contains(dayKey)) {
        streak++;
      } else {
        if (i == 0) continue;  // allow today to be missing (not yet synced)
        break;
      }
    }

    return streak;
  }

  int computeEarlyWakeStreak(Map<String, DateTime> wakeTimeByDay) {
    if (wakeTimeByDay.isEmpty) return 0;

    int streak = 0;
    final now  = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final dayKey  = dateKey(now.subtract(Duration(days: i)));
      final wakeTime = wakeTimeByDay[dayKey];

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
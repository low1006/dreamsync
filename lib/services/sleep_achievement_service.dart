import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

class SleepAchievementService {
  Future<void> updateAchievements({
    required List<SleepRecordModel> allRecords,
    required Map<String, DateTime> wakeTimeByDay,
    required int dailySleepScore,
    required AchievementViewModel achievementVM,
  }) async {
    int totalLogs = 0;
    int totalLifetimeMinutes = 0;
    final Set<String> sleepDates = <String>{};

    for (final record in allRecords) {
      if (record.totalMinutes > 0) {
        totalLogs++;
        totalLifetimeMinutes += record.totalMinutes;
        sleepDates.add(normalizeDateKey(record.date));
      }
    }

    final currentStreak = computeStreakFromDates(sleepDates).toDouble();
    final totalLifetimeHours = totalLifetimeMinutes / 60.0;
    final earlyWakeStreak = computeEarlyWakeStreak(wakeTimeByDay).toDouble();
    final score = dailySleepScore.toDouble();

    for (final a in achievementVM.getByType('total_logs')) {
      await achievementVM.setProgress(a.userAchievementId, totalLogs.toDouble());
    }

    for (final a in achievementVM.getByType('streak_days')) {
      await achievementVM.setProgress(a.userAchievementId, currentStreak);
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
  }

  int computeStreakFromDates(Set<String> dates) {
    if (dates.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final dayKey = dateKey(now.subtract(Duration(days: i)));

      if (dates.contains(dayKey)) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  int computeEarlyWakeStreak(Map<String, DateTime> wakeTimeByDay) {
    if (wakeTimeByDay.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final dayKey = dateKey(now.subtract(Duration(days: i)));
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

  String dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String normalizeDateKey(String rawDate) {
    return rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
  }
}

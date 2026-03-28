import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';

class SleepAchievementService {
  /// Used only for profile / leaderboard streak.
  static const int streakScoreThreshold = 70;

  Future<int> updateAchievements({
    required String userId,
    required InventoryRepository inventoryRepository,
    required List<SleepRecordModel> allRecords,
    required Map<String, DateTime> wakeTimeByDay,
    required int dailySleepScore,
    required AchievementViewModel achievementVM,
    required int friendCount,

    /// Optional data for centralized daily algorithms.
    Map<String, DateTime> sleepStartByDay = const {},
    int? targetBedtimeMinutesOfDay,
    Map<String, int> preSleepScreenMinutesByDay = const {},

    /// Temporary backward-compatible fallbacks.
    bool? bedtimeConsistentTodayOverride,
    bool? noScreenTimeTodayOverride,
  }) async {
    int totalLogs = 0;
    int totalLifetimeMinutes = 0;
    int bestLifetimeSleepScore = 0;

    final Map<String, bool> hasLogByDate = {};
    final Map<String, int> scoreByDate = {};
    final Map<String, int> minutesByDate = {};

    for (final record in allRecords) {
      final normalizedKey = normalizeDateKey(record.date);

      if (record.totalMinutes > 0) {
        totalLogs++;
        totalLifetimeMinutes += record.totalMinutes;

        hasLogByDate[normalizedKey] = true;
        scoreByDate[normalizedKey] = record.sleepScore;
        minutesByDate[normalizedKey] = record.totalMinutes;

        if (record.sleepScore > bestLifetimeSleepScore) {
          bestLifetimeSleepScore = record.sleepScore;
        }
      }
    }

    // 1) Profile / leaderboard streak:
    // consecutive days with score >= 70, with streak shield support.
    final profileQualityStreak = await computeQualityStreakWithShield(
      scoreByDate: scoreByDate,
      userId: userId,
      inventoryRepository: inventoryRepository,
    );

    // 2) Consecutive milestone achievement:
    // consecutive days with a valid sleep record.
    final loggingConsecutiveDays = computeLoggingConsecutiveDays(
      hasLogByDate: hasLogByDate,
    );

    final totalLifetimeHours = totalLifetimeMinutes / 60.0;

    final todayKey = dateKey(DateTime.now());
    final hasTodayRecord =
        hasLogByDate[todayKey] == true &&
            scoreByDate.containsKey(todayKey) &&
            minutesByDate.containsKey(todayKey);

    final todayScore = hasTodayRecord ? (scoreByDate[todayKey] ?? 0) : 0;
    final todayMinutes = hasTodayRecord ? (minutesByDate[todayKey] ?? 0) : 0;
    final todayHours = todayMinutes / 60.0;
    final todayWakeTime = hasTodayRecord ? wakeTimeByDay[todayKey] : null;
    final todaySleepStart = hasTodayRecord ? sleepStartByDay[todayKey] : null;

    final wokeEarlyToday = _didWakeBefore7Am(todayWakeTime);

    final bedtimeConsistentToday =
        bedtimeConsistentTodayOverride ??
            _isBedtimeConsistent(
              sleepStart: todaySleepStart,
              targetBedtimeMinutesOfDay: targetBedtimeMinutesOfDay,
              allowedDeltaMinutes: 30,
            );

    final noScreenTimeToday =
        noScreenTimeTodayOverride ??
            _hasNoPreSleepScreenTime(
              preSleepWindowMinutes: preSleepScreenMinutesByDay[todayKey],
            );

    // =========================================================
    // PERMANENT ACHIEVEMENTS
    // =========================================================

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'total_logs',
      newValue: totalLogs.toDouble(),
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'friends_count',
      newValue: friendCount.toDouble(),
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'streak_days',
      newValue: loggingConsecutiveDays.toDouble(),
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'sleep_score',
      newValue: bestLifetimeSleepScore.toDouble(),
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'total_hours',
      newValue: totalLifetimeHours,
    );

    // =========================================================
    // DAILY ACHIEVEMENTS
    // =========================================================

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'early_wake_daily',
      newValue: hasTodayRecord && wokeEarlyToday ? 1.0 : 0.0,
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'sleep_score_daily',
      newValue: hasTodayRecord ? todayScore.toDouble() : 0.0,
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'sleep_hours_daily',
      newValue: hasTodayRecord ? todayHours : 0.0,
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'bedtime_consistency_daily',
      newValue: hasTodayRecord && bedtimeConsistentToday ? 1.0 : 0.0,
    );

    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'no_screen_time_daily',
      newValue: hasTodayRecord && noScreenTimeToday ? 1.0 : 0.0,
    );

    return profileQualityStreak;
  }

  Future<void> updateFriendAchievements({
    required int friendCount,
    required AchievementViewModel achievementVM,
  }) async {
    await _setAllForType(
      achievementVM: achievementVM,
      criteriaType: 'friends_count',
      newValue: friendCount.toDouble(),
    );
  }

  /// =========================================================
  /// PROFILE / LEADERBOARD STREAK
  /// =========================================================
  ///
  /// Consecutive days with sleep score >= 70.
  /// Supports one streak shield.
  Future<int> computeQualityStreakWithShield({
    required Map<String, int> scoreByDate,
    required String userId,
    required InventoryRepository inventoryRepository,
  }) async {
    if (scoreByDate.isEmpty) return 0;

    int streak = 0;
    bool shieldUsed = false;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final day = dateKey(now.subtract(Duration(days: i)));
      final score = scoreByDate[day];

      if (score != null && score >= streakScoreThreshold) {
        streak++;
        continue;
      }

      // Allow today to be empty without instantly breaking streak.
      if (i == 0 && score == null) {
        continue;
      }

      if (!shieldUsed) {
        final consumed = await inventoryRepository.tryConsumeStreakShield(
          userId: userId,
          dateKey: day,
        );

        if (consumed) {
          shieldUsed = true;
          streak++;
          continue;
        }
      }

      break;
    }

    return streak;
  }

  /// =========================================================
  /// CONSECUTIVE ACHIEVEMENT ALGORITHM
  /// =========================================================
  ///
  /// Used for achievement rows like:
  /// - 3 consecutive days
  /// - 7 consecutive days
  /// - 30 consecutive days
  /// - 60 consecutive days
  ///
  /// Rule:
  /// count consecutive days where the user HAS a valid sleep record.
  ///
  /// Today may still be empty before the user sleeps, so day 0 can be empty
  /// without breaking the chain.
  int computeLoggingConsecutiveDays({
    required Map<String, bool> hasLogByDate,
  }) {
    if (hasLogByDate.isEmpty) return 0;

    int consecutiveDays = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final day = dateKey(now.subtract(Duration(days: i)));
      final hasLog = hasLogByDate[day] == true;

      if (hasLog) {
        consecutiveDays++;
        continue;
      }

      // Allow today to be empty before user sleeps.
      if (i == 0 && !hasLog) {
        continue;
      }

      break;
    }

    return consecutiveDays;
  }

  int computeEarlyWakeStreak(Map<String, DateTime> wakeTimeByDay) {
    if (wakeTimeByDay.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final day = dateKey(now.subtract(Duration(days: i)));
      final wakeTime = wakeTimeByDay[day];

      if (_didWakeBefore7Am(wakeTime)) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  bool _didWakeBefore7Am(DateTime? wakeTime) {
    if (wakeTime == null) return false;
    final wakeMinutes = wakeTime.hour * 60 + wakeTime.minute;
    return wakeMinutes < 7 * 60;
  }

  bool _isBedtimeConsistent({
    required DateTime? sleepStart,
    required int? targetBedtimeMinutesOfDay,
    int allowedDeltaMinutes = 30,
  }) {
    if (sleepStart == null || targetBedtimeMinutesOfDay == null) return false;

    final actualMinutes = sleepStart.hour * 60 + sleepStart.minute;
    final diff = _minutesDifferenceCircular(
      actualMinutes,
      targetBedtimeMinutesOfDay,
    );

    return diff <= allowedDeltaMinutes;
  }

  bool _hasNoPreSleepScreenTime({
    required int? preSleepWindowMinutes,
  }) {
    if (preSleepWindowMinutes == null) return false;
    return preSleepWindowMinutes <= 0;
  }

  int _minutesDifferenceCircular(int a, int b) {
    final diff = (a - b).abs();
    return diff <= 720 ? diff : 1440 - diff;
  }

  Future<void> _setAllForType({
    required AchievementViewModel achievementVM,
    required String criteriaType,
    required double newValue,
  }) async {
    for (final a in achievementVM.getByType(criteriaType)) {
      await achievementVM.setProgress(a.userAchievementId, newValue);
    }
  }

  String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String normalizeDateKey(String rawDate) =>
      rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
}
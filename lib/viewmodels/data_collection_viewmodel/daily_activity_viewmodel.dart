import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 ADDED
import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

class DailyActivityViewModel extends ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();

  bool isLoading = false;

  int exerciseMinutes = 0;
  int foodCalories = 0;
  int screenTimeMinutes = 0;

  List<DailyActivityModel> weeklyData = [];

  // ─────────────────────────────────────────────────────────────
  // 1. Load today's data from the database
  // ─────────────────────────────────────────────────────────────
  Future<void> loadTodayData(String userId) async {
    isLoading = true;
    notifyListeners();

    final today = _getTodayDateString();
    final data = await _repository.getTodayActivity(userId, today);

    if (data != null) {
      exerciseMinutes = data.exerciseMinutes;
      foodCalories = data.foodCalories;
      screenTimeMinutes = data.screenTimeMinutes;
    }

    isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Add / update today's activity
  // ─────────────────────────────────────────────────────────────
  Future<void> addActivity({
    required String userId,
    int? addExercise,
    int? addFood,
    int? setScreenTime,
  }) async {
    final existing =
    await _repository.getTodayActivity(userId, _getTodayDateString());

    exerciseMinutes = existing?.exerciseMinutes ?? exerciseMinutes;
    foodCalories = existing?.foodCalories ?? foodCalories;
    screenTimeMinutes = existing?.screenTimeMinutes ?? screenTimeMinutes;

    if (addExercise != null) exerciseMinutes += addExercise;
    if (addFood != null) foodCalories += addFood;
    if (setScreenTime != null) screenTimeMinutes = setScreenTime;

    notifyListeners();

    await _repository.saveActivity(DailyActivityModel(
      userId: userId,
      date: _getTodayDateString(),
      exerciseMinutes: exerciseMinutes,
      foodCalories: foodCalories,
      screenTimeMinutes: screenTimeMinutes,
    ));

    await _fetchWeeklyFromDB(userId);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. Fetch today's total screen time from the OS and save it.
  // ─────────────────────────────────────────────────────────────
  Future<String> fetchAndSaveScreenTime(
      String userId,
      AchievementViewModel achievementVM,
      ) async {
    try {
      final DateTime endDate = DateTime.now();
      final DateTime startDate =
      DateTime(endDate.year, endDate.month, endDate.day);

      final List<AppUsageInfo> infoList =
      await AppUsage().getAppUsage(startDate, endDate);

      int totalMinutes = 0;
      for (var info in infoList) {
        totalMinutes += info.usage.inMinutes;
      }

      await addActivity(userId: userId, setScreenTime: totalMinutes);

      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    } catch (e) {
      debugPrint("❌ Error fetching screen time: $e");
      return "Need Permission";
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Phone Down achievement — sliding window check (BUG FIXED)
  // ─────────────────────────────────────────────────────────────
  Future<void> checkPreSleepScreenTime(
      DateTime sleepStart,
      AchievementViewModel achievementVM,
      ) async {
    try {
      // 🔥 FIX 1: THE GUARD
      // Check if we already rewarded the user for this EXACT sleep session
      final prefs = await SharedPreferences.getInstance();
      final lastAwardedSleep = prefs.getString('last_awarded_phone_down');
      final currentSleepId = sleepStart.toIso8601String();

      if (lastAwardedSleep == currentSleepId) {
        debugPrint("🛡️ Phone Down: Already awarded for this sleep session. Skipping.");
        return; // Stop here, prevent double counting!
      }

      final windowStart = sleepStart.subtract(const Duration(minutes: 30));

      final List<AppUsageInfo> infoList =
      await AppUsage().getAppUsage(windowStart, sleepStart);

      int preSleepMinutes = 0;
      for (var info in infoList) {
        preSleepMinutes += info.usage.inMinutes;
      }

      debugPrint(
          "📱 Pre-sleep screen time "
              "(${windowStart.hour}:${windowStart.minute.toString().padLeft(2, '0')} → "
              "${sleepStart.hour}:${sleepStart.minute.toString().padLeft(2, '0')}): "
              "${preSleepMinutes} min");

      if (preSleepMinutes == 0) {
        for (final a in achievementVM.getByType('no_screen_time')) {
          // Because of our Guard above, it is now safe to use updateProgress (+1.0)
          await achievementVM.updateProgress(a.userAchievementId, 1.0);
        }

        // 🔥 FIX 2: LOCK IT IN
        // Save this sleep session ID so we never reward it again
        await prefs.setString('last_awarded_phone_down', currentSleepId);

        debugPrint("✅ Phone Down: no usage in 30 min before sleep. Awarded +1!");
      } else {
        debugPrint(
            "❌ Phone Down: ${preSleepMinutes} min of usage before sleep — not awarded");
      }
    } catch (e) {
      debugPrint("❌ checkPreSleepScreenTime error: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 5. Sync the last 7 days of screen time from OS → Supabase
  // ─────────────────────────────────────────────────────────────
  Future<void> syncWeeklyScreenTime(String userId) async {
    try {
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final startDate =
        DateTime(targetDate.year, targetDate.month, targetDate.day);
        final endDate = i == 0
            ? now
            : DateTime(
            targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

        final infoList = await AppUsage().getAppUsage(startDate, endDate);
        int totalMinutes = 0;
        for (var info in infoList) {
          totalMinutes += info.usage.inMinutes;
        }

        final targetDateStr =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final existing =
        await _repository.getTodayActivity(userId, targetDateStr);

        await _repository.saveActivity(DailyActivityModel(
          userId: userId,
          date: targetDateStr,
          exerciseMinutes: existing?.exerciseMinutes ?? 0,
          foodCalories: existing?.foodCalories ?? 0,
          screenTimeMinutes: totalMinutes,
        ));
      }
    } catch (e) {
      debugPrint("❌ Error syncing weekly screen time: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 6. Load 7 days of behavioural data for the weekly charts
  // ─────────────────────────────────────────────────────────────
  Future<void> loadWeeklyData(String userId) async {
    try {
      await _fetchWeeklyFromDB(userId);
      await syncWeeklyScreenTime(userId);
      await _fetchWeeklyFromDB(userId);
    } catch (e) {
      debugPrint("❌ Error loading weekly behavioural data: $e");
    }
  }

  Future<void> _fetchWeeklyFromDB(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));

      final startDateStr =
          "${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}";
      final endDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final records = await _repository.getActivityByDateRange(
          userId, startDateStr, endDateStr);

      List<DailyActivityModel> filledRecords = [];
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetDateStr =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final existing =
            records.where((r) => r.date == targetDateStr).firstOrNull;

        filledRecords.add(existing ??
            DailyActivityModel(
              userId: userId,
              date: targetDateStr,
              exerciseMinutes: 0,
              foodCalories: 0,
              screenTimeMinutes: 0,
            ));
      }

      weeklyData = filledRecords;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching weekly activity from DB: $e");
    }
  }

  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }
}
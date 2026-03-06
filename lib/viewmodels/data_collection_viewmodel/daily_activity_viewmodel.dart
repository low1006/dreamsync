import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/models/daily_activity_model.dart';

class DailyActivityViewModel extends ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();

  bool isLoading = false;

  // UI State Variables
  int exerciseMinutes = 0;
  int foodCalories = 0;
  int screenTimeMinutes = 0;

  // Weekly data list for charts
  List<DailyActivityModel> weeklyData = [];

  // 1. Load today's data from the database
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

  // 2. Add new activity (🔥 FIXED: Foolproof to prevent wiping DB)
  Future<void> addActivity({
    required String userId,
    int? addExercise,
    int? addFood,
    int? setScreenTime,
  }) async {
    // 1. Fetch the absolute latest from DB first to prevent race condition wipes
    final existing = await _repository.getTodayActivity(userId, _getTodayDateString());

    // 2. Merge memory with DB truth to guarantee we never accidentally wipe data with 0s
    exerciseMinutes = existing?.exerciseMinutes ?? exerciseMinutes;
    foodCalories = existing?.foodCalories ?? foodCalories;
    screenTimeMinutes = existing?.screenTimeMinutes ?? screenTimeMinutes;

    // 3. Apply the new additions
    if (addExercise != null) exerciseMinutes += addExercise;
    if (addFood != null) foodCalories += addFood;
    if (setScreenTime != null) screenTimeMinutes = setScreenTime;

    notifyListeners();

    // 4. Save to DB
    final newRecord = DailyActivityModel(
      userId: userId,
      date: _getTodayDateString(),
      exerciseMinutes: exerciseMinutes,
      foodCalories: foodCalories,
      screenTimeMinutes: screenTimeMinutes,
    );

    await _repository.saveActivity(newRecord);

    // 5. Update Weekly Chart
    await _fetchWeeklyFromDB(userId);
  }

  // 3. Fetch today's screen time
  Future<String> fetchAndSaveScreenTime(String userId) async {
    try {
      final DateTime endDate = DateTime.now();
      final DateTime startDate = DateTime(endDate.year, endDate.month, endDate.day);

      final List<AppUsageInfo> infoList = await AppUsage().getAppUsage(startDate, endDate);

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

  // 4. Sync the last 7 days of Screen Time from the Android OS to Supabase
  Future<void> syncWeeklyScreenTime(String userId) async {
    try {
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final startDate = DateTime(targetDate.year, targetDate.month, targetDate.day);
        final endDate = i == 0 ? now : DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

        final infoList = await AppUsage().getAppUsage(startDate, endDate);
        int totalMinutes = 0;
        for (var info in infoList) {
          totalMinutes += info.usage.inMinutes;
        }

        final targetDateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final existing = await _repository.getTodayActivity(userId, targetDateStr);

        final newRecord = DailyActivityModel(
          userId: userId,
          date: targetDateStr,
          exerciseMinutes: existing?.exerciseMinutes ?? 0,
          foodCalories: existing?.foodCalories ?? 0,
          screenTimeMinutes: totalMinutes,
        );

        await _repository.saveActivity(newRecord);
      }
    } catch (e) {
      debugPrint("❌ Error syncing weekly screen time: $e");
    }
  }

  // 5. Load 7 days of behavioural data for the Weekly Charts
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

      final startDateStr = "${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}";
      final endDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final records = await _repository.getActivityByDateRange(userId, startDateStr, endDateStr);

      List<DailyActivityModel> filledRecords = [];
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetDateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final existing = records.where((r) => r.date == targetDateStr).firstOrNull;

        if (existing != null) {
          filledRecords.add(existing);
        } else {
          filledRecords.add(DailyActivityModel(
            userId: userId,
            date: targetDateStr,
            exerciseMinutes: 0,
            foodCalories: 0,
            screenTimeMinutes: 0,
          ));
        }
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
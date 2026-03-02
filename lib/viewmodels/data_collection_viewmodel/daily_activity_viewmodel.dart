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

  // 2. Add new activity (e.g., user inputs they ate a 500 kcal burger)
  Future<void> addActivity({
    required String userId,
    int? addExercise,
    int? addFood,
    int? setScreenTime, // Screen time is overwritten, not accumulated
  }) async {
    // Update local UI variables
    if (addExercise != null) exerciseMinutes += addExercise;
    if (addFood != null) foodCalories += addFood;
    if (setScreenTime != null) screenTimeMinutes = setScreenTime;

    notifyListeners(); // Updates the UI instantly

    // Save the new totals to the database
    final newRecord = DailyActivityModel(
      userId: userId,
      date: _getTodayDateString(),
      exerciseMinutes: exerciseMinutes,
      foodCalories: foodCalories,
      screenTimeMinutes: screenTimeMinutes,
    );

    await _repository.saveActivity(newRecord);
  }

  // 3. NEW: Fetch screen time from the OS and save it to the database.
  //    This is the missing pipeline that mirrors how SleepViewModel
  //    fetches from Health Connect and then calls syncSleepDataToSupabase.
  Future<String> fetchAndSaveScreenTime(String userId) async {
    try {
      // Define the time range: midnight today → right now
      final DateTime endDate = DateTime.now();
      final DateTime startDate =
      DateTime(endDate.year, endDate.month, endDate.day);

      // Fetch per-app usage stats from the OS
      final List<AppUsageInfo> infoList =
      await AppUsage().getAppUsage(startDate, endDate);

      // Sum all apps into a single total
      int totalMinutes = 0;
      for (var info in infoList) {
        totalMinutes += info.usage.inMinutes;
      }

      // Persist to Supabase via addActivity
      await addActivity(userId: userId, setScreenTime: totalMinutes);

      // Return a formatted string for the UI to display
      final int hours = totalMinutes ~/ 60;
      final int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    } catch (e) {
      debugPrint("❌ Error fetching screen time: $e");
      return "Need Permission";
    }
  }

  // Helper method to get the date format Supabase expects (YYYY-MM-DD)
  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }
}
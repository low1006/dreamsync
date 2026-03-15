import 'package:flutter/material.dart';
import 'package:app_usage/app_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';

import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

class DailyActivityViewModel extends ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();
  final Health _health = Health();

  bool isLoading = false;

  int exerciseMinutes = 0;
  int foodCalories = 0;
  int screenTimeMinutes = 0;

  List<DailyActivityModel> weeklyData = [];

  Future<void> loadTodayData(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      final today = _getTodayDateString();

      await _repository.ensureTodayRow(userId, today);
      final data = await _repository.getTodayActivity(userId, today);

      exerciseMinutes = data?.exerciseMinutes ?? 0;
      foodCalories = data?.foodCalories ?? 0;
      screenTimeMinutes = data?.screenTimeMinutes ?? 0;

      debugPrint(
        "📍 Today data => date=$today, screen=$screenTimeMinutes, exercise=$exerciseMinutes, food=$foodCalories",
      );
    } catch (e) {
      debugPrint("❌ loadTodayData error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addActivity({
    required String userId,
    int? addExercise,
    int? addFood,
    int? setScreenTime,
    int? setExercise,
  }) async {
    final today = _getTodayDateString();

    await _repository.ensureTodayRow(userId, today);
    final existing = await _repository.getTodayActivity(userId, today);

    int nextExercise = existing?.exerciseMinutes ?? 0;
    int nextFood = existing?.foodCalories ?? 0;
    int nextScreen = existing?.screenTimeMinutes ?? 0;

    if (addExercise != null) nextExercise += addExercise;
    if (addFood != null) nextFood += addFood;
    if (setScreenTime != null) nextScreen = setScreenTime;
    if (setExercise != null) nextExercise = setExercise;

    exerciseMinutes = nextExercise;
    foodCalories = nextFood;
    screenTimeMinutes = nextScreen;

    debugPrint(
      "💾 Saving activity => date=$today, screen=$screenTimeMinutes, exercise=$exerciseMinutes, food=$foodCalories",
    );

    await _repository.saveActivity(
      DailyActivityModel(
        userId: userId,
        date: today,
        exerciseMinutes: exerciseMinutes,
        foodCalories: foodCalories,
        screenTimeMinutes: screenTimeMinutes,
      ),
    );

    await _fetchWeeklyFromDB(userId);
    notifyListeners();
  }

  Future<String> fetchAndSaveScreenTime(
      String userId,
      AchievementViewModel achievementVM,
      ) async {
    try {
      final todayKey = _getTodayDateString();
      final prefs = await SharedPreferences.getInstance();
      final lastFetchedDate = prefs.getString('screen_time_last_fetch_date');

      await _repository.ensureTodayRow(userId, todayKey);
      final existing = await _repository.getTodayActivity(userId, todayKey);

      if (lastFetchedDate == todayKey &&
          existing != null &&
          existing.screenTimeMinutes > 0) {
        screenTimeMinutes = existing.screenTimeMinutes;
        debugPrint(
          "📱 Using cached today screen time => date=$todayKey, screen=$screenTimeMinutes",
        );
        notifyListeners();
        return formatScreenTime(screenTimeMinutes);
      }

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final infoList = await AppUsage().getAppUsage(startOfToday, now);

      int totalMinutes = 0;
      for (final info in infoList) {
        totalMinutes += info.usage.inMinutes;
      }

      debugPrint(
        "📱 Fetched screen time from OS => date=$todayKey, totalMinutes=$totalMinutes",
      );

      await addActivity(userId: userId, setScreenTime: totalMinutes);
      await prefs.setString('screen_time_last_fetch_date', todayKey);

      final verify = await _repository.getTodayActivity(userId, todayKey);
      debugPrint(
        "✅ Verify after save => date=$todayKey, savedScreen=${verify?.screenTimeMinutes}",
      );

      return formatScreenTime(totalMinutes);
    } catch (e) {
      debugPrint("❌ Error fetching screen time: $e");
      return "Need Usage Access";
    }
  }

  Future<int> fetchTodayExerciseMinutesFromHealthConnect() async {
    try {
      _health.configure();

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final types = <HealthDataType>[
        HealthDataType.WORKOUT,
      ];

      final permissions = <HealthDataAccess>[
        HealthDataAccess.READ,
      ];

      final hasPermissions = await _health.hasPermissions(
        types,
        permissions: permissions,
      );

      bool granted = hasPermissions == true;
      if (!granted) {
        granted = await _health.requestAuthorization(
          types,
          permissions: permissions,
        ) ??
            false;
      }

      if (!granted) {
        debugPrint("⚠️ Exercise permission denied.");
        return 0;
      }

      final data = await _health.getHealthDataFromTypes(
        startTime: startOfToday,
        endTime: now,
        types: types,
      );

      final cleaned = _health.removeDuplicates(data);

      int totalMinutes = 0;
      for (final point in cleaned) {
        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        if (minutes > 0) {
          totalMinutes += minutes;
        }
      }

      debugPrint(
        "🏃 Health Connect exercise total today => $totalMinutes minutes",
      );

      return totalMinutes;
    } catch (e) {
      debugPrint("❌ Error fetching exercise from Health Connect: $e");
      return 0;
    }
  }

  Future<int> fetchAndSaveExerciseFromHealthConnect(String userId) async {
    try {
      final todayKey = _getTodayDateString();
      final prefs = await SharedPreferences.getInstance();
      final lastFetchedDate = prefs.getString('exercise_last_fetch_date');

      await _repository.ensureTodayRow(userId, todayKey);
      final existing = await _repository.getTodayActivity(userId, todayKey);

      if (lastFetchedDate == todayKey &&
          existing != null &&
          existing.exerciseMinutes > 0) {
        exerciseMinutes = existing.exerciseMinutes;
        debugPrint(
          "🏃 Using cached today exercise => date=$todayKey, exercise=$exerciseMinutes",
        );
        notifyListeners();
        return exerciseMinutes;
      }

      final totalMinutes = await fetchTodayExerciseMinutesFromHealthConnect();

      await addActivity(userId: userId, setExercise: totalMinutes);
      await prefs.setString('exercise_last_fetch_date', todayKey);

      final verify = await _repository.getTodayActivity(userId, todayKey);
      debugPrint(
        "✅ Verify exercise after save => date=$todayKey, savedExercise=${verify?.exerciseMinutes}",
      );

      return totalMinutes;
    } catch (e) {
      debugPrint("❌ Error saving exercise from Health Connect: $e");
      return 0;
    }
  }

  Future<void> loadWeeklyData(String userId) async {
    try {
      await _fetchWeeklyFromDB(userId);
      notifyListeners();
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
        userId,
        startDateStr,
        endDateStr,
      );

      debugPrint("📊 Weekly DB raw records count: ${records.length}");
      for (final r in records) {
        debugPrint(
          "📊 Weekly row => date=${r.date}, screen=${r.screenTimeMinutes}, exercise=${r.exerciseMinutes}, food=${r.foodCalories}",
        );
      }

      final Map<String, DailyActivityModel> recordsByDate = {
        for (final record in records) record.date: record,
      };

      final List<DailyActivityModel> filledRecords = [];

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetDateStr =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final row = recordsByDate[targetDateStr] ??
            DailyActivityModel(
              userId: userId,
              date: targetDateStr,
              exerciseMinutes: 0,
              foodCalories: 0,
              screenTimeMinutes: 0,
            );

        filledRecords.add(row);
      }

      weeklyData = filledRecords;

      debugPrint("📊 Weekly filled data:");
      for (final r in weeklyData) {
        debugPrint(
          "📊 Filled => date=${r.date}, screen=${r.screenTimeMinutes}, exercise=${r.exerciseMinutes}, food=${r.foodCalories}",
        );
      }
    } catch (e) {
      debugPrint("❌ Error fetching weekly activity from DB: $e");
      weeklyData = [];
    }
  }

  String formatScreenTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  String _getTodayDateString() {
    final today = DateTime.now();
    return "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  }
}
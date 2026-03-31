import "package:dreamsync/util/parsers.dart";
import 'package:flutter/material.dart';
import 'package:health/health.dart';

import 'package:dreamsync/repositories/daily_activity_repository.dart';
import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel/achievement_viewmodel.dart';
import 'package:dreamsync/services/screen_time_service.dart';
import 'package:dreamsync/services/sync_service.dart';

class DailyActivityViewModel extends ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();
  final Health _health = Health();
  final ScreenTimeService _screenTimeService = ScreenTimeService();
  final SyncService _syncService = SyncService();

  bool isLoading = false;
  bool _hasRestoredFromCloud = false;

  int exerciseMinutes = 0;
  int foodCalories = 0;
  int screenTimeMinutes = 0;
  int burnedCalories = 0;
  double caffeineIntakeMg = 0;
  double sugarIntakeG = 0;
  double alcoholIntakeG = 0;

  List<DailyActivityModel> weeklyData = [];

  Future<void> loadTodayData(String userId) async {
    isLoading = true;
    notifyListeners();

    try {
      if (!_hasRestoredFromCloud) {
        _hasRestoredFromCloud = true;
        if (await _syncService.isActivityLocalEmpty(userId)) {
          debugPrint('📦 Activity DB empty — restoring from encrypted cloud.');
          await _syncService.restoreActivityFromCloud(userId);
        }
      }

      final today = Parsers.todayKey();

      await _repository.ensureTodayRow(userId, today);
      final data = await _repository.getTodayActivity(userId, today);

      exerciseMinutes = data?.exerciseMinutes ?? 0;
      foodCalories = data?.foodCalories ?? 0;
      screenTimeMinutes = data?.screenTimeMinutes ?? 0;
      burnedCalories = data?.burnedCalories ?? 0;
      caffeineIntakeMg = data?.caffeineIntakeMg ?? 0;
      sugarIntakeG = data?.sugarIntakeG ?? 0;
      alcoholIntakeG = data?.alcoholIntakeG ?? 0;

      debugPrint(
        "📍 Today data => date=$today, screen=$screenTimeMinutes, exercise=$exerciseMinutes, food=$foodCalories, burned=$burnedCalories, caffeine=$caffeineIntakeMg, sugar=$sugarIntakeG, alcohol=$alcoholIntakeG",
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
    int? setBurnedCalories,
    int? addBurnedCalories,
    double? addCaffeine,
    double? addSugar,
    double? addAlcohol,
  }) async {
    final today = Parsers.todayKey();

    await _repository.ensureTodayRow(userId, today);
    final existing = await _repository.getTodayActivity(userId, today);

    int nextExercise = existing?.exerciseMinutes ?? 0;
    int nextFood = existing?.foodCalories ?? 0;
    int nextScreen = existing?.screenTimeMinutes ?? 0;
    int nextBurned = existing?.burnedCalories ?? 0;
    double nextCaffeine = existing?.caffeineIntakeMg ?? 0;
    double nextSugar = existing?.sugarIntakeG ?? 0;
    double nextAlcohol = existing?.alcoholIntakeG ?? 0;

    if (addExercise != null) nextExercise += addExercise;
    if (addFood != null) nextFood += addFood;
    if (setScreenTime != null) nextScreen = setScreenTime;
    if (setExercise != null) nextExercise = setExercise;
    if (setBurnedCalories != null) nextBurned = setBurnedCalories;
    if (addBurnedCalories != null) nextBurned += addBurnedCalories;
    if (addCaffeine != null) nextCaffeine += addCaffeine;
    if (addSugar != null) nextSugar += addSugar;
    if (addAlcohol != null) nextAlcohol += addAlcohol;

    exerciseMinutes = nextExercise;
    foodCalories = nextFood;
    screenTimeMinutes = nextScreen;
    burnedCalories = nextBurned;
    caffeineIntakeMg = nextCaffeine;
    sugarIntakeG = nextSugar;
    alcoholIntakeG = nextAlcohol;

    debugPrint(
      "💾 Saving activity => date=$today, screen=$screenTimeMinutes, exercise=$exerciseMinutes, food=$foodCalories, burned=$burnedCalories, caffeine=$caffeineIntakeMg, sugar=$sugarIntakeG, alcohol=$alcoholIntakeG",
    );

    await _repository.saveActivity(
      DailyActivityModel(
        userId: userId,
        date: today,
        exerciseMinutes: exerciseMinutes,
        foodCalories: foodCalories,
        screenTimeMinutes: screenTimeMinutes,
        burnedCalories: burnedCalories,
        caffeineIntakeMg: caffeineIntakeMg,
        sugarIntakeG: sugarIntakeG,
        alcoholIntakeG: alcoholIntakeG,
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
      final todayKey = Parsers.todayKey();

      await _repository.ensureTodayRow(userId, todayKey);

      // Always re-fetch from device — screen time grows throughout the day
      final screenTimeData = await _screenTimeService.getDailyScreenTimeData();

      if (screenTimeData.milliseconds < 0) {
        return "Need Usage Access";
      }

      final totalMinutes = screenTimeData.totalMinutes;

      debugPrint(
        "📱 Fetched screen time => date=$todayKey, "
            "rawMs=${screenTimeData.milliseconds}, "
            "minutes=${screenTimeData.totalMinutes}, "
            "formatted=${screenTimeData.formatted}",
      );

      await addActivity(userId: userId, setScreenTime: totalMinutes);

      await _syncService.syncActivityRecords(userId);

      final verify = await _repository.getTodayActivity(userId, todayKey);
      debugPrint(
        "✅ Verify after save => date=$todayKey, savedScreen=${verify?.screenTimeMinutes}",
      );

      return screenTimeData.formatted;
    } catch (e) {
      debugPrint("❌ Error fetching screen time: $e");
      return "Error fetching data";
    }
  }

  Future<int?> fetchTodayExerciseMinutesFromHealthConnect() async {
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
        );
      }

      if (!granted) {
        debugPrint("⚠️ Exercise permission denied.");
        return null;
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

      debugPrint("🏃 Health Connect exercise total today => $totalMinutes minutes");
      return totalMinutes;
    } catch (e) {
      debugPrint("❌ Error fetching exercise from Health Connect: $e");
      return null;
    }
  }

  Future<int> fetchAndSaveExerciseFromHealthConnect(String userId) async {
    try {
      final todayKey = Parsers.todayKey();

      await _repository.ensureTodayRow(userId, todayKey);
      final existing = await _repository.getTodayActivity(userId, todayKey);
      final currentValue = existing?.exerciseMinutes ?? 0;

      final totalMinutes = await fetchTodayExerciseMinutesFromHealthConnect();

      if (totalMinutes == null) {
        debugPrint("⚠️ Exercise not updated because permission/data fetch failed.");
        return currentValue;
      }

      // Only overwrite if HC returns MORE than current stored value.
      // This prevents HC (which may return 0) from wiping manual entries.
      if (totalMinutes > currentValue) {
        await addActivity(userId: userId, setExercise: totalMinutes);
        debugPrint(
          "🏃 HC exercise ($totalMinutes) > stored ($currentValue) — updated.",
        );
      } else {
        exerciseMinutes = currentValue;
        debugPrint(
          "🏃 HC exercise ($totalMinutes) ≤ stored ($currentValue) — keeping manual entry.",
        );
        notifyListeners();
      }

      await _syncService.syncActivityRecords(userId);

      final verify = await _repository.getTodayActivity(userId, todayKey);
      debugPrint(
        "✅ Verify exercise after save => date=$todayKey, savedExercise=${verify?.exerciseMinutes}",
      );

      return verify?.exerciseMinutes ?? exerciseMinutes;
    } catch (e) {
      debugPrint("❌ Error saving exercise from Health Connect: $e");
      return exerciseMinutes;
    }
  }

  Future<int?> fetchTodayBurnedCaloriesFromHealthConnect() async {
    try {
      _health.configure();

      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final types = <HealthDataType>[
        HealthDataType.ACTIVE_ENERGY_BURNED,
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
        );
      }

      if (!granted) {
        debugPrint("⚠️ Burned calories permission denied.");
        return null;
      }

      final data = await _health.getHealthDataFromTypes(
        startTime: startOfToday,
        endTime: now,
        types: types,
      );

      final cleaned = _health.removeDuplicates(data);

      double totalCalories = 0;

      for (final point in cleaned) {
        final value = point.value;

        if (value is NumericHealthValue) {
          totalCalories += value.numericValue.toDouble();
        } else {
          final parsed = double.tryParse(value.toString());
          if (parsed != null) {
            totalCalories += parsed;
          }
        }
      }

      final rounded = totalCalories.round();
      debugPrint("🔥 Health Connect burned calories today => $rounded kcal");
      return rounded;
    } catch (e) {
      debugPrint("❌ Error fetching burned calories from Health Connect: $e");
      return null;
    }
  }

  Future<int> fetchAndSaveBurnedCaloriesFromHealthConnect(String userId) async {
    try {
      final todayKey = Parsers.todayKey();

      await _repository.ensureTodayRow(userId, todayKey);
      final existing = await _repository.getTodayActivity(userId, todayKey);
      final currentValue = existing?.burnedCalories ?? 0;

      final totalCalories = await fetchTodayBurnedCaloriesFromHealthConnect();

      if (totalCalories == null) {
        debugPrint("⚠️ Burned calories not updated because permission/data fetch failed.");
        return currentValue;
      }

      // Only overwrite if HC returns MORE than current stored value.
      // This prevents HC (which may return 0) from wiping manual entries
      // (e.g. calories added from the exercise search dialog).
      if (totalCalories > currentValue) {
        await addActivity(userId: userId, setBurnedCalories: totalCalories);
        debugPrint(
          "🔥 HC burned ($totalCalories) > stored ($currentValue) — updated.",
        );
      } else {
        burnedCalories = currentValue;
        debugPrint(
          "🔥 HC burned ($totalCalories) ≤ stored ($currentValue) — keeping manual entry.",
        );
        notifyListeners();
      }

      await _syncService.syncActivityRecords(userId);

      final verify = await _repository.getTodayActivity(userId, todayKey);
      debugPrint(
        "✅ Verify burned calories after save => date=$todayKey, savedBurned=${verify?.burnedCalories}",
      );

      return verify?.burnedCalories ?? burnedCalories;
    } catch (e) {
      debugPrint("❌ Error saving burned calories from Health Connect: $e");
      return burnedCalories;
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
          "📊 Weekly row => date=${r.date}, screen=${r.screenTimeMinutes}, exercise=${r.exerciseMinutes}, food=${r.foodCalories}, burned=${r.burnedCalories}",
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
              burnedCalories: 0,
              caffeineIntakeMg: 0,
              sugarIntakeG: 0,
              alcoholIntakeG: 0,
            );

        filledRecords.add(row);
      }

      weeklyData = filledRecords;

      debugPrint("📊 Weekly filled data:");
      for (final r in weeklyData) {
        debugPrint(
          "📊 Filled => date=${r.date}, screen=${r.screenTimeMinutes}, exercise=${r.exerciseMinutes}, food=${r.foodCalories}, burned=${r.burnedCalories}",
        );
      }
    } catch (e) {
      debugPrint("❌ Error fetching weekly activity from DB: $e");
      weeklyData = [];
    }
  }
}
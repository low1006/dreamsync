import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/models/sleep_record_model.dart';
import 'package:dreamsync/viewmodels/achievement_viewmodel.dart';

class SleepChartPoint {
  final double hour;
  final double stage;

  SleepChartPoint(this.hour, this.stage);
}

enum SleepFilter { daily, weekly }

class SleepViewModel extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = "";
  bool isDataPendingSync = false;

  final health = Health();
  final SleepRepository _repository = SleepRepository();

  SleepFilter currentFilter = SleepFilter.daily;

  List<HealthDataPoint> _rawHealthData = [];

  // Daily-specific state
  String dailyTotalSleepDuration = "0h 0m";
  int dailySleepScore = 0;
  String dailyDeepSleep = "0h 0m";
  String dailyLightSleep = "0h 0m";
  String dailyRemSleep = "0h 0m";
  List<SleepChartPoint> hypnogramData = [];

  // Weekly-specific state
  String weeklyTotalSleepDuration = "0h 0m";
  int weeklySleepScore = 0;

  List<SleepRecordModel> weeklyData = [];

  final List<HealthDataType> _sleepDataTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_ASLEEP,
  ];

  // ─────────────────────────────────────────────────────────────
  // MAIN LOAD — Fetches from Health Connect, syncs to DB, checks achievements
  // ─────────────────────────────────────────────────────────────
  Future<void> loadSleepData({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
  }) async {
    isLoading = true;
    errorMessage = "";
    notifyListeners();

    try {
      health.configure();

      final status = await health.getHealthConnectSdkStatus();

      if (status == HealthConnectSdkStatus.sdkUnavailable ||
          status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        isLoading = false;
        notifyListeners();
        if (context != null && context.mounted) {
          _showInstallHealthConnectDialog(context);
        } else {
          debugPrint("⚠️ Background sync: Health Connect not available.");
        }
        return;
      }

      final permissions =
      _sleepDataTypes.map((e) => HealthDataAccess.READ).toList();

      bool? hasPermissions = await health.hasPermissions(
          _sleepDataTypes, permissions: permissions);

      if (hasPermissions != true) {
        if (context != null) {
          bool authorized = await health.requestAuthorization(
            _sleepDataTypes,
            permissions: permissions,
          );

          if (!authorized) {
            errorMessage = "Permission denied.";
            isLoading = false;
            notifyListeners();
            return;
          }
        } else {
          debugPrint("⚠️ Background sync aborted: Missing Health Connect permissions.");
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(days: 30));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: _sleepDataTypes,
      );

      _rawHealthData = health.removeDuplicates(healthData);

      _processSleepData(SleepFilter.daily);
      _processSleepData(SleepFilter.weekly);

      await syncSleepDataToSupabase(userId);
      await fetchWeeklyDataFromDatabase(userId);

      await _checkSleepAchievements(userId, achievementVM);
    } catch (e) {
      debugPrint("Error fetching from Health Connect: $e");
      errorMessage = "Failed to sync with Health Connect. Ensure data exists.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData({
    BuildContext? context,
    required String userId,
    required AchievementViewModel achievementVM,
  }) async {
    await loadSleepData(
        context: context,
        userId: userId,
        achievementVM: achievementVM
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACHIEVEMENT CHECKS — Called after every successful sync
  // ─────────────────────────────────────────────────────────────
  Future<void> _checkSleepAchievements(
      String userId, AchievementViewModel achievementVM) async {
    try {
      final allRecords = await _repository.getAllSleepRecords(userId);

      // ── 1. total_logs ──────────────────────────────────────────
      final totalLogs = allRecords
          .where((r) => r.totalMinutes > 0)
          .length
          .toDouble();

      for (final a in achievementVM.getByType('total_logs')) {
        await achievementVM.setProgress(a.userAchievementId, totalLogs);
      }

      // ── 2. streak_days ─────────────────────────────────────────
      final currentStreak = _computeStreak(allRecords).toDouble();

      for (final a in achievementVM.getByType('streak_days')) {
        await achievementVM.setProgress(a.userAchievementId, currentStreak);
      }

      // ── 3. sleep_score ─────────────────────────────────────────
      final score = dailySleepScore.toDouble();

      for (final a in achievementVM.getByType('sleep_score')) {
        await achievementVM.setProgress(a.userAchievementId, score);
      }

      // ── 4. total_hours ─────────────────────────────────────────
      // ✅ FIXED: Calculate true lifetime sleep hours across all records
      final totalLifetimeMinutes = allRecords.fold<int>(
          0, (sum, r) => sum + r.totalMinutes);

      final totalLifetimeHours = totalLifetimeMinutes / 60.0;

      debugPrint(
          "🏆 total_hours: total accumulated ${totalLifetimeHours.toStringAsFixed(2)}h");

      for (final a in achievementVM.getByType('total_hours')) {
        await achievementVM.setProgress(a.userAchievementId, totalLifetimeHours);
      }

      // ── 5. early_wake_streak ───────────────────────────────────
      final earlyWakeStreak = _computeEarlyWakeStreak().toDouble();

      for (final a in achievementVM.getByType('early_wake_streak')) {
        await achievementVM.setProgress(a.userAchievementId, earlyWakeStreak);
      }

    } catch (e) {
      debugPrint("❌ Error checking sleep achievements: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPER — Streak: consecutive days with sleep > 0 (newest first)
  // ─────────────────────────────────────────────────────────────
  int _computeStreak(List<SleepRecordModel> allRecords) {
    if (allRecords.isEmpty) return 0;

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

      final record = allRecords
          .where((r) => r.date.startsWith(dayStr) && r.totalMinutes > 0)
          .firstOrNull;

      if (record != null) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPER — Early wake streak
  // ─────────────────────────────────────────────────────────────
  int _computeEarlyWakeStreak() {
    if (_rawHealthData.isEmpty) return 0;

    final Map<String, DateTime> wakeTimeByDay = {};

    for (final point in _rawHealthData) {
      if (point.type != HealthDataType.SLEEP_SESSION &&
          point.type != HealthDataType.SLEEP_ASLEEP) continue;

      final dayStr =
          "${point.dateTo.year}-${point.dateTo.month.toString().padLeft(2, '0')}-${point.dateTo.day.toString().padLeft(2, '0')}";

      if (!wakeTimeByDay.containsKey(dayStr) ||
          point.dateTo.isAfter(wakeTimeByDay[dayStr]!)) {
        wakeTimeByDay[dayStr] = point.dateTo;
      }
    }

    int streak = 0;
    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      final dayStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

      final wakeTime = wakeTimeByDay[dayStr];

      if (wakeTime != null && wakeTime.hour < 7) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    return streak;
  }

  // ─────────────────────────────────────────────────────────────
  // WEEKLY DB FETCH
  // ─────────────────────────────────────────────────────────────
  Future<void> fetchWeeklyDataFromDatabase(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));

      final startDateStr =
          "${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}";
      final endDateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final endDateQuery = "$endDateStr 23:59:59";

      final records = await _repository.getSleepRecordsByDateRange(
          userId, startDateStr, endDateQuery);

      List<SleepRecordModel> filledRecords = [];

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetDateStr =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        final existingRecord =
            records.where((r) => r.date.startsWith(targetDateStr)).firstOrNull;

        if (existingRecord != null) {
          filledRecords.add(existingRecord);
        } else {
          filledRecords.add(SleepRecordModel(
            userId: userId,
            date: targetDateStr,
            totalMinutes: 0,
            sleepScore: 0,
          ));
        }
      }

      weeklyData = filledRecords;
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching weekly data from DB: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FILTER
  // ─────────────────────────────────────────────────────────────
  void changeFilter(SleepFilter newFilter) {
    if (currentFilter != newFilter) {
      currentFilter = newFilter;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PROCESS
  // ─────────────────────────────────────────────────────────────
  void _processSleepData(SleepFilter filter) {
    if (filter == SleepFilter.daily) {
      isDataPendingSync = false;
    }

    if (_rawHealthData.isEmpty) {
      _resetDisplayData(filter);
      return;
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    List<HealthDataPoint> filteredData = [];

    switch (filter) {
      case SleepFilter.daily:
        DateTime latestDate = _rawHealthData
            .reduce((a, b) => a.dateTo.isAfter(b.dateTo) ? a : b)
            .dateTo;

        DateTime latestMidnight =
        DateTime(latestDate.year, latestDate.month, latestDate.day);
        DateTime yesterdayMidnight =
        todayMidnight.subtract(const Duration(days: 1));

        if (now.hour < 12) {
          if (latestMidnight.isBefore(yesterdayMidnight)) {
            isDataPendingSync = true;
          }
        } else {
          if (latestMidnight.isBefore(todayMidnight)) {
            isDataPendingSync = true;
          }
        }

        filteredData = _rawHealthData
            .where((p) =>
        p.dateTo.year == latestDate.year &&
            p.dateTo.month == latestDate.month &&
            p.dateTo.day == latestDate.day)
            .toList();
        break;

      case SleepFilter.weekly:
        final weekStart = todayMidnight.subtract(const Duration(days: 7));
        filteredData =
            _rawHealthData.where((p) => p.dateTo.isAfter(weekStart)).toList();
        break;
    }

    if (filteredData.isEmpty) {
      _resetDisplayData(filter);
      return;
    }

    int totalMinutes = 0;
    int deepMin = 0;
    int lightMin = 0;
    int remMin = 0;

    bool hasSessions =
    filteredData.any((p) => p.type == HealthDataType.SLEEP_SESSION);
    Set<String> uniqueDays = {};
    List<SleepChartPoint> newHypnogramData = [];

    for (var point in filteredData) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes;
      uniqueDays.add(
          "${point.dateTo.year}-${point.dateTo.month}-${point.dateTo.day}");

      if (point.type == HealthDataType.SLEEP_DEEP) {
        deepMin += duration;
      } else if (point.type == HealthDataType.SLEEP_LIGHT ||
          point.type == HealthDataType.SLEEP_ASLEEP) {
        lightMin += duration;
      } else if (point.type == HealthDataType.SLEEP_REM) {
        remMin += duration;
      }

      if (hasSessions) {
        if (point.type == HealthDataType.SLEEP_SESSION) totalMinutes += duration;
      } else {
        if (point.type != HealthDataType.SLEEP_AWAKE &&
            point.type != HealthDataType.SLEEP_SESSION) {
          totalMinutes += duration;
        }
      }

      if (filter == SleepFilter.daily &&
          point.type != HealthDataType.SLEEP_SESSION) {
        double stageVal = 0;
        if (point.type == HealthDataType.SLEEP_REM) stageVal = 1;
        else if (point.type == HealthDataType.SLEEP_LIGHT ||
            point.type == HealthDataType.SLEEP_ASLEEP) stageVal = 2;
        else if (point.type == HealthDataType.SLEEP_DEEP) stageVal = 3;

        double hour = point.dateFrom.hour + (point.dateFrom.minute / 60.0);
        if (hour > 12) hour -= 24;

        newHypnogramData.add(SleepChartPoint(hour, stageVal));
      }
    }

    if (filter == SleepFilter.daily) {
      newHypnogramData.sort((a, b) => a.hour.compareTo(b.hour));
      hypnogramData = newHypnogramData;
    }

    if (filter != SleepFilter.daily) {
      int daysCount = uniqueDays.isNotEmpty ? uniqueDays.length : 1;
      totalMinutes = totalMinutes ~/ daysCount;
      deepMin = deepMin ~/ daysCount;
      lightMin = lightMin ~/ daysCount;
      remMin = remMin ~/ daysCount;
    }

    if (filter == SleepFilter.daily) {
      dailyTotalSleepDuration = _formatMinutes(totalMinutes);
      dailyDeepSleep = _formatMinutes(deepMin);
      dailyLightSleep = _formatMinutes(lightMin);
      dailyRemSleep = _formatMinutes(remMin);
      dailySleepScore = totalMinutes > 0
          ? ((totalMinutes / 480) * 100).clamp(0, 100).toInt()
          : 0;
    } else {
      weeklyTotalSleepDuration = _formatMinutes(totalMinutes);
      weeklySleepScore = totalMinutes > 0
          ? ((totalMinutes / 480) * 100).clamp(0, 100).toInt()
          : 0;
    }
  }

  void _resetDisplayData(SleepFilter filter) {
    if (filter == SleepFilter.daily) {
      dailyTotalSleepDuration = "0h 0m";
      dailySleepScore = 0;
      dailyDeepSleep = "0h 0m";
      dailyLightSleep = "0h 0m";
      dailyRemSleep = "0h 0m";
      hypnogramData = [];
    } else {
      weeklyTotalSleepDuration = "0h 0m";
      weeklySleepScore = 0;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SYNC
  // ─────────────────────────────────────────────────────────────
  Future<void> syncSleepDataToSupabase(String userId) async {
    try {
      Map<String, int> dailyTotals = {};
      bool hasSessions =
      _rawHealthData.any((p) => p.type == HealthDataType.SLEEP_SESSION);

      for (var point in _rawHealthData) {
        final dateStr =
            "${point.dateTo.year}-${point.dateTo.month.toString().padLeft(2, '0')}-${point.dateTo.day.toString().padLeft(2, '0')}";
        int duration = point.dateTo.difference(point.dateFrom).inMinutes;

        if (hasSessions) {
          if (point.type == HealthDataType.SLEEP_SESSION) {
            dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0) + duration;
          }
        } else {
          if (point.type != HealthDataType.SLEEP_AWAKE) {
            dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0) + duration;
          }
        }
      }

      for (var entry in dailyTotals.entries) {
        final totalMins = entry.value;
        if (totalMins > 0) {
          int dailyScore = ((totalMins / 480) * 100).clamp(0, 100).toInt();
          await _repository.saveDailySummary(SleepRecordModel(
            userId: userId,
            date: entry.key,
            totalMinutes: totalMins,
            sleepScore: dailyScore,
          ));
        }
      }
    } catch (e) {
      debugPrint("❌ Error syncing sleep data: $e");
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return "0h 0m";
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOG
  // ─────────────────────────────────────────────────────────────
  void _showInstallHealthConnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: Colors.blueAccent),
            SizedBox(width: 10),
            Text("Health Connect Required", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          "To sync your sleep data, DreamSync requires the official Google Health Connect app. "
              "Would you like to install it from the Play Store now?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final Uri playStoreUri = Uri.parse(
                  "https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata");
              if (await canLaunchUrl(playStoreUri)) {
                await launchUrl(playStoreUri,
                    mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("Install"),
          ),
        ],
      ),
    );
  }
}
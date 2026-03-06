import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dreamsync/repositories/sleep_repository.dart';
import 'package:dreamsync/models/sleep_record_model.dart';

class SleepChartPoint {
  final double hour;
  final double stage;

  SleepChartPoint(this.hour, this.stage);
}

enum SleepFilter { daily, weekly}

class SleepViewModel extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = "";
  bool isDataPendingSync = false;

  final health = Health();
  final SleepRepository _repository = SleepRepository();

  SleepFilter currentFilter = SleepFilter.daily;

  List<HealthDataPoint> _rawHealthData = [];

  String totalSleepDuration = "0h 0m";
  int sleepScore = 0;
  String deepSleep = "0h 0m";
  String lightSleep = "0h 0m";
  String remSleep = "0h 0m";

  List<SleepChartPoint> hypnogramData = [];
  List<SleepRecordModel> weeklyData = [];

  final List<HealthDataType> _sleepDataTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<void> loadSleepData(BuildContext context, String userId) async {
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
        if (context.mounted) {
          _showInstallHealthConnectDialog(context);
        }
        return;
      }

      final permissions = _sleepDataTypes.map((e) => HealthDataAccess.READ).toList();

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

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(days: 30));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: _sleepDataTypes,
      );

      _rawHealthData = health.removeDuplicates(healthData);

      _processSleepData();

      await syncSleepDataToSupabase(userId);
      await fetchWeeklyDataFromDatabase(userId);

    } catch (e) {
      debugPrint("Error fetching from Health Connect: $e");
      errorMessage = "Failed to sync with Health Connect. Ensure data exists.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 🔥 UPDATE: This function now guarantees exactly 7 records, filling missing days with 0s
  Future<void> fetchWeeklyDataFromDatabase(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));

      final startDateStr = "${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}";
      final endDateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final records = await _repository.getSleepRecordsByDateRange(userId, startDateStr, endDateStr);

      List<SleepRecordModel> filledRecords = [];

      // Loop exactly 7 times (6 days ago -> Today)
      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final targetDateStr = "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        // Try to find a matching record in the database
        final existingRecord = records.where((r) => r.date == targetDateStr).firstOrNull;

        if (existingRecord != null) {
          filledRecords.add(existingRecord);
        } else {
          // If the user didn't sync sleep that day, inject a "0" so the chart still draws the Day label!
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

  void changeFilter(SleepFilter newFilter) {
    if (currentFilter != newFilter) {
      currentFilter = newFilter;
      _processSleepData();
      notifyListeners();
    }
  }

  void _processSleepData() {
    isDataPendingSync = false;

    if (_rawHealthData.isEmpty) {
      _resetDisplayData();
      return;
    }

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    List<HealthDataPoint> filteredData = [];

    switch (currentFilter) {
      case SleepFilter.daily:
        if (_rawHealthData.isNotEmpty) {
          DateTime latestDate = _rawHealthData.reduce((a, b) =>
          a.dateTo.isAfter(b.dateTo) ? a : b).dateTo;

          DateTime latestMidnight = DateTime(latestDate.year, latestDate.month, latestDate.day);
          DateTime yesterdayMidnight = todayMidnight.subtract(const Duration(days: 1));

          if (now.hour < 12) {
            if (latestMidnight.isBefore(yesterdayMidnight)) {
              isDataPendingSync = true;
            }
          } else {
            if (latestMidnight.isBefore(todayMidnight)) {
              isDataPendingSync = true;
            }
          }

          filteredData = _rawHealthData.where((p) =>
          p.dateTo.year == latestDate.year &&
              p.dateTo.month == latestDate.month &&
              p.dateTo.day == latestDate.day
          ).toList();
        }
        break;
      case SleepFilter.weekly:
        final weekStart = todayMidnight.subtract(const Duration(days: 7));
        filteredData = _rawHealthData.where((p) => p.dateTo.isAfter(weekStart)).toList();
        break;
    }

    if (filteredData.isEmpty) {
      _resetDisplayData();
      return;
    }

    int totalMinutes = 0;
    int deepMin = 0;
    int lightMin = 0;
    int remMin = 0;

    bool hasSessions = filteredData.any((p) => p.type == HealthDataType.SLEEP_SESSION);
    Set<String> uniqueDays = {};
    hypnogramData = [];

    for (var point in filteredData) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes;
      uniqueDays.add("${point.dateTo.year}-${point.dateTo.month}-${point.dateTo.day}");

      if (point.type == HealthDataType.SLEEP_DEEP) {
        deepMin += duration;
      } else if (point.type == HealthDataType.SLEEP_LIGHT || point.type == HealthDataType.SLEEP_ASLEEP) {
        lightMin += duration;
      } else if (point.type == HealthDataType.SLEEP_REM) {
        remMin += duration;
      }

      if (hasSessions) {
        if (point.type == HealthDataType.SLEEP_SESSION) totalMinutes += duration;
      } else {
        if (point.type != HealthDataType.SLEEP_AWAKE && point.type != HealthDataType.SLEEP_SESSION) {
          totalMinutes += duration;
        }
      }

      if (currentFilter == SleepFilter.daily && point.type != HealthDataType.SLEEP_SESSION) {
        double stageVal = 0;
        if (point.type == HealthDataType.SLEEP_REM) stageVal = 1;
        else if (point.type == HealthDataType.SLEEP_LIGHT || point.type == HealthDataType.SLEEP_ASLEEP) stageVal = 2;
        else if (point.type == HealthDataType.SLEEP_DEEP) stageVal = 3;

        double hour = point.dateFrom.hour + (point.dateFrom.minute / 60.0);
        if (hour > 12) hour -= 24;

        hypnogramData.add(SleepChartPoint(hour, stageVal));
      }
    }

    if (currentFilter == SleepFilter.daily) {
      hypnogramData.sort((a, b) => a.hour.compareTo(b.hour));
    } else {
      hypnogramData = [];
    }

    if (currentFilter != SleepFilter.daily) {
      int daysCount = uniqueDays.isNotEmpty ? uniqueDays.length : 1;
      totalMinutes = totalMinutes ~/ daysCount;
    }

    totalSleepDuration = _formatMinutes(totalMinutes);
    deepSleep = _formatMinutes(deepMin);
    lightSleep = _formatMinutes(lightMin);
    remSleep = _formatMinutes(remMin);

    if (totalMinutes > 0) {
      sleepScore = ((totalMinutes / 480) * 100).clamp(0, 100).toInt();
    } else {
      sleepScore = 0;
    }
  }

  void _resetDisplayData() {
    totalSleepDuration = "0h 0m";
    sleepScore = 0;
    deepSleep = "0h 0m";
    lightSleep = "0h 0m";
    remSleep = "0h 0m";
    hypnogramData = [];
  }

  Future<void> syncSleepDataToSupabase(String userId) async {
    try {
      Map<String, int> dailyTotals = {};
      bool hasSessions = _rawHealthData.any((p) => p.type == HealthDataType.SLEEP_SESSION);

      for (var point in _rawHealthData) {
        final dateStr = "${point.dateTo.year}-${point.dateTo.month.toString().padLeft(2, '0')}-${point.dateTo.day.toString().padLeft(2, '0')}";
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
        final dateString = entry.key;
        final totalMins = entry.value;

        if (totalMins > 0) {
          int dailyScore = ((totalMins / 480) * 100).clamp(0, 100).toInt();

          final newRecord = SleepRecordModel(
            userId: userId,
            date: dateString,
            totalMinutes: totalMins,
            sleepScore: dailyScore,
          );

          await _repository.saveDailySummary(newRecord);
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

  Future<void> refreshData(BuildContext context, String userId) async {
    await loadSleepData(context, userId);
  }

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
              final Uri playStoreUri = Uri.parse("https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata");
              if (await canLaunchUrl(playStoreUri)) {
                await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text("Install"),
          ),
        ],
      ),
    );
  }
}
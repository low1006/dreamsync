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

class SleepViewModel extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = "";

  final health = Health();
  final SleepRepository _repository = SleepRepository();

  String totalSleepDuration = "0h 0m";
  int sleepScore = 0;
  String deepSleep = "0h 0m";
  String lightSleep = "0h 0m";
  String remSleep = "0h 0m";

  List<SleepChartPoint> hypnogramData = [];
  bool useDummyData = true;

  final List<HealthDataType> _sleepDataTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
  ];

  Future<void> loadSleepData(BuildContext context, String userId) async {
    isLoading = true;
    errorMessage = "";
    notifyListeners();

    if (useDummyData) {
      _loadDummyData();
      await syncSleepDataToSupabase(userId);
      isLoading = false;
      notifyListeners();
      return;
    }

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
        errorMessage = "Permission to access Health Connect was denied.";
        return;
      }

      final now = DateTime.now();
      final startTime = now.subtract(const Duration(days: 2));

      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
        startTime: startTime,
        endTime: now,
        types: _sleepDataTypes,
      );

      _processSleepData(healthData);

      // Save real data to Supabase
      await syncSleepDataToSupabase(userId);

    } catch (e) {
      debugPrint("Error fetching from Health Connect: $e");
      errorMessage = "Failed to sync with Health Connect. Ensure the app is installed and has data.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncSleepDataToSupabase(String userId) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateString = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

      int totalMinutes = _parseDurationToMinutes(totalSleepDuration);
      if (totalMinutes == 0) return;

      // Creates the model with NO 'id'
      final newRecord = SleepRecordModel(
        userId: userId,
        date: dateString,
        totalMinutes: totalMinutes,
        sleepScore: sleepScore,
      );

      // Hands the model directly to the updated repository
      await _repository.saveDailySummary(newRecord);

    } catch (e) {
      debugPrint("❌ Error syncing sleep data: $e");
    }
  }

  void _loadDummyData() {
    totalSleepDuration = "7h 45m";
    sleepScore = 85;
    deepSleep = "2h 15m";
    lightSleep = "4h 0m";
    remSleep = "1h 30m";

    hypnogramData = [
      SleepChartPoint(0.0, 3),
      SleepChartPoint(0.5, 1),
      SleepChartPoint(1.0, 0),
      SleepChartPoint(2.5, 1),
      SleepChartPoint(3.0, 2),
      SleepChartPoint(4.0, 1),
      SleepChartPoint(5.5, 0),
      SleepChartPoint(6.5, 2),
      SleepChartPoint(7.5, 1),
      SleepChartPoint(8.0, 3),
    ];
  }

  void _processSleepData(List<HealthDataPoint> dataPoints) {
    if (dataPoints.isEmpty) {
      totalSleepDuration = "0h 0m";
      sleepScore = 0;
      deepSleep = "0h 0m";
      lightSleep = "0h 0m";
      remSleep = "0h 0m";
      hypnogramData = [];
      return;
    }

    int totalAsleepMinutes = 0;
    int deepSleepMinutes = 0;
    int lightSleepMinutes = 0;
    int remSleepMinutes = 0;

    for (var point in dataPoints) {
      final duration = point.dateTo.difference(point.dateFrom).inMinutes;

      switch (point.type) {
        case HealthDataType.SLEEP_ASLEEP:
          totalAsleepMinutes += duration;
          break;
        case HealthDataType.SLEEP_DEEP:
          deepSleepMinutes += duration;
          totalAsleepMinutes += duration;
          break;
        case HealthDataType.SLEEP_LIGHT:
          lightSleepMinutes += duration;
          totalAsleepMinutes += duration;
          break;
        case HealthDataType.SLEEP_REM:
          remSleepMinutes += duration;
          totalAsleepMinutes += duration;
          break;
        default:
          break;
      }
    }

    totalSleepDuration = _formatMinutes(totalAsleepMinutes);
    deepSleep = _formatMinutes(deepSleepMinutes);
    lightSleep = _formatMinutes(lightSleepMinutes);
    remSleep = _formatMinutes(remSleepMinutes);

    if (totalAsleepMinutes > 0) {
      sleepScore = ((totalAsleepMinutes / 480) * 100).clamp(0, 100).toInt();
    } else {
      sleepScore = 0;
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return "0h 0m";
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  int _parseDurationToMinutes(String durationStr) {
    try {
      if (durationStr == "0h 0m" || durationStr.isEmpty) return 0;
      final parts = durationStr.split(' ');
      int hours = int.parse(parts[0].replaceAll('h', ''));
      int minutes = int.parse(parts[1].replaceAll('m', ''));
      return (hours * 60) + minutes;
    } catch (e) {
      return 0;
    }
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
              final Uri playStoreUri = Uri.parse(
                  "https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata"
              );
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
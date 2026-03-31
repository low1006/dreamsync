import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class SleepHealthService {
  final Health health;

  SleepHealthService({Health? health}) : health = health ?? Health();

  List<HealthDataType> get sleepDataTypes => const [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_ASLEEP,
  ];

  Future<HealthConnectSdkStatus?> getSdkStatus() async {
    health.configure();
    final status = await health.getHealthConnectSdkStatus();
    debugPrint('🩺 Health Connect SDK status => $status');
    return status;
  }

  Future<bool> ensurePermissions({required bool requestIfNeeded}) async {
    final permissions =
    sleepDataTypes.map((_) => HealthDataAccess.READ).toList();

    final hasPermissions = await health.hasPermissions(
      sleepDataTypes,
      permissions: permissions,
    );

    debugPrint('🔐 Sleep permissions already granted => $hasPermissions');

    if (hasPermissions == true) return true;
    if (!requestIfNeeded) return false;

    final granted = await health.requestAuthorization(
      sleepDataTypes,
      permissions: permissions,
    ) ??
        false;

    debugPrint('🔐 Sleep permissions request result => $granted');
    return granted;
  }

  Future<List<HealthDataPoint>> fetchLast30DaysSleepData() async {
    final now = DateTime.now();
    final startTime = now.subtract(const Duration(days: 30));

    final healthData = await health.getHealthDataFromTypes(
      startTime: startTime,
      endTime: now,
      types: sleepDataTypes,
    );

    debugPrint('📥 Raw sleep points fetched => ${healthData.length}');

    final deduped = health.removeDuplicates(healthData);

    debugPrint('🧹 Sleep points after removeDuplicates => ${deduped.length}');

    return deduped;
  }
}
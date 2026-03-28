import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenTimeData {
  final int milliseconds;
  final int totalMinutes;
  final String formatted;

  const ScreenTimeData({
    required this.milliseconds,
    required this.totalMinutes,
    required this.formatted,
  });
}

class ScreenTimeService {
  static const MethodChannel platform =
  MethodChannel('com.example.dreamsync/screentime');

  Future<bool> hasUsagePermission() async {
    try {
      final bool hasPermission =
      await platform.invokeMethod('checkUsagePermission');
      return hasPermission;
    } on PlatformException catch (e) {
      debugPrint(
        "❌ Failed to check usage permission: '${e.message}'.",
      );
      return false;
    }
  }

  Future<void> requestUsagePermission() async {
    try {
      await platform.invokeMethod('requestUsagePermission');
    } on PlatformException catch (e) {
      debugPrint(
        "❌ Failed to request usage permission: '${e.message}'.",
      );
    }
  }

  Future<int> getDailyScreenTimeMillis() async {
    try {
      final bool hasPermission = await hasUsagePermission();

      if (!hasPermission) {
        debugPrint("📱 Usage permission not granted, requesting...");
        await requestUsagePermission();
        return -1;
      }

      final int? screenTimeMillis =
      await platform.invokeMethod<int>('getScreenTime');

      final result = screenTimeMillis ?? 0;
      debugPrint("📱 Daily screen time raw ms: $result");
      return result;
    } on PlatformException catch (e) {
      debugPrint(
        "❌ Failed to get screen time via MethodChannel: '${e.message}'.",
      );
      return 0;
    }
  }

  Future<int> getDailyScreenTimeMinutes() async {
    final int milliseconds = await getDailyScreenTimeMillis();
    if (milliseconds < 0) return -1;
    return Duration(milliseconds: milliseconds).inMinutes;
  }

  Future<String> getDailyScreenTimeFormatted() async {
    final int milliseconds = await getDailyScreenTimeMillis();
    if (milliseconds < 0) return 'Permission required';
    return formatScreenTime(milliseconds);
  }

  Future<ScreenTimeData> getDailyScreenTimeData() async {
    final int milliseconds = await getDailyScreenTimeMillis();

    if (milliseconds < 0) {
      return const ScreenTimeData(
        milliseconds: -1,
        totalMinutes: -1,
        formatted: 'Permission required',
      );
    }

    final int totalMinutes = Duration(milliseconds: milliseconds).inMinutes;

    return ScreenTimeData(
      milliseconds: milliseconds,
      totalMinutes: totalMinutes,
      formatted: formatScreenTime(milliseconds),
    );
  }

  String formatScreenTime(int milliseconds) {
    if (milliseconds <= 0) return '0m';

    final duration = Duration(milliseconds: milliseconds);
    final totalMinutes = duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
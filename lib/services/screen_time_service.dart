import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class ScreenTimeService {
  static const platform = MethodChannel('com.example.dreamsync/screentime');

  Future<int> getDailyScreenTimeMinutes() async {
    try {
      final bool hasPermission = await platform.invokeMethod('checkUsagePermission');

      if (!hasPermission) {
        debugPrint("📱 Usage permission not granted, requesting...");
        await platform.invokeMethod('requestUsagePermission');
        return -1; // Indicate that permission is needed
      }

      final int screenTimeMillis = await platform.invokeMethod('getScreenTime');

      // Convert milliseconds to minutes
      final int minutes = (screenTimeMillis / 1000 / 60).round();
      return minutes;

    } on PlatformException catch (e) {
      debugPrint("❌ Failed to get screen time via MethodChannel: '${e.message}'.");
      return 0;
    }
  }
}
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';

class PermissionService {
  PermissionService._(); // Prevent instantiation

  // ==========================================
  // 1. CORE APP STARTUP PERMISSIONS
  // ==========================================

  /// Call this once when the app starts (e.g., in main.dart)
  static Future<void> requestAppStartupPermissions(BuildContext context) async {
    // 1. Notification Permission (Required for Android 13+ and iOS)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      // 2. Exact Alarms Permission (Required for Android 12+ for precise alarms)
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      // 3. Ignore Battery Optimizations (Highly recommended for alarm apps to wake up)
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      // 4. Activity Recognition (Optional startup permission, good for step tracking)
      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    }
  }

  // ==========================================
  // 2. CONTEXTUAL PERMISSIONS (Call when needed)
  // ==========================================

  /// Request Health Connect Permission (Best called when the user opens the Sleep Dashboard)
  static Future<bool> requestHealthPermission(BuildContext context) async {
    final health = Health();

    final types = [
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_ASLEEP,
    ];

    final permissions =
    List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);

    try {
      final hasPermission = await health.hasPermissions(
        types,
        permissions: permissions,
      );

      if (hasPermission == true) return true;

      final granted = await health.requestAuthorization(
        types,
        permissions: permissions,
      );

      return granted;
    } catch (e) {
      debugPrint("❌ Health permission error: $e");
      return false;
    }
  }

  /// Explicit Activity Recognition check (if you need to force it with a dialog later)
  static Future<bool> requestActivityRecognitionPermission(
      BuildContext context) async {
    if (await Permission.activityRecognition.isGranted) {
      return true;
    }

    final status = await Permission.activityRecognition.request();

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        final goToSettings = await _showSettingsDialog(
          context,
          "Activity Permission Needed",
          "We need motion tracking to detect when you are walking vs sleeping. Please enable 'Physical Activity' in Settings.",
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }

    return status.isGranted;
  }

  // ==========================================
  // 3. UI HELPERS
  // ==========================================

  /// A beautiful bottom sheet dialog to guide users to Settings if a permission is permanently denied
  static Future<bool?> _showSettingsDialog(
      BuildContext context, String title, String content) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.settings_suggest, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Go To Settings"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Maybe Later"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
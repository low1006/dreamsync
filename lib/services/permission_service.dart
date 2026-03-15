import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';
import 'package:dreamsync/services/notification_service.dart';
import 'package:app_usage/app_usage.dart';

class PermissionService {
  PermissionService._();

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

  static Future<bool> requestActivityRecognitionPermission(
      BuildContext context,
      ) async {
    try {
      final status = await Permission.activityRecognition.status;
      if (status.isGranted) return true;

      final result = await Permission.activityRecognition.request();
      return result.isGranted;
    } catch (e) {
      debugPrint("❌ Activity recognition permission error: $e");
      return false;
    }
  }

  static Future<bool> requestUsageAccessPermission(
      BuildContext context,
      ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 1));

      // Small probe query to test whether usage access is available
      await AppUsage().getAppUsage(start, now);
      return true;
    } catch (e) {
      debugPrint("❌ Usage access not granted or query failed: $e");

      final goToSettings = await _showExplanationBottomSheet(
        context,
        "Usage Access Required",
        "To read your daily screen time, DreamSync needs Usage Access permission. On the next screen, open 'Usage access' or 'Usage data access' and allow DreamSync.",
      );

      if (goToSettings != true) return false;

      await openAppSettings();
      return false;
    }
  }

  static Future<bool> requestExactAlarmPermission(
      BuildContext context,
      ) async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isGranted) return true;

      final goToSettings = await _showExplanationBottomSheet(
        context,
        "Exact Alarms Required",
        "To ensure your alarm rings exactly on time, we need this permission. Please allow it on the next screen.",
      );

      if (goToSettings != true) return false;

      final result = await Permission.scheduleExactAlarm.request();
      return result.isGranted;
    } catch (e) {
      debugPrint("❌ Exact alarm permission error: $e");
      return false;
    }
  }

  static Future<bool> requestOverlayPermission(
      BuildContext context,
      ) async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.systemAlertWindow.status;
      if (status.isGranted) return true;

      final goToSettings = await _showExplanationBottomSheet(
        context,
        "Display Over Other Apps",
        "We need this to wake your screen up and show the alarm when your phone is locked. Please allow it on the next screen.",
      );

      if (goToSettings != true) return false;

      final result = await Permission.systemAlertWindow.request();
      return result.isGranted;
    } catch (e) {
      debugPrint("❌ Overlay permission error: $e");
      return false;
    }
  }

  static Future<bool> requestDndPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    try {
      final hasDnd = await NotificationService().hasDndAccess();
      if (hasDnd) return true;

      final goToSettings = await _showExplanationBottomSheet(
        context,
        "Do Not Disturb Access",
        "To automatically silence distractions during bedtime, we need Do Not Disturb access. Please allow it on the next screen.",
      );

      if (goToSettings != true) return false;

      await NotificationService().openDndSettings();
      return await NotificationService().hasDndAccess();
    } catch (e) {
      debugPrint("❌ DND permission error: $e");
      return false;
    }
  }

  static Future<bool?> _showExplanationBottomSheet(
      BuildContext context,
      String title,
      String content,
      ) {
    return showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
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
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

class PermissionService {
  PermissionService._();

  static Future<void> requestAppStartupPermissions(BuildContext context) async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    if (Platform.isAndroid) {
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }

      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }

      if (await Permission.activityRecognition.isDenied) {
        await Permission.activityRecognition.request();
      }
    }
  }

  static Future<bool> requestHealthPermission(BuildContext context) async {
    final health = Health();

    final types = [
      HealthDataType.SLEEP_SESSION,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_REM,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WORKOUT,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    ];

    final permissions =
    List<HealthDataAccess>.filled(types.length, HealthDataAccess.READ);

    try {
      _showInfoSnackBar(
        context,
        'Requesting Health Connect access...',
      );

      final hasPermission = await health.hasPermissions(
        types,
        permissions: permissions,
      );

      if (hasPermission == true) {
        return true;
      }

      final granted = await health.requestAuthorization(
        types,
        permissions: permissions,
      );

      if (granted) {
        _showSuccessSnackBar(
          context,
          'Health Connect access granted.',
        );
        return true;
      }

      if (context.mounted) {
        final action = await _showHealthConnectDeniedDialog(context);
        if (action == _HealthDialogAction.settings) {
          await openAppSettings();
        } else if (action == _HealthDialogAction.install) {
          await _openHealthConnectPlayStore();
        }
      }

      return false;
    } catch (e) {
      debugPrint("❌ Health permission error: $e");

      if (context.mounted) {
        final action = await _showHealthConnectErrorDialog(context, e.toString());
        if (action == _HealthDialogAction.settings) {
          await openAppSettings();
        } else if (action == _HealthDialogAction.install) {
          await _openHealthConnectPlayStore();
        }
      }

      return false;
    }
  }

  static Future<bool> requestActivityRecognitionPermission(
      BuildContext context,
      ) async {
    if (await Permission.activityRecognition.isGranted) {
      return true;
    }

    final status = await Permission.activityRecognition.request();

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        final goToSettings = await _showSettingsDialog(
          context,
          "Activity Permission Needed",
          "We need motion tracking to detect when you are walking vs sleeping. Please enable Physical Activity in Settings.",
        );
        if (goToSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }

    if (status.isDenied && context.mounted) {
      _showErrorSnackBar(
        context,
        'Physical Activity permission was denied.',
      );
    }

    return status.isGranted;
  }

  static Future<_HealthDialogAction?> _showHealthConnectDeniedDialog(
      BuildContext context,
      ) {
    return showModalBottomSheet<_HealthDialogAction>(
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
              const Icon(
                Icons.health_and_safety_outlined,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                "Health Connect Access Needed",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                "DreamSync could not read your exercise or calories data because Health Connect permission was not granted.\n\nPlease allow access to exercise and calories burned so the behavioural data can be shown.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(ctx, _HealthDialogAction.settings),
                icon: const Icon(Icons.settings),
                label: const Text("Open App Settings"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(ctx, _HealthDialogAction.install),
                icon: const Icon(Icons.download),
                label: const Text("Open Health Connect"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _HealthDialogAction.cancel),
                child: const Text("Maybe Later"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<_HealthDialogAction?> _showHealthConnectErrorDialog(
      BuildContext context,
      String error,
      ) {
    return showModalBottomSheet<_HealthDialogAction>(
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
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                "Health Connect Error",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "DreamSync could not access Health Connect.\n\n$error\n\nPlease check that Health Connect is installed and permissions are enabled.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(ctx, _HealthDialogAction.settings),
                icon: const Icon(Icons.settings),
                label: const Text("Open App Settings"),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pop(ctx, _HealthDialogAction.install),
                icon: const Icon(Icons.download),
                label: const Text("Open Health Connect"),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, _HealthDialogAction.cancel),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool?> _showSettingsDialog(
      BuildContext context,
      String title,
      String content,
      ) {
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

  static Future<void> _openHealthConnectPlayStore() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void _showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

enum _HealthDialogAction {
  settings,
  install,
  cancel,
}
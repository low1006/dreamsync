import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

@pragma('vm:entry-point')
void fireAlarmCallback(int id) {
  // This runs in a separate isolate when the alarm fires.
  // We re-initialize the NotificationService to show the UI.
  NotificationService().showAlarmNotification(id);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // 1. Define the MethodChannel to match your Kotlin code
  static const platform = MethodChannel('com.example.dreamsync/alarm');

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- NEW: Store snooze preferences ---
  final Map<int, bool> _snoozeEnabled = {};


  Future<void> init() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones();

    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint("âš ï¸ Error setting timezone: $e");
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }

    // 2. iOS Setup (Keep this for iOS support)
    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      iOS: initializationSettingsDarwin,
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // --- FIXED: ADDED MISSING METHOD ---
  bool isSnoozeEnabled(int alarmId) {
    // Return true by default if not found (safe default)
    return _snoozeEnabled[alarmId] ?? true;
  }

  // --- FIXED: ADDED MISSING METHOD ---
  Future<void> scheduleSnooze(int notificationId) async {
    debugPrint("ðŸ’¤ Scheduling snooze for ID: $notificationId");

    // 1. Stop the audio
    await stopAlarmSound();

    // 2. Calculate snooze time (9 minutes from now)
    final now = DateTime.now();
    final snoozeTime = now.add(const Duration(minutes: 9));
    final snoozeTimeMillis = snoozeTime.millisecondsSinceEpoch;

    // 3. Create a unique snooze ID (add 100000 to avoid conflict with main alarms)
    final snoozeId = notificationId + 100000;

    try {
      if (Platform.isAndroid) {
        // Call Native Android Alarm
        await platform.invokeMethod('scheduleAlarm', {
          'notificationId': snoozeId,
          'title': 'Snooze',
          'scheduledTime': snoozeTimeMillis,
          'repeatWeekly': false, // Snooze runs only once
        });
      } else {
        // iOS Fallback
        await flutterLocalNotificationsPlugin.zonedSchedule(
          snoozeId,
          "Snooze",
          "Time to wake up!",
          tz.TZDateTime.from(snoozeTime, tz.local),
          const NotificationDetails(iOS: DarwinNotificationDetails(sound: 'buzzer.mp3', presentSound: true, presentAlert: true)),
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
      debugPrint("âœ… Snooze scheduled for: $snoozeTime");
    } catch (e) {
      debugPrint("âŒ Error scheduling snooze: $e");
    }
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required List<String> days,
    required bool isEnabled,
    required bool isSnoozeOn,
  }) async {
    // 1. Cancel existing alarms first
    await cancelAlarm(id);

    if (!isEnabled || days.isEmpty) return;

    // --- SAVE SNOOZE PREFERENCE ---
    _snoozeEnabled[id] = isSnoozeOn;

    // 2. Iterate through selected days
    for (String day in days) {
      final notificationId = _createUniqueId(id, day);
      final nextTime = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      // Calculate milliseconds for Java/Kotlin
      final int scheduledTimeMillis = nextTime.millisecondsSinceEpoch;

      debugPrint("ðŸ“… Scheduling Native Alarm for $day at $nextTime (ID: $notificationId)");

      try {
        if (Platform.isAndroid) {
          // CALL NATIVE KOTLIN METHOD
          await platform.invokeMethod('scheduleAlarm', {
            'notificationId': notificationId,
            'title': title,
            'scheduledTime': scheduledTimeMillis,
            'repeatWeekly': true,
          });
        } else {
          // iOS Fallback
          _scheduleIOSAlarm(notificationId, title, nextTime);
        }
      } catch (e) {
        debugPrint("âŒ Error scheduling native alarm: $e");
      }
    }
  }

  Future<void> cancelAlarm(int id) async {
    final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    for (var day in allDays) {
      final uniqueId = _createUniqueId(id, day);

      try {
        if (Platform.isAndroid) {
          // CANCEL NATIVE KOTLIN ALARM
          await platform.invokeMethod('cancelAlarm', {'notificationId': uniqueId});
          await platform.invokeMethod('cancelAlarm', {'notificationId': uniqueId + 100000}); // Snooze ID
        } else {
          await flutterLocalNotificationsPlugin.cancel(uniqueId);
          await flutterLocalNotificationsPlugin.cancel(uniqueId + 100000);
        }
      } catch (e) {
        debugPrint("âŒ Error canceling native alarm: $e");
      }
    }
    _snoozeEnabled.remove(id);
    debugPrint("ðŸ—‘ï¸ Cancelled all alarms for ID: $id");
  }

  // Helper for iOS only
  Future<void> _scheduleIOSAlarm(int id, String title, tz.TZDateTime scheduledDate) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      "Time to wake up!",
      scheduledDate,
      const NotificationDetails(iOS: DarwinNotificationDetails(sound: 'buzzer.mp3', presentSound: true, presentAlert: true)),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // --- HELPERS ---
  int _createUniqueId(int baseId, String day) {
    int safeBase = baseId.abs() % 100000;
    int dayOffset = _getDayOfWeek(day);
    return (safeBase * 10) + dayOffset;
  }

  int _getDayOfWeek(String day) {
    switch (day) {
      case 'Mon': return DateTime.monday;
      case 'Tue': return DateTime.tuesday;
      case 'Wed': return DateTime.wednesday;
      case 'Thu': return DateTime.thursday;
      case 'Fri': return DateTime.friday;
      case 'Sat': return DateTime.saturday;
      case 'Sun': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(TimeOfDay time, int dayOfWeek) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, time.hour, time.minute,
    );

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }

  // Expose player for Ring Screen
  Future<void> playAlarmSound() async {
    try {
      await _audioPlayer.setSource(AssetSource('audio/buzzer.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
    } catch(e) {
      debugPrint("Error playing sound: $e");
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _audioPlayer.stop();
    } catch(e) {
      debugPrint("Error stopping sound: $e");
    }
  }
}
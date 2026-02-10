import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:dreamsync/views/alarm_ring_screen.dart';
import 'package:dreamsync/util/global.dart';
import 'dart:io' show Platform;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones();

    // 2. Get Device Timezone
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 3. Android Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // 4. iOS Setup
    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // FIXED: Pass the notification ID to the screen so we can stop it later
        if (response.id != null) {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => AlarmRingScreen(notificationId: response.id!),
            ),
          );
        }
      },
    );

    // 5. Request Basic Permissions
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Request Notification Permission (Android 13+)
      await androidImplementation?.requestNotificationsPermission();

      // NEW: Explicitly ask for Exact Alarm permission (Android 12+)
      await requestExactAlarmPermission();

    } else if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  // --- NEW FUNCTION TO ASK PERMISSION ---
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // This will check and request the 'SCHEDULE_EXACT_ALARM' permission
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required List<String> days,
    required bool isEnabled,
  }) async {
    await cancelAlarm(id);

    if (!isEnabled || days.isEmpty) return;

    // --- FIXED CONFIGURATION ---
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel_v2', // ID must match what you use elsewhere
      'Alarm Channel',
      channelDescription: 'Channel for Alarm Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      // 1. Link to your raw sound file (android/app/src/main/res/raw/buzzer.mp3)
      // Note: Do not include the .mp3 extension here
      sound: RawResourceAndroidNotificationSound('buzzer'),

      // 2. Critical: Use Alarm stream so it bypasses Silent/Vibrate mode
      audioAttributesUsage: AudioAttributesUsage.alarm,

      // 3. Show full screen intent (wakes up phone)
      fullScreenIntent: true,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    for (String day in days) {
      final notificationId = _createUniqueId(id, day);
      final scheduledDate = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      debugPrint("Scheduling: $day at $scheduledDate (Local Time) ID: $notificationId");

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        "Time to wake up!",
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelAlarm(int id) async {
    final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    for (var day in allDays) {
      await flutterLocalNotificationsPlugin.cancel(_createUniqueId(id, day));
    }
  }

  // --- Helpers ---

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
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    return scheduledDate;
  }
}
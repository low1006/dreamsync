import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// --- BACKGROUND CALLBACK ---
@pragma('vm:entry-point')
void fireAlarmCallback(int id, Map<String, dynamic> params) {
  // 1. Show the Alarm Notification (Rings the device)
  NotificationService().showAlarmNotification(
    id: id,
    title: params['title'] ?? 'Wake Up',
    body: params['body'] ?? 'Time to wake up!',
    payload: id.toString(),
    soundFile: params['soundFile'],
  );

  // 2. RESCHEDULE FOR NEXT WEEK (The Fix)
  // If this is a recurring alarm (loop: true), schedule it again for 7 days later.
  bool loop = params['loop'] ?? false;
  if (loop) {
    _rescheduleNextWeek(id, params);
  }
}

// Separate function to handle rescheduling in the background isolate
void _rescheduleNextWeek(int id, Map<String, dynamic> params) async {
  // We need to initialize the plugin in the background isolate if it's not ready
  // (Usually handled automatically, but safer to just call oneShotAt directly)

  int hour = params['hour'];
  int minute = params['minute'];

  // Calculate exactly 7 days from NOW (approximate) or align to the target time
  // Safest approach: Take current date + 7 days, set specific hour/minute.
  DateTime now = DateTime.now();
  DateTime nextRun = DateTime(
    now.year,
    now.month,
    now.day + 7, // Add 7 days
    hour,
    minute,
    0, // second
  );

  debugPrint("🔄 Rescheduling Alarm ID: $id for next week: $nextRun");

  await AndroidAlarmManager.oneShotAt(
    nextRun,
    id,
    fireAlarmCallback, // Recursive callback
    exact: true,
    wakeup: true,
    alarmClock: true,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
    params: params, // Pass the SAME params so it keeps looping forever
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final StreamController<String> _alarmStreamController = StreamController<String>.broadcast();
  Stream<String> get onAlarmFired => _alarmStreamController.stream;

  Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

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
        if (response.payload != null) {
          _alarmStreamController.add(response.payload!);
        }
      },
    );

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
      if (await Permission.systemAlertWindow.isDenied) {
        await Permission.systemAlertWindow.request();
      }
    }
  }

  // --- SCHEDULE ALARM ---
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required List<String> days,
    required bool isEnabled,
    required bool isSnoozeOn,
    String? soundFile,
  }) async {
    await cancelAlarm(id);

    if (!isEnabled || days.isEmpty) return;

    for (String day in days) {
      final uniqueId = _createUniqueId(id, day);
      final nextTime = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      debugPrint("📅 Scheduling Alarm for $day at $nextTime (ID: $uniqueId) with sound: $soundFile");

      if (Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          nextTime,
          uniqueId,
          fireAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: {
            'title': title,
            'body': 'Time to wake up!',
            'payload': id.toString(),
            'isSnoozeOn': isSnoozeOn,
            'soundFile': soundFile,

            // --- NEW PARAMS FOR RECURRENCE ---
            'loop': true,             // Enable looping
            'hour': time.hour,        // Store original hour
            'minute': time.minute,    // Store original minute
            'day': day,               // Store day name (debug/unused)
          },
        );
      } else {
        await _scheduleIOSAlarm(uniqueId, title, nextTime, soundFile);
      }
    }
  }

  // --- SHOW ALARM ---
  Future<void> showAlarmNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundFile,
  }) async {

    String cleanSoundName = (soundFile ?? 'buzzer').split('.').first;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel_v3',
      'High Priority Alarms',
      channelDescription: 'This channel is for loud alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      sound: RawResourceAndroidNotificationSound(cleanSoundName),
      additionalFlags: Int32List.fromList(<int>[4]),
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      ticker: 'Alarm Ringing',
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
          sound: '$cleanSoundName.mp3',
          presentSound: true,
          presentAlert: true
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // --- SNOOZE ---
  Future<void> scheduleSnooze(int originalId) async {
    final now = DateTime.now();
    final snoozeTime = now.add(const Duration(minutes: 9));
    final snoozeId = originalId + 100000;

    if (Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        snoozeId,
        fireAlarmCallback,
        exact: true,
        wakeup: true,
        alarmClock: true,
        // Snooze does NOT loop
        params: {
          'title': 'Snooze',
          'body': 'Snooze over!',
          'payload': originalId.toString(),
          'soundFile': 'buzzer.mp3',
          'loop': false // Important: Snooze does NOT repeat next week
        },
      );
    } else {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        snoozeId, "Snooze", "Snooze is over!", tz.TZDateTime.from(snoozeTime, tz.local),
        const NotificationDetails(
            iOS: DarwinNotificationDetails(sound: 'buzzer.mp3', presentSound: true, presentAlert: true)),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  // --- STOP & CANCEL ---
  Future<void> stopNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAlarm(int id) async {
    final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    for (var day in allDays) {
      final uniqueId = _createUniqueId(id, day);
      if (Platform.isAndroid) {
        await AndroidAlarmManager.cancel(uniqueId);
        await AndroidAlarmManager.cancel(uniqueId + 100000);
      }
      await flutterLocalNotificationsPlugin.cancel(uniqueId);
      await flutterLocalNotificationsPlugin.cancel(uniqueId + 100000);
    }
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

  Future<void> _scheduleIOSAlarm(int id, String title, tz.TZDateTime scheduledDate, String? soundFile) async {
    String cleanSound = (soundFile ?? 'buzzer').split('.').first;
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id, title, "Time to wake up!", scheduledDate,
      NotificationDetails(iOS: DarwinNotificationDetails(sound: '$cleanSound.mp3', presentSound: true, presentAlert: true)),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
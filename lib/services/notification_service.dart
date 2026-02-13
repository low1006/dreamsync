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
import 'package:do_not_disturb/do_not_disturb.dart';

// Create a global instance for the background tasks to use
final _dndPlugin = DoNotDisturbPlugin();

// --- WAKE UP CALLBACK (TURNS OFF DND & RINGS) ---
@pragma('vm:entry-point')
void fireAlarmCallback(int id, Map<String, dynamic> params) async {
  // 1. MUST ADD THIS FOR BACKGROUND PLUGINS TO WORK
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Turn OFF DND if Smart Notification is enabled
  bool isSmartNotification = params['isSmartNotification'] ?? false;
  if (isSmartNotification) {
    bool hasAccess = await _dndPlugin.isNotificationPolicyAccessGranted();
    debugPrint("☀️ Wake Up DND Check - Has Access? $hasAccess");

    if (hasAccess) {
      await _dndPlugin.setInterruptionFilter(InterruptionFilter.all);
      debugPrint("☀️ DND turned OFF (InterruptionFilter.all)");
    }
  }

  // 3. Show the Alarm Notification
  NotificationService().showAlarmNotification(
    id: id,
    title: params['title'] ?? 'Wake Up',
    body: params['body'] ?? 'Time to wake up!',
    payload: id.toString(),
    soundFile: params['soundFile'],
  );

  // 4. Reschedule for next week
  bool loop = params['loop'] ?? false;
  if (loop) {
    _rescheduleNextWeek(id, params);
  }
}

void _rescheduleNextWeek(int id, Map<String, dynamic> params) async {
  int hour = params['hour'];
  int minute = params['minute'];

  DateTime now = DateTime.now();
  DateTime nextRun = DateTime(
    now.year, now.month, now.day + 7, hour, minute, 0,
  );

  debugPrint("🔄 Rescheduling Alarm ID: $id for next week: $nextRun");

  await AndroidAlarmManager.oneShotAt(
    nextRun, id, fireAlarmCallback,
    exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true, rescheduleOnReboot: true,
    params: params,
  );
}

// --- BEDTIME CALLBACK (TURNS ON DND) ---
@pragma('vm:entry-point')
void fireBedtimeCallback(int id, Map<String, dynamic> params) async {
  // 1. MUST ADD THIS FOR BACKGROUND PLUGINS TO WORK
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint("🌙 Bedtime triggered! Turning ON Do Not Disturb.");

  // 2. Turn ON DND (Allowing alarms through)
  bool hasAccess = await _dndPlugin.isNotificationPolicyAccessGranted();
  debugPrint("🌙 Bedtime DND Check - Has Access? $hasAccess");

  if (hasAccess) {
    await _dndPlugin.setInterruptionFilter(InterruptionFilter.alarms);
    debugPrint("🌙 DND successfully set to ALARMS ONLY!");

    // 3. Show the helpful UI Notification
    await NotificationService().showDndNotification();
  } else {
    debugPrint("❌ ERROR: App does not have DND permissions in the background!");
  }

  bool loop = params['loop'] ?? false;
  if (loop) {
    _rescheduleBedtimeNextWeek(id, params);
  }
}

void _rescheduleBedtimeNextWeek(int id, Map<String, dynamic> params) async {
  int hour = params['hour'];
  int minute = params['minute'];

  DateTime now = DateTime.now();
  DateTime nextRun = DateTime(
    now.year, now.month, now.day + 7, hour, minute, 0,
  );

  debugPrint("🔄 Rescheduling Bedtime ID: $id for next week: $nextRun");

  await AndroidAlarmManager.oneShotAt(
    nextRun, id, fireBedtimeCallback,
    exact: true, wakeup: true, alarmClock: false, allowWhileIdle: true, rescheduleOnReboot: true,
    params: params,
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

  // --- SCHEDULE ALARM & BEDTIME ---
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required TimeOfDay bedTime,
    required List<String> days,
    required bool isEnabled,
    required bool isSnoozeOn,
    required bool isSmartNotification,
    String? soundFile,
  }) async {
    await cancelAlarm(id);

    if (!isEnabled || days.isEmpty) return;

    for (String day in days) {
      final uniqueId = _createUniqueId(id, day);
      final bedtimeUniqueId = uniqueId + 200000;

      final nextWakeTime = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      DateTime nextBedTime = DateTime(
          nextWakeTime.year, nextWakeTime.month, nextWakeTime.day, bedTime.hour, bedTime.minute
      );
      if (nextBedTime.isAfter(nextWakeTime)) {
        nextBedTime = nextBedTime.subtract(const Duration(days: 1));
      }

      debugPrint("📅 Scheduling Wake Up for $day at $nextWakeTime (ID: $uniqueId)");
      if (isSmartNotification) {
        debugPrint("🌙 Scheduling Bedtime DND for $day at $nextBedTime (ID: $bedtimeUniqueId)");
      }

      if (Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          nextWakeTime,
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
            'isSmartNotification': isSmartNotification,
            'loop': true,
            'hour': time.hour,
            'minute': time.minute,
            'day': day,
          },
        );

        if (isSmartNotification) {
          await AndroidAlarmManager.oneShotAt(
            nextBedTime,
            bedtimeUniqueId,
            fireBedtimeCallback,
            exact: true,
            wakeup: true,
            alarmClock: false,
            allowWhileIdle: true,
            rescheduleOnReboot: true,
            params: {
              'loop': true,
              'hour': bedTime.hour,
              'minute': bedTime.minute,
              'day': day,
            },
          );
        }

      } else {
        await _scheduleIOSAlarm(uniqueId, title, nextWakeTime, soundFile);
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
        params: {
          'title': 'Snooze',
          'body': 'Snooze over!',
          'payload': originalId.toString(),
          'soundFile': 'buzzer.mp3',
          'loop': false
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
        await AndroidAlarmManager.cancel(uniqueId + 200000);
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

  // --- NEW DND PERMISSION & NOTIFICATION HELPERS ---

  // 1. Checks if we have permission
  Future<bool> hasDndAccess() async {
    return await _dndPlugin.isNotificationPolicyAccessGranted();
  }

  // 2. Opens the settings
  Future<void> openDndSettings() async {
    await _dndPlugin.openNotificationPolicyAccessSettings();
  }

  // 3. Shows the Bedtime Notification
  Future<void> showDndNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'dnd_status_channel',
      'DND Status',
      channelDescription: 'Notifies you when Do Not Disturb is activated',
      importance: Importance.low, // Low importance so it doesn't vibrate/make noise
      priority: Priority.low,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      9999, // Unique ID for DND status
      'Bedtime Activated 🌙',
      'Do Not Disturb is ON. Sleep well, your morning alarm will still ring!',
      platformDetails,
    );
  }
}
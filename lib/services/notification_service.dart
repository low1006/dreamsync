import 'dart:async';
import 'dart:convert';
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

final _dndPlugin = DoNotDisturbPlugin();

@pragma('vm:entry-point')
void fireAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. DND Logic
  bool isSmartNotification = params['isSmartNotification'] ?? false;
  if (isSmartNotification) {
    try {
      if (await _dndPlugin.isNotificationPolicyAccessGranted()) {
        await _dndPlugin.setInterruptionFilter(InterruptionFilter.all);
      }
    } catch (e) {
      debugPrint("DND Error: $e");
    }
  }

  // 2. Prepare Payload
  String currentSound = params['soundFile'] ?? 'classic.mp3';
  int snoozeCount = params['snoozeCount'] ?? 0;
  bool isSmartAlarm = params['isSmartAlarm'] ?? false;
  bool isSnoozeOn = params['isSnoozeOn'] ?? true;

  String payloadData = jsonEncode({
    'id': id,
    'isSmartAlarm': isSmartAlarm,
    'isSnoozeOn': isSnoozeOn,
    'snoozeCount': snoozeCount,
    'soundFile': currentSound,
  });

  // 3. Show Notification
  NotificationService().showAlarmNotification(
    id: id,
    title: params['title'] ?? 'Wake Up',
    body: params['body'] ?? 'Time to wake up!',
    payload: payloadData,
    soundFile: currentSound,
  );

  // 4. Loop Logic
  bool loop = params['loop'] ?? false;
  if (loop) {
    _rescheduleNextWeek(id, params);
  }
}

// ... _rescheduleNextWeek, fireBedtimeCallback, etc. (UNCHANGED) ...
void _rescheduleNextWeek(int id, Map<String, dynamic> params) async {
  int hour = params['hour'];
  int minute = params['minute'];
  DateTime now = DateTime.now();
  DateTime nextRun = DateTime(now.year, now.month, now.day + 7, hour, minute, 0);

  await AndroidAlarmManager.oneShotAt(
    nextRun, id, fireAlarmCallback,
    exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true, rescheduleOnReboot: true,
    params: params,
  );
}

@pragma('vm:entry-point')
void fireBedtimeCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (await _dndPlugin.isNotificationPolicyAccessGranted()) {
    await _dndPlugin.setInterruptionFilter(InterruptionFilter.alarms);
    await NotificationService().showDndNotification();
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
  DateTime nextRun = DateTime(now.year, now.month, now.day + 7, hour, minute, 0);

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

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final StreamController<String> _alarmStreamController = StreamController<String>.broadcast();
  Stream<String> get onAlarmFired => _alarmStreamController.stream;

  Future<void> init() async {
    // ... (UNCHANGED) ...
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }

    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
    }

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestSoundPermission: true, requestBadgePermission: true, requestAlertPermission: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: initializationSettingsAndroid, iOS: initializationSettingsDarwin),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _alarmStreamController.add(response.payload!);
        }
      },
    );
    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    // ... (UNCHANGED) ...
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) await androidImplementation.requestNotificationsPermission();
      if (await Permission.scheduleExactAlarm.isDenied) await Permission.scheduleExactAlarm.request();
      if (await Permission.systemAlertWindow.isDenied) await Permission.systemAlertWindow.request();
    }
  }

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required TimeOfDay bedTime,
    required List<String> days,
    required bool isAlarmEnabled,
    required bool isSnoozeOn,
    required bool isSmartNotification,
    required bool isSmartAlarm,
    String? soundFile,
  }) async {
    await cancelAlarm(id);

    if (days.isEmpty) return;
    if (!isAlarmEnabled && !isSmartNotification) return;

    for (String day in days) {
      final uniqueId = _createUniqueId(id, day);
      final bedtimeUniqueId = uniqueId + 200000;
      final nextWakeTime = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      DateTime nextBedTime = DateTime(nextWakeTime.year, nextWakeTime.month, nextWakeTime.day, bedTime.hour, bedTime.minute);
      if (nextBedTime.isAfter(nextWakeTime)) nextBedTime = nextBedTime.subtract(const Duration(days: 1));

      if (isAlarmEnabled && Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          nextWakeTime, uniqueId, fireAlarmCallback,
          exact: true, wakeup: true, alarmClock: true, allowWhileIdle: true, rescheduleOnReboot: true,
          params: {
            'title': title,
            'body': 'Time to wake up!',
            'isSnoozeOn': isSnoozeOn,
            'soundFile': soundFile,
            'isSmartNotification': isSmartNotification,
            'isSmartAlarm': isSmartAlarm,
            'snoozeCount': 0,
            'loop': true,
            'hour': time.hour, 'minute': time.minute, 'day': day,
          },
        );
      } else if (isAlarmEnabled && !Platform.isAndroid) {
        await _scheduleIOSAlarm(uniqueId, title, nextWakeTime, soundFile);
      }

      if (isSmartNotification && Platform.isAndroid) {
        await AndroidAlarmManager.oneShotAt(
          nextBedTime, bedtimeUniqueId, fireBedtimeCallback,
          exact: true, wakeup: true, alarmClock: false, allowWhileIdle: true, rescheduleOnReboot: true,
          params: {'loop': true, 'hour': bedTime.hour, 'minute': bedTime.minute, 'day': day},
        );
      }
    }
  }

  // --- UPDATED SHOW ALARM: Dynamic Channel ID ---
  Future<void> showAlarmNotification({required int id, required String title, required String body, String? payload, String? soundFile}) async {
    String cleanSoundName = (soundFile ?? 'buzzer').split('.').first;

    // !!! IMPORTANT CHANGE !!!
    // Generate a unique channel ID based on the sound name.
    // 'alarm_channel_classic' OR 'alarm_channel_buzzer'
    // This forces Android to treat them as different channels with different sounds.
    String channelId = 'alarm_channel_$cleanSoundName';
    String channelName = 'Alarm ($cleanSoundName)';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId, // <--- Dynamic Channel ID
      channelName,
      channelDescription: 'Loud alarm notifications',
      importance: Importance.max, priority: Priority.max, fullScreenIntent: true,
      sound: RawResourceAndroidNotificationSound(cleanSoundName),
      additionalFlags: Int32List.fromList(<int>[4]), playSound: true,
      category: AndroidNotificationCategory.alarm, visibility: NotificationVisibility.public,
      ongoing: true, autoCancel: false, ticker: 'Alarm Ringing',
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(sound: '$cleanSoundName.mp3', presentSound: true, presentAlert: true),
    );

    await flutterLocalNotificationsPlugin.show(id, title, body, platformDetails, payload: payload);
  }

  Future<void> scheduleSnooze({
    required int originalId,
    required int currentSnoozeCount,
    required bool isSmartAlarm,
    required bool isSnoozeOn,
    required String soundFile,
  }) async {
    final now = DateTime.now();
    // 5 minutes snooze
    final snoozeTime = now.add(const Duration(minutes: 5));
    final snoozeId = originalId + 100000;

    int nextSnoozeCount = currentSnoozeCount + 1;

    String payload = jsonEncode({
      'id': originalId,
      'isSmartAlarm': isSmartAlarm,
      'isSnoozeOn': isSnoozeOn,
      'snoozeCount': nextSnoozeCount,
      'soundFile': soundFile,
    });

    if (Platform.isAndroid) {
      await AndroidAlarmManager.oneShotAt(
        snoozeTime, snoozeId, fireAlarmCallback,
        exact: true, wakeup: true, alarmClock: true,
        params: {
          'title': 'Snooze',
          'body': 'Snooze over!',
          'isSmartAlarm': isSmartAlarm,
          'isSnoozeOn': isSnoozeOn,
          'snoozeCount': nextSnoozeCount,
          'soundFile': soundFile,
          'loop': false
        },
      );
    } else {
      String cleanSound = soundFile.split('.').first;
      await flutterLocalNotificationsPlugin.zonedSchedule(
        snoozeId, "Snooze", "Snooze is over!", tz.TZDateTime.from(snoozeTime, tz.local),
        NotificationDetails(iOS: DarwinNotificationDetails(sound: '$cleanSound.mp3', presentSound: true, presentAlert: true)),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    }
  }

  // ... (REST OF THE FILE UNCHANGED) ...
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
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, time.hour, time.minute);
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

  Future<bool> hasDndAccess() async {
    return await _dndPlugin.isNotificationPolicyAccessGranted();
  }

  Future<void> openDndSettings() async {
    await _dndPlugin.openNotificationPolicyAccessSettings();
  }

  Future<void> showDndNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'dnd_status_channel', 'DND Status', channelDescription: 'Notifies when Do Not Disturb is activated',
      importance: Importance.low, priority: Priority.low, icon: '@mipmap/ic_launcher',
    );
    await flutterLocalNotificationsPlugin.show(
      9999, 'Bedtime Activated 🌙', 'Do Not Disturb is ON. Sleep well, your morning alarm will still ring!',
      const NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails()),
    );
  }
}
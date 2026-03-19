import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final DoNotDisturbPlugin _dndPlugin = DoNotDisturbPlugin();

@pragma('vm:entry-point')
Future<void> fireAlarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final service = NotificationService();
  await service.initForIsolate();

  try {
    final bool isSmartNotification = params['isSmartNotification'] ?? false;

    if (isSmartNotification) {
      try {
        final granted = await _dndPlugin.isNotificationPolicyAccessGranted();
        if (granted) {
          await _dndPlugin.setInterruptionFilter(InterruptionFilter.all);
        }
      } catch (e) {
        debugPrint('DND access error in alarm callback: $e');
      }
    }

    final String currentSound = NotificationService.normalizeSoundFile(
      params['soundFile']?.toString(),
    );

    final int snoozeCount = params['snoozeCount'] ?? 0;
    final bool isSmartAlarm = params['isSmartAlarm'] ?? false;
    final bool isSnoozeOn = params['isSnoozeOn'] ?? true;

    final payload = jsonEncode({
      'id': id,
      'isSmartAlarm': isSmartAlarm,
      'isSnoozeOn': isSnoozeOn,
      'snoozeCount': snoozeCount,
      'soundFile': currentSound,
    });

    await service.showAlarmNotification(
      id: id,
      title: params['title'] ?? 'Wake Up',
      body: params['body'] ?? 'Time to wake up!',
      payload: payload,
      soundFile: currentSound,
    );

    final bool loop = params['loop'] ?? false;
    if (loop) {
      await _rescheduleNextWeek(id, params);
    }
  } catch (e, st) {
    debugPrint('fireAlarmCallback error: $e');
    debugPrint('$st');
  }
}

Future<void> _rescheduleNextWeek(int id, Map<String, dynamic> params) async {
  final int hour = params['hour'];
  final int minute = params['minute'];
  final now = DateTime.now();

  final nextRun = DateTime(now.year, now.month, now.day + 7, hour, minute);

  await AndroidAlarmManager.oneShotAt(
    nextRun,
    id,
    fireAlarmCallback,
    exact: true,
    wakeup: true,
    alarmClock: true,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
    params: params,
  );
}

@pragma('vm:entry-point')
Future<void> fireBedtimeCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final service = NotificationService();
  await service.initForIsolate();

  try {
    final granted = await _dndPlugin.isNotificationPolicyAccessGranted();
    if (granted) {
      await _dndPlugin.setInterruptionFilter(InterruptionFilter.alarms);
      await service.showDndNotification();
    }

    final bool loop = params['loop'] ?? false;
    if (loop) {
      await _rescheduleBedtimeNextWeek(id, params);
    }
  } catch (e, st) {
    debugPrint('fireBedtimeCallback error: $e');
    debugPrint('$st');
  }
}

Future<void> _rescheduleBedtimeNextWeek(
    int id,
    Map<String, dynamic> params,
    ) async {
  final int hour = params['hour'];
  final int minute = params['minute'];
  final now = DateTime.now();

  final nextRun = DateTime(now.year, now.month, now.day + 7, hour, minute);

  await AndroidAlarmManager.oneShotAt(
    nextRun,
    id,
    fireBedtimeCallback,
    exact: true,
    wakeup: true,
    alarmClock: false,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
    params: params,
  );
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  final StreamController<String> _alarmStreamController =
  StreamController<String>.broadcast();

  Stream<String> get onAlarmFired => _alarmStreamController.stream;

  bool _initialized = false;
  bool _timezoneReady = false;
  bool _pluginReady = false;

  static bool _hasConsumedLaunchPayload = false;

  static const String _dndChannelId = 'bedtime_dnd_channel';
  static const String _dndChannelName = 'Bedtime Notifications';
  static const int _dndNotificationId = 999999;

  static const int smartAlarmMaxSnoozes = 2;

  static String normalizeSoundFile(String? soundFile) {
    final raw = (soundFile == null || soundFile.trim().isEmpty)
        ? 'classic.mp3'
        : soundFile.trim();

    final lower = raw.toLowerCase().replaceAll(' ', '_');

    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg')) {
      return lower;
    }

    return '$lower.mp3';
  }

  static String soundResourceName(String? soundFile) {
    return normalizeSoundFile(soundFile).split('.').first;
  }

  static String audioAssetPath(String? soundFile) {
    return 'audio/${normalizeSoundFile(soundFile)}';
  }

  Future<void> init() async {
    if (_initialized) return;

    await _initTimezone();
    await AndroidAlarmManager.initialize();
    await _initializeNotifications();

    _initialized = true;
  }

  Future<void> initForIsolate() async {
    if (_initialized) return;

    await _initTimezone();
    await _initializeNotifications();

    _initialized = true;
  }

  Future<void> _initTimezone() async {
    if (_timezoneReady) return;

    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
    }

    _timezoneReady = true;
  }

  Future<void> _initializeNotifications() async {
    if (_pluginReady) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _alarmStreamController.add(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
      notificationTapBackgroundHandler,
    );

    _pluginReady = true;
  }

  Future<String?> getLaunchPayload() async {
    if (_hasConsumedLaunchPayload) return null;

    final details =
    await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp == true) {
      _hasConsumedLaunchPayload = true;
      return details?.notificationResponse?.payload;
    }
    return null;
  }

  @pragma('vm:entry-point')
  static void notificationTapBackgroundHandler(
      NotificationResponse response,
      ) {}

  Future<void> showAlarmNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? soundFile,
  }) async {
    final normalizedSoundFile = normalizeSoundFile(soundFile);
    final cleanSoundName = normalizedSoundFile.split('.').first;

    final channelId = 'loud_alarm_channel_v4_$cleanSoundName';
    final channelName = 'Loud Alarm ($cleanSoundName)';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Loud alarm notifications',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(cleanSoundName),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      ongoing: true,
      autoCancel: false,
      ticker: 'Alarm Ringing',
      additionalFlags: Int32List.fromList(<int>[4]),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: normalizedSoundFile,
      interruptionLevel: InterruptionLevel.critical,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    debugPrint(
      '🔔 Showing LOUD native alarm notification: id=$id sound=$cleanSoundName',
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }

  Future<void> showDndNotification() async {
    const androidDetails = AndroidNotificationDetails(
      _dndChannelId,
      _dndChannelName,
      channelDescription: 'Bedtime mode notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    await flutterLocalNotificationsPlugin.show(
      _dndNotificationId,
      'Bedtime Mode',
      'Do Not Disturb has been enabled for bedtime.',
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> stopNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAlarm(int baseId) async {
    try {
      for (int i = 1; i <= 7; i++) {
        final int alarmId = baseId + i;
        final int snoozeId = alarmId + 100000;
        final int bedtimeId = alarmId + 500000;

        await AndroidAlarmManager.cancel(alarmId);
        await AndroidAlarmManager.cancel(snoozeId);
        await AndroidAlarmManager.cancel(bedtimeId);

        await stopNotification(alarmId);
        await stopNotification(snoozeId);
        await stopNotification(bedtimeId);
      }

      await stopNotification(_dndNotificationId);

      debugPrint('🛑 All alarms cancelled for base id: $baseId');
    } catch (e) {
      debugPrint('cancelAlarm error: $e');
    }
  }

  Future<void> cancelAllAlarmNotificationsAndSchedules({
    int maxBaseId = 10000,
  }) async {
    try {
      for (int baseId = 0; baseId <= maxBaseId; baseId++) {
        for (int i = 1; i <= 7; i++) {
          final int alarmId = baseId + i;
          final int snoozeId = alarmId + 100000;
          final int bedtimeId = alarmId + 500000;

          await AndroidAlarmManager.cancel(alarmId);
          await AndroidAlarmManager.cancel(snoozeId);
          await AndroidAlarmManager.cancel(bedtimeId);

          await stopNotification(alarmId);
          await stopNotification(snoozeId);
          await stopNotification(bedtimeId);
        }
      }

      await flutterLocalNotificationsPlugin.cancelAll();
      await stopNotification(_dndNotificationId);

      debugPrint('🧹 All alarm schedules and notifications cleared.');
    } catch (e) {
      debugPrint('cancelAllAlarmNotificationsAndSchedules error: $e');
    }
  }

  Future<void> debugResetForDevelopment() async {
    if (!kDebugMode) return;
    await init();
    await cancelAllAlarmNotificationsAndSchedules();
  }

  String resolveNextSnoozeSoundFile({
    required String currentSoundFile,
    required int currentSnoozeCount,
    required bool isSmartAlarm,
  }) {
    if (isSmartAlarm && (currentSnoozeCount + 1) >= smartAlarmMaxSnoozes) {
      return 'buzzer.mp3';
    }
    return normalizeSoundFile(currentSoundFile);
  }

  bool shouldEnterPanicMode({
    required bool isSmartAlarm,
    required int snoozeCount,
  }) {
    return isSmartAlarm && snoozeCount >= smartAlarmMaxSnoozes;
  }

  Future<void> handleSnooze({
    required int notificationId,
    required int snoozeCount,
    required bool isSmartAlarm,
    required bool isSnoozeOn,
    required String soundFile,
  }) async {
    final int originalId =
    notificationId > 100000 ? notificationId - 100000 : notificationId;

    final int snoozeId = originalId + 100000;

    await stopNotification(originalId);
    await stopNotification(snoozeId);

    await AndroidAlarmManager.cancel(snoozeId);

    final String nextSoundFile = resolveNextSnoozeSoundFile(
      currentSoundFile: soundFile,
      currentSnoozeCount: snoozeCount,
      isSmartAlarm: isSmartAlarm,
    );

    await scheduleSnooze(
      originalId: originalId,
      currentSnoozeCount: snoozeCount,
      isSmartAlarm: isSmartAlarm,
      isSnoozeOn: isSnoozeOn,
      soundFile: nextSoundFile,
    );
  }

  Future<void> handleStopAlarm({required int notificationId}) async {
    final int originalId =
    notificationId > 100000 ? notificationId - 100000 : notificationId;

    final int snoozeId = originalId + 100000;

    try {
      await stopNotification(originalId);
      await stopNotification(snoozeId);

      await AndroidAlarmManager.cancel(originalId);
      await AndroidAlarmManager.cancel(snoozeId);

      debugPrint('🛑 Alarm fully stopped: id=$originalId');
    } catch (e) {
      debugPrint('handleStopAlarm error: $e');
    }
  }

  Future<void> scheduleSnooze({
    required int originalId,
    required int currentSnoozeCount,
    required bool isSmartAlarm,
    required bool isSnoozeOn,
    required String soundFile,
  }) async {
    final int snoozeId = originalId + 100000;
    final DateTime snoozeTime = DateTime.now().add(const Duration(minutes: 1));
    final normalizedSoundFile = normalizeSoundFile(soundFile);

    await AndroidAlarmManager.cancel(snoozeId);
    await stopNotification(snoozeId);

    final params = <String, dynamic>{
      'title': 'Wake Up',
      'body': 'Time to wake up!',
      'hour': snoozeTime.hour,
      'minute': snoozeTime.minute,
      'loop': false,
      'isSmartAlarm': isSmartAlarm,
      'isSnoozeOn': isSnoozeOn,
      'isSmartNotification': false,
      'snoozeCount': currentSnoozeCount + 1,
      'soundFile': normalizedSoundFile,
    };

    await AndroidAlarmManager.oneShotAt(
      snoozeTime,
      snoozeId,
      fireAlarmCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,
      allowWhileIdle: true,
      rescheduleOnReboot: false,
      params: params,
    );

    debugPrint('😴 Snooze scheduled: id=$snoozeId at $snoozeTime');
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
    required String soundFile,
  }) async {
    await init();
    await cancelAlarm(id);

    if (!isAlarmEnabled && !isSmartNotification) return;

    final normalizedSoundFile = normalizeSoundFile(soundFile);

    final weekdayMap = <String, int>{
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };

    for (final day in days) {
      final targetWeekday = weekdayMap[day];
      if (targetWeekday == null) continue;

      if (isAlarmEnabled) {
        final alarmDateTime = _nextInstanceOfWeekdayTime(
          targetWeekday,
          time.hour,
          time.minute,
        );

        await AndroidAlarmManager.oneShotAt(
          alarmDateTime,
          id + targetWeekday,
          fireAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: {
            'title': title,
            'body': 'Time to wake up!',
            'hour': time.hour,
            'minute': time.minute,
            'loop': true,
            'isSmartAlarm': isSmartAlarm,
            'isSnoozeOn': isSnoozeOn,
            'isSmartNotification': isSmartNotification,
            'snoozeCount': 0,
            'soundFile': normalizedSoundFile,
          },
        );

        debugPrint('Alarm scheduled for $day at $alarmDateTime');
      }

      if (isSmartNotification) {
        final bedtimeDateTime = _nextInstanceOfWeekdayTime(
          targetWeekday,
          bedTime.hour,
          bedTime.minute,
        );

        await AndroidAlarmManager.oneShotAt(
          bedtimeDateTime,
          (id + targetWeekday) + 500000,
          fireBedtimeCallback,
          exact: true,
          wakeup: true,
          alarmClock: false,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: {
            'hour': bedTime.hour,
            'minute': bedTime.minute,
            'loop': true,
          },
        );

        debugPrint('Bedtime DND scheduled for $day at $bedtimeDateTime');
      }
    }
  }

  DateTime _nextInstanceOfWeekdayTime(int weekday, int hour, int minute) {
    final now = DateTime.now();
    DateTime scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      scheduled = DateTime(
        scheduled.year,
        scheduled.month,
        scheduled.day,
        hour,
        minute,
      );
    }

    return scheduled;
  }
}
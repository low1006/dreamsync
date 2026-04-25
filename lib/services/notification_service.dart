import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:do_not_disturb/do_not_disturb.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final String currentSound = NotificationService.normalizeSoundFile(
      params['soundFile']?.toString(),
    );

    final int snoozeCount = params['snoozeCount'] ?? 0;
    final bool isSmartAlarm = params['isSmartAlarm'] ?? false;
    final bool isSnoozeOn = params['isSnoozeOn'] ?? true;
    final bool loop = params['loop'] ?? false;
    final int snoozeDurationMinutes = params['snoozeDurationMinutes'] ?? 5;

    final payload = jsonEncode({
      'id': id,
      'isSmartAlarm': isSmartAlarm,
      'isSnoozeOn': isSnoozeOn,
      'snoozeCount': snoozeCount,
      'soundFile': currentSound,
      'snoozeDurationMinutes': snoozeDurationMinutes,
    });

    debugPrint(
      '[callback] ⏰ Alarm fired: id=$id sound=$currentSound '
          'snoozeCount=$snoozeCount loop=$loop',
    );

    await NotificationService.clearConsumedLaunchPayload();

    await service.showAlarmNotification(
      id: id,
      title: params['title'] ?? 'Wake Up',
      body: params['body'] ?? 'Time to wake up!',
      payload: payload,
      soundFile: currentSound,
    );

    debugPrint(
      '[callback] ℹ️ Alarm shown only. Weekly reschedule will happen on STOP, not on FIRE.',
    );
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

  NotificationService.registerScheduledAlarm(
    id: id,
    when: nextRun,
    params: params,
    source: 'weekly_reschedule_from_stop',
  );

  debugPrint(
    '[main] 🔁 Weekly alarm rescheduled from STOP: '
        'id=$id nextRun=${NotificationService.formatLogTime(nextRun)}',
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
      debugPrint('[callback] 🌙 DND enabled by bedtime callback id=$id');
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

  NotificationService.registerScheduledAlarm(
    id: id,
    when: nextRun,
    params: params,
    source: 'bedtime_reschedule',
  );

  debugPrint(
    '🌙 Bedtime rescheduled: id=$id nextRun=${NotificationService.formatLogTime(nextRun)}',
  );
}

@pragma('vm:entry-point')
Future<void> fireWakeDndOffCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final service = NotificationService();
  await service.initForIsolate();

  try {
    final granted = await _dndPlugin.isNotificationPolicyAccessGranted();
    if (granted) {
      await _dndPlugin.setInterruptionFilter(InterruptionFilter.all);
      await service.stopNotification(NotificationService.dndNotificationId);
      debugPrint('[callback] ☀️ DND disabled by wake callback id=$id');
    }

    final bool loop = params['loop'] ?? false;
    if (loop) {
      await _rescheduleWakeDndOffNextWeek(id, params);
    }
  } catch (e, st) {
    debugPrint('fireWakeDndOffCallback error: $e');
    debugPrint('$st');
  }
}

Future<void> _rescheduleWakeDndOffNextWeek(
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
    fireWakeDndOffCallback,
    exact: true,
    wakeup: true,
    alarmClock: false,
    allowWhileIdle: true,
    rescheduleOnReboot: true,
    params: params,
  );

  NotificationService.registerScheduledAlarm(
    id: id,
    when: nextRun,
    params: params,
    source: 'wake_dnd_off_reschedule',
  );

  debugPrint(
    '☀️ Wake DND-off rescheduled: id=$id nextRun=${NotificationService.formatLogTime(nextRun)}',
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
  static int get dndNotificationId => _dndNotificationId;

  static const int smartAlarmMaxSnoozes = 2;

  static final Map<int, DateTime> _scheduledAlarmTimes = <int, DateTime>{};
  static final Map<int, Map<String, dynamic>> _scheduledAlarmParams =
  <int, Map<String, dynamic>>{};

  static const MethodChannel _audioChannel =
  MethodChannel('com.dreamsync/audios');

  static const String _consumedPayloadKey = 'consumed_launch_payload';

  static Future<int> getSystemAlarmMaxSteps() async {
    try {
      final int max = await _audioChannel.invokeMethod('getAlarmMaxVolume');
      return max > 0 ? max : 7;
    } catch (e) {
      debugPrint('⚠️ getSystemAlarmMaxSteps failed: $e — defaulting to 7');
      return 7;
    }
  }

  static String normalizeSoundFile(String? soundFile) {
    String raw = (soundFile == null || soundFile.trim().isEmpty)
        ? 'classic.mp3'
        : soundFile.trim().toLowerCase().replaceAll('\\', '/');

    if (raw.startsWith('assets/audios/')) {
      raw = raw.substring('assets/audios/'.length);
    } else if (raw.startsWith('audios/')) {
      raw = raw.substring('audios/'.length);
    } else if (raw.startsWith('assets/')) {
      raw = raw.substring('assets/'.length);
      if (raw.startsWith('audios/')) {
        raw = raw.substring('audios/'.length);
      }
    }

    raw = raw.replaceAll(' ', '_');

    if (raw.endsWith('.mp3') || raw.endsWith('.wav') || raw.endsWith('.ogg')) {
      return raw;
    }

    return '$raw.mp3';
  }

  static String soundResourceName(String? soundFile) {
    return normalizeSoundFile(soundFile).split('.').first;
  }

  static String audioAssetPath(String? soundFile) {
    return 'audios/${normalizeSoundFile(soundFile)}';
  }

  static String formatLogTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static void registerScheduledAlarm({
    required int id,
    required DateTime when,
    required Map<String, dynamic> params,
    required String source,
  }) {
    _scheduledAlarmTimes[id] = when;
    _scheduledAlarmParams[id] = Map<String, dynamic>.from(params);

    debugPrint(
      '🗓️ [$source] Scheduled alarm registered: '
          'id=$id '
          'at=${formatLogTime(when)} '
          'title=${params['title'] ?? 'Wake Up'} '
          'sound=${params['soundFile'] ?? 'classic.mp3'} '
          'loop=${params['loop'] ?? false}',
    );
  }

  static void unregisterScheduledAlarm(int id) {
    _scheduledAlarmTimes.remove(id);
    _scheduledAlarmParams.remove(id);
  }

  static DateTime? latestScheduledTimeFor(int id) => _scheduledAlarmTimes[id];

  static Map<String, dynamic>? latestScheduledParamsFor(int id) =>
      _scheduledAlarmParams[id];

  Map<String, dynamic>? getTrackedAlarmParams(int id) {
    final params = _scheduledAlarmParams[id];
    if (params == null) return null;
    return Map<String, dynamic>.from(params);
  }

  static void debugPrintLatestSchedule(int id, {String prefix = 'ℹ️'}) {
    final when = _scheduledAlarmTimes[id];
    final params = _scheduledAlarmParams[id];

    if (when == null) {
      debugPrint('$prefix No tracked future schedule for id=$id');
      return;
    }

    debugPrint(
      '$prefix Latest tracked schedule for id=$id -> '
          '${formatLogTime(when)} '
          'title=${params?['title'] ?? 'Wake Up'} '
          'sound=${params?['soundFile'] ?? 'classic.mp3'} '
          'loop=${params?['loop'] ?? false}',
    );
  }

  static Future<void> clearConsumedLaunchPayload() async {
    _hasConsumedLaunchPayload = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_consumedPayloadKey);
      debugPrint('🧹 Cleared consumed launch payload flag (new alarm fired).');
    } catch (e) {
      debugPrint('⚠️ clearConsumedLaunchPayload error: $e');
    }
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
      final payload = details?.notificationResponse?.payload;

      try {
        final prefs = await SharedPreferences.getInstance();
        final lastConsumed = prefs.getString(_consumedPayloadKey);

        if (lastConsumed != null && lastConsumed == payload) {
          debugPrint(
            '⏭️ Stale launch payload detected (already consumed). Skipping alarm screen.',
          );
          _hasConsumedLaunchPayload = true;
          return null;
        }

        _hasConsumedLaunchPayload = true;
        if (payload != null) {
          await prefs.setString(_consumedPayloadKey, payload);
        }
      } catch (e) {
        debugPrint('⚠️ getLaunchPayload SharedPreferences error: $e');
        _hasConsumedLaunchPayload = true;
      }

      return payload;
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
        final int wakeDndOffId = alarmId + 700000;

        await AndroidAlarmManager.cancel(alarmId);
        await AndroidAlarmManager.cancel(snoozeId);
        await AndroidAlarmManager.cancel(bedtimeId);
        await AndroidAlarmManager.cancel(wakeDndOffId);

        await stopNotification(alarmId);
        await stopNotification(snoozeId);
        await stopNotification(bedtimeId);
        await stopNotification(wakeDndOffId);

        unregisterScheduledAlarm(alarmId);
        unregisterScheduledAlarm(snoozeId);
        unregisterScheduledAlarm(bedtimeId);
        unregisterScheduledAlarm(wakeDndOffId);
      }

      await stopNotification(_dndNotificationId);

      debugPrint('🛑 All alarms cancelled for base id: $baseId');
    } catch (e) {
      debugPrint('cancelAlarm error: $e');
    }
  }

  Future<void> cancelAllAlarmNotificationsAndSchedules() async {
    try {
      final trackedIds = List<int>.from(_scheduledAlarmTimes.keys);

      for (final id in trackedIds) {
        await AndroidAlarmManager.cancel(id);
        await stopNotification(id);
        unregisterScheduledAlarm(id);
        debugPrint('🧹 Cancelled tracked alarm id=$id');
      }

      await flutterLocalNotificationsPlugin.cancelAll();

      debugPrint('🧹 All tracked alarm schedules and notifications cleared.');
    } catch (e) {
      debugPrint('cancelAllAlarmNotificationsAndSchedules error: $e');
    }
  }

  Future<void> debugResetForDevelopment() async {
    if (!kDebugMode) return;
    await init();
    await cancelAllAlarmNotificationsAndSchedules();
    await clearConsumedLaunchPayload();
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
    int snoozeDurationMinutes = 5,
  }) async {
    final int originalId =
    notificationId > 100000 ? notificationId - 100000 : notificationId;

    final int snoozeId = originalId + 100000;

    await stopNotification(originalId);
    await stopNotification(snoozeId);

    await AndroidAlarmManager.cancel(snoozeId);
    unregisterScheduledAlarm(snoozeId);

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
      snoozeDurationMinutes: snoozeDurationMinutes,
    );
  }

  Future<void> handleStopAlarm({required int notificationId}) async {
    final int originalId =
    notificationId > 100000 ? notificationId - 100000 : notificationId;

    final int snoozeId = originalId + 100000;

    try {
      await stopNotification(originalId);
      await stopNotification(snoozeId);

      await AndroidAlarmManager.cancel(snoozeId);
      unregisterScheduledAlarm(snoozeId);

      try {
        final prefs = await SharedPreferences.getInstance();
        final currentPayload = prefs.getString(_consumedPayloadKey);
        if (currentPayload != null) {
          debugPrint(
            '🛡️ Launch payload already persisted — hot restart is safe.',
          );
        }
      } catch (e) {
        debugPrint('⚠️ handleStopAlarm prefs check error: $e');
      }

      final trackedParams = getTrackedAlarmParams(originalId);
      final bool shouldLoop = trackedParams?['loop'] ?? false;

      debugPrint(
        '[main] 🛑 Alarm stopped by user: '
            'currentId=$notificationId originalId=$originalId shouldLoop=$shouldLoop',
      );

      if (shouldLoop && trackedParams != null) {
        await _rescheduleNextWeek(originalId, trackedParams);
      } else {
        debugPrint(
          '[main] ℹ️ No weekly reschedule on STOP because loop=false or tracked params missing.',
        );
      }

      debugPrintLatestSchedule(originalId, prefix: '[main] 📌');
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
    int snoozeDurationMinutes = 5,
  }) async {
    final int snoozeId = originalId + 100000;
    final DateTime snoozeTime =
    DateTime.now().add(Duration(minutes: snoozeDurationMinutes));
    final normalizedSoundFile = normalizeSoundFile(soundFile);

    await AndroidAlarmManager.cancel(snoozeId);
    await stopNotification(snoozeId);
    unregisterScheduledAlarm(snoozeId);

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
      'snoozeDurationMinutes': snoozeDurationMinutes,
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

    registerScheduledAlarm(
      id: snoozeId,
      when: snoozeTime,
      params: params,
      source: 'snooze',
    );

    debugPrint(
      '😴 Snooze scheduled: id=$snoozeId at ${formatLogTime(snoozeTime)}',
    );
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
    int snoozeDurationMinutes = 5,
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

    debugPrint(
      '📝 Scheduling alarm baseId=$id title=$title '
          'alarmEnabled=$isAlarmEnabled smartNotification=$isSmartNotification '
          'smartAlarm=$isSmartAlarm snoozeOn=$isSnoozeOn sound=$normalizedSoundFile days=$days',
    );

    for (final day in days) {
      final targetWeekday = weekdayMap[day];
      if (targetWeekday == null) continue;

      // 1. ALWAYS calculate the wake time first. Everything anchors to this.
      final wakeDateTime = _nextInstanceOfWeekdayTime(
        targetWeekday,
        time.hour,
        time.minute,
      );

      if (isAlarmEnabled) {
        final alarmId = id + targetWeekday;

        final params = <String, dynamic>{
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
          'snoozeDurationMinutes': snoozeDurationMinutes,
        };

        await AndroidAlarmManager.oneShotAt(
          wakeDateTime,
          alarmId,
          fireAlarmCallback,
          exact: true,
          wakeup: true,
          alarmClock: true,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: params,
        );

        registerScheduledAlarm(
          id: alarmId,
          when: wakeDateTime,
          params: params,
          source: 'weekly_alarm',
        );

        debugPrint(
          '✅ Alarm scheduled for $day -> id=$alarmId at ${formatLogTime(wakeDateTime)}',
        );
      }

      if (isSmartNotification) {
        // 2. Anchor the bedtime exactly to the wakeDateTime
        DateTime bedtimeDateTime = DateTime(
          wakeDateTime.year,
          wakeDateTime.month,
          wakeDateTime.day,
          bedTime.hour,
          bedTime.minute,
        );

        // If bedtime is not strictly before the wake time on the SAME day,
        // it means you go to sleep the night before.
        if (!bedtimeDateTime.isBefore(wakeDateTime)) {
          bedtimeDateTime = bedtimeDateTime.subtract(const Duration(days: 1));
        }

        // 3. DND turns off exactly when the alarm was supposed to ring
        final wakeDndOffDateTime = wakeDateTime;

        final bedtimeId = (id + targetWeekday) + 500000;
        final wakeDndOffId = (id + targetWeekday) + 700000;

        final bedtimeParams = <String, dynamic>{
          'hour': bedTime.hour,
          'minute': bedTime.minute,
          'loop': true,
        };

        final wakeDndOffParams = <String, dynamic>{
          'hour': time.hour,
          'minute': time.minute,
          'loop': true,
        };

        await AndroidAlarmManager.oneShotAt(
          bedtimeDateTime,
          bedtimeId,
          fireBedtimeCallback,
          exact: true,
          wakeup: true,
          alarmClock: false,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: bedtimeParams,
        );

        registerScheduledAlarm(
          id: bedtimeId,
          when: bedtimeDateTime,
          params: bedtimeParams,
          source: 'bedtime',
        );

        debugPrint(
          '🌙 Bedtime DND scheduled for $day -> id=$bedtimeId at ${formatLogTime(bedtimeDateTime)}',
        );

        await AndroidAlarmManager.oneShotAt(
          wakeDndOffDateTime,
          wakeDndOffId,
          fireWakeDndOffCallback,
          exact: true,
          wakeup: true,
          alarmClock: false,
          allowWhileIdle: true,
          rescheduleOnReboot: true,
          params: wakeDndOffParams,
        );

        registerScheduledAlarm(
          id: wakeDndOffId,
          when: wakeDndOffDateTime,
          params: wakeDndOffParams,
          source: 'wake_dnd_off',
        );

        debugPrint(
          '☀️ Wake DND-off scheduled for $day -> id=$wakeDndOffId at ${formatLogTime(wakeDndOffDateTime)}',
        );
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
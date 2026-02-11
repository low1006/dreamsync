import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';
import 'package:dreamsync/views/alarm_ring_screen.dart';
import 'package:dreamsync/util/global.dart';
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Audio player for long alarm sound
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAlarmPlaying = false;

  Future<void> init() async {
    // 1. Initialize Timezone Database
    tz.initializeTimeZones();

    // 2. Get Device Timezone and set it properly
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      debugPrint("🌍 Device timezone name: $timeZoneName");

      tz.setLocalLocation(tz.getLocation(timeZoneName));

      // CRITICAL: Verify the timezone is set correctly
      final now = tz.TZDateTime.now(tz.local);
      debugPrint("📍 Timezone initialized: $timeZoneName");
      debugPrint("🕐 Current local time: $now");
      debugPrint("🌐 UTC offset: ${now.timeZoneOffset}");
    } catch (e) {
      debugPrint("⚠️ Error setting timezone: $e");
      // Fallback to Asia/Kuala_Lumpur if detection fails
      tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
      debugPrint("📍 Using fallback timezone: Asia/Kuala_Lumpur");
    }

    // 3. Android Setup with notification channel
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
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // This handles the tap event
        if (response.id != null) {
          await _launchAlarmScreen(response.id!);
        }
      },
    );

    // 5. Create notification channel
    await _createNotificationChannel();

    // 6. Request permissions
    await _requestPermissions();

    debugPrint("✅ Notification Service initialized successfully");
  }

  // AUTO-LAUNCH: Show alarm screen and play long sound
  Future<void> _launchAlarmScreen(int notificationId) async {
    debugPrint("🚀 Launching alarm screen for notification: $notificationId");

    // Start playing alarm sound (loops for 1 minute)
    await _playAlarmSound();

    // Navigate to alarm screen
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => AlarmRingScreen(
          notificationId: notificationId,
          onStop: _stopAlarmSound,
          onSnooze: (int id) => _handleSnooze(id),
        ),
      ),
    );
  }

  // LONG ALARM: Play alarm sound for 1 minute with looping
  Future<void> _playAlarmSound() async {
    if (_isAlarmPlaying) return;

    _isAlarmPlaying = true;
    debugPrint("🔊 Starting alarm sound (1 minute duration)");

    try {
      // Play the buzzer sound from assets
      await _audioPlayer.setSource(AssetSource('audio/buzzer.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Loop the sound
      await _audioPlayer.setVolume(1.0); // Max volume
      await _audioPlayer.resume();

      // Stop after 1 minute
      Future.delayed(const Duration(minutes: 1), () {
        if (_isAlarmPlaying) {
          _stopAlarmSound();
          debugPrint("⏱️ Alarm auto-stopped after 1 minute");
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      debugPrint("❌ Error playing alarm sound: $e");
      _isAlarmPlaying = false;
    }
  }

  // Stop alarm sound
  Future<void> _stopAlarmSound() async {
    if (!_isAlarmPlaying) return;

    debugPrint("🔇 Stopping alarm sound");
    await _audioPlayer.stop();
    _isAlarmPlaying = false;
  }

  // SNOOZE: Schedule alarm for 9 minutes later
  Future<void> _handleSnooze(int originalNotificationId) async {
    debugPrint("😴 Snoozing alarm for 9 minutes");

    // Stop current sound
    await _stopAlarmSound();

    // Cancel the current notification
    await flutterLocalNotificationsPlugin.cancel(originalNotificationId);

    // Schedule new one-time alarm for 9 minutes from now
    final snoozeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 9));

    // Use a unique snooze ID (add 100000 to avoid collision)
    final snoozeId = originalNotificationId + 100000;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel_v2',
      'Alarm Channel',
      channelDescription: 'Channel for Alarm Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('buzzer'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      enableVibration: true,
      enableLights: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      snoozeId,
      "Snooze Alarm",
      "Time to wake up!",
      snoozeTime,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint("⏰ Snooze alarm scheduled for: $snoozeTime");
  }

  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'alarm_channel_v2',
        'Alarm Channel',
        description: 'Channel for Alarm Notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        sound: RawResourceAndroidNotificationSound('buzzer'),
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      debugPrint("📢 Notification channel created: ${channel.id}");
    }
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      final bool? notifGranted =
      await androidImplementation?.requestNotificationsPermission();
      debugPrint("📱 Notification permission: ${notifGranted ?? false}");

      final bool? alarmGranted =
      await androidImplementation?.requestExactAlarmsPermission();
      debugPrint("⏰ Exact alarm permission: ${alarmGranted ?? false}");
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

  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required TimeOfDay time,
    required List<String> days,
    required bool isEnabled,
    required bool isSnoozeOn, // NEW: Check if snooze is enabled
  }) async {
    await cancelAlarm(id);

    if (!isEnabled || days.isEmpty) {
      debugPrint("⚠️ Alarm not scheduled - disabled or no days selected");
      return;
    }

    // Store snooze preference for this alarm
    _snoozeEnabled[id] = isSnoozeOn;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel_v2',
      'Alarm Channel',
      channelDescription: 'Channel for Alarm Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      sound: RawResourceAndroidNotificationSound('buzzer'),
      fullScreenIntent: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF00FF00),
      ledOnMs: 1000,
      ledOffMs: 500,
      autoCancel: false,
    );

    const NotificationDetails platformDetails =
    NotificationDetails(android: androidDetails);

    int scheduledCount = 0;
    for (String day in days) {
      final notificationId = _createUniqueId(id, day);
      final scheduledDate = _nextInstanceOfDayAndTime(time, _getDayOfWeek(day));

      debugPrint("📅 Scheduling alarm:");
      debugPrint("   Day: $day");
      debugPrint("   Time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}");
      debugPrint("   Scheduled for: $scheduledDate");
      debugPrint("   Notification ID: $notificationId");
      debugPrint("   Snooze enabled: $isSnoozeOn");

      final currentTime = tz.TZDateTime.now(tz.local);
      debugPrint("   Current time: $currentTime");
      debugPrint("   Time until alarm: ${scheduledDate.difference(currentTime)}");

      try {
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
        scheduledCount++;
        debugPrint("   ✅ Successfully scheduled");
      } catch (e) {
        debugPrint("   ❌ Error scheduling: $e");
      }
    }

    debugPrint("🎯 Total alarms scheduled: $scheduledCount/${days.length}");
  }

  // Store snooze preferences per alarm
  final Map<int, bool> _snoozeEnabled = {};

  bool isSnoozeEnabled(int alarmId) {
    return _snoozeEnabled[alarmId] ?? true; // Default to enabled
  }

  Future<void> cancelAlarm(int id) async {
    final allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    for (var day in allDays) {
      await flutterLocalNotificationsPlugin.cancel(_createUniqueId(id, day));
    }
    // Also cancel any snooze alarms
    for (var day in allDays) {
      await flutterLocalNotificationsPlugin.cancel(_createUniqueId(id, day) + 100000);
    }
    debugPrint("🗑️ Cancelled all alarms for ID: $id");
  }

  Future<void> checkPendingNotifications() async {
    final List<PendingNotificationRequest> pendingNotifications =
    await flutterLocalNotificationsPlugin.pendingNotificationRequests();

    debugPrint("📋 Pending notifications: ${pendingNotifications.length}");
    for (var notification in pendingNotifications) {
      debugPrint("   ID: ${notification.id}, Title: ${notification.title}");
    }
  }

  int _createUniqueId(int baseId, String day) {
    int safeBase = baseId.abs() % 100000;
    int dayOffset = _getDayOfWeek(day);
    return (safeBase * 10) + dayOffset;
  }

  int _getDayOfWeek(String day) {
    switch (day) {
      case 'Mon':
        return DateTime.monday;
      case 'Tue':
        return DateTime.tuesday;
      case 'Wed':
        return DateTime.wednesday;
      case 'Thu':
        return DateTime.thursday;
      case 'Fri':
        return DateTime.friday;
      case 'Sat':
        return DateTime.saturday;
      case 'Sun':
        return DateTime.sunday;
      default:
        return DateTime.monday;
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

  // Cleanup
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
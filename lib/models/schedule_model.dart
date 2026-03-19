import 'package:flutter/material.dart';

class ScheduleModel {
  final String id;
  final String label;
  final TimeOfDay bedtime;
  final TimeOfDay wakeTime;
  final bool isActive;
  final List<String> days;
  final bool isSmartAlarm;
  final bool isSmartNotification;
  final bool isSnoozeOn;

  final int toneId;
  final String toneName;
  final String toneFile;

  ScheduleModel({
    required this.id,
    required this.label,
    required this.bedtime,
    required this.wakeTime,
    required this.isActive,
    required this.days,
    this.isSmartAlarm = false,
    this.isSmartNotification = true,
    this.isSnoozeOn = true,
    this.toneId = 1,
    this.toneName = 'Classic',
    this.toneFile = 'classic.mp3',
  });

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    final toneData = map['store_items'] ?? {};
    final metadata = toneData['metadata'] ?? {};

    return ScheduleModel(
      id: map['schedule_id']?.toString() ?? '',
      label: map['label'] ?? 'Schedule',
      bedtime: _parseTime(map['target_bed_time']),
      wakeTime: _parseTime(map['target_wake_time']),
      isActive: map['is_alarm_on'] ?? true,
      days: _parseDays(map['days']),
      isSmartAlarm: map['is_smart_alarm'] ?? false,
      isSmartNotification: map['is_smart_notification'] ?? true,
      isSnoozeOn: map['is_snooze_on'] ?? true,
      toneId: map['item_id'] ?? 1,
      toneName: toneData['name'] ?? 'Classic',
      toneFile: metadata['file'] ?? 'classic.mp3',
    );
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  static List<String> _parseDays(dynamic input) {
    if (input == null) return [];

    if (input is List) {
      return List<String>.from(input);
    }

    if (input is String) {
      final clean = input.replaceAll(RegExp(r'[\[\]"{}]'), '');
      if (clean.trim().isEmpty) return [];
      return clean.split(',').map((e) => e.trim()).toList();
    }

    return [];
  }

  static String formatTimeForDB(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m:00";
  }

  ScheduleModel copyWith({
    String? id,
    String? label,
    TimeOfDay? bedtime,
    TimeOfDay? wakeTime,
    bool? isActive,
    List<String>? days,
    bool? isSmartAlarm,
    bool? isSmartNotification,
    bool? isSnoozeOn,
    int? toneId,
    String? toneName,
    String? toneFile,
  }) {
    return ScheduleModel(
      id: id ?? this.id,
      label: label ?? this.label,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      isActive: isActive ?? this.isActive,
      days: days ?? this.days,
      isSmartAlarm: isSmartAlarm ?? this.isSmartAlarm,
      isSmartNotification: isSmartNotification ?? this.isSmartNotification,
      isSnoozeOn: isSnoozeOn ?? this.isSnoozeOn,
      toneId: toneId ?? this.toneId,
      toneName: toneName ?? this.toneName,
      toneFile: toneFile ?? this.toneFile,
    );
  }
}
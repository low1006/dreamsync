import "package:dreamsync/util/parsers.dart";
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
  final int snoozeDurationMinutes;

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
    this.snoozeDurationMinutes = 5,
    this.toneId = 1,
    this.toneName = 'Classic',
    this.toneFile = 'classic.mp3',
  });

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    final toneData = map['store_items'] is Map<String, dynamic>
        ? map['store_items'] as Map<String, dynamic>
        : <String, dynamic>{};

    final metadata = toneData['metadata'] is Map<String, dynamic>
        ? toneData['metadata'] as Map<String, dynamic>
        : <String, dynamic>{};

    return ScheduleModel(
      id: map['schedule_id']?.toString() ?? '',
      label: (map['label'] ?? 'Schedule').toString(),
      bedtime: _parseTime(map['target_bed_time']),
      wakeTime: _parseTime(map['target_wake_time']),
      isActive: Parsers.toBool(map['is_alarm_on'], fallback: true),
      days: _parseDays(map['days']),
      isSmartAlarm: Parsers.toBool(map['is_smart_alarm']),
      isSmartNotification:
      Parsers.toBool(map['is_smart_notification'], fallback: true),
      isSnoozeOn: Parsers.toBool(map['is_snooze_on'], fallback: true),
      snoozeDurationMinutes: Parsers.toInt(map['snooze_duration_minutes'], fallback: 5),
      toneId: Parsers.toInt(map['item_id'], fallback: 1),
      toneName: (toneData['name'] ?? 'Classic').toString(),
      toneFile: (metadata['file'] ?? 'classic.mp3').toString(),
    );
  }

  static TimeOfDay _parseTime(dynamic input) {
    final timeStr = (input ?? '00:00:00').toString();
    final parts = timeStr.split(':');

    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static List<String> _parseDays(dynamic input) {
    if (input == null) return [];

    if (input is List) {
      return input.map((e) => e.toString()).toList();
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
    int? snoozeDurationMinutes,
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
      snoozeDurationMinutes: snoozeDurationMinutes ?? this.snoozeDurationMinutes,
      toneId: toneId ?? this.toneId,
      toneName: toneName ?? this.toneName,
      toneFile: toneFile ?? this.toneFile,
    );
  }
}
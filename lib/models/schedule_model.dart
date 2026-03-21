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
      isActive: _toBool(map['is_alarm_on'], defaultValue: true),
      days: _parseDays(map['days']),
      isSmartAlarm: _toBool(map['is_smart_alarm']),
      isSmartNotification:
      _toBool(map['is_smart_notification'], defaultValue: true),
      isSnoozeOn: _toBool(map['is_snooze_on'], defaultValue: true),
      toneId: _toInt(map['item_id'], defaultValue: 1),
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

  static bool _toBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    final text = value.toString().toLowerCase().trim();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return defaultValue;
  }

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? defaultValue;
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
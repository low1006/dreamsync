import 'package:flutter/material.dart';

class ScheduleModel {
  final String id;
  final String label;
  final TimeOfDay bedtime;
  final TimeOfDay wakeTime;
  final bool isActive;
  final List<String> days;
  final bool isSmartAlarm;
  final bool isSnoozeOn;

  ScheduleModel({
    required this.id,
    required this.label,
    required this.bedtime,
    required this.wakeTime,
    required this.isActive,
    required this.days,
    this.isSmartAlarm = false,
    this.isSnoozeOn = true,

  });

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      // FIXED: Map 'schedule_id' from DB to 'id' in app
      id: map['schedule_id']?.toString() ?? '',

      // NOTE: Since 'label' column is missing in DB, this defaults to 'Schedule'
      label: map['label'] ?? 'Schedule',

      bedtime: _parseTime(map['target_bed_time']),
      wakeTime: _parseTime(map['target_wake_time']),

      // FIXED: Map 'is_alarm_on' from DB to 'isActive' in app
      isActive: map['is_alarm_on'] ?? true,

      days: _parseDays(map['days']),
      isSmartAlarm: map['is_smart_alarm'] ?? false,
      isSnoozeOn: map['is_snooze_on']?? true,
    );
  }

  static TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1])
    );
  }

  static List<String> _parseDays(dynamic input) {
    if (input == null) return [];

    // Case A: It's already a List (Standard Supabase Array/JSON)
    if (input is List) {
      return List<String>.from(input);
    }

    // Case B: It's a String (e.g., "{Mon,Tue}" or "['Mon', 'Tue']")
    if (input is String) {
      // Remove brackets [], braces {}, and quotes ""
      final clean = input.replaceAll(RegExp(r'[\[\]"{}]'), '');
      if (clean.trim().isEmpty) return [];
      // Split by comma and trim whitespace
      return clean.split(',').map((e) => e.trim()).toList();
    }

    return [];
  }


  static String formatTimeForDB(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return "$h:$m:00";
  }
}
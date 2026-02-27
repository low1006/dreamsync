import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/schedule_model.dart';

class ScheduleRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final String _tableName = 'sleep_schedules';

  Future<List<ScheduleModel>> fetchSchedules() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from(_tableName)
        .select('*, store_items(*)')
        .eq('user_id', userId);

    return (data as List).map((e) => ScheduleModel.fromMap(e)).toList();
  }

  Future<void> createSchedule({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required bool isSmartAlarm,        // Pass to DB
    required bool isSmartNotification,
    required int itemId,
    bool isSnoozeOn = true,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from(_tableName).insert({
      'user_id': userId,
      'target_bed_time': ScheduleModel.formatTimeForDB(bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(wakeTime),
      'days': days,
      'is_alarm_on': true,
      'is_smart_alarm': isSmartAlarm,
      'is_smart_notification': isSmartNotification,
      'item_id': itemId,
      'is_snooze_on': isSnoozeOn,
    });
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    await _client.from(_tableName).update({
      'target_bed_time': ScheduleModel.formatTimeForDB(schedule.bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(schedule.wakeTime),
      'days': schedule.days,
      'is_alarm_on': schedule.isActive,
      'is_smart_alarm': schedule.isSmartAlarm,
      'is_smart_notification': schedule.isSmartNotification,
      'is_snooze_on' : schedule.isSnoozeOn,
      'item_id': schedule.toneId,
    }).eq('schedule_id', schedule.id);
  }

  Future<void> toggleActive(String id, bool currentValue) async {
    await _client.from(_tableName).update({'is_alarm_on': currentValue}).eq('schedule_id', id);
  }

  Future<void> toggleSmartNotification(String id, bool currentValue) async {
    await _client.from(_tableName).update({'is_smart_notification': currentValue}).eq('schedule_id', id);
  }

  // --- ADDED THIS METHOD ---
  Future<void> toggleSmartAlarm(String id, bool currentValue) async {
    await _client.from(_tableName).update({'is_smart_alarm': currentValue}).eq('schedule_id', id);
  }

  Future<void> deleteSchedule(String id) async {
    await _client.from(_tableName).delete().eq('schedule_id', id);
  }
}
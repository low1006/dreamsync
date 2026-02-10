import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/schedule_model.dart';

class ScheduleRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final String _tableName = 'sleep_schedules';

  // Fetch all schedules
  Future<List<ScheduleModel>> fetchSchedules() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // FIX: Join with store_items so we know the tone name/file
    final data = await _client
        .from(_tableName)
        .select('*, store_items(*)')
        .eq('user_id', userId);

    return (data as List).map((e) => ScheduleModel.fromMap(e)).toList();
  }

  // Create (Now requires itemId)
  Future<void> createSchedule({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required bool isSmartAlarm,
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
      'item_id': itemId,
      'is_snooze_on': isSnoozeOn,
    });
  }

  // Update
  Future<void> updateSchedule(ScheduleModel schedule) async {
    await _client.from(_tableName).update({
      'target_bed_time': ScheduleModel.formatTimeForDB(schedule.bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(schedule.wakeTime),
      'days': schedule.days,
      'is_alarm_on': schedule.isActive,
      'is_smart_alarm': schedule.isSmartAlarm,
      'is_snooze_on' : schedule.isSnoozeOn,
    }).eq('schedule_id', schedule.id);
  }

  Future<void> toggleActive(String id, bool currentValue) async {
    await _client.from(_tableName).update({'is_alarm_on': currentValue}).eq('schedule_id', id);
  }

  Future<void> deleteSchedule(String id) async {
    await _client.from(_tableName).delete().eq('schedule_id', id);
  }
}
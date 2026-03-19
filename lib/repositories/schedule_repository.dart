import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/util/local_database.dart';

class ScheduleRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final String _tableName = 'sleep_schedules';

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
    } catch (_) {
      return false;
    }
  }

  Future<List<ScheduleModel>> fetchSchedules() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    if (await _isOnline()) {
      try {
        final data = await _client
            .from(_tableName)
            .select('*, store_items(*)')
            .eq('user_id', userId);

        for (var json in data) {
          final localJson = Map<String, dynamic>.from(json);
          localJson['id'] = localJson['schedule_id']?.toString() ?? DateTime.now().toString();
          localJson.remove('store_items');
          await LocalDatabase.instance.insertRecord('schedule', localJson, isSynced: true);
        }

        return (data as List).map((e) => ScheduleModel.fromMap(e)).toList();
      } catch (e) {
        debugPrint("❌ Supabase fetch failed: $e, falling back to local cache.");
        return _getOfflineSchedules(userId);
      }
    } else {
      debugPrint("📴 Offline: Fetching schedules from local database.");
      return _getOfflineSchedules(userId);
    }
  }

  Future<List<ScheduleModel>> _getOfflineSchedules(String userId) async {
    try {
      final localRecords = await LocalDatabase.instance.getAllByUser('schedule', userId);
      return localRecords.map((json) {
        final map = Map<String, dynamic>.from(json);

        map['schedule_id'] = map['schedule_id'] ?? map['id'];

        if (map['is_alarm_on'] is int) map['is_alarm_on'] = map['is_alarm_on'] == 1;
        if (map['is_smart_alarm'] is int) map['is_smart_alarm'] = map['is_smart_alarm'] == 1;
        if (map['is_smart_notification'] is int) map['is_smart_notification'] = map['is_smart_notification'] == 1;
        if (map['is_snooze_on'] is int) map['is_snooze_on'] = map['is_snooze_on'] == 1;

        // 🚨 FIXED: Removed the broken string split here. The JSON string is passed directly
        // to ScheduleModel.fromMap where it uses regex to safely decode it.

        return ScheduleModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint("❌ Error fetching offline schedules: $e");
      return [];
    }
  }

  Future<void> createSchedule({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required bool isSmartAlarm,
    required bool isSmartNotification,
    required int itemId,
    bool isSnoozeOn = true,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final scheduleData = {
      'user_id': userId,
      'target_bed_time': ScheduleModel.formatTimeForDB(bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(wakeTime),
      'days': days,
      'is_alarm_on': true,
      'is_smart_alarm': isSmartAlarm,
      'is_smart_notification': isSmartNotification,
      'item_id': itemId,
      'is_snooze_on': isSnoozeOn,
    };

    if (await _isOnline()) {
      try {
        final response = await _client.from(_tableName).insert(scheduleData).select().single();
        final localJson = Map<String, dynamic>.from(response);
        localJson['id'] = localJson['schedule_id']?.toString() ?? DateTime.now().toString();
        await LocalDatabase.instance.insertRecord('schedule', localJson, isSynced: true);
      } catch (e) {
        _saveOfflineSchedule(scheduleData);
      }
    } else {
      _saveOfflineSchedule(scheduleData);
    }
  }

  Future<void> _saveOfflineSchedule(Map<String, dynamic> scheduleData) async {
    scheduleData['id'] = 'offline_${DateTime.now().millisecondsSinceEpoch}';
    await LocalDatabase.instance.insertRecord('schedule', scheduleData, isSynced: false);
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    final updateData = {
      'target_bed_time': ScheduleModel.formatTimeForDB(schedule.bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(schedule.wakeTime),
      'days': schedule.days,
      'is_alarm_on': schedule.isActive,
      'is_smart_alarm': schedule.isSmartAlarm,
      'is_smart_notification': schedule.isSmartNotification,
      'is_snooze_on': schedule.isSnoozeOn,
      'item_id': schedule.toneId,
    };

    if (await _isOnline()) {
      try {
        await _client.from(_tableName).update(updateData).eq('schedule_id', schedule.id);
        final localData = Map<String, dynamic>.from(updateData);
        localData['id'] = schedule.id.toString();
        localData['user_id'] = _client.auth.currentUser?.id ?? '';
        await LocalDatabase.instance.insertRecord('schedule', localData, isSynced: true);
      } catch (e) {
        debugPrint("Error updating schedule online: $e");
      }
    }
  }

  Future<void> toggleActive(String id, bool currentValue) async {
    if (await _isOnline()) {
      await _client.from(_tableName).update({'is_alarm_on': currentValue}).eq('schedule_id', id);
    }
  }

  Future<void> toggleSmartNotification(String id, bool currentValue) async {
    if (await _isOnline()) {
      await _client.from(_tableName).update({'is_smart_notification': currentValue}).eq('schedule_id', id);
    }
  }

  Future<void> toggleSmartAlarm(String id, bool currentValue) async {
    if (await _isOnline()) {
      await _client.from(_tableName).update({'is_smart_alarm': currentValue}).eq('schedule_id', id);
    }
  }

  Future<void> toggleSnooze(String id, bool currentValue) async {
    if (await _isOnline()) {
      try {
        await _client.from(_tableName).update({'is_snooze_on': currentValue}).eq('schedule_id', id);
      } catch (e) {
        debugPrint("Error toggling snooze online: $e");
      }
    } else {
      debugPrint("📴 Offline: Cannot toggle snooze right now.");
    }
  }

  Future<void> deleteSchedule(String id) async {
    if (await _isOnline()) {
      await _client.from(_tableName).delete().eq('schedule_id', id);
    }
  }

  Future<void> syncOfflineData() async {
    final unsynced = await LocalDatabase.instance.getUnsyncedRecords('schedule');
    for (var record in unsynced) {
      try {
        final supabaseData = Map<String, dynamic>.from(record)..remove('is_synced')..remove('id');
        await _client.from(_tableName).insert(supabaseData);
        await LocalDatabase.instance.markAsSynced('schedule', record['id']);
        debugPrint("✅ Synced offline schedule");
      } catch (e) {
        debugPrint("❌ Schedule sync failed: $e");
      }
    }
  }

  Future<int> assignDefaultTone() async {
    final userId = _client.auth.currentUser?.id;
    int defaultId = 1; // Fallback ID

    if (userId == null) return defaultId;

    if (await _isOnline()) {
      try {
        final defaultToneData = await _client
            .from('store_items')
            .select()
            .eq('cost', 0)
            .eq('type', 'TONE')
            .limit(1)
            .maybeSingle();

        if (defaultToneData != null) {
          defaultId = defaultToneData['item_id'];
        }

        await _client.from('user_inventory').upsert({
          'user_id': userId,
          'item_id': defaultId,
        }, onConflict: 'user_id, item_id');

      } catch (e) {
        debugPrint("Network unavailable, using default tone ID $defaultId: $e");
      }
    }

    return defaultId;
  }
}
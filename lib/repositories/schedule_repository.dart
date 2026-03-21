import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:dreamsync/models/schedule_model.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

class ScheduleRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _tableName = 'sleep_schedules';

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<List<ScheduleModel>> fetchSchedules() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final db = await _db;
    final rows = await db.query(
      'sleep_schedule',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'target_bed_time ASC',
    );

    return rows
        .map((json) => ScheduleModel.fromMap(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> createSchedule({
    required TimeOfDay bedtime,
    required TimeOfDay wakeTime,
    required List<String> days,
    required bool isSmartAlarm,
    required bool isSmartNotification,
    required int itemId,
    required bool isSnoozeOn,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in.');
    }

    final scheduleId = '${userId}_${DateTime.now().millisecondsSinceEpoch}';

    final localRow = {
      'schedule_id': scheduleId,
      'user_id': userId,
      'target_bed_time': ScheduleModel.formatTimeForDB(bedtime),
      'target_wake_time': ScheduleModel.formatTimeForDB(wakeTime),
      'days': jsonEncode(days),
      'is_alarm_on': 1,
      'is_smart_alarm': isSmartAlarm ? 1 : 0,
      'is_smart_notification': isSmartNotification ? 1 : 0,
      'item_id': itemId,
      'is_snooze_on': isSnoozeOn ? 1 : 0,
    };

    await LocalDatabase.instance.insertRecord(
      'sleep_schedule',
      localRow,
      isSynced: false,
    );

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: schedule saved locally only.');
      return;
    }

    await _syncScheduleById(scheduleId);
  }

  Future<void> updateSchedule(ScheduleModel schedule) async {
    final db = await _db;

    await db.update(
      'sleep_schedule',
      {
        'target_bed_time': ScheduleModel.formatTimeForDB(schedule.bedtime),
        'target_wake_time': ScheduleModel.formatTimeForDB(schedule.wakeTime),
        'days': jsonEncode(schedule.days),
        'is_alarm_on': schedule.isActive ? 1 : 0,
        'is_smart_alarm': schedule.isSmartAlarm ? 1 : 0,
        'is_smart_notification': schedule.isSmartNotification ? 1 : 0,
        'item_id': schedule.toneId,
        'is_snooze_on': schedule.isSnoozeOn ? 1 : 0,
        'is_synced': 0,
      },
      where: 'schedule_id = ?',
      whereArgs: [schedule.id],
    );

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: schedule update kept local.');
      return;
    }

    await _syncScheduleById(schedule.id);
  }

  Future<void> toggleActive(String id, bool newValue) async {
    await _updateLocalBool(id, 'is_alarm_on', newValue);
  }

  Future<void> toggleSmartNotification(String id, bool newValue) async {
    await _updateLocalBool(id, 'is_smart_notification', newValue);
  }

  Future<void> toggleSmartAlarm(String id, bool newValue) async {
    await _updateLocalBool(id, 'is_smart_alarm', newValue);
  }

  Future<void> toggleSnooze(String id, bool newValue) async {
    await _updateLocalBool(id, 'is_snooze_on', newValue);
  }

  Future<void> deleteSchedule(String id) async {
    final db = await _db;
    await db.delete(
      'sleep_schedule',
      where: 'schedule_id = ?',
      whereArgs: [id],
    );

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: schedule deleted locally only.');
      return;
    }

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _client.from(_tableName).delete().eq('user_id', userId);
        debugPrint('✅ Schedule deleted from Supabase: $id');
      } else {
        debugPrint('⚠️ Failed deleting schedule from Supabase: no user');
      }
    } catch (e) {
      debugPrint('⚠️ Failed deleting schedule from Supabase: $e');
    }
  }

  Future<void> _updateLocalBool(String id, String field, bool value) async {
    final db = await _db;
    await db.update(
      'sleep_schedule',
      {field: value ? 1 : 0, 'is_synced': 0},
      where: 'schedule_id = ?',
      whereArgs: [id],
    );

    final online = await NetworkHelper.hasInternet();
    if (!online) return;

    await _syncScheduleById(id);
  }

  Future<void> syncPendingSchedules() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: pending schedule sync skipped.');
      return;
    }

    final db = await _db;
    final rows = await db.query(
      'sleep_schedule',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
    );

    for (final row in rows) {
      await _syncLocalRow(row);
    }
  }

  Future<void> _syncScheduleById(String scheduleId) async {
    final db = await _db;
    final rows = await db.query(
      'sleep_schedule',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
      limit: 1,
    );

    if (rows.isEmpty) return;
    await _syncLocalRow(rows.first);
  }

  Future<void> _syncLocalRow(Map<String, dynamic> row) async {
    try {
      final daysValue = row['days'];
      final days = daysValue is String ? jsonDecode(daysValue) : daysValue;

      await _client.from(_tableName).upsert({
        'user_id': row['user_id'],
        'target_bed_time': row['target_bed_time'],
        'target_wake_time': row['target_wake_time'],
        'days': days,
        'is_alarm_on': row['is_alarm_on'] == 1,
        'is_smart_alarm': row['is_smart_alarm'] == 1,
        'is_smart_notification': row['is_smart_notification'] == 1,
        'item_id': row['item_id'],
        'is_snooze_on': row['is_snooze_on'] == 1,
      }, onConflict: 'user_id');

      final db = await _db;
      await db.update(
        'sleep_schedule',
        {'is_synced': 1},
        where: 'schedule_id = ?',
        whereArgs: [row['schedule_id']],
      );

      debugPrint('✅ Schedule synced: ${row['schedule_id']}');
    } catch (e) {
      debugPrint('⚠️ Schedule sync failed for ${row['schedule_id']}: $e');
    }
  }

  Future<int> assignDefaultTone() async {
    final userId = _client.auth.currentUser?.id;
    int defaultId = 1;

    if (userId == null) return defaultId;

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return defaultId;
    }

    try {
      final ownedItems = await _client
          .from('user_inventory')
          .select('item_id')
          .eq('user_id', userId);

      if (ownedItems is List && ownedItems.isNotEmpty) {
        final itemIds = ownedItems
            .map((item) => item['item_id'])
            .where((id) => id != null)
            .cast<int>()
            .toList();

        if (itemIds.isNotEmpty) {
          defaultId = itemIds.first;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to assign default tone, using fallback: $e');
    }

    return defaultId;
  }
}
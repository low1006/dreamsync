import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/services/encryption_service.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

/// Coordinates offline-first sync between local encrypted SQLite and Supabase.
///
/// Responsibilities:
///   1. Push unsynced local records (encrypted) to Supabase.
///   2. Restore encrypted records from Supabase into local DB.
///
/// Public API:
///   [syncAll]                    — push all unsynced records (both tables).
///   [syncSleepRecords]           — push unsynced sleep records only.
///   [syncActivityRecords]        — push unsynced activity records only.
///   [restoreFromCloud]           — restore both tables from encrypted cloud.
///   [restoreSleepFromCloud]      — restore sleep only.
///   [restoreActivityFromCloud]   — restore activity only.
///   [isLocalEmpty]               — check if sleep_record is empty for user.
///   [isActivityLocalEmpty]       — check if daily_activity is empty for user.
class SyncService {
  final SupabaseClient _client = Supabase.instance.client;
  final EncryptionService _encryption = EncryptionService.instance;

  Future<Database> get _db async => LocalDatabase.instance.database;

  // ===========================================================================
  // SYNC ALL — push unsynced records to Supabase (encrypted)
  // ===========================================================================

  Future<void> syncAll(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ SyncService: device is offline, sync skipped.');
      return;
    }

    debugPrint('🔄 SyncService: starting sync for $userId...');
    await syncSleepRecords(userId);
    await syncActivityRecords(userId);
    debugPrint('✅ SyncService: sync complete.');
  }

  // ===========================================================================
  // RESTORE ALL — decrypt cloud data into local DB
  // ===========================================================================

  Future<void> restoreFromCloud(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ SyncService: device is offline, restore skipped.');
      return;
    }

    debugPrint('☁️ SyncService: restoring all data from cloud for $userId...');
    await restoreSleepFromCloud(userId);
    await restoreActivityFromCloud(userId);
    debugPrint('✅ SyncService: cloud restore complete.');
  }

  // ===========================================================================
  // EMPTY CHECKS
  // ===========================================================================

  Future<bool> isLocalEmpty(String userId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM sleep_record WHERE user_id = ?',
        [userId],
      ),
    );
    return (count ?? 0) == 0;
  }

  Future<bool> isActivityLocalEmpty(String userId) async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM daily_activities WHERE user_id = ?',
        [userId],
      ),
    );
    return (count ?? 0) == 0;
  }

  // ===========================================================================
  // SLEEP — sync unsynced records
  // ===========================================================================

  Future<void> syncSleepRecords(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ syncSleepRecords skipped: device is offline.');
      return;
    }

    try {
      final db = await _db;
      final unsynced = await db.query(
        'sleep_record',
        where: 'user_id = ? AND is_synced = 0',
        whereArgs: [userId],
      );

      if (unsynced.isEmpty) {
        debugPrint('   sleep_record: nothing to sync.');
        return;
      }

      debugPrint('   sleep_record: ${unsynced.length} unsynced record(s).');

      for (final row in unsynced) {
        try {
          final record = SleepRecordModel.fromJson(
            Map<String, dynamic>.from(row),
          );

          final payload = _sleepToEncryptableMap(record);
          final encrypted = _encryption.encryptData(payload, userId);

          await _client.from('sleep_record').upsert({
            'user_id': userId,
            'date': record.date,
            'encrypted_payload': encrypted['encrypted_payload'],
            'iv': encrypted['iv'],
          }, onConflict: 'user_id,date');

          await db.update(
            'sleep_record',
            {'is_synced': 1},
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, record.date],
          );

          debugPrint('   ✅ Synced sleep ${record.date}');
        } catch (e) {
          debugPrint('   ⚠️ Failed to sync sleep ${row['date']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ syncSleepRecords error: $e');
    }
  }

  // ===========================================================================
  // SLEEP — restore from cloud
  // ===========================================================================

  Future<void> restoreSleepFromCloud(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ restoreSleepFromCloud skipped: device is offline.');
      return;
    }

    try {
      final rows = await _client
          .from('sleep_record')
          .select()
          .eq('user_id', userId);

      if ((rows as List).isEmpty) {
        debugPrint('   No encrypted sleep records found in cloud.');
        return;
      }

      debugPrint('   Restoring ${rows.length} sleep record(s) from cloud...');

      for (final row in rows) {
        try {
          final decrypted = _encryption.decryptData(
            row['encrypted_payload'] as String,
            row['iv'] as String,
            userId,
          );

          final date = row['date'] as String;

          final localRow = {
            'sleep_id': '${userId}_$date',
            'user_id': userId,
            'date': date,
            'total_minutes': _toInt(decrypted['total_minutes']),
            'sleep_score': _toInt(decrypted['sleep_score']),
            'deep_minutes': _toInt(decrypted['deep_minutes']),
            'light_minutes': _toInt(decrypted['light_minutes']),
            'rem_minutes': _toInt(decrypted['rem_minutes']),
            'awake_minutes': _toInt(decrypted['awake_minutes']),
            'hypnogram_json': decrypted['hypnogram_json'],
            'mood_feedback': decrypted['mood_feedback'],
          };

          await LocalDatabase.instance.insertRecord(
            'sleep_record',
            localRow,
            isSynced: true,
          );

          debugPrint('   ✅ Restored sleep $date');
        } catch (e) {
          debugPrint('   ⚠️ Failed to restore sleep ${row['date']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ restoreSleepFromCloud error: $e');
    }
  }

  // ===========================================================================
  // ACTIVITY — sync unsynced records
  // ===========================================================================

  Future<void> syncActivityRecords(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ syncActivityRecords skipped: device is offline.');
      return;
    }

    try {
      final db = await _db;
      final unsynced = await db.query(
        'daily_activities',
        where: 'user_id = ? AND is_synced = 0',
        whereArgs: [userId],
      );

      if (unsynced.isEmpty) {
        debugPrint('   daily_activities: nothing to sync.');
        return;
      }

      debugPrint('   daily_activities: ${unsynced.length} unsynced record(s).');

      for (final row in unsynced) {
        try {
          final record = DailyActivityModel.fromJson(
            Map<String, dynamic>.from(row),
          );

          final payload = _activityToEncryptableMap(record);
          final encrypted = _encryption.encryptData(payload, userId);

          await _client.from('daily_activities').upsert({
            'user_id': userId,
            'date': record.date,
            'encrypted_payload': encrypted['encrypted_payload'],
            'iv': encrypted['iv'],
          }, onConflict: 'user_id,date');

          await db.update(
            'daily_activities',
            {'is_synced': 1},
            where: 'user_id = ? AND date = ?',
            whereArgs: [userId, record.date],
          );

          debugPrint('   ✅ Synced activity ${record.date}');
        } catch (e) {
          debugPrint('   ⚠️ Failed to sync activity ${row['date']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ syncActivityRecords error: $e');
    }
  }

  // ===========================================================================
  // ACTIVITY — restore from cloud
  // ===========================================================================

  Future<void> restoreActivityFromCloud(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ restoreActivityFromCloud skipped: device is offline.');
      return;
    }

    try {
      final rows = await _client
          .from('daily_activities')
          .select()
          .eq('user_id', userId);

      if ((rows as List).isEmpty) {
        debugPrint('   No encrypted activity records found in cloud.');
        return;
      }

      debugPrint('   Restoring ${rows.length} activity record(s) from cloud...');

      for (final row in rows) {
        try {
          final decrypted = _encryption.decryptData(
            row['encrypted_payload'] as String,
            row['iv'] as String,
            userId,
          );

          final date = row['date'] as String;

          final localRow = {
            'activity_id': '${userId}_$date',
            'user_id': userId,
            'date': date,
            'exercise_minutes': _toInt(decrypted['exercise_minutes']),
            'food_calories': _toInt(decrypted['food_calories']),
            'screen_time_minutes': _toInt(decrypted['screen_time_minutes']),
          };

          await LocalDatabase.instance.insertRecord(
            'daily_activities',
            localRow,
            isSynced: true,
          );

          debugPrint('   ✅ Restored activity $date');
        } catch (e) {
          debugPrint('   ⚠️ Failed to restore activity ${row['date']}: $e');
        }
      }
    } catch (e) {
      debugPrint('❌ restoreActivityFromCloud error: $e');
    }
  }

  // ===========================================================================
  // PRIVATE — helpers
  // ===========================================================================

  Map<String, dynamic> _sleepToEncryptableMap(SleepRecordModel r) {
    return {
      'total_minutes': r.totalMinutes,
      'sleep_score': r.sleepScore,
      'deep_minutes': r.deepMinutes,
      'light_minutes': r.lightMinutes,
      'rem_minutes': r.remMinutes,
      'awake_minutes': r.awakeMinutes,
      'hypnogram_json': r.hypnogramJson,
      'mood_feedback': r.moodFeedback,
    };
  }

  Map<String, dynamic> _activityToEncryptableMap(DailyActivityModel r) {
    return {
      'exercise_minutes': r.exerciseMinutes,
      'food_calories': r.foodCalories,
      'screen_time_minutes': r.screenTimeMinutes,
    };
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }
}
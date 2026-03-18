import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/util/local_database.dart';

class SleepRepository {
  final _client = Supabase.instance.client;

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));

      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet;
    } catch (_) {
      return false;
    }
  }

  /// Columns that exist locally (SQLite) but are NOT in the Supabase schema.
  /// Supabase sleep_record only has:
  ///   record_id, date, total_minutes, sleep_score, created_at, user_id, mood_feedback
  ///
  /// Everything else is local-only and must be stripped before any upsert.
  static const List<String> _localOnlyColumns = [
    'is_synced',
    'deep_minutes',
    'light_minutes',
    'rem_minutes',
    'awake_minutes',
    'hypnogram_json',
  ];

  /// Strips all local-only columns from a record map before upserting to Supabase.
  Map<String, dynamic> _toSupabaseJson(Map<String, dynamic> json) {
    final copy = Map<String, dynamic>.from(json);
    for (final col in _localOnlyColumns) {
      copy.remove(col);
    }
    return copy;
  }

  // ─── Queries ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getLatestDailyRecord(String userId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.rawQuery('''
        SELECT *
        FROM sleep_record
        WHERE user_id = ? AND total_minutes > 0
        ORDER BY date DESC
        LIMIT 1
      ''', [userId]);

      if (rows.isNotEmpty) return rows.first;
    } catch (e) {
      debugPrint('❌ getLatestDailyRecord error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getLatestRecordForMoodCheck(
      String userId, String cutoffDate) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.rawQuery('''
        SELECT date, mood_feedback
        FROM sleep_record
        WHERE user_id = ? AND date >= ? AND total_minutes > 0
        ORDER BY date DESC
        LIMIT 1
      ''', [userId, cutoffDate]);

      if (rows.isNotEmpty) return rows.first;
    } catch (e) {
      debugPrint('❌ getLatestRecordForMoodCheck error: $e');
    }
    return null;
  }

  Future<List<SleepRecordModel>> getAllSleepRecords(String userId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query(
        'sleep_record',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date ASC',
      );
      return rows.map((e) => SleepRecordModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ Error getting all sleep records: $e');
      return [];
    }
  }

  Future<List<SleepRecordModel>> getSleepRecordsByDateRange(
      String userId, String startDateStr, String endDateStr) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query(
        'sleep_record',
        where: 'user_id = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startDateStr, endDateStr],
        orderBy: 'date DESC',
      );
      return rows
          .map((e) => SleepRecordModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching sleep data range: $e');
      return [];
    }
  }

  // ─── Writes ─────────────────────────────────────────────────────────────────

  Future<void> saveDailySummary(SleepRecordModel record) async {
    await saveDailySummaries([record]);
  }

  Future<void> saveDailySummaries(List<SleepRecordModel> records) async {
    if (records.isEmpty) return;

    final online = await _isOnline();
    final db = await LocalDatabase.instance.database;

    for (final record in records) {
      try {
        // Preserve any existing mood feedback so a sync never wipes it
        final existing = await db.query(
          'sleep_record',
          columns: ['mood_feedback'],
          where: 'user_id = ? AND date = ?',
          whereArgs: [record.userId, record.date],
        );

        String? preservedMood;
        if (existing.isNotEmpty) {
          preservedMood = existing.first['mood_feedback'] as String?;
        }
        if (preservedMood == null || preservedMood.isEmpty) {
          preservedMood = record.moodFeedback;
        }

        final toInsert = record.toJson();
        toInsert['mood_feedback'] = preservedMood;
        toInsert['is_synced'] = online ? 1 : 0;

        await db.insert(
          'sleep_record',
          toInsert,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (e) {
        debugPrint('❌ Failed to save local daily summary: $e');
      }
    }

    if (online) {
      try {
        // ✅ FIX 2: Strip awake_minutes (and is_synced) before sending to Supabase
        final toUpsert =
        records.map((r) => _toSupabaseJson(r.toJson())).toList();

        // ✅ FIX: specify onConflict so Supabase updates on (user_id, date)
        // instead of defaulting to primary key and throwing a duplicate error.
        await _client
            .from('sleep_record')
            .upsert(toUpsert, onConflict: 'user_id,date');

        // Mark all records as synced locally
        for (final r in records) {
          await db.update(
            'sleep_record',
            {'is_synced': 1},
            where: 'user_id = ? AND date = ?',
            whereArgs: [r.userId, r.date],
          );
        }
      } catch (e) {
        debugPrint('❌ Failed to upsert to Supabase: $e');
      }
    } else {
      debugPrint('📴 Offline: skipped Supabase upsert for daily summaries.');
    }
  }

  Future<void> saveMoodFeedback({
    required String userId,
    required String date,
    required String mood,
  }) async {
    try {
      final db = await LocalDatabase.instance.database;

      await db.update(
        'sleep_record',
        {
          'mood_feedback': mood,
          'is_synced': 0,
        },
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
      );
      debugPrint('✅ Mood saved locally: $mood for $date');

      if (await _isOnline()) {
        await _client
            .from('sleep_record')
            .update({'mood_feedback': mood})
            .eq('user_id', userId)
            .eq('date', date);

        await db.update(
          'sleep_record',
          {'is_synced': 1},
          where: 'user_id = ? AND date = ?',
          whereArgs: [userId, date],
        );
        debugPrint('✅ Mood synced to Supabase.');
      }
    } catch (e) {
      debugPrint('❌ Failed to save mood feedback: $e');
      rethrow;
    }
  }

  // ─── Offline sync ────────────────────────────────────────────────────────────

  Future<void> syncOfflineData() async {
    try {
      if (!await _isOnline()) return;

      final db = await LocalDatabase.instance.database;

      final unsyncedRows = await db.query(
        'sleep_record',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      if (unsyncedRows.isEmpty) {
        debugPrint('✅ All sleep records are already synced.');
        return;
      }

      debugPrint(
          '🔄 Syncing ${unsyncedRows.length} offline sleep records to Supabase...');

      // ✅ FIX 2 (also here): Strip awake_minutes and is_synced from offline batch
      final List<Map<String, dynamic>> toUpsert = unsyncedRows
          .map((row) => _toSupabaseJson(Map<String, dynamic>.from(row)))
          .toList();

      await _client
          .from('sleep_record')
          .upsert(toUpsert, onConflict: 'user_id,date');

      for (final row in unsyncedRows) {
        await db.update(
          'sleep_record',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }

      debugPrint('✅ Offline sleep records synced successfully.');
    } catch (e) {
      debugPrint('❌ syncOfflineData error: $e');
    }
  }
}
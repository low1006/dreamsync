import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:dreamsync/models/sleep_model/sleep_record_model.dart';
import 'package:dreamsync/services/encryption_service.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

class SleepRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final EncryptionService _encryption = EncryptionService.instance;

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<Map<String, dynamic>?> getLatestDailyRecord(String userId) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT *
        FROM sleep_record
        WHERE user_id = ? AND total_minutes > 0
        ORDER BY date DESC
        LIMIT 1
      ''', [userId]);

      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
      return null;
    } catch (e) {
      debugPrint('❌ getLatestDailyRecord error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestRecordForMoodCheck(
      String userId,
      String cutoffDate,
      ) async {
    try {
      final db = await _db;
      final rows = await db.rawQuery('''
        SELECT date, mood_feedback
        FROM sleep_record
        WHERE user_id = ? AND date >= ? AND total_minutes > 0
        ORDER BY date DESC
        LIMIT 1
      ''', [userId, cutoffDate]);

      if (rows.isNotEmpty) return Map<String, dynamic>.from(rows.first);
      return null;
    } catch (e) {
      debugPrint('❌ getLatestRecordForMoodCheck error: $e');
      rethrow;
    }
  }

  Future<List<SleepRecordModel>> getAllSleepRecords(String userId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'sleep_record',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'date ASC',
      );

      return rows
          .map((e) => SleepRecordModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching all sleep records: $e');
      return [];
    }
  }

  Future<List<SleepRecordModel>> getSleepRecordsByDateRange(
      String userId,
      String startDateStr,
      String endDateStr,
      ) async {
    try {
      final db = await _db;
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

  Future<void> saveDailySummary(SleepRecordModel record) async {
    await saveDailySummaries([record]);
  }

  Future<void> saveDailySummaries(List<SleepRecordModel> records) async {
    if (records.isEmpty) return;

    try {
      for (final r in records) {
        final normalized = r.id == null
            ? r.copyWith(id: '${r.userId}_${r.date}')
            : r;

        await LocalDatabase.instance.insertRecord(
          'sleep_record',
          normalized.toJson(),
          isSynced: false,
        );
      }

      debugPrint('✅ ${records.length} sleep record(s) saved locally.');

      final online = await NetworkHelper.hasInternet();
      if (!online) {
        debugPrint('⚠️ Offline mode: sleep sync skipped.');
        return;
      }

      for (final r in records) {
        final normalized = r.id == null
            ? r.copyWith(id: '${r.userId}_${r.date}')
            : r;
        await _syncOneRecord(normalized);
      }
    } catch (e) {
      debugPrint('❌ Failed to save sleep records: $e');
      rethrow;
    }
  }

  Future<void> saveMoodFeedback({
    required String userId,
    required String date,
    required String mood,
  }) async {
    try {
      final db = await _db;
      await db.update(
        'sleep_record',
        {'mood_feedback': mood, 'is_synced': 0},
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
      );

      final online = await NetworkHelper.hasInternet();
      if (!online) {
        debugPrint('⚠️ Offline mode: mood sync skipped.');
        return;
      }

      final rows = await db.query(
        'sleep_record',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final record = SleepRecordModel.fromJson(
          Map<String, dynamic>.from(rows.first),
        );
        await _syncOneRecord(record);
      }

      debugPrint('✅ Mood saved locally + sync attempted.');
    } catch (e) {
      debugPrint('❌ Failed to save mood feedback: $e');
      rethrow;
    }
  }

  Future<void> syncPendingRecords(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: pending sleep sync skipped.');
      return;
    }

    final db = await _db;
    final rows = await db.query(
      'sleep_record',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );

    for (final row in rows) {
      final record = SleepRecordModel.fromJson(Map<String, dynamic>.from(row));
      await _syncOneRecord(record);
    }
  }

  Future<void> _syncOneRecord(SleepRecordModel record) async {
    try {
      final payload = {
        'total_minutes': record.totalMinutes,
        'sleep_score': record.sleepScore,
        'deep_minutes': record.deepMinutes,
        'light_minutes': record.lightMinutes,
        'rem_minutes': record.remMinutes,
        'awake_minutes': record.awakeMinutes,
        'hypnogram_json': record.hypnogramJson,
        'mood_feedback': record.moodFeedback,
      };

      final encrypted = _encryption.encryptData(payload, record.userId);

      await _client.from('sleep_record').upsert({
        'user_id': record.userId,
        'date': record.date,
        'encrypted_payload': encrypted['encrypted_payload'],
        'iv': encrypted['iv'],
      }, onConflict: 'user_id,date');

      await LocalDatabase.instance.markAsSynced(
        'sleep_record',
        record.userId,
        record.date,
      );

      debugPrint('✅ Sleep synced: ${record.date}');
    } catch (e) {
      debugPrint('⚠️ Encrypted sync failed for ${record.date}: $e');
    }
  }
}
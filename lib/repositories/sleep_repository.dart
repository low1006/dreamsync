import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> saveDailySummary(SleepRecordModel record) async {
    await saveDailySummaries([record]);
  }

  Future<void> saveDailySummaries(List<SleepRecordModel> records) async {
    if (records.isEmpty) return;

    final online = await _isOnline();
    final db     = await LocalDatabase.instance.database;

    for (final record in records) {
      try {
        // Check if a record already exists for this date to preserve mood_feedback
        final existing = await db.query(
          'sleep_record',
          columns  : ['mood_feedback'],
          where    : 'user_id = ? AND date = ?',
          whereArgs: [record.userId, record.date],
          limit    : 1,
        );

        // Keep existing mood_feedback if present — never overwrite with null
        final existingMood = existing.isNotEmpty
            ? existing.first['mood_feedback'] as String?
            : null;

        final json = record.toLocalJson();
        if (existingMood != null && existingMood.isNotEmpty) {
          json['mood_feedback'] = existingMood;
        }

        await LocalDatabase.instance.insertRecord(
          'sleep_record',
          json,
          isSynced: false,
        );

        if (online) {
          await _client.from('sleep_record').upsert(
            record.toSupabaseSummaryJson(),
            onConflict: 'user_id,date',
          );

          if (record.id != null) {
            await LocalDatabase.instance.markAsSynced(
              'sleep_record',
              record.id,
            );
          }

          debugPrint('✅ Sleep summary synced: ${record.date}');
        } else {
          debugPrint('💾 Sleep detail saved locally only: ${record.date}');
        }
      } catch (e) {
        debugPrint('❌ Failed saving sleep record ${record.date}: $e');
      }
    }
  }

  Future<void> syncOfflineData() async {
    final unsyncedRecords =
    await LocalDatabase.instance.getUnsyncedRecords('sleep_record');

    if (unsyncedRecords.isEmpty) return;
    if (!await _isOnline()) return;

    debugPrint('🔄 Syncing ${unsyncedRecords.length} offline sleep records...');

    for (final recordJson in unsyncedRecords) {
      try {
        final record = SleepRecordModel.fromLocalJson(
          Map<String, dynamic>.from(recordJson),
        );

        await _client.from('sleep_record').upsert(
          record.toSupabaseSummaryJson(),
          onConflict: 'user_id,date',
        );

        if (record.id != null) {
          await LocalDatabase.instance.markAsSynced(
            'sleep_record',
            record.id,
          );
        }

        debugPrint('✅ Synced record: ${record.id ?? record.date}');
      } catch (e) {
        debugPrint(
          '❌ Failed to sync record ${recordJson['id'] ?? recordJson['date']}: $e',
        );
      }
    }
  }

  Future<List<SleepRecordModel>> getAllSleepRecords(String userId) async {
    try {
      final localRecords =
      await LocalDatabase.instance.getAllByUser('sleep_record', userId);

      return localRecords
          .map(
            (json) => SleepRecordModel.fromLocalJson(
          Map<String, dynamic>.from(json),
        ),
      )
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching all sleep records: $e');
      return [];
    }
  }

  Future<List<SleepRecordModel>> getSleepRecordsByDateRange(
      String userId,
      String startDate,
      String endDate,
      ) async {
    try {
      final localRecords = await LocalDatabase.instance.getRecordsByDateRange(
        userId,
        startDate,
        endDate,
      );

      return localRecords
          .map(
            (json) => SleepRecordModel.fromLocalJson(
          Map<String, dynamic>.from(json),
        ),
      )
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching sleep data range: $e');
      return [];
    }
  }

  /// Save mood feedback for a sleep record.
  /// Updates local SQLite first, then syncs to Supabase if online.
  Future<void> saveMoodFeedback({
    required String userId,
    required String date,
    required String mood,   // 'sad' | 'neutral' | 'happy'
  }) async {
    try {
      final db = await LocalDatabase.instance.database;

      // 1. Update local SQLite
      await db.update(
        'sleep_record',
        {
          'mood_feedback' : mood,
          'is_synced'     : 0,
        },
        where     : 'user_id = ? AND date = ?',
        whereArgs : [userId, date],
      );
      debugPrint('✅ Mood saved locally: $mood for $date');

      // 2. Sync to Supabase if online
      if (await _isOnline()) {
        await _client
            .from('sleep_record')
            .update({'mood_feedback': mood})
            .eq('user_id', userId)
            .eq('date', date);

        await db.update(
          'sleep_record',
          {'is_synced': 1},
          where     : 'user_id = ? AND date = ?',
          whereArgs : [userId, date],
        );
        debugPrint('✅ Mood synced to Supabase: $mood for $date');
      } else {
        debugPrint('📴 Mood queued for sync: $mood for $date');
      }
    } catch (e) {
      debugPrint('❌ saveMoodFeedback: $e');
    }
  }
}
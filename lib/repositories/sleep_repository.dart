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

    for (final record in records) {
      try {
        await LocalDatabase.instance.insertRecord(
          'sleep_record',
          record.toLocalJson(),
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
}
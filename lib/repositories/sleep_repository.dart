import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/sleep_record_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/util/local_database.dart';

class SleepRepository {
  final _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Connectivity helper — single ConnectivityResult (connectivity_plus v5)
  // ---------------------------------------------------------------------------
  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi;
  }

  // ---------------------------------------------------------------------------
  // SAVE — Supabase if online, SQLite if offline
  // ---------------------------------------------------------------------------
  Future<void> saveDailySummary(SleepRecordModel record) async {
    if (await _isOnline()) {
      try {
        await _client.from('sleep_record').upsert(
          record.toJson(),
          onConflict: 'user_id, date',
        );
        debugPrint("✅ Sleep data stored successfully in Supabase!");

        // Cache locally as synced so offline reads work immediately
        await LocalDatabase.instance
            .insertSleepRecord(record.toJson(), isSynced: true);
      } catch (e) {
        debugPrint("❌ Error storing sleep data, saving offline instead: $e");
        await LocalDatabase.instance
            .insertSleepRecord(record.toJson(), isSynced: false);
      }
    } else {
      debugPrint("📴 Offline: Saving sleep data locally.");
      await LocalDatabase.instance
          .insertSleepRecord(record.toJson(), isSynced: false);
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC OFFLINE — push unsynced local records to Supabase when online
  // ---------------------------------------------------------------------------
  Future<void> syncOfflineData() async {
    final unsyncedRecords = await LocalDatabase.instance.getUnsyncedRecords();
    if (unsyncedRecords.isEmpty) return;

    debugPrint("🔄 Syncing ${unsyncedRecords.length} offline records...");

    for (var recordJson in unsyncedRecords) {
      try {
        final supabaseData = Map<String, dynamic>.from(recordJson)
          ..remove('is_synced');

        await _client.from('sleep_record').upsert(
          supabaseData,
          onConflict: 'user_id, date',
        );

        await LocalDatabase.instance.markAsSynced(recordJson['id']);
        debugPrint("✅ Synced record: ${recordJson['id']}");
      } catch (e) {
        debugPrint("❌ Failed to sync record ${recordJson['id']}: $e");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GET ALL — for achievement checks
  // Online  → Supabase (full history)
  // Offline → local SQLite cache
  // ---------------------------------------------------------------------------
  Future<List<SleepRecordModel>> getAllSleepRecords(String userId) async {
    try {
      if (await _isOnline()) {
        debugPrint("🌐 getAllSleepRecords: fetching from Supabase...");
        final response = await _client
            .from('sleep_record')
            .select()
            .eq('user_id', userId)
            .order('date', ascending: true);

        final records = response
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();

        debugPrint("✅ getAllSleepRecords: ${records.length} records from Supabase");
        return records;
      } else {
        debugPrint("📴 getAllSleepRecords: offline, reading from SQLite...");
        final localRecords =
        await LocalDatabase.instance.getAllRecords(userId);
        final records = localRecords
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();

        debugPrint("✅ getAllSleepRecords: ${records.length} records from SQLite");
        return records;
      }
    } catch (e) {
      debugPrint("❌ Error fetching all sleep records: $e");

      // Last resort — try local cache even if online fetch failed
      try {
        final localRecords =
        await LocalDatabase.instance.getAllRecords(userId);
        return localRecords
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GET BY DATE RANGE — for weekly chart
  // Online  → Supabase
  // Offline → local SQLite cache
  // ---------------------------------------------------------------------------
  Future<List<SleepRecordModel>> getSleepRecordsByDateRange(
      String userId, String startDate, String endDate) async {
    try {
      if (await _isOnline()) {
        debugPrint("🌐 getSleepRecordsByDateRange: fetching from Supabase...");
        final response = await _client
            .from('sleep_record')
            .select()
            .eq('user_id', userId)
            .gte('date', startDate)
            .lte('date', endDate)
            .order('date', ascending: true);

        final records = response
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();

        debugPrint("✅ getSleepRecordsByDateRange: ${records.length} records from Supabase");
        return records;
      } else {
        debugPrint("📴 getSleepRecordsByDateRange: offline, reading from SQLite...");
        final localRecords = await LocalDatabase.instance
            .getRecordsByDateRange(userId, startDate, endDate);
        final records = localRecords
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();

        debugPrint("✅ getSleepRecordsByDateRange: ${records.length} records from SQLite");
        return records;
      }
    } catch (e) {
      debugPrint("❌ Error fetching sleep data range: $e");

      // Last resort — try local cache even if online fetch failed
      try {
        final localRecords = await LocalDatabase.instance
            .getRecordsByDateRange(userId, startDate, endDate);
        return localRecords
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();
      } catch (_) {
        return [];
      }
    }
  }
}
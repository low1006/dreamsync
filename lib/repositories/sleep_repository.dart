import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/sleep_record_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/util/local_database.dart';

class SleepRepository {
  final _client = Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Connectivity helper — with 2-second timeout to prevent UI hanging!
  // ---------------------------------------------------------------------------
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity().timeout(const Duration(seconds: 2));
      return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
    } catch (_) {
      return false; // Automatically assume offline if check hangs
    }
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

        // FIXED: Use the generic insertRecord method
        await LocalDatabase.instance.insertRecord('sleep_record', record.toJson(), isSynced: true);
      } catch (e) {
        debugPrint("❌ Error storing sleep data, saving offline instead: $e");
        await LocalDatabase.instance.insertRecord('sleep_record', record.toJson(), isSynced: false);
      }
    } else {
      debugPrint("📴 Offline: Saving sleep data locally.");
      await LocalDatabase.instance.insertRecord('sleep_record', record.toJson(), isSynced: false);
    }
  }

  // ---------------------------------------------------------------------------
  // SYNC OFFLINE — push unsynced local records to Supabase when online
  // ---------------------------------------------------------------------------
  Future<void> syncOfflineData() async {
    // FIXED: Added 'sleep_record' table name argument
    final unsyncedRecords = await LocalDatabase.instance.getUnsyncedRecords('sleep_record');
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

        // FIXED: Added 'sleep_record' table name argument
        await LocalDatabase.instance.markAsSynced('sleep_record', recordJson['id']);
        debugPrint("✅ Synced record: ${recordJson['id']}");
      } catch (e) {
        debugPrint("❌ Failed to sync record ${recordJson['id']}: $e");
      }
    }
  }

  // ---------------------------------------------------------------------------
  // GET ALL — for achievement checks
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

        // Cache data locally so achievements work when offline tomorrow
        for (var json in response) {
          await LocalDatabase.instance.insertRecord('sleep_record', json, isSynced: true);
        }

        debugPrint("✅ getAllSleepRecords: ${records.length} records from Supabase");
        return records;
      } else {
        debugPrint("📴 getAllSleepRecords: offline, reading from SQLite...");

        // FIXED: Changed to getAllByUser
        final localRecords = await LocalDatabase.instance.getAllByUser('sleep_record', userId);
        final records = localRecords
            .map((json) => SleepRecordModel.fromJson(json))
            .toList();

        debugPrint("✅ getAllSleepRecords: ${records.length} records from SQLite");
        return records;
      }
    } catch (e) {
      debugPrint("❌ Error fetching all sleep records: $e");

      try {
        // FIXED: Changed to getAllByUser
        final localRecords = await LocalDatabase.instance.getAllByUser('sleep_record', userId);
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
import 'package:flutter/material.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/util/local_database.dart';

class DailyActivityRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity()
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      return result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi;
    } catch (_) {
      return false;
    }
  }

  Future<DailyActivityModel?> getTodayActivity(String userId, String date) async {
    if (await _isOnline()) {
      try {
        debugPrint("🌐 Online: Fetching daily activity from Supabase...");
        final response = await _client
            .from('daily_activities')
            .select()
            .eq('user_id', userId)
            .eq('date', date);

        if (response.isEmpty) {
          return await _getLocalActivity(userId, date);
        }

        final data = Map<String, dynamic>.from(response.first);
        await _cacheLocally(data, userId);
        return DailyActivityModel.fromJson(data);
      } catch (e) {
        debugPrint("❌ Error fetching activity: $e");
        return _getLocalActivity(userId, date);
      }
    } else {
      debugPrint("📴 Offline: Reading daily activity from SQLite...");
      return _getLocalActivity(userId, date);
    }
  }

  Future<DailyActivityModel?> _getLocalActivity(String userId, String date) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query(
        'daily_activity',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return _fromLocalRow(rows.first);
    } catch (e) {
      debugPrint("❌ Error reading local activity: $e");
      return null;
    }
  }

  Future<List<DailyActivityModel>> getActivityByDateRange(
      String userId,
      String startDate,
      String endDate,
      ) async {
    if (await _isOnline()) {
      try {
        debugPrint("🌐 Online: Fetching activity date range from Supabase...");
        final response = await _client
            .from('daily_activities')
            .select()
            .eq('user_id', userId)
            .gte('date', startDate)
            .lte('date', endDate)
            .order('date', ascending: true);

        final rows = (response as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        final localRows =
        rows.map((e) => _toLocalRowFromServer(e, userId)).toList();

        await LocalDatabase.instance.insertRecords(
          'daily_activity',
          localRows,
          isSynced: true,
        );

        return rows.map((e) => DailyActivityModel.fromJson(e)).toList();
      } catch (e) {
        debugPrint("❌ Error fetching activity date range: $e");
        return _getLocalActivityRange(userId, startDate, endDate);
      }
    } else {
      debugPrint("📴 Offline: Reading activity date range from SQLite...");
      return _getLocalActivityRange(userId, startDate, endDate);
    }
  }

  Future<List<DailyActivityModel>> _getLocalActivityRange(
      String userId,
      String startDate,
      String endDate,
      ) async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query(
        'daily_activity',
        where: 'user_id = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startDate, endDate],
        orderBy: 'date ASC',
      );

      return rows.map(_fromLocalRow).toList();
    } catch (e) {
      debugPrint("❌ Error reading local activity range: $e");
      return [];
    }
  }

  Future<void> saveActivity(DailyActivityModel record) async {
    final localRow = _toLocalRowFromModel(record);

    await LocalDatabase.instance.insertRecord(
      'daily_activity',
      localRow,
      isSynced: false,
    );

    debugPrint("💾 Local daily activity saved: ${record.date}");

    if (await _isOnline()) {
      try {
        await _client
            .from('daily_activities')
            .upsert(_toServerRowFromModel(record), onConflict: 'user_id, date');

        await LocalDatabase.instance.markAsSynced(
          'daily_activity',
          localRow['id'],
        );

        debugPrint("✅ Daily activity synced to Supabase: ${record.date}");
      } catch (e) {
        debugPrint("❌ Error storing daily activity online: $e");
      }
    } else {
      debugPrint("📴 Offline: Daily activity queued for sync.");
    }
  }

  Future<void> ensureTodayRow(String userId, String date) async {
    final existing = await _getLocalActivity(userId, date);
    if (existing != null) return;

    await saveActivity(
      DailyActivityModel(
        userId: userId,
        date: date,
        exerciseMinutes: 0,
        foodCalories: 0,
        screenTimeMinutes: 0,
      ),
    );
  }

  Future<void> syncOfflineData() async {
    if (!await _isOnline()) return;

    final unsynced =
    await LocalDatabase.instance.getUnsyncedRecords('daily_activity');

    if (unsynced.isEmpty) return;

    for (final row in unsynced) {
      try {
        final data = {
          'user_id': row['user_id'],
          'date': row['date'],
          'exercise_minutes': row['exercise_minutes'],
          'food_calories': row['food_calories'],
          'screen_time_minutes': row['screen_time_minutes'],
        };

        await _client
            .from('daily_activities')
            .upsert(data, onConflict: 'user_id, date');

        await LocalDatabase.instance.markAsSynced('daily_activity', row['id']);
        debugPrint("✅ Synced offline daily_activity: ${row['date']}");
      } catch (e) {
        debugPrint("❌ Failed to sync daily_activity row: $e");
      }
    }
  }

  Future<void> _cacheLocally(
      Map<String, dynamic> supabaseRow,
      String userId,
      ) async {
    try {
      final local = _toLocalRowFromServer(supabaseRow, userId);

      await LocalDatabase.instance.insertRecord(
        'daily_activity',
        local,
        isSynced: true,
      );
    } catch (e) {
      debugPrint("❌ _cacheLocally error: $e");
    }
  }

  Map<String, dynamic> _toServerRowFromModel(DailyActivityModel record) {
    return {
      'user_id': record.userId,
      'date': record.date,
      'exercise_minutes': record.exerciseMinutes,
      'food_calories': record.foodCalories,
      'screen_time_minutes': record.screenTimeMinutes,
    };
  }

  Map<String, dynamic> _toLocalRowFromModel(DailyActivityModel record) {
    return {
      'id': '${record.userId}_${record.date}',
      'user_id': record.userId,
      'date': record.date,
      'exercise_minutes': record.exerciseMinutes,
      'food_calories': record.foodCalories,
      'screen_time_minutes': record.screenTimeMinutes,
    };
  }

  Map<String, dynamic> _toLocalRowFromServer(
      Map<String, dynamic> row,
      String userId,
      ) {
    final date = row['date']?.toString() ?? '';

    return {
      'id': '${userId}_$date',
      'user_id': userId,
      'date': date,
      'exercise_minutes': (row['exercise_minutes'] as num?)?.toInt() ?? 0,
      'food_calories': (row['food_calories'] as num?)?.toInt() ?? 0,
      'screen_time_minutes': (row['screen_time_minutes'] as num?)?.toInt() ?? 0,
    };
  }

  DailyActivityModel _fromLocalRow(Map<String, dynamic> row) {
    return DailyActivityModel.fromJson({
      'user_id': row['user_id'],
      'date': row['date'],
      'exercise_minutes': row['exercise_minutes'],
      'food_calories': row['food_calories'],
      'screen_time_minutes': row['screen_time_minutes'],
    });
  }
}
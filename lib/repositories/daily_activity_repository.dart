import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:dreamsync/models/daily_activity_model.dart';
import 'package:dreamsync/services/encryption_service.dart';
import 'package:dreamsync/util/local_database.dart';
import 'package:dreamsync/util/network_helper.dart';

class DailyActivityRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final EncryptionService _encryption = EncryptionService.instance;

  Future<Database> get _db async => LocalDatabase.instance.database;

  Future<DailyActivityModel?> getTodayActivity(String userId, String date) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'daily_activities',
        where: 'user_id = ? AND date = ?',
        whereArgs: [userId, date],
        limit: 1,
      );

      if (rows.isEmpty) return null;
      return _fromLocalRow(rows.first);
    } catch (e) {
      debugPrint('❌ Error reading local activity: $e');
      return null;
    }
  }

  Future<List<DailyActivityModel>> getActivityByDateRange(
      String userId,
      String startDate,
      String endDate,
      ) async {
    try {
      final db = await _db;
      final rows = await db.query(
        'daily_activities',
        where: 'user_id = ? AND date >= ? AND date <= ?',
        whereArgs: [userId, startDate, endDate],
        orderBy: 'date ASC',
      );

      return rows.map(_fromLocalRow).toList();
    } catch (e) {
      debugPrint('❌ Error reading local activity range: $e');
      return [];
    }
  }

  Future<void> saveActivity(DailyActivityModel record) async {
    try {
      final normalized = record.id == null
          ? record.copyWith(id: '${record.userId}_${record.date}')
          : record;

      await LocalDatabase.instance.insertRecord(
        'daily_activities',
        _toLocalRow(normalized),
        isSynced: false,
      );
      debugPrint('💾 Daily activity saved locally: ${normalized.date}');

      final online = await NetworkHelper.hasInternet();
      if (!online) {
        debugPrint('⚠️ Offline mode: activity sync skipped.');
        return;
      }

      await _syncOneRecord(normalized);
    } catch (e) {
      debugPrint('❌ Error saving daily activity: $e');
      rethrow;
    }
  }

  Future<void> ensureTodayRow(String userId, String date) async {
    final existing = await getTodayActivity(userId, date);
    if (existing != null) return;

    await saveActivity(
      DailyActivityModel(
        id: '${userId}_$date',
        userId: userId,
        date: date,
        exerciseMinutes: 0,
        foodCalories: 0,
        screenTimeMinutes: 0,
        burnedCalories: 0,
        caffeineIntakeMg: 0,
        sugarIntakeG: 0,
        alcoholIntakeG: 0,
      ),
    );
  }

  Future<void> syncPendingRecords(String userId) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      debugPrint('⚠️ Offline mode: pending activity sync skipped.');
      return;
    }

    final db = await _db;
    final rows = await db.query(
      'daily_activities',
      where: 'user_id = ? AND is_synced = 0',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );

    for (final row in rows) {
      await _syncOneRecord(_fromLocalRow(row));
    }
  }

  Future<void> _syncOneRecord(DailyActivityModel record) async {
    try {
      final payload = {
        'exercise_minutes': record.exerciseMinutes,
        'food_calories': record.foodCalories,
        'screen_time_minutes': record.screenTimeMinutes,
        'burned_calories': record.burnedCalories,
        'caffeine_intake_mg': record.caffeineIntakeMg,
        'sugar_intake_g': record.sugarIntakeG,
        'alcohol_intake_g': record.alcoholIntakeG,
      };

      final encrypted = _encryption.encryptData(payload, record.userId);

      await _client.from('daily_activities').upsert({
        'user_id': record.userId,
        'date': record.date,
        'encrypted_payload': encrypted['encrypted_payload'],
        'iv': encrypted['iv'],
      }, onConflict: 'user_id,date');

      await LocalDatabase.instance.markAsSynced(
        'daily_activities',
        record.userId,
        record.date,
      );

      debugPrint('✅ Activity encrypted + synced: ${record.date}');
    } catch (e) {
      debugPrint('⚠️ Encrypted activity sync failed for ${record.date}: $e');
    }
  }

  Map<String, dynamic> _toLocalRow(DailyActivityModel record) {
    return {
      'activity_id': record.id ?? '${record.userId}_${record.date}',
      'user_id': record.userId,
      'date': record.date,
      'exercise_minutes': record.exerciseMinutes,
      'food_calories': record.foodCalories,
      'screen_time_minutes': record.screenTimeMinutes,
      'burned_calories': record.burnedCalories,
      'caffeine_intake_mg': record.caffeineIntakeMg,
      'sugar_intake_g': record.sugarIntakeG,
      'alcohol_intake_g': record.alcoholIntakeG,
    };
  }

  DailyActivityModel _fromLocalRow(Map<String, dynamic> row) {
    return DailyActivityModel.fromJson({
      'activity_id': row['activity_id'],
      'user_id': row['user_id'],
      'date': row['date'],
      'exercise_minutes': row['exercise_minutes'],
      'food_calories': row['food_calories'],
      'screen_time_minutes': row['screen_time_minutes'],
      'burned_calories': row['burned_calories'],
      'caffeine_intake_mg': row['caffeine_intake_mg'],
      'sugar_intake_g': row['sugar_intake_g'],
      'alcohol_intake_g': row['alcohol_intake_g'],
    });
  }
}
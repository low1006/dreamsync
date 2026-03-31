import 'package:flutter/foundation.dart'; // Required for debugPrint
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:dreamsync/models/sleep_model/sleep_recommendation_cache_model.dart';
import 'package:dreamsync/util/local_database.dart';

class RecommendationCacheRepository {
  Future<void> save(SleepRecommendationCacheModel model) async {
    debugPrint('💾 [RecommendationCache] Saving recommendation for date: ${model.date} (user: ${model.userId})...');
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'sleep_recommendation',
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('✅ [RecommendationCache] Save successful.');
  }

  Future<SleepRecommendationCacheModel?> getLatestRecommendation(String userId) async {
    debugPrint('🔍 [RecommendationCache] Fetching latest recommendation for user: $userId...');
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'sleep_recommendation',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC', // Gets the most recent recommendation
      limit: 1,
    );

    if (rows.isEmpty) {
      debugPrint('⚠️ [RecommendationCache] No recommendation found for user: $userId.');
      return null;
    }

    debugPrint('✅ [RecommendationCache] Found latest recommendation from date: ${rows.first['date']}');
    return SleepRecommendationCacheModel.fromMap(rows.first);
  }

  Future<SleepRecommendationCacheModel?> getToday({
    required String userId,
    required String date,
  }) async {
    debugPrint('🔍 [RecommendationCache] Checking for existing recommendation on $date...');
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'sleep_recommendation',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );

    if (rows.isEmpty) {
      debugPrint('⏭️ [RecommendationCache] No cache found for $date. A new one will be generated.');
      return null;
    }

    debugPrint('✅ [RecommendationCache] Cache HIT for $date!');
    return SleepRecommendationCacheModel.fromMap(rows.first);
  }

  Future<void> deleteToday({
    required String userId,
    required String date,
  }) async {
    debugPrint('🗑️ [RecommendationCache] Deleting recommendation for date: $date...');
    final db = await LocalDatabase.instance.database;
    final count = await db.delete(
      'sleep_recommendation',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
    debugPrint('✅ [RecommendationCache] Deleted $count record(s).');
  }
}